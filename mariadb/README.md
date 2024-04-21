# Setup Replication
1. Select the MariaDB pod on one of NUC4-6 and go to command prompt:
```
mariadb -u root -p$MARIADB_ROOT_PASSWORD
```
```
flush tables with read lock;
show variables like 'gtid_binlog_pos';  
```
2. Take results from above and set **gtid_slave_pos** for step 7. DO NOT CLOSE WINDOW.

3. Run **mariadb-backup** job on **mariadb** namespace

4. Once done, then unlock tables from first window:
```
unlock tables;
```

5. If replication was previously enabled on secondary, run:
```
stop slave;
drop database gitea;
drop database homeassist;
drop database ucdialplans;
drop database vaultwarden;
drop database phpmyadmin;
```

6. Run **mariadb-restore** from **mariadb-standalone** namespace.

7. For MariaDB-Standalone, run
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

8. From NAS01 host
```
sudo cp /share/backup/mariadb/mariadb-backup.sql /share/appdata/docker-vol/mariadb/databases/mariadb-backup.sql
```

9. Get to pod shell on NAS01 container and run:
```
mariadb -u root -p$MARIADB_ROOT_PASSWORD < /bitnami/mariadb/data/mariadb-backup.sql
```

10. Then run 
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

If you get replication errors, try skipping the error and continuing:
```
STOP SLAVE;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;
SELECT SLEEP(5);
SHOW SLAVE STATUS;
```

# Recovery Procedures
From https://artifacthub.io/packages/helm/bitnami/mariadb-galera

## Zero nodes with safe_to_bootstrap

```
helm uninstall -n mariadb mariadb
```

Delete all PV/PVCs for MariaDB, then:
```
kubectl apply -f /home/ken/k3s/mariadb/pv.yaml

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb-galera \
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

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb-galera

helm upgrade -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb-galera --set rootUser.password=***REMOVED*** --set galera.mariabackup.password=***REMOVED*** --set podManagementPolicy=Parallel
```


## One nodes with safe_to_bootstrap
```
helm uninstall -n mariadb mariadb
```

Delete all PV/PVCs for MariaDB, then:
```
kubectl apply -f /home/ken/k3s/mariadb/pv.yaml

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb-galera \
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

helm install -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb-galera \
--set rootUser.password=***REMOVED*** \
--set galera.mariabackup.password=***REMOVED*** 
```


## Other helpful commands
### Scale down to 1 or zero pods
```
kubectl scale statefulset mariadb -n mariadb --replicas=1
```

### Use Ansible to clean persistent folder for all
```
ansible-playbook k3s/ansible-clean-db-folders.yaml --ask-become-pass
```

### Use Ansible to clean persistent folder for one
```
ansible-playbook k3s/ansible-clean-db-folders.yaml --limit "nuc2" --ask-become-pass
```

### Other
```
helm upgrade -n mariadb mariadb -f /home/ken/k3s/mariadb/values.yaml bitnami/mariadb-galera \
--set rootUser.password=***REMOVED*** \
--set galera.mariabackup.password=***REMOVED***
```

```
helm upgrade --namespace mariadb mariadb oci://registry-1.docker.io/bitnamicharts/mariadb-galera \
      --set rootUser.password=$(kubectl get secret --namespace mariadb mariadb -o jsonpath="{.data.mariadb-root-password}" | base64 -d) \
      --set galera.mariabackup.password=$(kubectl get secret --namespace mariadb mariadb -o jsonpath="{.data.mariadb-galera-mariabackup-password}" | base64 -d)
```