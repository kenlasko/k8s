# Introduction
This folder contains the Argo CD application definitions for most of the Kubernetes workloads, excluding the media-apps, which depend on [Longhorn](/manifests/longhorn) volumes being available and restored from backup. This is currently a manual process.

It is starting to make use of [Argo CD sync-waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) to ensure that apps like [MariaDB databases](/manifests/mariadb) are up before the apps that depend on them (like [Gitea](/manifests/gitea), [VaultWarden](/manifests/vaultwarden) and others). The lower the number, the earlier in the process the app gets deployed.

The [00-disabled](/argocd-apps/00-disabled) folder is used to put applications that I don"t want to use anymore, but might want to in the future.


## Sync Wave -5
Apps that basically everything else depends on:
* [Argo CD](/manifests/argocd)
* [Cert Manager](/manifests/cert-manager)
* [Cilium](/manifests/cilium)
* [CSI Drivers](/manifests/csi-drivers)
* [Kubelet Serving Cert Approver](https://github.com/alex1989hu/kubelet-serving-cert-approver)
* [Sealed Secrets](/manifests/sealed-secrets)

## Sync Wave 1
* [Cloudflare Tunnel](/manifests/cloudflare-tunnel)
* [Longhorn](/manifests/longhorn)
* [MariaDB](/manifests/mariadb)
* [PHPMyAdmin](/manifests/phpmyadmin)
* [Registry](/manifests/registry)
* [SnapScheduler](/manifests/snapscheduler)

## Sync Wave 2
* [AdGuard Home](/manifests/adguard)
* [External DNS](/manifests/external-dns)
* [Smarter Device Manager](/manifests/smarter-device-manager)
* [Tailscale Operator](/manifests/tailscale)
* [UCDialplans](/manifests/ucdialplans)
* [UPS Monitor](/manifests/home-automation/ups-monitor)
* [ZWave Admin](/manifests/home-automation/zwaveadmin)

## Sync Wave 10
* [Descheduler](/manifests/descheduler)
* [ESPHome](/manifests/home-automation/esphome)
* [Gitea](/manifests/gitea)
* [Headlamp](/manifests/headlamp)
* [Home Assistant](/manifests/home-automation/homeassist)
* [MariaDB Standalone](/manifests/mariadb-standalone)
* [Metrics Server](/manifests/metrics-server)
* [Portainer](/manifests/portainer)
* [Uptime Kuma](/manifests/uptime-kuma)
* [VaultWarden](/manifests/vaultwarden)

## Sync Wave 15
* [Alert Manager/Grafana/Prometheus/Loki](/manifests/promstack)
* [Sealed Secrets Web](/manifests/sealed-secrets-web)

## Sync Wave 99
* [Media Tools](/manifests/media-tools)