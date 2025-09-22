# Introduction
This is the Git repository that contains all the configuration for my multiple homelab Kubernetes clusters. The clusters are used to host a number of self-hosted services mostly focused on movies and TV along with all the supporting software. This repository is fully gitops-optimized and is managed by [ArgoCD](https://argoproj.github.io/).

The clusters are built on Sidero Lab's [Talos OS](https://github.com/siderolabs/talos) using on-prem [Omni](https://github.com/siderolabs/omni) for low-level cluster management.

## Cluster Descriptions
### Home Cluster
My home cluster runs on 7 mini-PCs named `NUC1` through to `NUC7`. NUC1-NUC3 are used as control-plane nodes, while NUC4-NUC7 are workers. While this repo can be used for any environment, some workloads require (or benefit from) hardware that is specific to certain named nodes. The manifests are configured for this. For example:
* [Plex](/manifests/media-apps/plex) works best on nodes with Intel GPUs for efficient transcoding. NUC5 and NUC6 have the N100 processor, which is best for transcoding, but can run on NUC4 or NUC7 which run the older N95 if necessary.
* [Home Assistant](/manifests/homeops/homeassist) requires access to USB-attached resources such as Zigbee/Z-Wave controllers and a UPS monitor. Obviously, these are plugged into one node, which the pods require access to (currently NUC4).
* [MariaDB](/manifests/database/mariadb) and [PostgreSQL](/manifests/database/postgresql) requires local storage, which is available on NUC4-NUC7.
* [Longhorn](/manifests/system/longhorn) is configured to only run on NUC4-NUC7 in order to keep workloads off the control-plane nodes

#### Server Specs
| Name | Make/Model           |  CPU                                           |  RAM                 |  Disk          | Purpose       |
|:----:|:---------------------|:-----------------------------------------------|:---------------------|:---------------|:--------------|
| NUC1 | Intel NUC6CAYH       | Intel Celeron J3455 (2M Cache, up to 2.30 GHz) | 8 GB DDR3L-1600/1866 | 500 GB SSD     | Control Plane |
| NUC2 | Intel NUC6CAYH       | Intel Celeron J3455 (2M Cache, up to 2.30 GHz) | 8 GB DDR3L-1600/1866 | 500 GB SSD     | Control Plane |
| NUC3 | Intel NUC5CPYH       | Intel Celeron N3060 (2M Cache, up to 2.48 GHz) | 8 GB DDR3L-1333/1600 | 500 GB SSD     | Control Plane |
| NUC4 | Beelink U59 Pro      | Intel Celeron N5105 (4M Cache, up to 2.90 GHz) | 16 GB DDR4-2400      | 500 GB M.2 SSD | Worker        |
| NUC5 | Beelink Mini S12 Pro | Intel N100 (6M Cache, up to 3.40 GHz)          | 16 GB DDR4-3400      | 500 GB M.2 SSD | Worker        |
| NUC6 | Beelink Mini S12 Pro | Intel N100 (6M Cache, up to 3.40 GHz)          | 16 GB DDR4-3400      | 500 GB M.2 SSD | Worker        |
| NUC7 | Beelink U59 Pro      | Intel Celeron N5105 (4M Cache, up to 2.90 GHz) | 16 GB DDR4-2400      | 500 GB M.2 SSD | Worker        |

### Cloud Cluster
This cluster is hosted on a single node in [Oracle Cloud](https://cloud.oracle.com) and is used as a disaster-recovery solution for my home cluster. It replicates the function of some critical services:
* MariaDB
* PostgreSQL
* AdGuard Home
* VaultWarden
* UCDialplans website

The MariaDB/PostgreSQL servers are live replicas of the home-based servers. Most of the services are in warm-standby mode. AdGuard Home is the only actively used service for when I am away from home as it responds to requests from *.dns.ucdialplans.com. However, it is very lightly used, since my phone is usually connected to my home network via Wireguard.

The Oracle Cloud Talos OS image is not available on Oracle Cloud but can be built by [following these procedures](/docs/ORACLE-TALOS-PREP.md).

### Lab Cluster
This is my Kubernetes lab environment, which I have historically used to test out new features before deploying to my 'production' Kubernetes cluster. It runs on 1 to 3 Talos VMs on my Windows 11 machine under Hyper-V.

## Inter-Cluster Communication
I use the [Tailscale Operator](/manifests/network/tailscale) to securely share data between my home and cloud cluster. I decided to use limited service-level links instead of a cluster-wide link to limit exposure. This does complicate things somewhat, but is generally manageable. 

## Folder structure
The folders are laid out in the following manner:
- [argocd](/argocd): the "brains" of the operation that controls the creation/management of all resources
- [argocd-apps](/argocd-apps): where all the ArgoCD application definitions reside. This basically tells ArgoCD where to find the relevant manifests for each application. Broken down by type (app, database, system etc). The ArgoCD applications reference manifests stored in the [manifests](/manifests) folder.
- [docs](/docs): documents
- [manifests](/manifests): all the manifests used by each application. Broken down by type (app, database, system etc) then by name. Used by [ArgoCD applications](/argocd-apps).
- [helm](/helm/baseline): where I keep my universal Helm chart for most non-Helm based applications
- [scripts](/scripts): a mish-mash of scripts used for various purposes

Applications that are used by multiple clusters are structured for [Kustomize](https://kustomize.io/) by following this structure underneath [manifests](/manifests):
```
appName/
├── base/
│   ├── kustomization.yaml    # Base manifests and Helm chart setup
│   ├── deployment.yaml       # Base Deployment manifest
│   ├── service.yaml          # Base Service manifest
│   └── values.yaml           # Base Helm values (if using Helm chart)
├── overlays/
│   ├── cloud/
│   │   ├── kustomization.yaml  # Patches and config specific to Cloud cluster
│   │   ├── patch.yaml          # Example patch (e.g., change replicas)
│   │   └── values.yaml         # Helm values patch (if using Helm chart)
│   ├── home/
│   │   ├── kustomization.yaml  # Patches and config specific to Home cluster
│   │   ├── patch.yaml          # Example patch (e.g., change replicas)
│   │   └── values.yaml         # Helm values patch (if using Helm chart)
│   ├── lab/
│   │   ├── kustomization.yaml  # Patches and config specific to Lab cluster
│   │   ├── patch.yaml          # Example patch (e.g., change replicas)
│   │   └── values.yaml         # Helm values patch (if using Helm chart)
```

## Software Updates
All software updates are managed via [Renovate](https://github.com/renovatebot/renovate). Renovate watches the Github repo and checks for software version updates on any Helm chart, ArgoCD application manifest or deployment manifest. If an update is found, Renovate will update the version in the repo and let ArgoCD handle the actual upgrade. All updates are logged in the repo as commits.

The configuration for Renovate is stored in [renovate.json](/renovate.json). The dashboard is available at https://developer.mend.io/github/kenlasko

Renovate is set to automatically and silently upgrade every software package EXCEPT for the following:
* [Cilium](/manifests/network/cilium)
* [Longhorn](/manifests/system/longhorn)
* [MariaDB](/manifests/database/mariadb)
* [PostgreSQL](/manifests/database/postgresql)

When upgrades for the above packages are found, Renovate will create a pull request that has to be manually approved (or denied). Once approved, ArgoCD manages the actual upgrade as with any other software.

# Cluster Installation Procedures
[This document](/docs/CLUSTER-INSTALL.md) outlines the steps to install the cluster using [SideroLabs Omni](https://github.com/kenlasko/omni/), a [bootstrap script](/scripts/bootstrap-cluster.sh) and [ArgoCD](/argocd).

# Commit Pre-Check
This repository makes use of [pre-commit](https://pre-commit.com) to guard against accidental secret commits. When you attempt a commit, Pre-Commit will check for secrets and block the commit if one is found. It is currently using [GitGuardian](https://dashboard.gitguardian.com) [ggshield](https://www.gitguardian.com/ggshield) for secret validation. Requires a GitGuardian account, which does offer a free tier for home use. See [this document](/docs/COMMIT-PRECHECK.md) for more information.


# Useful Commands
## Check for open port without tools
Many container images do not have any tools like `nc` to check network port connectivity. This handy command will allow you to do that with just `echo`
```bash
(echo > /dev/tcp/<servicename>/<port>) >/dev/null 2>&1 && echo "It's up" || echo "It's down"
```

## Validate Kustomize manifests
```
kustomize build ~/k8s/manifests/apps/adguard/overlays/home/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/kustomize-test.yaml
```

## Validate Homegrown Helm Chart
```
helm template plex ~/k8s/helm/baseline -n media-apps -f ~/k8s/manifests/media-apps/plex/values.yaml > ~/helm-test.yaml
```

## Generate Kustomize Manifest and Apply to Kubernetes
```
kustomize build k8s/manifests/apps/adguard/overlays/home/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -
```


# Related Repositories
Links to my other repositories mentioned or used in this repo:
- [NetbootXYZ](https://github.com/kenlasko/docker-rpi1/tree/main/netbootxyz): Simplified PXE boot setup for Omni-managed Talos nodes.
- [NixOS](https://github.com/kenlasko/nixos-wsl): A declarative OS modified to support my Kubernetes cluster
- [Omni](https://github.com/kenlasko/omni): Creates and manages the Kubernetes clusters.