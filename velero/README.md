# Introduction
[Velero](https://velero.io/) is a backup solution for Kubernetes resources. Don't think I'll be using this as its primary goal is to backup manifests along with PVs/PVCs. Since my deployment is entirely declarative, most of this isn't required. PVs/PVCs can be backed up using simpler tools. Using [SnapScheduler](/snapscheduler) instead.

# Configuration
The default backup location is an S3 bucket called `kube` on the NAS. Ensure this bucket exists before deploying Velero.

## Install Velero CLI
```
wget https://github.com/vmware-tanzu/velero/releases/download/v1.15.0/velero-v1.15.0-linux-amd64.tar.gz
tar -xvf velero-v1.15.0-linux-amd64.tar.gz
sudo cp velero-v1.15.0-linux-amd64/velero /usr/local/bin/velero
rm -rf velero-v1.15.0-linux-amd64*
```