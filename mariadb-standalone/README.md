# Introduction
This serves as a realtime backup for the [3-node production MariaDB Galera cluster](/mariadb) running in the same cluster. It's intended for a situation where the primary cluster is completely destroyed (usually because of something I've done). This instance is handy for when the primary cluster goes down, because it provides a near-realtime backup that can be used to bootstrap a new primary cluster.

# Replication Setup
The [sync-bootstrap.sh](/mariadb/scripts/sync-bootstrap.sh) script automates the backup, restore and sync config for all MariaDB deployments. If it does not work, manually run:
```
./k3s/mariadb/scripts/sync-bootstrap.sh
```
## DB Backup for Bootstrapping
If you need to bootstrap a new cluster after the loss of the primary, run `mariadb-backup-sync` job from `mariadb-standalone` namespace on Home cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb-standalone --from=cronjob/mariadb-backup-sync mariadb-backup-sync
```
Once done, run `mariadb-restore` on the fresh primary cluster and then run the sync bootstrap script to re-sync all remote instances.