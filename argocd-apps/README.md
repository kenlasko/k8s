# Introduction
This folder contains the Argo CD application definitions for most of the Kubernetes workloads, excluding the media-apps, which depend on [Longhorn](/longhorn) volumes being available and restored from backup. This is currently a manual process.

It is starting to make use of [Argo CD sync-waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) to ensure that apps like [MariaDB databases](/mariadb) are up before the apps that depend on them (like [Gitea](/gitea), [VaultWarden](/vaultwarden) and others). The lower the number, the earlier in the process the app gets deployed.

## Sync Wave -5
Apps that basically everything else depends on:
* [Cert Manager](/cert-manager)
* [Cilium](/cilium)
* [Kubelet Serving Cert Approver](https://github.com/alex1989hu/kubelet-serving-cert-approver)
* [NFS Provisioner](/nfs-provisioner)
* [Sealed Secrets](/sealed-secrets)

## Sync Wave 1
* [Cloudflare Tunnel](/cloudflare-tunnel)
* [Longhorn](/longhorn)
* [MariaDB](/mariadb)
* [PHPMyAdmin](/phpmyadmin)
* [Registry](/registry)


## Sync Wave 2
* [AdGuard Home](/adguard)
* [External DNS](/external-dns)
* [Home Assistant](/home-automation/homeassist)
* [Smarter Device Manager][/smarter-device-manager]
* [UCDialplans](/ucdialplans)
* [UPS Monitor](/home-automation/ups-monitor)
* [VaultWarden](/vaultwarden)
* [ZWave Admin](/home-automation/zwaveadmin)

## Sync Wave 5
* 