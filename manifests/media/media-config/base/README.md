# Summary
This contains the base network policy for the media namespace as well as creates the NAS NFS volume for media access.

# Backups
Each media application creates backups in their local volume. The [media backup script](/manifests/media/media-config/base/configmap-backup-script.yaml) backs up these volumes to the NAS every night, so even if Longhorn backups are corrupted (has happened before), I have a way to restore the data.

