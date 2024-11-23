# Introduction
This cluster makes heavy use of NAS resources for storing stateful files that play well with NFS. For workloads that don't work with NFS (such as SQLite databases), Longhorn is used.

This document helps define the configuration of storage used in this Kubernetes cluster.

# Base Folders
These are the base folders used for the cluster. These are visible in the cluster as NFS shares. Actual location doesn't matter.
* **appdata** - used for application storage
* **backup** - used for backup data
* **media** - used for media (movies/TV/music etc)

## Appdata
This folder stores all the data used by applications. Most applications use standard NFS folders (stored under `/appdata/vol`), which have to be pre-defined for use by PV/PVCs. A few use the [NFS Subdir Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner), which automatically creates folders. These are stored under `/appdata/pv` However, these folder names are not terribly readable, and are only used for workloads that can't use the predefined PV/PVC option. These are also folders that don't require backup as they just store log and performance metrics.
```
/share/appdata
├── container-station-data  # QNAP Container Station
├── docker-vol              # Docker volume data for Container Station
├── pv                      # NFS Subdir Provisioner data
├── pxeboot                 # PXEBoot data for Matchbox
└── vol                     # NFS appdata (pre-created base folders)
```

### appdata/pv
These folders are used by apps that make use of the [NFS Subdir Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner). The benefit of this is that the app folders don't have to exist prior to running the workload. The downside is that its difficult/impossible (as far as I know) to re-use one of these should the workload be deleted and recreated. This is reserved for workloads that I don't care about backing up or restoring after a cluster rebuild.
Apps that currently use the `appdata/pv` folder are:
* [alertmanager/grafana/loki/prometheus](/monitoring)

### appdata/pxeboot
This folder stores all the files used for network booting (PXE) into [Talos OS](https://www.siderolabs.com/platform/talos-os-for-kubernetes/). Installing the Talos OS on cluster members is handled by [Matchbox](https://github.com/poseidon/matchbox) via PXE. Follow the [PXEBoot instructions](https://github.com/kenlasko/pxeboot) to setup.

### appdata/vol
These folders are used for most apps that don't have SQLite databases ([Longhorn](https://github.com/longhorn/longhorn) is used for workloads with SQLite DBs). The cluster uses defined PV/PVCs to attach to them. The folders must exist before the apps can use them. These are backed up using the [NAS AppData Backup](/nfs-provisioner) script.
Apps that currently use the `appdata/vol` folder are:
* [adguard](/adguard)
* [esphome](/home-automation/esphome)
* [garmin-upload](/garmin-upload)
* [gitea](/gitea)
* [homeassist](/home-automation/homeassist)
* [keel](/keel)
* [nectar-ps](/nectar-ps)
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
cd /share/appdata
mkdir adguard esphome garmin-upload gitea homeassist keel nectar pgadmin portainer recyclarr registry romm transmission ucdialplans ups-monitor uptime-kuma vaultwarden zwaveadmin
```

## Backup
This folder stores data created by backup processes, such as Longhorn and manual backup scripts:
* [Github Repo Backup](/gitea/configmap-github-backup.yaml)
* [MariaDB Backup](/mariadb/backup-cronjob.yaml)
* [Media Apps](/media-tools/backup)
* [NAS AppData Vol Backup](/nfs-provisioner/configmap-backup-apps-script.yaml)
* [Sealed Secret Backup](/sealed-secrets/configmap-script.yaml)

```
/share/backup
├── apps        # Media apps
├── github      # Github repo
├── k3s         # Sealed Secret backup
├── longhorn    # Done from within Longhorn
├── mariadb     # MariaDB
├── nas         # QNAP backup
├── omni        # SideroLabs Omni cluster management
└── vol         # appdata/vol
```

To create these folders on a fresh install:
```
cd /share/backup
mkdir apps github k3s longhorn mariadb nas omni vol
```