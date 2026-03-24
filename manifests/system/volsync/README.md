# Summary
[VolSync](https://github.com/backube/volsync) is a tool for backing up or replicating PVs to other locations. I use this to backup many of my NAS-based or local volumes to S3 buckets on Cloudflare, Backblaze or Oracle Cloud.

[Cloudflare R2 Object Storage](https://dash.cloudflare.com/fa831d805d821b7c4627b464a9845a9d/r2/overview) gives me 10GB of free S3 storage. I am using this for daily backups of applications that store on the `appdata/vol` folder on the NAS. So far, its staying under the 10GB limit. Other larger volumes are backed up to [Backblaze](https://secure.backblaze.com/b2_buckets.htm). Oracle Cloud is generally not used, but is ready in a pinch.

I could be utilizing [Volume Populator](https://volsync.readthedocs.io/en/stable/usage/volume-populator/index.html) to automatically restore when starting up for the first time, but I have elected not to use this, as in most practical scenarios, the actual live volumes are still on the NAS and don't require restoration.

Each application has a disabled restore manifest that can be enabled for any restore job that's required. It is called `restore.yaml`. By default, it will restore the most recent backup, but the options `restoreAsOf` or `previous` can be used to restore older backups. To enable it, simply add it to the `resources:` field of the appropriate `kustomization.yaml`.

# Tips & Tricks
## Backup fails due to volume locking
Sometimes, a VolSync backup will continually fail to complete due to volume lock issues in Restic. This appears to happen more frequently to [NextCloud](/manifests/apps/nextcloud). 

To resolve this, update the Volsync `ReplicationSource` manifest for the app in question (usually defined as part of my custom Helm chart) to include a random value for `unlock`:
```yaml
backup:
  location: cloudflare 
  schedule: "05 6 * * *"
  unlock: "some-random-value"
```

If you are manually defining the Volsync `ReplicationSource`:
```yaml
spec:
  restic:
    unlock: "some-random-value"
```

Once a replication completes, `status.restic.lastUnlocked` will be set to the same string value from `spec.restic.unlock`. Unlock will not be performed again on subsequent replications unless `spec.restic.unlock` is set to a different value. (From [VolSync docs](https://volsync.readthedocs.io/en/stable/usage/restic/index.html))


To resolve manually, EXEC into the volsync pod before it restarts (you have several minutes to do this) and run this command:
```
restick unlock
```
That should be sufficient to allow the backup to complete.