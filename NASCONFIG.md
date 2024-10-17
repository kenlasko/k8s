# Introduction
This cluster makes heavy use of NAS resources for storing stateful files that play well with NFS. For workloads that don't work with NFS (such as SQLLite databases), Longhorn is used.

This document helps define the configuration of storage used in this Kubernetes cluster

# Base Folders
These are the base folders used for the cluster. These are visible in the cluster as NFS shares. Actual location doesn't matter.
* appdata - used for application storage
* backup - used for backup data
* media - used for media (movies/TV/music etc)

## Appdata
This folder stores all the data used by applications. Most applications use standard NFS folders (stored under `/appdata/vol`), which have to be pre-defined for use by PV/PVCs. A few use the [NFS Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner), which automatically creates folders. These are stored under `/appdata/pv` However, these folder names are not terribly readable, and are only used for workloads that can't use the predefined PV/PVC option. These are also folders that don't require backup as they're just 
```
/share/appdata
├── container-station-data  # QNAP Container Station
├── docker-vol              # Docker volume data for Container Station
├── pv                      # NFS Provisioner data
├── pxeboot                 # PXEBoot data for Matchbox
└── vol                     # NFS appdata (pre-created base folders)
```

### appdata/pv
These folders are used by apps that make use of the [NFS Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner). The benefit of this is that the app folders don't have to exist. The downside is that its difficult/impossible (as far as I know) to re-use one of these should the app be deleted and recreated. This is reserved for workloads that I don't care about backing up or restoring after a cluster rebuild.
Apps that currently use the `appdata/pv` folder are:
* [alertmanager/grafana/loki/prometheus](/monitoring)

### appdata/vol
These folders are used for most apps that don't have SQLLite databases (Longhorn is used for workloads with SQLLite DBs). The cluster uses PV/PVCs to attach to them. The folders must exist before the apps can use them. These are backed up using the [NAS AppData Backup](/nfs-provisioner) script.
Apps that currently use the `appdata/vol` folder are:
* [adguard](/adguard)
* [esphome](/home-automation/esphome)
* [garmin-upload](/garmin-upload)
* [gitea](/gitea)
* [homeassist](/home-automation/homeassist)
* [keel](/keel)
* [nectar](/nectar)
* [pgadmin](/pgadmin)
* [portainer](/portainer)
* [recyclarr](/media-tools/recyclarr)
* [registry](/registry)
* [romm](/media-tools/romm)
* [transmission](/media-tools/transmission)
* [ucdialplans](/ucdialplans)
* [ups-monitor](/home-automation/ups-monitor)
* [uptime-kuma](/uptime-kuma)
* [vaultwarden](/vaultwarden)
* [zwaveadmin](/home-automation/zwaveadmin)

To create these folders on a fresh install (may not be necessary, depending on how the data is restored):
```
mkdir adguard esphome garmin-upload gitea homeassist keel nectar pgadmin portainer recyclarr registry romm transmission ucdialplans ups-monitor uptime-kuma vaultwarden zwaveadmin
```

## Backup
This folder stores data created by backup processes, such as Longhorn and manual backup scripts, such as:
* [Media Apps](/media-tools/backup)
* [NAS AppData Backup](/nfs-provisioner)
