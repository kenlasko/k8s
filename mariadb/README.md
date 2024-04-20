# Setup Replication
Select the MariaDB pod on NUC6 and go to command prompt:
```
mariadb -u root -p***REMOVED***
flush tables with read lock;
show variables like 'gtid_binlog_pos';  
```
Take results from above and set **gtid_slave_pos** for last step

From another window on same cluster member:
```
mariadb-dump -h mariadb.mariadb.svc.cluster.local -u root -p***REMOVED*** -B gitea homeassist phpmyadmin ucdialplans vaultwarden > /bitnami/mariadb/data/mariadb-repl-backup.sql
```
Once done, then unlock from first:
```
unlock tables;
```

From NUC3 host
```
sudo scp ken@nuc6:/var/mariadb/data/mariadb-repl-backup.sql /var/mariadb/mariadb-repl-backup.sql
```

From NAS01 host
```
sudo scp ken@nuc6:/var/mariadb/data/mariadb-repl-backup.sql /share/appdata/docker-vol/mariadb/backup/mariadb-repl-backup.sql
```

Then on mariadb-standalone/NAS01 container command prompt:
```
mariadb -u root -p***REMOVED***
stop slave;

drop database gitea;
drop database homeassist;
drop database ucdialplans;
drop database vaultwarden;
drop database phpmyadmin;
```

Exit to prompt and run on MariaDB-Standalone
```
mariadb -u root -p***REMOVED*** < /bitnami/mariadb/mariadb-repl-backup.sql
```

Then run 
```
mariadb -u root -p***REMOVED***
set global gtid_slave_pos = "0-1-3853320,1-1-42";
change master to
    master_host='mariadb.mariadb.svc.cluster.local',
    master_user='replicator',
    master_password='***REMOVED***',
    master_port=3306,
    master_connect_retry=10,
    master_use_gtid=slave_pos;

start slave;
```

Exit to prompt and run on NAS01 MariaDB container
```
mariadb -u root -p***REMOVED*** < /backup/mariadb-repl-backup.sql
```

Then run 
```
mariadb -u root -p***REMOVED***
set global gtid_slave_pos = "0-1-3853320,1-1-42";
change master to
    master_host='192.168.1.13',
    master_user='replicator',
    master_password='***REMOVED***',
    master_port=3306,
    master_connect_retry=10,
    master_use_gtid=slave_pos;

start slave;
```

Check status
```
show slave status;
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