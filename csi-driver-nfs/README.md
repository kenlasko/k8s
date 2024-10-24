# Summary
The [CSI Driver for NFS](https://github.com/kubernetes-csi/csi-driver-nfs) is a proper CSI driver for NFS that replaces the built-in NFS driver and the NFS provisioner.  Its used for all NFS volumes, both static and dynamic. 

There are two storageClasses:
* nfs-csi           - for static-named NFS volumes. Holds most volumes for applications. Daily backups
* nfs-csi-dynamic   - for dynamically-named NFS volumes. Used only for [Promstack](/monitoring) apps. No backups