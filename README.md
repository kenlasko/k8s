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
[Workstation Prep Instructions](/docs/WORKSTATION.md)

Most of the workloads use NAS-based storage for persistent data. This doc shows the configuration for the various things that need to be ready before the cluster can be spun up:
[NAS Configuration](/docs/NASCONFIG.md)

# Kubernetes Install
Ensure that Omnictl/Talosctl is ready to go. Installation steps are [here](https://github.com/kenlasko/omni/).

## Install Kubernetes
1. Copy `default-sealing-key.yaml` and `global-sealed-secrets-key.yaml` from Onedrive Vault `certificates` folder to `/home/ken`
2. Make sure all Talos nodes are in maintenance mode and appearing in [Omni](https://omni.ucdialplans.com). Use network boot via [NetBootXYZ](https://github.com/kenlasko/pxeboot/) to boot nodes into Talos maintenance mode.
3. Create cluster via `omnictl`:
```
omnictl cluster template sync -f ~/omni/cluster-template-home.yaml
```
4. Set the proper context with kubectl and verify you see the expected nodes
```
kubectl config use-context omni-home
kubectl get nodes
```
5. Install Cilium, Cert-Manager, Sealed-Secrets and ArgoCD
```
ansible-playbook ~/k8s/ansible/k8s-apps.yaml
```

## Argo App Install Order
ArgoCD sync-waves should install apps in the correct order. The full list of apps and their relative order can be found [here](/argocd-apps).

## Get Kubernetes token
```
kubectl -n kube-system get secret kubeapi-service-account-secret -o jsonpath="{.data.token}" | base64 -d; echo
```

# Handy commands to know
## Check for open port without tools
Many container images do not have any tools like `nc` to check network port connectivity. This handy command will allow you to do that with just `echo`
```
(echo > /dev/tcp/<servicename>/<port>) >/dev/null 2>&1 && echo "It's up" || echo "It's down"
```