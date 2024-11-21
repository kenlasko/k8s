# Introduction
This serves as a realtime backup for the [MariaDB Galera cluster](/mariadb-galera) running in the same cluster. It's intended for a situation where the Galera cluster is completely destroyed (usually because of something I've done). Since I've gotten a hang of running the cluster, this instance has seen very little use and may eventually be decommissioned, although I actually used it for a restore source just the other week (2024-Nov).

# Replication Setup
## Primary DB Backup
Run `mariadb-backup-sync` job from `mariadb` namespace on Home cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb --from=cronjob/mariadb-backup-sync mariadb-backup-sync
```

## MariaDB Standalone Setup
Run `mariadb-restore` job from `mariadb-standalone` namespace on Home cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb-standalone --from=cronjob/mariadb-restore mariadb-restore-sync
```