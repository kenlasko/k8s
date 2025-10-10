> [!WARNING]
> MariaDB has been deprecated in favour of [CloudNative PostgreSQL](/manifests/database/cnpg). After the [Bitnami debacle](https://thenewstack.io/broadcom-ends-free-bitnami-images-forcing-users-to-find-alternatives/), I had considered moving to the excellent [MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator), but since I was already using CNPG successfully for some workloads, I elected to migrate everything to that, instead of managing two database platforms. This part of the repo is kept around for historical purposes.

# Introduction
[MariaDB](https://mariadb.org/) is the database provider of choice for the cluster. It hosts databases for the following applications:
* [Home Assistant](/manifests/homeops/homeassist)
* [UCDialplans](/manifests/apps/ucdialplans)
* [VaultWarden](/manifests/apps/vaultwarden)

All databases are replicated to 3 Kubernetes nodes using Galera for high-availability. It is also replicated to a [standalone MariaDB instance](/manifests/database/mariadb-standalone), should the Galera cluster go down. For even more resilience, the databases are replicated to a Docker-based MariaDB instance running on the NAS as well as a [remote MariaDB instance running in Oracle Cloud](https://github.com/kenlasko/k3s-cloud/tree/main/mariadb).

# Initial Bootstrapping
Run `mariadb-restore` CronJob from `mariadb` namespace. This will restore the newest available database backup along with user accounts and grants and procedures. Do via either ArgoCD or:
```
kubectl create job -n mariadb --from=cronjob/mariadb-restore mariadb-initial-restore
```

# Setup Replication
The [sync-bootstrap.sh](/manifests/database/mariadb/scripts/sync-bootstrap.sh) script automates the backup, restore and sync config for all MariaDB deployments. If it does not work, the manual steps are in the following sections. Simply run:
```
./k8s/manifests/database/mariadb/scripts/sync-bootstrap.sh
```
For the script to fully work, you must have a valid `kubeconfig` file with both Home and Cloud instances

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

## MariaDB Cloud Setup
1. Enable ```Oracle to NAS``` port forwarding rule on https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding
2. Run `mariadb-restore` job from `mariadb` namespace on Cloud cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb --from=cronjob/mariadb-restore mariadb-restore-sync
```
3. Disable ```Oracle to NAS``` port forwarding rule on https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding


## From NAS01 DR Host
Should be able to run the `mariadb-restore-nas01` job from `mariadb` namespace on Home cluster. Do via either ArgoCD or:
```
kubectl create job -n mariadb --from=cronjob/mariadb-restore-nas01 mariadb-restore-sync-nas01
```

If it doesn't work, use the manual method below.

1. From NAS01 host via SSH:
```
NEWEST_SQL_FILE=$(ls -t /backup/mariadb-backup-*.sql /backup/backup.*.sql 2>/dev/null | head -n 1)
sudo cp $NEWEST_SQL_FILE /share/appdata/docker-vol/mariadb/databases/mariadb-backup.sql
```
2. If replication was previously enabled on NAS01, run:
```
stop slave;
drop database gitea;
drop database homeassist;
drop database ucdialplans;
drop database vaultwarden;
drop database phpmyadmin;
```
3. Get to pod shell on NAS01 container via [Portainer](https://portainer.ucdialplans.com) and run:
```
mariadb -u root -p$MARIADB_ROOT_PASSWORD < /bitnami/mariadb/data/mariadb-backup.sql
```

4. Then run 
```
mariadb -u root -p$MARIADB_ROOT_PASSWORD
```
```
set global gtid_slave_pos = "0-1-19420";
change master to
    master_host='mariadb-access.ucdialplans.com',
    master_user='replicator',
    master_password='***REDACTED***',
    master_port=3306,
    master_connect_retry=10,
    master_use_gtid=slave_pos;

start slave;
```

## Replication Errors?
If you get replication errors, try skipping the error and continuing:
```
STOP SLAVE;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;
SELECT SLEEP(2);
SELECT Last_Error FROM `SLAVE_STATUS`; 
```

# Recovery Procedures
From https://artifacthub.io/packages/helm/bitnami/mariadb-galera

## Zero nodes with safe_to_bootstrap

```
helm uninstall -n mariadb mariadb
```

Delete all PV/PVCs for MariaDB, then:
```
kubectl apply -f /home/ken/k8s/manifests/database/mariadb/pv.yaml

helm install -n mariadb mariadb -f /home/ken/k8s/manifests/database/mariadb/values.yaml bitnami/mariadb-galera \
--set rootUser.password=***REDACTED*** \
--set galera.mariabackup.password=  \
--set galera.bootstrap.forceBootstrap=true \
--set galera.bootstrap.bootstrapFromNode=1 \
--set galera.bootstrap.forceSafeToBootstrap=true \
--set podManagementPolicy=Parallel

kubectl scale statefulset mariadb -n mariadb --replicas=1
```

Wait a bit
```
kubectl scale statefulset mariadb -n mariadb --replicas=0

helm uninstall -n mariadb mariadb

helm install -n mariadb mariadb -f /home/ken/k8s/manifests/database/mariadb/values.yaml bitnami/mariadb-galera

helm upgrade -n mariadb mariadb -f /home/ken/k8s/manifests/database/mariadb/values.yaml bitnami/mariadb-galera --set rootUser.password=***REDACTED*** --set galera.mariabackup.password=***REDACTED*** --set podManagementPolicy=Parallel
```


## One nodes with safe_to_bootstrap
```
helm uninstall -n mariadb mariadb
```

Delete all PV/PVCs for MariaDB, then:
```
kubectl apply -f /home/ken/k8s/manifests/database/mariadb/pv.yaml

helm install -n mariadb mariadb -f /home/ken/k8s/manifests/database/mariadb/values.yaml bitnami/mariadb-galera \
--set rootUser.password=***REDACTED*** \
--set galera.mariabackup.password=***REDACTED*** \
--set galera.bootstrap.forceBootstrap=true \
--set galera.bootstrap.bootstrapFromNode=1 \
--set podManagementPolicy=Parallel 
```

Once up and running
```
kubectl scale statefulset mariadb -n mariadb --replicas=1
```
Wait a bit
```
kubectl scale statefulset mariadb -n mariadb --replicas=0
helm uninstall -n mariadb mariadb

helm install -n mariadb mariadb -f /home/ken/k8s/manifests/mariadb/values.yaml bitnami/mariadb-galera \
--set rootUser.password=***REDACTED*** \
--set galera.mariabackup.password=***REDACTED*** 
```


## Other helpful commands
### Scale down to 1 or zero pods
```
kubectl scale statefulset mariadb -n mariadb --replicas=1
```


### Other
```
helm upgrade -n mariadb mariadb -f /home/ken/k8s/manifests/database/mariadb/values.yaml bitnami/mariadb-galera \
--set rootUser.password=***REDACTED*** \
--set galera.mariabackup.password=***REDACTED***
```

```
helm upgrade --namespace mariadb mariadb oci://registry-1.docker.io/bitnamicharts/mariadb-galera \
      --set rootUser.password=$(kubectl get secret --namespace mariadb mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 -d) \
      --set galera.mariabackup.password=$(kubectl get secret --namespace mariadb mariadb -o jsonpath="{.data.mariadb-galera-mariabackup-password}" | base64 -d)
```