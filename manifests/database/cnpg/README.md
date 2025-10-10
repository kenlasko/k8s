# Summary
This is a highly-available PostgreSQL cluster using the excellent [CloudNativePG Operator](https://cloudnative-pg.io/). Its configured as a 3-node cluster using local storage. It has live replication to a remote PostgreSQL server running on Oracle Cloud. It hosts databases for the following apps:

* [Home Assistant](/manifests/homeops/homeassist)
* [Immich](/manifests/media-apps/immich)
* [NextCloud](/manifests/apps/nextcloud)
* [Paperless](/manifests/apps/paperless)
* [Prowlarr](/manifests/media-apps/prowlarr)
* [Radarr](/manifests/media-apps/radarr)
* [Sonarr](/manifests/media-apps/sonarr)
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

## Backups
Constant backups are being made to a remote S3 bucket, which makes restoration very simple. This is defined in [cluster.yaml](overlays/home/cluster.yaml) and [backup.yaml](overlays/home/backup.yaml). Normally, the `cnpg` plugin should show the status of continuous backups, but this is [currently broken](https://github.com/cloudnative-pg/cloudnative-pg/issues/8276). In the meantime, status checks can be done via the following (taken from [this comment](https://github.com/cloudnative-pg/cloudnative-pg/issues/8276#issuecomment-3162854414) on the issue):

For now, the most reliable way to monitor WAL archiving and backup health with plugins is to check the Cluster status conditions (`ContinuousArchiving: True`, `LastBackupSucceeded: True`) and the `ObjectStore` CRD's `ServerRecoveryWindow` fields (`firstRecoverabilityPoint`, `lastSuccessfulBackupTime`) [docs](https://cloudnative-pg.io/plugin-barman-cloud/docs/concepts/). Pod logs are also essential for catching silent failures or S3 compatibility issues.

# Things I've Found
## Recovering from a failed node
I had a pod not come back properly after a node upgrade. Thankfully it was Home-3. The controller was throwing errors about being unable to connect to the pod, and the pod couldn't communicate with the controller. I tried to scale the cluster to 2 pods, but it kept failing to communicate with the pod.

I tried wiping out the local-disk contents, but that didn't work. Ultimately, the solution was to delete the PV/PVC associated with Home-3, and then scale the cluster back to 3 pods. Now that pod is known as Home-4, which is something CNPG or PG itself does to ensure a clean slate for the "new" pod.