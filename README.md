# Introduction
This is the Git repository that contains all the configuration for my home-based Kubernetes cluster. The cluster is used to host a number of self-hosted services mostly focused on movies and TV along with all the supporting software. This repository is fully gitops-optimized and is managed by [ArgoCD](https://argoproj.github.io/).

This cluster is built on Sidero Lab's [Talos OS](https://github.com/siderolabs/talos) using on-prem [Omni](https://github.com/siderolabs/omni) for low-level cluster management.

My cluster runs on 6 mini-PCs named `NUC1` through to `NUC6`. NUC1-NUC3 are used as control-plane nodes, while NUC4-NUC6 are workers. While this repo can be used for any environment, some workloads require (or benefit from) hardware that is specific to certain named nodes. The manifests are configured for this. For example:
* [Plex](/manifests/media-apps/plex) works best on nodes with Intel GPUs for efficient transcoding. NUC5 and NUC6 have the N100 processor, which is best for transcoding, but can run on NUC3 or NUC4 which run the older N95 if necessary.
* [Home Assistant](/manifests/homeops/homeassist) requires access to USB-attached resources such as Zigbee/Z-Wave controllers and a UPS monitor. Obviously, these are plugged into one node, which the pods require access to (currently NUC4).
* [MariaDB](/manifests/database/mariadb) and [PostgreSQL](/manifests/database/postgresql) requires local storage, which is available on NUC4-NUC6.
* [Longhorn](/manifests/system/longhorn) is configured to only run on NUC4-NUC6 in order to keep workloads off the control-plane nodes

## Related Repositories
Links to my other repositories mentioned or used in this repo:
- [K8s Bootstrap](https://github.com/kenlasko/k8s-bootstrap): Bootstraps Kubernetes clusters with essential apps using Terraform/OpenTofu
- [NetbootXYZ](https://github.com/kenlasko/docker-rpi1/tree/main/netbootxyz): Simplified PXE boot setup for Omni-managed Talos nodes.
- [NixOS](https://github.com/kenlasko/nixos-wsl): A declarative OS modified to support my Kubernetes cluster
- [Omni](https://github.com/kenlasko/omni): Creates and manages the Kubernetes clusters.

## Folder structure
The relevent folders are laid out in the following manner:
- [argocd](/argocd): the "brains" of the operation that controls the creation/management of all resources
- [argocd-apps](/argocd-apps): where all the ArgoCD application definitions reside. This basically tells ArgoCD where to find the relevant manifests for each application. Broken down by type (app, database, system etc). The ArgoCD applications reference manifests stored in the [manifests](/manifests) folder.
- [docs](/docs): documents
- [manifests](/manifests): all the manifests used by each application. Broken down by type (app, database, system etc) then by name. Used by [ArgoCD applications](/argocd-apps).
- [helm](/helm/baseline): where I keep my universal Helm chart for most non-Helm based applications
- [scripts](/scripts): a mish-mash of scripts used for various purposes

## Software Updates
All software updates (excluding Kubernetes and OS) are managed via [Renovate](https://github.com/renovatebot/renovate). Renovate watches the Github repo and checks for software version updates on any Helm chart, ArgoCD application manifest or deployment manifest. If an update is found, Renovate will update the version in the repo and let ArgoCD handle the actual upgrade. All updates are logged in the repo as commits.

The configuration for Renovate is stored in [renovate.json](/renovate.json). The dashboard is available at https://developer.mend.io/github/kenlasko

Renovate is set to automatically and silently upgrade every software package EXCEPT for the following:
* [Cilium](/manifests/network/cilium)
* [Longhorn](/manifests/system/longhorn)
* [MariaDB](/manifests/database/mariadb)
* [PostgreSQL](/manifests/database/postgresql)

When upgrades for the above packages are found, Renovate will create a pull request that has to be manually approved (or denied). Once approved, ArgoCD manages the actual upgrade as with any other software.

# Cluster Installation Prerequisites
SideroLabs Omni must be ready to go. Installation steps are in the repository link below:
[Omni On-Prem installation and configuration](https://github.com/kenlasko/omni/)

You will need a workstation (preferably Linux-based) with several tools to get things rolling. Choose one of the following approaches:
- [Workstation Prep Instructions for Ubuntu-based distributions](/docs/WORKSTATION.md)
- [NixOS Workstation Build](https://github.com/kenlasko/nixos-wsl/)

Most of the workloads use NAS-based storage for persistent data. The 
[NAS Configuration](/docs/NASCONFIG.md) doc shows the configuration for the various things that need to be ready before the cluster can be spun up.

# Kubernetes Install
Ensure that Omnictl/Talosctl is ready to go. Installation steps are [in my Omni repo](https://github.com/kenlasko/omni/).

## Install Kubernetes
This guide assumes you're using a NixOS distribution that is configured to securely store and present all required certificates. For more information, see [my NixOS repo](https://github.com/kenlasko/nixos-wsl/).

1. Make sure all Talos nodes are in maintenance mode and appearing in [Omni](https://omni.ucdialplans.com). Use network boot via [NetBootXYZ](https://github.com/kenlasko/pxeboot/) to boot nodes into Talos maintenance mode.
2. Create cluster via `omnictl`:
```bash
omnictl cluster template sync -f ~/omni/cluster-template-home.yaml
```
3. Set the proper context with kubectl and verify you see the expected nodes. It will take a few minutes before `kubectl get nodes` returns data. Pods will not start, because of the lack of a CNI, which we will install with Terraform/OpenTofu.
```bash
kubectl config use-context omni-home
kubectl get nodes
```
4. Once `kubectl get nodes` returns node info, [bootstrap the cluster](https://github.com/kenlasko/k8s-bootstrap) by installing Cilium, Cert-Manager, External Secrets Operator and ArgoCD via OpenTofu/Terraform
```bash
cd ~/terraform
tf workspace new home
tf workspace select home
tf init
tf apply
```
Monitor the status of the Terraform install by running `kubectl get pods -A`. It will take several minutes for Cilium, Cert-Manager, External Secrets Operator and ArgoCD to start.

## Argo App Install
Once Terraform/OpenTofu bootstraps the cluster, ArgoCD should take over and install all the remaining applications. ArgoCD sync-waves should install apps in the correct order. The full list of apps and their relative order can be found [here](/argocd-apps).

## Get Kubernetes token for token-based authentication
Cluster connectivity can be done via OIDC through Omni, but its a good idea to have secondary access through standard token-based authentication. The cluster is configured for this using [Talos Shared VIP](https://www.talos.dev/v1.9/talos-guides/network/vip/), which makes cluster API access via a shared IP that is advertised by one of the control plane nodes. The address for this is `https://192.168.1.11:6443`.

The service account is configured via [kubeapi-serviceaccount.yaml](/manifests/argocd/kubeapi-serviceaccount.yaml) and gets its token when the service account is created.

For configuring your `kubeconfig` file with the token-based authentication information, you need the service account token as well as the certificate authority public certificate. To get these, run:
```bash
echo
echo "Service Account Token:"
kubectl -n kube-system get secret kubeapi-service-account-secret -o jsonpath="{.data.token}" | base64 -d; echo
echo
echo "Certificate Authority:"
kubectl -n kube-system get secret kubeapi-service-account-secret -o jsonpath="{.data.ca\.crt}"
```

Add these to your `.kube/config` file like this:
```yaml
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
```bash
# To use OIDC
kubectl config use-context omni-home

# To use the token
kubectl config use-context home
```

# Commit Pre-Check
This repository makes use of [pre-commit](https://pre-commit.com) to guard against accidental secret commits. When you attempt a commit, Pre-Commit will check for secrets and block the commit if one is found. It is currently using [GitGuardian](https://dashboard.gitguardian.com) [ggshield](https://www.gitguardian.com/ggshield) for secret validation. Requires a GitGuardian account, which does offer a free tier for home use.

## Requirements
Requires installation of the following programs:
* ggshield
* pre-commit

In my case, this is handled by [NixOS](https://github.com/kenlasko/nixos). Otherwise, install via:
```bash
sudo apt install python3-venv -y
pip install pre-commit
pip install pipx
pipx install ggshield
```

## Configuration
1. Create a file called `.pre-commit-config.yaml` and place in the root of your repository
2. Populate the file according to your desired platform (ggshield shown):
```yaml
repos:
  - repo: https://github.com/GitGuardian/ggshield
    rev: v1.37.0
    hooks:
      - id: ggshield
```
3. Run the following command:
```bash
pre-commit install
```
4. For ggshield, login to your GitGuardian account. Only required once.
```bash
# Local or WSL machine
ggshield auth login

# Remote SSH session
ggshield auth login --method token
```

## Handy Commands
Scan a repository before onboarding:
```bash
ggshield secret scan path <PathName> --recursive --use-gitignore
```


# Handy commands to know
## Check for open port without tools
Many container images do not have any tools like `nc` to check network port connectivity. This handy command will allow you to do that with just `echo`
```bash
(echo > /dev/tcp/<servicename>/<port>) >/dev/null 2>&1 && echo "It's up" || echo "It's down"
```

## Validate Kustomize manifests
```
kustomize build k8s/manifests/apps/adguard/overlays/home/ --enable-helm --load-restrictor LoadRestrictionsNone
```

## Validate Homegrown Helm Chart
```
helm template plex ~/k8s/helm/baseline -n media-apps -f ~/k8s/manifests/media-tools/plex/values.yaml > ~/chart-test.yaml
```