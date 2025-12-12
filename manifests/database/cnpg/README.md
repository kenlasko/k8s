# Summary
This is a highly-available PostgreSQL cluster using the excellent [CloudNativePG Operator](https://cloudnative-pg.io/). Its configured as a 3-node cluster using local storage. It has live replication to a remote PostgreSQL server running on Oracle Cloud and a standalone server in the K8S cluster. It hosts databases for the following apps:

* [Home Assistant](/manifests/homeops/homeassist)
* [Kite](/manifests/system/kite)
* ~[Immich](/manifests/media/immich)~
* [NextCloud](/manifests/apps/nextcloud)
* [Paperless](/manifests/apps/paperless)
* [PGAdmin](/manifests/database/pgadmin)
* [Prowlarr](/manifests/media/prowlarr)
* [Radarr](/manifests/media/radarr)
* [Seerr](/manifests/media/seerr)
* [Sonarr](/manifests/media/sonarr)
* [UCDialplans Website](/manifests/apps/ucdialplans)
* [Vaultwarden](/manifests/apps/vaultwarden)


# Replication
Replication is configured from the 3-node cluster to two separate instances, using WAL streaming replication from the primary:
- A [single node server](overlays/home/cluster-standby.yaml) in the same K8S cluster/namespace as the production cluster to act as a secondary failover, if the primary cluster fails
- An [Oracle Cloud single node server](overlays/cloud/cluster.yaml) to act as a DR node

For streaming to work, the cloud cluster needs to authenticate using the self-generated certificates on the home cluster. A [CronJob](overlays/home/cronjob-akeyless-update.yaml) is configured to run a daily check via a custom script called [update-cloud-certs.sh](scripts/update-cloud-certs.sh) and to update the AKeyless secret if the certificate content has changed. 

The manual steps to do this are below, but shouldn't be necessary (at least steps 1 and 2)
1. Run the [update-cloud-certs.sh](scripts/update-cloud-certs.sh) script to extract the certificates from the home cluster and update the AKeyless PostgreSQL secret
2. Delete the `replication-certs` external secret in the cloud cluster to trigger a pull of the updated external secret data, or wait for the scheduled update to happen (every 24h).
3. Kill the `cloud-1` pod in the cloud cluster to initiate a fresh instance to ensure it uses the new certificates. PostgreSQL may eventually self-update, but I'm not sure.

## Monitoring Replication
I'm using [Uptime Kuma](/manifests/monitoring/uptime-kuma) to alert me via Slack if either the standby or cloud cluster replication gets out-of-sync with the primary. The Uptime Kuma query to use to alert on replication sync issues is:
```
DO $$
BEGIN
  IF EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) > 120 THEN
    RAISE EXCEPTION 'Replication lag exceeds 120 seconds';
  END IF;
END $$;
```

## Backups
Constant backups are being made to a remote S3 bucket, which makes restoration very simple. This is defined in [cluster.yaml](overlays/home/cluster.yaml) and [backup.yaml](overlays/home/backup.yaml). Normally, the `cnpg` plugin should show the status of continuous backups, but this is [currently broken](https://github.com/cloudnative-pg/cloudnative-pg/issues/8276). In the meantime, status checks can be done via the following (taken from [this comment](https://github.com/cloudnative-pg/cloudnative-pg/issues/8276#issuecomment-3162854414) on the issue):

For now, the most reliable way to monitor WAL archiving and backup health with plugins is to check the Cluster status conditions (`ContinuousArchiving: True`, `LastBackupSucceeded: True`) and the `ObjectStore` CRD's `ServerRecoveryWindow` fields (`firstRecoverabilityPoint`, `lastSuccessfulBackupTime`) [docs](https://cloudnative-pg.io/plugin-barman-cloud/docs/concepts/). Pod logs are also essential for catching silent failures or S3 compatibility issues.

I'm also using [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) in a [daily Cronjob](overlays/home/cronjob-pgdump.yaml) to make platform-independent backups of all databases. This has proven to be useful when the S3 backups are unusable or I need to restore a single database. The backups are stored on the NAS.

# Things I've Found
## Restoring the cluster after a failure
When the cluster fails and needs rebuilding, a few things need to happen before restoring:
- Delete the contents of the database folders on the nodes using the [volreset.sh](scripts/volreset.sh) script.
- Delete the PVs assigned to the previous cluster, so that CNPG can reclaim them. Tip: if you want the pod order to sequentially match up with the nodes (home-1 on NUC4, home-2 on NUC5 etc.), only delete the PV associated with NUC4 first, then NUC5 after NUC4 claims the PV, etc.
- Enable the [patch-recovery.yaml](overlays/home/patch-recovery.yaml) patch in the [kustomization.yaml](overlays/home/kustomization.yaml) and disable once recovery is complete

## Testing Recovery
Its good practice to regularly test the cluster recovery process. I use my [standby server](overlays/home/cluster-standby.yaml) for this. To test this, you must comment out the `replica` section and set the `bootstrap` recovery options as desired.

The fastest way to test this is to follow these steps:
1. Make all changes to the [standby cluster manifest](overlays/home/cluster-standby.yaml) and sync with ArgoCD
2. Log into NUC7 and delete all files under `/host/var/postgresql`. Can use the [volreset.sh](scripts/volreset.sh) script to do this
3. Delete the `postgresql-data-nuc7` PV
4. Delete the `standby` CNPG cluster object

Recovery should start shortly.

## Restore Options
The [CNPG Recovery section](https://cloudnative-pg.io/documentation/1.20/recovery/) has lots of good info about recovery. A few useful tidbits (this is all set in the `cluster` manifest):

### Recovering to a specific period
```
  bootstrap:
    recovery:
      source: s3-backupsource
      recoveryTarget:
        targetTime: "2025-11-11 15:00:00.000000+00:00"
```

### Recovering to a specific backup ID
Use `targetImmediate` to restore to the most immediate restore point (minimal WAL requirements) 
```
  bootstrap:
    recovery:
      source: s3-backupsource
      recoveryTarget:
        backupID: 20251110T070003 
        targetImmediate: true
```

### Recovering a single database from pg_dump
To restore a single database, its generally easier to use the `pg_dump` [daily backup](overlays/home/cronjob-pgdump.yaml) as long as you are comfortable with up to 24h of data loss. To restore:
1. Copy the desired backup from `NAS01/backup/cnpg` into the [NixOS](https://github.com/kenlasko/nixos-wsl) home directory where `psql` is already configured.
2. Unzip the archive:
```bash
mkdir pg-restore
tar -xzf postgres_backup_Sunday.tar.gz -C pg-restore
```
3. Connect to the cluster via `psql` (My NixOS installation already has the necessary environment variables for server/user/pw, so no additional switches are required)
4. Drop the database to restore if you want to start clean:
```sql
-- Replace this with the database name you want to drop
\set dbname 'DATABASE_TO_DROP'

-- Terminate active connections
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = :'dbname';

-- Drop the database using dynamic SQL
DO $$
BEGIN
    EXECUTE format('DROP DATABASE %I', :'dbname');
END$$;
```
5. Delete the desired `Database` object from Kubernetes. This will trigger the recreation of the database when ArgoCD recreates the Database object.
6. Restore the desired database (connection params are assumed to be stored in environment variables):
```bash
# Restore to an empty database
pg_restore -d mydb mydb.dump

# Restore to an existing database
pg_restore -d mydb --clean --if-exists mydb.dump
```

### Deleting old Backblaze files
For whatever reason, the Barman Cloud plugin doesn't actually delete files outside of the retention period. It simply marks them as ready to delete. To ensure that Backblaze deletes files after the retention period expires, set a `custom lifecycle rule` with the following settings:

| Setting          |   Value   |
|------------------|:---------:|
| File Path        |   home    |
| Days Till Hide   | <blank>   |
| Days Till Delete |     1     |


After a few days, files outside the retention window will be deleted.

### Backblaze B2 CLI Tips & Tricks
The Backblaze B2 CLI is installed in my NixOS repo. Handy to get info without logging into the UI.

Get a list of files for all subfolders:
```
b2 ls b2://klasko-postgresql --long --recursive
```

Get a full list of files (including ones to be deleted):
```
b2 ls b2://klasko-postgresql/home/base --versions --long --recursive
```

Get the total size of all files in the bucket:
```
b2 ls b2://klasko-postgresql --long --recursive --versions | awk '{sum += $5} END {printf "%.2f GB\n", sum/1000000000}'
```

## Recovering from a failed node
I had a pod not come back properly after a node upgrade. Thankfully it was Home-3. The controller was throwing errors about being unable to connect to the pod, and the pod couldn't communicate with the controller. I tried to scale the cluster to 2 pods, but it kept failing to communicate with the pod.

I tried wiping out the local-disk contents, but that didn't work. Ultimately, the solution was to delete the PV/PVC associated with Home-3, and then scale the cluster back to 3 pods. Now that pod is known as Home-4, which is something CNPG or PG itself does to ensure a clean slate for the "new" pod.

