# Introduction
This cluster makes heavy use of NAS resources for storing stateful files that play well with NFS. For workloads that don't work with NFS (such as SQLite databases), Longhorn is used.

This document helps define the configuration of storage used in this Kubernetes cluster.

# Connectivity
The cluster uses the [NFS CSI driver](https://github.com/kubernetes-csi/csi-driver-nfs) to provide NAS connectivity. Using CSI drivers allow for backups using CSI backup methods like Velero and SnapScheduler. See the application definition for [CSI Drivers](/manifests/csi-drivers) for more information. 

# Base Folders
These are the base folders used for the cluster. These are visible in the cluster as NFS shares. Actual location doesn't matter.
* **appdata** - used for application storage
* **backup** - used for backup data
* **media** - used for media (movies/TV/music etc)

## Appdata
This folder stores all the data used by applications. Most applications use statically-defined NFS folders (stored under `/appdata/vol`), which have to be pre-defined for use by PV/PVCs. A few use dynamically provisioned NFS folders. These are stored under `/appdata/pv` However, these folder names are not terribly readable, and are only used for workloads that can't use the predefined PV/PVC option. These are also folders that don't require backup as they just store log and performance metrics.
```
/share/appdata
├── container-station-data  # QNAP Container Station
├── docker-vol              # Docker volume data for Container Station
├── pv                      # NFS Subdir Provisioner data
└── vol                     # NFS appdata (pre-created base folders)
```

### appdata/pv
These folders are used by apps that make use of the [NFS Subdir Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner). The benefit of this is that the app folders don't have to exist prior to running the workload. The downside is that its difficult/impossible (as far as I know) to re-use one of these should the workload be deleted and recreated. This is reserved for workloads that I don't care about backing up or restoring after a cluster rebuild.
Apps that currently use the `appdata/pv` folder are:
* [alertmanager/grafana/loki/prometheus](/manifests/monitoring)


### appdata/vol
These folders are used for most apps that don't have SQLite databases ([Longhorn](https://github.com/longhorn/longhorn) is used for workloads with SQLite DBs). The cluster uses defined PV/PVCs to attach to them. The folders must exist before the apps can use them. These are backed up using the [NAS AppData Backup](/manifests/csi-drivers/configmap-backup-apps-script.yaml) script.
Apps that currently use the `appdata/vol` folder are:
* [adguard](/manifests/adguard)
* [esphome](/manifests/home-automation/esphome)
* [garmin-upload](/manifests/garmin-upload)
* [gitea](/manifests/gitea)
* [homeassist](/manifests/home-automation/homeassist)
* [nectar-ps](/manifests/nectar-ps)
* [pgadmin](/manifests/pgadmin)
* [portainer](/manifests/portainer)
* [recyclarr](/manifests/media-apps/recyclarr)
* [registry](/manifests/registry)
* [romm](/manifests/media-apps/romm)
* [transmission](/manifests/media-apps/transmission)
* [ucdialplans](/manifests/ucdialplans)
* [ups-monitor](/manifests/home-automation/ups-monitor)
* [uptime-kuma](/manifests/uptime-kuma)
* [vaultwarden](/manifests/vaultwarden)
* [zwaveadmin](/manifests/home-automation/zwaveadmin)

To create these folders on a fresh install (may not be necessary, depending on how the data is restored):
```
cd /share/appdata
mkdir adguard esphome garmin-upload gitea homeassist nectar pgadmin portainer recyclarr registry romm transmission ucdialplans ups-monitor uptime-kuma vaultwarden zwaveadmin
```

## Backup
This folder stores data created by backup processes, such as Longhorn and manual backup scripts:
* [Github Repo Backup](/manifests/gitea/configmap-github-backup.yaml)
* [MariaDB Backup](/manifests/mariadb/backup-cronjob.yaml)
* [Media Apps](/manifests/media-apps/backup)
* [NAS AppData Vol Backup](/manifests/csi-drivers/configmap-backup-apps-script.yaml)
* [Sealed Secret Backup](/manifests/sealed-secrets/configmap-script.yaml)

```
/share/backup
├── apps        # Media apps
├── github      # Github repo
├── k8s         # Sealed Secret backup
├── longhorn    # Done from within Longhorn
├── mariadb     # MariaDB
├── nas         # QNAP backup
├── omni        # SideroLabs Omni cluster management
└── vol         # appdata/vol
```

To create these folders on a fresh install:
```
cd /share/backup
mkdir apps github k8s longhorn mariadb nas omni vol
```

# Backing up the NAS
To ensure data is recoverable, all the contents are backed up weekly to an old media PC called BACKUPPC (192.168.1.19).

This PC has a number of drives that are merged together into a single volume using [MergerFS](https://github.com/trapexit/mergerfs). MergerFS is installed via:
```
sudo apt install mergerfs -y
```

The drives are configured via `/etc/fstab`
```
# /etc/fstab: static file system information.
#
# This is the fstab file for BACKUPPC. It is used to mount the backup storage on NAS01, which is available via a dedicated 2.5GbE network card.
# The NIC is configured using Netplan
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda2 during curtin installation
/dev/disk/by-uuid/58430b64-91c5-4fb6-8202-4da7832e6582 / ext4 defaults 0 1
# /boot/efi was on /dev/sda1 during curtin installation
/dev/disk/by-uuid/3841-7C00 /boot/efi vfat defaults 0 1
/swap.img       none    swap    sw      0       0
/dev/sdg1 /mnt/c1      ext4    defaults   0       0
/dev/sdf1 /mnt/c2      ext4    defaults   0       0
/dev/sde1 /mnt/c3      ext4    defaults   0       0
/dev/sdd1 /mnt/c4      ext4    defaults   0       0
/dev/sdc1 /mnt/c5      ext4    defaults   0       0
/dev/sdb1 /media/other ext4    defaults   0       0

# MergerFS mount
/mnt/c1:/mnt/c2:/mnt/c3:/mnt/c4:/mnt/c5  /media/movies  fuse.mergerfs  defaults,allow_other  0       0

# NAS mount
192.168.100.3:/appdata    /mnt/appdata   nfs    defaults 0  0
192.168.100.3:/media      /mnt/media     nfs    defaults 0  0
192.168.100.3:/backup     /mnt/backup    nfs    defaults 0  0
```

BACKUPPC has a dedicated 2.5GBe network interface connected directly to NAS01. The config is done via Netplan:
```
# This is the network config written by 'subiquity'
network:
  ethernets:
    enp3s0:
      mtu: 1500
      dhcp4: true
    enp6s0:
      mtu: 9000
      dhcp4: false
      addresses: [192.168.100.4/24]
  version: 2
```

Backups are triggered via a [Home Assistant](/manifests/home-automation/homeassist) automation every Saturday. This automation does the following:
1. Turns on BACKUPPC
2. Waits for a successful ping
3. Calls a shell command to start the backup
4. Waits for a webhook sent by the script at the end of the backup
5. Shuts off BACKUPPC

The backup script is saved at `~/backup-nas.sh` as below:
```
#! /bin/bash

rm rsync.log

rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log /mnt/media/movies/ /media/movies
if [ "$?" -ne 0 ]; then
    echo "Movie backup failed";
fi

rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log /mnt/media/tv/ /media/other/tv
if [ "$?" -ne 0 ]; then
    echo "TV backup failed";
fi

rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log /mnt/media/music/ /media/other/music
if [ "$?" -ne 0 ]; then
    echo "Music backup failed";
fi

rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log /mnt/backup/media-apps/ /media/other/backup/media-apps
if [ "$?" -ne 0 ]; then
    echo "Media app backup failed";
fi

rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log /mnt/backup/vol/ /media/other/backup/vol
if [ "$?" -ne 0 ]; then
    echo "VolData backup failed";
fi

rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log /mnt/backup/mariadb/ /media/other/backup/mariadb
if [ "$?" -ne 0 ]; then
    echo "MariaDB backup failed";
fi

rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log /mnt/backup/omni/ /media/other/backup/omni
if [ "$?" -ne 0 ]; then
    echo "Omni backup failed";
fi

# This sends an email with the backup report attached via SendGrid
SENDGRID_API_KEY="***REMOVED***"
EMAIL_TO="ken.lasko@gmail.com"
FROM_EMAIL="klasko@ucdialplans.com"
FROM_NAME="NAS-Backup"
SUBJECT="NAS Backup report"

# This sends a webhook to Home Assistant to notify that the backup is complete. This will initiate a shutdown of BACKUPPC
bodyHTML="<p>Attached is the NAS backup report generated by BACKUPPC</p>"

encodedFile=$(base64 -w 0 rsync.log)

maildata='{"personalizations": [{"to": [{"email": "'${EMAIL_TO}'"}]}],"from": {"email": "'${FROM_EMAIL}'","name": "'${FROM_NAME}'"},"subject": "'${SUBJECT}'","content": [{"type": "text/html", "value": "'${bodyHTML}'"}],"attachments": [{"content": "'${encodedFile}'", "type": "text/plain", "filename": "NAS-Backup-Report.txt"}]}'

curl --request POST \
  --url https://api.sendgrid.com/v3/mail/send \
  --header 'Authorization: Bearer '$SENDGRID_API_KEY \
  --header 'Content-Type: application/json' \
  --data "@-" <<<"${maildata}"

curl -X PUT -H "Content-Type: application/json" -d '{ "key": "value" }' https://ha.ucdialplans.com/api/webhook/media-backup-FuLoPlQpi-olRDMYNqfBMHWy
```