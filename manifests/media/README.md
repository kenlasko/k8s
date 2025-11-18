# Summary
This section contains all the media applications used for media management and consumption. The manifests for all of these were created manually, because adequate Helm charts didn't exist when I first did this. Now that its done, there's no real reason to switch.

Its separated from the other applications because several of these apps require [Longhorn](/manifests/system/longhorn) for storage. When the cluster is first built, the Longhorn volumes must be restored before starting the media applications. If not, then the apps will create empty Longhorn volumes. It is recoverable, but takes much more work than if the restored volumes are there first. The affected applications are:
* [Calibre Web](/manifests/media/calibre)
* [Maintainerr](/manifests/media/maintainerr)
* [Plex](/manifests/media/plex)
* [SABNZBD](/manifests/media/sabnzbd)
* [Tautulli](/manifests/media/tautulli)

Eventually, I hope to automate the Longhorn restore process, so that a cluster can be rebuilt with no user intervention.

Each application creates backups in their local volume. The [media backup script](/manifests/media/media-config/base/configmap-backup-script.yaml) backs up these volumes to the NAS, so even if Longhorn backups are corrupted (has happened before), I have a way to restore the data.

Most configuration is done via my [custom Helm chart](/helm/baseline).