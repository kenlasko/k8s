# Introduction
This is the Git repository that contains all the configuration for my multiple homelab Kubernetes clusters. The clusters are used to host a number of self-hosted services mostly focused on movies and TV along with all the supporting software. This repository is fully gitops-optimized and is managed by [ArgoCD](https://argoproj.github.io/).

The clusters are built on Sidero Lab's [Talos OS](https://github.com/siderolabs/talos) using on-prem [Omni](https://github.com/siderolabs/omni) for low-level cluster management.

## CLuster Descriptions
### Home Cluster
My home cluster runs on 6 mini-PCs named `NUC1` through to `NUC6`. NUC1-NUC3 are used as control-plane nodes, while NUC4-NUC6 are workers. While this repo can be used for any environment, some workloads require (or benefit from) hardware that is specific to certain named nodes. The manifests are configured for this. For example:
* [Plex](/manifests/media-apps/plex) works best on nodes with Intel GPUs for efficient transcoding. NUC5 and NUC6 have the N100 processor, which is best for transcoding, but can run on NUC3 or NUC4 which run the older N95 if necessary.
* [Home Assistant](/manifests/homeops/homeassist) requires access to USB-attached resources such as Zigbee/Z-Wave controllers and a UPS monitor. Obviously, these are plugged into one node, which the pods require access to (currently NUC4).
* [MariaDB](/manifests/database/mariadb) and [PostgreSQL](/manifests/database/postgresql) requires local storage, which is available on NUC4-NUC6.
* [Longhorn](/manifests/system/longhorn) is configured to only run on NUC4-NUC6 in order to keep workloads off the control-plane nodes

### Cloud Cluster
This cluster is hosted on a single node in [Oracle Cloud](https://cloud.oracle.com) and is used as a disaster-recovery solution for my home cluster. It replicates the function of some critical services:
* MariaDB
* PostgreSQL
* AdGuard Home
* VaultWarden
* UCDialplans website

The MariaDB/PostgreSQL servers are live replicas of the home-based servers. Most of the services are in warm-standby mode. AdGuard Home is the only actively used service for when I am away from home as it responds to requests from *.dns.ucdialplans.com. However, it is very lightly used, since my phone is usually connected to home via Wireguard.

The Oracle Cloud image is not available on Oracle Cloud but can be built by [following these procedures](#oracle-cloud-talos-node-prep).

### Lab Cluster
This is my Kubernetes lab environment, which I have historically used to test out new features before deploying to my 'production' Kubernetes cluster. It runs on 1 to 3 Talos VMs on my Windows 11 machine under Hyper-V.

## Related Repositories
Links to my other repositories mentioned or used in this repo:
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
│   │   └── patch.yaml          # Example patch (e.g., change replicas)
│   ├── home/
│   │   ├── kustomization.yaml  # Patches and config specific to Home cluster
│   │   └── patch.yaml          # Example patch
│   └── lab/
│       ├── kustomization.yaml  # Patches and config specific to Lab cluster
│       └── patch.yaml          # Example patch
```

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

## Initial Cluster Setup
This guide assumes you're using a NixOS distribution that is configured to securely store and present all required certificates. For more information, see [my NixOS repo](https://github.com/kenlasko/nixos-wsl/). Otherwise, you will have to manually ensure all supporting files are present.

Initially, I used tools like Ansible/Terraform to bootstrap the cluster, which worked when each cluster had its own repo. After my changes to use Kustomize and Helm to manage all my clusters from one repo, this no longer worked. After a lot of trial-and-error, I gave up on Terraform and used ChatGPT to create a rather robust Bash script to take care of the entire cluster bootstrapping process. 

Now, all that is needed is to run the following and wait for completion:
```
~/k8s/scripts/bootstrap-cluster.sh
```
The script will take care of the following:
- Use `omnictl` to spin up the cluster
- Apply initial manifests to get the cluster to the point where ArgoCD can take over. These manifests include:
  - [Cilium](/manifests/network/cilium)
  - [Cert-Manager](/manifests/system/cert-manager)
  - [External Secrets](/manifests/system/external-secrets)
  - [CSI Drivers](/manifests/system/csi-drivers)
  - [Redis](/manifests/database/redis)
  - [ArgoCD](/manifests/argocd)

## Argo App Install
Once the `bootstrap-cluster.sh` script bootstraps the cluster, ArgoCD should take over and install all the remaining applications. ArgoCD sync-waves should install apps in the correct order. The full list of apps and their relative order can be found [here](/argocd-apps).

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

# Oracle Cloud Talos Node Prep
1. Download ARM64 Talos Oracle image from https://omni.ucdialplans.com and place in /home/ken/
2. Create image metadata file and save as ```image_metadata.json```
```
{
    "version": 2,
    "externalLaunchOptions": {
        "firmware": "UEFI_64",
        "networkType": "PARAVIRTUALIZED",
        "bootVolumeType": "PARAVIRTUALIZED",
        "remoteDataVolumeType": "PARAVIRTUALIZED",
        "localDataVolumeType": "PARAVIRTUALIZED",
        "launchOptionsSource": "PARAVIRTUALIZED",
        "pvAttachmentVersion": 2,
        "pvEncryptionInTransitEnabled": true,
        "consistentVolumeNamingEnabled": true
    },
    "imageCapabilityData": null,
    "imageCapsFormatVersion": null,
    "operatingSystem": "Talos",
    "operatingSystemVersion": "1.8.1",
    "additionalMetadata": {
        "shapeCompatibilities": [
            {
                "internalShapeName": "VM.Standard.A1.Flex",
                "ocpuConstraints": null,
                "memoryConstraints": null
            }
        ]
    }
}
```
3. Create .oci image for Oracle
```
xz --decompress oracle-arm64-omni-onprem-omni-v1.8.1.qcow2.xz
tar zcf talos-oracle-arm64.oci oracle-arm64.qcow2 image_metadata.json
```
4. Copy image to [Oracle storage bucket](https://cloud.oracle.com/object-storage/buckets?region=ca-toronto-1)
5. [Import custom image](https://cloud.oracle.com/compute/images?region=ca-toronto-1) to Oracle cloud
6. Edit image capabilities and set ```Boot volume type``` and ```Local data volume``` to ```PARAVIRTUALIZED```
7. [Create instance](https://cloud.oracle.com/compute/instances?region=ca-toronto-1) using custom image
8. Open all inbound firewall ports from home network
9. Set Oracle public IP address on [Unifi port forwarding](https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding)


# Handy commands to know
## Check for open port without tools
Many container images do not have any tools like `nc` to check network port connectivity. This handy command will allow you to do that with just `echo`
```bash
(echo > /dev/tcp/<servicename>/<port>) >/dev/null 2>&1 && echo "It's up" || echo "It's down"
```

## Validate Kustomize manifests
```
kustomize build k8s/manifests/apps/adguard/overlays/home/ --enable-helm --load-restrictor LoadRestrictionsNone > ~/kustomize-test.yaml
```

## Validate Homegrown Helm Chart
```
helm template plex ~/k8s/helm/baseline -n media-apps -f ~/k8s/manifests/media-tools/plex/values.yaml > ~/helm-test.yaml
```

## Generate Kustomize Manifest and Apply to Kubernetes
```
kustomize build k8s/manifests/apps/adguard/overlays/home/ --enable-helm --load-restrictor LoadRestrictionsNone | kubectl apply -f -
```