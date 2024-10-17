# Introduction
This cluster makes heavy use of NAS resources for storing stateful files that play well with NFS. For workloads that don't work with NFS (such as SQLLite databases), Longhorn is used.

This document helps define the configuration of storage used in this Kubernetes cluster

# Base Folders
These are the base folders used for the cluster. These are visible in the cluster as NFS shares. Actual location doesn't matter.
* appdata - used for application storage
* backup - used for backup data
* media - used for media (movies/TV/music etc)

## Appdata
This folder stores all the data used by applications. Most applications use standard NFS folders (stored under `/appdata/vol`), which have to be pre-defined for use by PV/PVCs. A few use the NFS operator, which automatically creates folders. These are stored under `/appdata/pv` However, these folder names are not terribly readable, and are only used for workloads that can't use the predefined PV/PVC option.
```
/share/appdata
├── container-station-data  # QNAP Container Station
├── docker-vol				# Docker volume data for Container Station
├── pv						# NFS operator data
├── pxeboot					# PXEBoot data for Matchbox
└── vol						# NFS appdata (pre-created base folders)
```

Apps that currently use the appdata folder are:
* [adguard](/adguard)
* [esphome]
* [garmin-upload]
* [gitea]
* [homeassist]
* [keel]
* [lidarr]
* [nectar]
* [pgadmin]
* [portainer]
* [recyclarr]
* [registry]
* [romm]
* [transmission]
* [ucdialplans]
* [ups-monitor]
* [uptime-kuma]
* [vaultwarden]
* [zwaveadmin]

To create these folders on a fresh install (may not be necessary, depending on how the data is restored):
```
mkdir adguard esphome garmin-upload gitea homeassist keel lidarr nectar pgadmin portainer recyclarr registry romm transmission ucdialplans ups-monitor uptime-kuma vaultwarden zwaveadmin
```

## Backup
This folder stores data created by backup processes, such as Longhorn and manual backup scripts such as 