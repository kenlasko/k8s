# Summary
[VolSync](https://github.com/backube/volsync) is a tool for backing up or replicating PVs to other locations. I use this to backup many of my NAS-based volumes to S3 buckets on Cloudflare (mostly) or Oracle Cloud

[Cloudflare R2 Object Storage](https://dash.cloudflare.com/fa831d805d821b7c4627b464a9845a9d/r2/overview) gives me 10GB of free S3 storage. I am using this for daily backups of applications that store on the `appdata/vol` folder on the NAS. So far, its staying under the 10GB limit.

I could be utilizing [Volume Populator](https://volsync.readthedocs.io/en/stable/usage/volume-populator/index.html) to automatically restore when starting up for the first time, but I have elected not to use this, as in most practical scenarios, the actual live volumes are still on the NAS and don't require restoration.

Each application has a disabled restore manifest that can be enabled for any restore job that's required. It is called `restore_DISABLED.yaml`. By default, it will restore the most recent backup, but the options `restoreAsOf` or `previous` can be used to restore older backups.