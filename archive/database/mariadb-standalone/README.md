> [!WARNING]
> MariaDB has been deprecated in favour of [CloudNative PostgreSQL](/manifests/database/cnpg). After the [Bitnami debacle](https://thenewstack.io/broadcom-ends-free-bitnami-images-forcing-users-to-find-alternatives/), I had considered moving to the excellent [MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator), but since I was already using CNPG successfully for some workloads, I elected to migrate everything to that, instead of managing two database platforms. This part of the repo is kept around for historical purposes.

# Introduction
This serves as a realtime backup for the [3-node production MariaDB Galera cluster](/manifests/database/mariadb) running in the same cluster. It's intended for a situation where the primary cluster is completely destroyed (usually because of something I've done). This instance is handy for when the primary cluster goes down, because it provides a near-realtime backup that can be used to bootstrap a new primary cluster.

# Replication Setup
The [sync-bootstrap.sh](/manifests/mariadb/database/scripts/sync-bootstrap.sh) script automates the backup, restore and sync config for all MariaDB deployments. If it does not work, run `mariadb-restore` job from `mariadb-standalone` namespace on Home cluster once the initial backup has been done from the primary cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb-standalone --from=cronjob/mariadb-restore mariadb-restore-sync
```

## DB Backup for Bootstrapping
If you need to bootstrap a new cluster after the loss of the primary, run `mariadb-backup-sync` job from `mariadb-standalone` namespace on Home cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb-standalone --from=cronjob/mariadb-backup-sync mariadb-backup-sync
```
Once done, run `mariadb-restore` on the fresh primary cluster and then run the sync bootstrap script to re-sync all remote instances. Follow the steps [here](https://github.com/kenlasko/K3S/blob/main/mariadb/README.md#initial-bootstrapping)