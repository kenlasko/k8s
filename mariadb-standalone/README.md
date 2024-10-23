# Introduction
This serves as a realtime backup for the [MariaDB Galera cluster](/mariadb) running in the same cluster. It's intended for a situation where the Galera cluster is completely destroyed (usually because of something I've done). Since I've gotten a hang of running the cluster, this instance has seen very little use and may eventually be decommissioned.

# Replication Setup
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

## Secondary DB Sync Configuration
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

3. Connect to MariaDB-Standalone pod and run (or use PHPMyAdmin, if available):
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