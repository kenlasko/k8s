# Introduction
[MariaDB](https://mariadb.org/) is the database provider of choice for the cluster. It hosts databases for the following applications:
* [Gitea](/gitea)
* [Home Assistant](/home-automation/homeassist)
* [UCDialplans](/ucdialplans)
* [VaultWarden](/vaultwarden)

All databases are replicated to 3 Kubernetes nodes using Galera for high-availability. It is also replicated to a [standalone MariaDB instance(/mariadb-standalone)], should the Galera cluster go down. For even more resilience, the databases are replicated to a Docker-based MariaDB instance running on the NAS as well as a remote MariaDB instance running in Oracle Cloud.

This uses the [MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator) instead of the original, less-resilient Bitnami MariaDB Helm chart.

# Initial build from backup (no databases on nodes)
Use this method if there isn't an available local database source on the nodes. This is likely only occuring during a new cluster build. We can recover from backup, which requires a backup exists in the NAS on /share/backup/mariadb
1. Simply uncomment the `bootstrapFrom` section from the [galera-cluster.yaml](galera-cluster.yaml)
```
  # bootstrapFrom:
  #   volume:
  #     nfs:
  #       server: 192.168.1.3
  #       path: /backup/mariadb/bootstrap
```
2. Deploy the cluster via ArgoCD. The Operator will build a new cluster and automatically restore the latest database.

# Recover from disaster (databases available on nodes)
If the database files exist on the nodes (under /var/mariadb), we can use the Operator recovery procedures to recover the databases.
1. Ensure the `bootstrapFrom` is commented out in [galera-cluster.yaml](galera-cluster.yaml)
2. Check the status of the databases on the nodes by running the [mariadb-showgrastate.sh](scripts/mariadb-showgrastate.yaml) script from a computer connected to the cluster
3. Use the [mariadb-bootstrap.sh](scripts/mariadb-bootstrap.yaml) script to set `safe_to_bootstrap: 1` in `/host/var/mariadb/storage/grastate.dat` on the most appropriate node
4. Deploy the cluster via ArgoCD. The Operator will build a new cluster using the database files on the existing nodes.

# Setup Replication
## Primary DB Backup
1. Select the MariaDB pod on one of NUC4-6 and go to command prompt:
```
mariadb -u root -p$MARIADB_ROOT_PASSWORD
```
```
flush tables with read lock;
show variables like 'gtid_binlog_pos';  
```
2. Take results from above and set `gtid_slave_pos` for replication config on other hosts. **DO NOT CLOSE WINDOW!**

3. Run `mariadb-backup` job on `mariadb` namespace

4. Once done, then unlock tables from first window:
```
unlock tables;
```
5. Connect to NAS01 and rename `/share/backup/mariadb/mariadb-backup-<dayofweek>.sql` to `mariadb-backup.sql`

## MariaDB Standalone Setup
1. If replication was previously enabled on secondary, run:
```
stop slave;
drop database gitea;
drop database homeassist;
drop database ucdialplans;
drop database vaultwarden;
drop database phpmyadmin;
```

2. Run `mariadb-restore` from `mariadb-standalone` namespace.

3. Connect to MariaDB-Standalone pod and run:
```
mariadb -u root -p$MARIADB_ROOT_PASSWORD
```
```
set global gtid_slave_pos = "0-1-19420";
change master to
    master_host='mariadb.mariadb.svc.cluster.local',
    master_user='replicator',
    master_password='***REMOVED***',
    master_port=3306,
    master_connect_retry=10,
    master_use_gtid=slave_pos;

start slave;
```

## From NAS01 DR Host
1. From NAS01 host via SSH:
```
sudo cp /share/backup/mariadb/mariadb-backup.sql /share/appdata/docker-vol/mariadb/databases/mariadb-backup.sql
```
2. If replication was previously enabled on secondary, run:
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
    master_host='192.168.1.13',
    master_user='replicator',
    master_password='***REMOVED***',
    master_port=3306,
    master_connect_retry=10,
    master_use_gtid=slave_pos;

start slave;
```

## From ONode1
1. If replication was previously enabled on cloud, run:
```
stop slave;
drop database gitea;
drop database homeassist;
drop database ucdialplans;
drop database vaultwarden;
drop database phpmyadmin;
```
2. Enable ```Oracle to NAS``` port forwarding rule on https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding
3. Run `mariadb-restore` from `mariadb` namespace.

4. Connect to MariaDB pod and run (or do it from PHPMyAdmin):
```
mariadb -u root -p$MARIADB_ROOT_PASSWORD
```
```
set global gtid_slave_pos = "0-1-19420";
change master to
    master_host='cloud-egress',
    master_user='replicator',
    master_password='***REMOVED***',
    master_port=3306,
    master_connect_retry=10,
    master_use_gtid=slave_pos;

start slave;
```

5. Disable ```Oracle to NAS``` port forwarding rule on https://unifi.ucdialplans.com/network/default/settings/security/port-forwarding

## Uptime-Kuma Procedure
Re-add this procedure to allow Uptime-Kuma to check replication status
```
DELIMITER $$
CREATE PROCEDURE phpmyadmin.check_replication()
BEGIN
    DECLARE rep_status VARCHAR(50);
    SELECT VARIABLE_VALUE INTO rep_status
    FROM INFORMATION_SCHEMA.GLOBAL_STATUS
    WHERE VARIABLE_NAME = 'Slave_running';

    IF rep_status != 'ON' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Replication is not ON.';
    ELSE
	SELECT rep_status;
    END IF;
END$$
```

## Replication Errors?
If you get replication errors, try skipping the error and continuing:
```
STOP SLAVE;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;
SELECT SLEEP(5);
SHOW SLAVE STATUS;
```

# Recovery Procedures
From https://artifacthub.io/packages/helm/bitnami/mariadb

## Zero nodes with safe_to_bootstrap

```
helm uninstall -n mariadb mariadb
```

Delete all PV/PVCs for MariaDB, then:
```
kubectl apply -f /home/ken/k3s/mariadb/pv.yaml

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb \
--set rootUser.password=***REMOVED*** \
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

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb

helm upgrade -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb --set rootUser.password=***REMOVED*** --set galera.mariabackup.password=***REMOVED*** --set podManagementPolicy=Parallel
```


## One nodes with safe_to_bootstrap
```
helm uninstall -n mariadb mariadb
```

Delete all PV/PVCs for MariaDB, then:
```
kubectl apply -f /home/ken/k3s/mariadb/pv.yaml

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb \
--set rootUser.password=***REMOVED*** \
--set galera.mariabackup.password=***REMOVED*** \
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

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb \
--set rootUser.password=***REMOVED*** \
--set galera.mariabackup.password=***REMOVED*** 
```


## Other helpful commands
### Scale down to 1 or zero pods
```
kubectl scale statefulset mariadb -n mariadb --replicas=1
```


### Other
```
helm upgrade -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb \
--set rootUser.password=***REMOVED*** \
--set galera.mariabackup.password=***REMOVED***
```

```
helm upgrade --namespace mariadb mariadb oci://registry-1.docker.io/bitnamicharts/mariadb \
      --set rootUser.password=$(kubectl get secret --namespace mariadb mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 -d) \
      --set galera.mariabackup.password=$(kubectl get secret --namespace mariadb mariadb -o jsonpath="{.data.mariadb-mariabackup-password}" | base64 -d)
```