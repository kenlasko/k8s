# Setup Replication
## Primary DB Backup
Run `mariadb-backup-sync` job from `mariadb` namespace on Home cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb --from=cronjob/mariadb-backup-sync mariadb-backup-sync
```

## MariaDB Cloud Setup
1. Enable ```Oracle to NAS``` port forwarding rule on https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding
2. Run `mariadb-restore` job from `mariadb` namespace on Cloud cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb --from=cronjob/mariadb-restore mariadb-restore-sync
```
3. Disable ```Oracle to NAS``` port forwarding rule on https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding


## Replication Errors?
If you get replication errors, try skipping the error and continuing:
```
STOP SLAVE;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;
SELECT SLEEP(5);
SHOW SLAVE STATUS;
```