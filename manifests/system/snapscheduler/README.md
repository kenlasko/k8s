# Introduction
Since everything in the cluster is declaratively managed via GitHub/ArgoCD, I don't need a full cluster backup solution like Velero. Should a disaster befall my cluster, all I need to do is bootstrap it via [Omni](https://github.com/kenlasko/omni) and [Ansible](/ansible) and let [ArgoCD](/manifests/argocd) handle everything else. The only things that need backups are the persistent volumes.

For all the volumes on the NAS, I use the NAS built-in backup utilities to backup those volumes as well as sync those backups to Onedrive for cases where the NAS also has a disaster. In the future, I may look at a different strategy where I directly backup to the cloud, so I won't be reliant on the NAS being functional and workload volumes restored before bootstrapping a new cluster. For that, I will consider [Volsync](https://github.com/backube/volsync). I have a [test setup](/manifests/system/volsync) I'm working on for that.

The only thing that remains are Longhorn volumes, which are used for my [media](/manifests/media-apps) apps. In a disaster, the current workflow involves first setting up Longhorn, manually restoring the volumes which are backed up using Longhorn-native tooling (pretty fast and straightforward), then starting the media apps. 

I can eliminate the manual process by switching backups to use [CSI volume snapshotting](https://kubernetes.io/docs/concepts/storage/volume-snapshots/). This allows me to automatically restore a volume without manual intervention. To take advantage of this, we first must backup using volume snapshots. Since Longhorn volumes use a CSI driver, this is pretty straightforward and is handled via [CSI Drivers](/manifests/system/csi-drivers). The second thing is a scheduling tool, which is where [SnapScheduler](https://github.com/backube/snapscheduler) comes in. 

SnapScheduler will automatically backup any volumes that meet the desired criteria. I have a [default schedule](schedule.yaml) that will backup any volume that has the label `csi-backup: "true"`. Once this is done, then application restores can be done by adding a `.spec/datasource` section to the PVC volume definition like the one below, and removing any PV definition:
```
  dataSource:
    name: lidarr-backup
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```
When the application starts up, if the PV doesn't exist, one will be created and restored from the backup automatically.