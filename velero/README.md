# Introduction
[Velero](https://velero.io/) is the chosen backup system for the cluster.

# Configuration
The default backup location is an S3 bucket called `kube` on the NAS. Ensure this bucket exists before deploying Velero.

## Install Velero CLI
```
wget https://github.com/vmware-tanzu/velero/releases/download/v1.15.0/velero-v1.15.0-linux-amd64.tar.gz
tar -xvf velero-v1.15.0-linux-amd64.tar.gz
sudo cp velero-v1.15.0-linux-amd64/velero /usr/local/bin/velero
rm -rf velero-v1.15.0-linux-amd64*
```