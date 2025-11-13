# Introduction
This cluster makes heavy use of NAS resources for storing stateful files that play well with NFS. For workloads that don't work with NFS (such as SQLite databases), Longhorn is used.

This document helps define the configuration of storage used in this Kubernetes cluster.

# Connectivity
The cluster uses the [NFS CSI driver](https://github.com/kubernetes-csi/csi-driver-nfs) to provide NAS connectivity. Using CSI drivers allow for backups using CSI backup methods like Velero and SnapScheduler. See the application definition for [CSI Drivers](/manifests/system/csi-drivers) for more information. 

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
These folders are used by apps that make use of the [NFS CSI driver](https://github.com/kubernetes-csi/csi-driver-nfs) to provide NAS connectivity. The benefit of this is that the app folders don't have to exist prior to running the workload. The downside is that its difficult/impossible (as far as I know) to re-use one of these should the workload be deleted and recreated. This is reserved for workloads that I don't care about backing up or restoring after a cluster rebuild.
Apps that currently use the `appdata/pv` folder are:
* [alertmanager/grafana/loki/prometheus](/manifests/monitoring)


### appdata/vol
These folders are used for most apps that don't have SQLite databases ([Longhorn](https://github.com/longhorn/longhorn) is used for workloads with SQLite DBs). The cluster uses defined PV/PVCs to attach to them. The folders must exist before the apps can use them. These are backed up using the [NAS AppData Backup](/manifests/system/csi-drivers/configmap-backup-apps-script.yaml) script.
Apps that currently use the `appdata/vol` folder are:
* [adguard](/manifests/apps/adguard)
* [esphome](/manifests/homeops/esphome)
* [garmin-upload](/manifests/apps/garmin-upload)
* [gitea](/manifests/apps/gitea)
* [homeassist](/manifests/homeops/homeassist)
* [pgadmin](/manifests/networking/pgadmin)
* [portainer](/manifests/apps/portainer)
* [recyclarr](/manifests/media-apps/recyclarr)
* [registry](/manifests/system/registry)
* [romm](/manifests/media-apps/romm)
* [transmission](/manifests/media-apps/transmission)
* [ucdialplans](/manifests/apps/ucdialplans)
* [ups-monitor](/manifests/homeops/ups-monitor)
* [uptime-kuma](/manifests/monitoring/uptime-kuma)
* [vaultwarden](/manifests/apps/vaultwarden)
* [zwaveadmin](/manifests/homeops/zwaveadmin)

To create these folders on a fresh install (may not be necessary, depending on how the data is restored):
```
cd /share/appdata
mkdir adguard esphome garmin-upload gitea homeassist pgadmin portainer recyclarr registry romm transmission ucdialplans ups-monitor uptime-kuma vaultwarden zwaveadmin
```

## Backup
This folder stores data created by backup processes, such as Longhorn and manual backup scripts:
* [Github Repo Backup](/manifests/apps/gitea/configmap-github-backup.yaml)
* [MariaDB Backup](/manifests/networking/mariadb/backup-cronjob.yaml)
* [Media Apps](/manifests/media-apps/backup)
* [NAS AppData Vol Backup](/manifests/system/csi-drivers/configmap-backup-apps-script.yaml)
* [Sealed Secret Backup](/manifests/system/sealed-secrets/configmap-script.yaml)

```
/share/backup
├── cnpg        # PostgreSQL
├── k8s         # Sealed Secret backup
├── longhorn    # Done from within Longhorn
├── media-apps  # Media apps
├── nas         # QNAP backup
├── nextcloud   # NextCloud data
├── omni        # SideroLabs Omni cluster management
└── vol         # appdata/vol
```

To create these folders on a fresh install:
```
cd /share/backup
mkdir cnpg k8s longhorn media-apps nas nextcloud omni vol
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

Backups are triggered via a [Home Assistant](/manifests/homeops/homeassist) automation every Saturday. This automation does the following:
1. Turns on BACKUPPC
2. Waits for a successful ping
3. Calls a shell command to start the backup
4. Waits for a webhook sent by the script at the end of the backup
5. Shuts off BACKUPPC

The backup script is saved at `~/backup-nas.sh` as below:
```
#!/bin/bash

rm -f rsync.log

FAILURES=""

run_backup() {
    local src="$1"
    local dest="$2"
    local name="$3"

    rsync -aP --no-perms --no-owner --no-group --delete --log-file=rsync.log "$src" "$dest"
    if [ "$?" -ne 0 ]; then
        echo "$name backup failed"
        FAILURES="${FAILURES}<p><b>${name} backup failed</b></p>"
    fi
}

# Backups
run_backup "/mnt/media/movies/"        "/media/movies"                   "Movie"
run_backup "/mnt/media/tv/"            "/media/other/tv"                 "TV"
run_backup "/mnt/media/music/"         "/media/other/music"              "Music"
run_backup "/mnt/backup/media-apps/"   "/media/other/backup/media-apps"  "Media app"
run_backup "/mnt/backup/nextcloud/"    "/media/other/backup/nextcloud"   "Nextcloud"
run_backup "/mnt/backup/vol/"          "/media/other/backup/vol"         "VolData"
run_backup "/mnt/backup/cnpg/"         "/media/other/backup/cnpg"        "PostgreSQL"
run_backup "/mnt/backup/omni/"         "/media/other/backup/omni"        "Omni"

# Email setup
API_KEY="api-<REDACTED>"
EMAIL_TO="ken.lasko@gmail.com"
FROM_EMAIL="klasko@ucdialplans.com"
FROM_NAME="NAS-Backup"
SUBJECT="NAS Backup Report"

# Build HTML body
if [ -z "$FAILURES" ]; then
    bodyHTML="<p>All backups completed successfully.</p>"
else
    bodyHTML="<p>The following backups failed:</p>${FAILURES}"
fi

# Add generic message
bodyHTML="${bodyHTML}<p>Attached is the rsync backup log.</p>"

encodedFile=$(base64 -w 0 rsync.log)

maildata=$(cat <<EOF
{
  "sender": "${FROM_EMAIL}",
  "to": ["${EMAIL_TO}"],
  "subject": "NAS Backup Report",
  "html_body": "${bodyHTML}",
  "attachments": [
    {
      "fileblob": "${encodedFile}",
      "mimetype": "text/plain",
      "filename": "NAS-Backup-Report.txt"
    }
  ]
}
EOF
)

# Send email
curl --request POST \
  --url https://api.smtp2go.com/v3/email/send \
  --header "X-Smtp2go-Api-Key: ${API_KEY}" \
  --header "Content-Type: application/json" \
  --data "${maildata}"

# Notify Home Assistant
curl -X PUT -H "Content-Type: application/json" \
  -d '{ "key": "value" }' \
  https://ha.ucdialplans.com/api/webhook/media-backup-<REDACTED>

```