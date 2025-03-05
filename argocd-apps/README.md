# Introduction
This folder contains the Argo CD application definitions for most of the Kubernetes workloads, excluding the media-apps, which depend on [Longhorn](/manifests/longhorn) volumes being available and restored from backup. This is currently a manual process.

It is starting to make use of [Argo CD sync-waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) to ensure that apps like [MariaDB databases](/manifests/mariadb) are up before the apps that depend on them (like [Gitea](/manifests/gitea), [VaultWarden](/manifests/vaultwarden) and others). The lower the number, the earlier in the process the app gets deployed.

All software updates (excluding Kubernetes and OS) are managed via [Renovate](https://github.com/renovatebot/renovate). Renovate watches the Github repo and checks for software version updates on any Helm chart, ArgoCD application manifest or deployment manifest. If an update is found, Renovate will update the version in the repo and let ArgoCD handle the actual upgrade. All updates are logged in the repo as commits.

The configuration for Renovate is stored in [renovate.json](/renovate.json). The dashboard is available at https://developer.mend.io/github/kenlasko

The [00-disabled](/argocd-apps/00-disabled) folder is used to put applications that I don"t want to use anymore, but might want to in the future.


## Sync Wave -5
Apps that basically everything else depends on:
* [Argo CD](/manifests/argocd)
* [Cert Manager](/manifests/system/cert-manager)
* [Cilium](/manifests/network/cilium)
* [CSI Drivers](/manifests/system/csi-drivers)
* [Kubelet Serving Cert Approver](https://github.com/alex1989hu/kubelet-serving-cert-approver)
* [Sealed Secrets](/manifests/system/sealed-secrets)

## Sync Wave 1
* [Cloudflare Tunnel](/manifests/network/cloudflare-tunnel)
* [Longhorn](/manifests/system/longhorn)
* [MariaDB](/manifests/network/mariadb)
* [PHPMyAdmin](/manifests/network/phpmyadmin)
* [Registry](/manifests/system/registry)
* [SnapScheduler](/manifests/system/snapscheduler)

## Sync Wave 2
* [AdGuard Home](/manifests/apps/adguard)
* [External DNS](/manifests/network/external-dns)
* [Smarter Device Manager](/manifests/system/smarter-device-manager)
* [Tailscale Operator](/manifests/network/tailscale)
* [UCDialplans](/manifests/apps/ucdialplans)
* [UPS Monitor](/manifests/homeops/ups-monitor)
* [ZWave Admin](/manifests/homeops/zwaveadmin)

## Sync Wave 10
* [Descheduler](/manifests/system/descheduler)
* [ESPHome](/manifests/homeops/esphome)
* [Gitea](/manifests/apps/gitea)
* [Headlamp](/manifests/apps/headlamp)
* [Home Assistant](/manifests/homeops/homeassist)
* [MariaDB Standalone](/manifests/database/mariadb-standalone)
* [Metrics Server](/manifests/monitoring/metrics-server)
* [Portainer](/manifests/apps/portainer)
* [Uptime Kuma](/manifests/monitoring/uptime-kuma)
* [VaultWarden](/manifests/apps/vaultwarden)

## Sync Wave 15
* [Alert Manager/Grafana/Prometheus/Loki](/manifests/monitoring/promstack)
* [Sealed Secrets Web](/manifests/system/sealed-secrets-web)

## Sync Wave 99
* [Media Tools](/manifests/apps/media-apps)