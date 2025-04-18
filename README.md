# Introduction
This is the Git repository that contains all the configuration for my home-based Kubernetes cluster. The cluster is used to host a number of self-hosted services mostly focused on movies and TV along with all the supporting software.

This cluster is built on Sidero Lab's [Talos OS](https://github.com/siderolabs/talos) using on-prem [Omni](https://github.com/siderolabs/omni) for cluster management.

My cluster runs on 6 mini-PCs named NUC1 through to NUC6. NUC1-NUC3 are used as control-plane nodes, while NUC4-NUC6 are workers. While this repo can be used for any environment, some workloads require hardware that is specific to certain named nodes. The manifests are configured for this. For example:
* [Plex](/manifests/media-apps/plex) requires nodes with Intel GPUs for efficient transcoding. NUC5 and NUC6 have the N100 processor, which is best for transcoding, but can run on NUC3 or NUC4 which run the older N95 if necessary.
* [Home Assistant](/manifests/homeops/homeassist) requires access to USB-attached resources such as Zigbee/Z-Wave controllers and a UPS monitor. Obviously, these are plugged into one node, which the pods require access to (currently NUC4).
* [MariaDB](/manifests/database/mariadb) requires local storage, which is available on NUC4-NUC6.
* [Longhorn](/manifests/system/longhorn) is configured to only run on NUC4-NUC6 in order to keep workloads off the control-plane nodes

## Software Updates
All software updates (excluding Kubernetes and OS) are managed via [Renovate](https://github.com/renovatebot/renovate). Renovate watches the Github repo and checks for software version updates on any Helm chart, ArgoCD application manifest or deployment manifest. If an update is found, Renovate will update the version in the repo and let ArgoCD handle the actual upgrade. All updates are logged in the repo as commits.

The configuration for Renovate is stored in [renovate.json](/renovate.json). The dashboard is available at https://developer.mend.io/github/kenlasko

Renovate is set to automatically and silently upgrade every software package EXCEPT for the following:
* [Cilium](/manifests/network/cilium)
* [Longhorn](/manifests/system/longhorn)
* [MariaDB](/manifests/database/mariadb)

When upgrades for the above packages are found, Renovate will create a pull request that has to be manually approved (or denied). Once approved, ArgoCD manages the actual upgrade as with any other software.

# Cluster Installation Prerequisites
SideroLabs Omni must be ready to go. Installation steps are in the repository link below:
[Omni On-Prem installation and configuration](https://github.com/kenlasko/omni/)

You will need a workstation (preferably Linux-based) with several tools to get things rolling:
- [Workstation Prep Instructions for Ubuntu-based distributions](/docs/WORKSTATION.md)
- [NixOS Workstation Build](https://github.com/kenlasko/nixos-wsl/)

Most of the workloads use NAS-based storage for persistent data. This doc shows the configuration for the various things that need to be ready before the cluster can be spun up:
[NAS Configuration](/docs/NASCONFIG.md)

# Kubernetes Install
Ensure that Omnictl/Talosctl is ready to go. Installation steps are [in my Omni repo](https://github.com/kenlasko/omni/).

## Install Kubernetes
This guide assumes you're using a NixOS distribution that is configured to securely store and present all required certificates. For more information, see [my NixOS repo](https://github.com/kenlasko/nixos-wsl/).

1. Make sure all Talos nodes are in maintenance mode and appearing in [Omni](https://omni.ucdialplans.com). Use network boot via [NetBootXYZ](https://github.com/kenlasko/pxeboot/) to boot nodes into Talos maintenance mode.
2. Create cluster via `omnictl`:
```
omnictl cluster template sync -f ~/omni/cluster-template-home.yaml
```
3. Set the proper context with kubectl and verify you see the expected nodes
```
kubectl config use-context omni-home
kubectl get nodes
```
4. [Bootstrap cluster](https://github.com/kenlasko/k8s-bootstrap) by installing Cilium, Cert-Manager, Sealed-Secrets and ArgoCD via OpenTofu/Terraform
```
cd ~/terraform
tf workspace new home
tf workspace select home
tf init
tf apply
```

## Argo App Install Order
ArgoCD sync-waves should install apps in the correct order. The full list of apps and their relative order can be found [here](/argocd-apps).

## Get Kubernetes token for token-based authentication
Cluster connectivity can be done via OIDC through Omni, but its a good idea to have secondary access through standard token-based authentication. The cluster is configured for this using [Talos Shared VIP](https://www.talos.dev/v1.9/talos-guides/network/vip/), which makes cluster API access via a shared IP that is advertised by one of the control plane nodes. The address for this is `https://192.168.1.11:6443`.

The service account is configured via [kubeapi-serviceaccount.yaml](/manifests/argocd/kubeapi-serviceaccount.yaml) and gets its token when the service account is created.

For configuring your `kubeconfig` file with the token-based authentication information, you need the service account token as well as the certificate authority public certificate. To get these, run:
```
echo
echo "Service Account Token:"
kubectl -n kube-system get secret kubeapi-service-account-secret -o jsonpath="{.data.token}" | base64 -d; echo
echo
echo "Certificate Authority:"
kubectl -n kube-system get secret kubeapi-service-account-secret -o jsonpath="{.data.ca\.crt}"
```

Add these to your `.kube/config` file like this:
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: 
    *********************************** ADD-CERT-AUTH-BASE64-STRING-HERE ***********************************
    server: https://192.168.1.11:6443
  name: home
- cluster:
    server: https://omni.ucdialplans.com:8100/
  name: omni-home
contexts:
- context:
    cluster: home
    user: home-user
  name: home
- context:
    cluster: omni-home
    user: onprem-omni-home-ken.lasko@gmail.com
  name: omni-home
current-context: home
kind: Config
preferences: {}
users:
- name: home-user
  user:
    token: *********************************** ADD-SERVICE-ACCOUNT-TOKEN-HERE ***********************************
- name: onprem-omni-home-ken.lasko@gmail.com
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://omni.ucdialplans.com/oidc
      - --oidc-client-id=native
      - --browser-command=wslview
      - --oidc-extra-scope=cluster:home
      command: kubectl
      env: null
      interactiveMode: IfAvailable
      provideClusterInfo: false
```

Switch context between the OIDC-based authenticated access and the token-based access with:
```
# To use OIDC
kubectl config use-context omni-home

# To use the token
kubectl config use-context home
```

# Commit Pre-Check
This repository makes use of [pre-commit](https://pre-commit.com) to guard against accidental secret commits. It is currently using [GitGuardian](https://dashboard.gitguardian.com) [ggshield](https://www.gitguardian.com/ggshield) for secret validation. Requires a GitGuardian account, which does offer a free tier for home use.

## Requirements
Requires installation of the following programs:
* ggshield
* pre-commit

In my case, this is handled by [NixOS](https://github.com/kenlasko/nixos)

## Configuration
1. Create a file called `.pre-commit-config.yaml` and place in the root of your repository
2. Populate the file according to your desired platform (ggshield shown):
```
repos:
  - repo: https://github.com/GitGuardian/ggshield
    rev: v1.37.0
    hooks:
      - id: ggshield
```
3. Run the following command:
```
pre-commit install
```
4. For ggshield, login to your GitGuardian account. Only required once.
```
ggshield auth login
```


# Handy commands to know
## Check for open port without tools
Many container images do not have any tools like `nc` to check network port connectivity. This handy command will allow you to do that with just `echo`
```
(echo > /dev/tcp/<servicename>/<port>) >/dev/null 2>&1 && echo "It's up" || echo "It's down"
```