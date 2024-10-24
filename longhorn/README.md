# Introduction
[Longhorn](https://github.com/longhorn/longhorn) is a distributed block storage system for Kubernetes. It maintains multiple copies of data on separate nodes, so should one go down, the data is safe on the other two. 

# Configuration
Its configured to only run on worker nodes by specifying a node label called `storage: longhorn`. The only workloads that use it are ones that use SQLite, which are all the [Media Tools](/media-tools) applications.

All data is backed up nightly to the NAS via NFS. Should a disaster require a complete rebuild, Longhorn should be restored first, followed by restoring all the volumes before the [Media Tools](/media-tools) applications are started.

# CSI Snapshot Support
I enabled CSI snapshot support, which should let me declaratively restore volumes during bootstrapping. Updated the [Longhorn Argo CD application definition](/argocd-apps/longhorn.yaml) to include it. Followed the steps here: https://longhorn.io/docs/1.7.2/snapshots-and-backups/csi-snapshot-support/enable-csi-snapshot-support/
