> :warning: **IN PROGRESS**: I'm still working out some issues with this before I replace my now-vile Bitnami MariaDB Galera implementation. Not complete yet.

# Introduction
[MariaDB](https://mariadb.org/) is the database provider of choice for the cluster. It hosts databases for the following applications:
* [Home Assistant](/manifests/homeops/homeassist)
* [NextCloud](/manifests/apps/nextcloud)
* [Paperless](/manifests/apps/paperless)
* [UCDialplans](/manifests/apps/ucdialplans)
* [VaultWarden](/manifests/apps/vaultwarden)

All databases are replicated to 3 Kubernetes nodes using Galera for high-availability. 

This uses the [MariaDB Operator](https://github.com/mariadb-operator/mariadb-operator) instead of the original, more manual Bitnami MariaDB Helm chart. Information about that deployment can be found [here](/manifests/database/mariadb)

# Initial build from backup (no databases on nodes)
Use this method if there isn't an available local database source on the nodes. This is likely only occuring during a new cluster build. We can recover from backup, which requires a backup exists in the NAS on /share/backup/mariadb
1. Simply uncomment the `bootstrapFrom` section from the [galera-cluster.yaml](overlays/home/galera-cluster.yaml)
```
  # Only use during initial load when the local databases on disk aren't available
  bootstrapFrom:
    volume:
      persistentVolumeClaim: 
        claimName: nfs-galera-backup
```
2. Deploy the cluster via ArgoCD. The Operator will build a new cluster and automatically restore the latest database as long as there aren't any databases files existing. Use [volreset.sh](scripts/volreset.sh) to clear out
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
1. Ensure the `bootstrapFrom` is commented out in [galera-cluster.yaml](overlays/home/galera-cluster.yaml)
2. Check the status of the databases on the nodes by running the [showgrastate.sh](scripts/showgrastate.sh) script from a computer connected to the cluster
3. Use the [safe-to-bootstrap.sh](scripts/safe-to-bootstrap.sh) script to set `safe_to_bootstrap: 1` in `/host/var/mariadb-galera/storage/grastate.dat` on the most appropriate node with the highest sequence number.
4. Deploy the cluster via ArgoCD. The Operator will build a new cluster using the database files on the existing nodes.
