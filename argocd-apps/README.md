# Introduction
This folder contains the Argo CD application definitions for most of the Kubernetes workloads, excluding the media-apps, which depend on [Longhorn](/longhorn) volumes being available and restored from backup. This is currently a manual process.

It is starting to make use of [Argo CD sync-waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) to ensure that apps like [MariaDB databases](/mariadb) are up before the apps that depend on them (like [Gitea](/gitea), [VaultWarden](/vaultwarden) and others). The lower the number, the earlier in the process the app gets deployed.

The [00-disabled](/argocd-apps/00-disabled) folder is used to put applications that I don't want to use anymore, but might want to in the future.

Most of the Helm chart managed applications are set to auto-update to newer versions by way of setting `spec.sources.targetRevision: "*"`. A few (like Argo CD), are set to only upgrade minor revisions. Manually managed apps (without Helm charts) are updated via [Keel](/keel). The exceptions include:
* [Cilium](/cilium)
* [Longhorn](/longhorn)
* [MariaDB](/mariadb)

## Sync Wave -5
Apps that basically everything else depends on:
* [Argo CD](/argocd)
* [Cert Manager](/cert-manager)
* [Cilium](/cilium)
* [CSI Drivers](/csi-drivers)
* [Kubelet Serving Cert Approver](https://github.com/alex1989hu/kubelet-serving-cert-approver)
* [Sealed Secrets](/sealed-secrets)

## Sync Wave 1
* [Cloudflare Tunnel](/cloudflare-tunnel)
* [Longhorn](/longhorn)
* [MariaDB](/mariadb)
* [PHPMyAdmin](/phpmyadmin)
* [Registry](/registry)
* [SnapScheduler](/snapscheduler)

## Sync Wave 2
* [AdGuard Home](/adguard)
* [External DNS](/external-dns)
* [Smarter Device Manager](/smarter-device-manager)
* [Tailscale Operator](/tailscale)
* [UCDialplans](/ucdialplans)
* [UPS Monitor](/home-automation/ups-monitor)
* [ZWave Admin](/home-automation/zwaveadmin)

## Sync Wave 10
* [Descheduler](/descheduler)
* [ESPHome](/home-automation/esphome)
* [Gitea](/gitea)
* [Headlamp](/headlamp)
* [Home Assistant](/home-automation/homeassist)
* [Keel](/keel)
* [MariaDB Standalone](/mariadb-standalone)
* [Metrics Server](/metrics-server)
* [Portainer](/portainer)
* [Uptime Kuma](/uptime-kuma)
* [VaultWarden](/vaultwarden)

## Sync Wave 15
* [Alert Manager/Grafana/Prometheus/Loki](/promstack)
* [Sealed Secrets Web](/sealed-secrets-web)

## Sync Wave 99
* [Media Tools](/media-tools)