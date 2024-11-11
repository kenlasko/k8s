# Introduction
[MariaDB](https://mariadb.org/) is the database provider of choice for the cluster. It hosts databases for the following applications:
* [Gitea](/gitea)
* [Home Assistant](/home-automation/homeassist)
* [UCDialplans](/ucdialplans)
* [VaultWarden](/vaultwarden)

All databases are replicated to 3 Kubernetes nodes using Galera for high-availability. It is also replicated to a [standalone MariaDB instance(/mariadb-standalone)], should the Galera cluster go down. For even more resilience, the databases are replicated to a Docker-based MariaDB instance running on the NAS as well as a remote MariaDB instance running in Oracle Cloud.

This uses the [MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator) instead of the original, more manual Bitnami MariaDB Helm chart. Information about that deployment can be found [here](/mariadb)

# Initial build from backup (no databases on nodes)
Use this method if there isn't an available local database source on the nodes. This is likely only occuring during a new cluster build. We can recover from backup, which requires a backup exists in the NAS on /share/backup/mariadb
1. Simply uncomment the `bootstrapFrom` section from the [galera-cluster.yaml](galera-cluster.yaml)
```
  # Only use during initial load when the local databases on disk aren't available
  bootstrapFrom:
    volume:
      persistentVolumeClaim: 
        claimName: nfs-galera-backup
```
2. Deploy the cluster via ArgoCD. The Operator will build a new cluster and automatically restore the latest database as long as there aren't any databases files existing. Use [mariadb-volreset.sh](scripts/mariadb-volreset.yaml) to clear out
3. Manually add UCDialplans procedure, as there isn't currently a way to do this automatically
```
DELIMITER $$
CREATE PROCEDURE ucdialplans.InfoCache_Update()
BEGIN
        UPDATE ucdialplans.InfoCache ic SET ic.Value = (SELECT(SELECT COUNT(ac.ID) FROM ucdialplans.AreaCodes ac) + (SELECT COUNT(acnz.ID) FROM ucdialplans.AreaCodes_NZ acnz) + (SELECT Count(DISTINCT np.City) FROM ucdialplans.NANPA_Prefix np)) WHERE ic.`Attribute` = 'TotalRegions';
        UPDATE ucdialplans.InfoCache ic SET ic.Value = (SELECT COUNT(rs.ID) FROM ucdialplans.Rulesets rs) WHERE ic.`Attribute` = 'TotalRulesets';
        UPDATE ucdialplans.InfoCache ic SET ic.Value = (SELECT COUNT(u.UserID) FROM ucdialplans.Users u) WHERE ic.`Attribute` = 'TotalUsers';

        DELETE FROM ucdialplans.InfoCache_Top10_Countries;
        INSERT INTO ucdialplans.InfoCache_Top10_Countries (Country, Rulesets) SELECT dr.CountryName as Country, COUNT(*) as Rulesets FROM ucdialplans.Rulesets rs INNER JOIN ucdialplans.DialRules dr ON dr.CountryID = rs.CountryID GROUP BY dr.CountryName ORDER BY Count(*) DESC LIMIT 10;

        DELETE FROM ucdialplans.InfoCache_Top10_Regions;
        INSERT INTO ucdialplans.InfoCache_Top10_Regions (City, CountryID, Frequency) SELECT City, CountryID, COUNT(*) as Frequency FROM Rulesets GROUP BY City, CountryID ORDER BY count(*) DESC LIMIT 10;
END$$
```


# Recover from disaster (databases available on nodes)
If the database files exist on the nodes (under /var/mariadb), we can use the Operator recovery procedures to recover the databases.
1. Ensure the `bootstrapFrom` is commented out in [galera-cluster.yaml](galera-cluster.yaml)
2. Check the status of the databases on the nodes by running the [mariadb-showgrastate.sh](scripts/mariadb-showgrastate.yaml) script from a computer connected to the cluster
3. Use the [mariadb-bootstrap.sh](scripts/mariadb-bootstrap.yaml) script to set `safe_to_bootstrap: 1` in `/host/var/mariadb/storage/grastate.dat` on the most appropriate node with the highest sequence number.
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
2. Take the value of `gtid_binlog_pos` and set `gtid_slave_pos` for replication config on other hosts (see below). **DO NOT CLOSE WINDOW!**

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

## Post-Replication Uptime Kuma Config
Uptime Kuma relies on checking the results of a procedure to validate replication. Execute the following SQL statements on each MariaDB remote instance:
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

## Replication Errors?
If you get replication errors, try skipping the error and continuing:
```
STOP SLAVE;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;
```

