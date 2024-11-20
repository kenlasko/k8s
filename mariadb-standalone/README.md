# Introduction
This serves as a realtime backup for the [MariaDB Galera cluster](/mariadb-galera) running in the same cluster. It's intended for a situation where the Galera cluster is completely destroyed (usually because of something I've done). Since I've gotten a hang of running the cluster, this instance has seen very little use and may eventually be decommissioned, although I actually used it for a restore source just the other week (2024-Nov).

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

## Secondary DB Sync Configuration
1. Run `mariadb-restore` from `mariadb-standalone` namespace. This will restore the newest available database backup along with user accounts and grants and procedures.
2. Connect to MariaDB-Standalone pod and run (or use PHPMyAdmin, if available):
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

## Post-Replication Uptime Kuma Config
Uptime Kuma relies on checking the results of a procedure to validate replication. Execute the following SQL statements:
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

GRANT EXECUTE ON PROCEDURE `phpmyadmin`.`check_replication` TO `uptime-kuma`@`%`;
```