# Summary
The [CSI Driver for NFS](https://github.com/kubernetes-csi/csi-driver-nfs) is a proper CSI driver for NFS that replaces the built-in NFS driver and the NFS provisioner.  Its used for all NFS volumes, both static and dynamic. 

There are two storageClasses:
* nfs-csi           - for static-named NFS volumes. Holds most volumes for applications. Daily backups
* nfs-csi-dynamic   - for dynamically-named NFS volumes. Used only for [Promstack](/manifests/monitoring) apps. No backups

Using CSI drivers allow for using a wide variety of cluster backup solutions such as Velero. Snapshot classes are added for NFS. We also add CSI volume snapshot classes for Longhorn. These allow for fully automated cluster builds without manual volume restores. See [SnapScheduler](/manifests/system/snapscheduler) for more information.