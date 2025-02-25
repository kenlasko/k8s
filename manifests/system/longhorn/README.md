# Introduction
[Longhorn](https://github.com/longhorn/longhorn) is a distributed block storage system for Kubernetes. It maintains multiple copies of data on separate nodes, so should one go down, the data is safe on the other two. 

# Configuration
Its configured to only run on worker nodes by specifying a node label called `storage: longhorn`. The only workloads that use it are ones that use SQLite, which are all the [Media Tools](/manifests/media-apps) applications.

All data is backed up nightly to the NAS via NFS. Should a disaster require a complete rebuild, Longhorn should be restored first, followed by restoring all the volumes before the [Media Tools](/manifests/media-apps) applications are started.

# CSI Snapshot Support
I enabled [CSI snapshot](https://github.com/kubernetes-csi/external-snapshotter) support, which should let me declaratively restore volumes during bootstrapping. Updated the [Longhorn Argo CD application definition](/argocd-apps/longhorn.yaml) to include it. Followed the steps here: https://longhorn.io/docs/1.7.2/snapshots-and-backups/csi-snapshot-support/enable-csi-snapshot-support/

## Configuration sample for restoring volume during bootstrap
For my current Longhorn volumes, I define both the PV and PVC and manually restore volumes in Longhorn. Using CSI backups, volumes can be automatically restored from backup.

### CSI-Based Backup Config
There must be a CSI backup available for this to work. My examples below:
```
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: lidarr-backup
  namespace: media-apps
spec:
  volumeSnapshotClassName: longhorn-backup
  source:
    persistentVolumeClaimName: longhorn-lidarr-test-config-pvc
```

In the PVC definition, add a `dataSource` section with the appropriate config. If there's a PV definition to set the PV name, delete it. As long as there's a CSI backup available, the volume will be automatically restored.
This works well, but I lose the nice PV names of `pvc-<servicename>` that I'm currently using and it uses the standard `pvc-<GUID>` format.
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-lidarr-test-config-pvc
  namespace: media-apps
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  dataSource:
    name: lidarr-backup
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 300Mi
```

One thing I'm not sure of is how this works on a new cluster. Presumably, I would need to backup and restore the backup objects so the CSI driver will know there's a PV backup to restore (not sure if that sentence makeS sense)