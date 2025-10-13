# Introduction
This folder contains the Argo CD ApplicationSet definitions for all Kubernetes workloads.

It makes use of [Argo CD sync-waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) to ensure that apps like [PostgreSQL databases](/manifests/database/cnpg) and [Longhorn](/manifests/system/longhorn) are up before the apps that depend on them (like [VaultWarden](/manifests/apps/vaultwarden) and others). The lower the number, the earlier in the process the app gets deployed.

All software updates (excluding Kubernetes and OS) are managed via [Renovate](https://github.com/renovatebot/renovate). Renovate watches the Github repo and checks for software version updates on any Helm chart, ArgoCD application manifest or deployment manifest. If an update is found, Renovate will update the version in the repo and let ArgoCD handle the actual upgrade. All updates are logged in the repo as commits.

The configuration for Renovate is stored in [renovate.json](/renovate.json). The dashboard is available at https://developer.mend.io/github/kenlasko

|     Type    |  Description              |Syncwave| 
|:-----------:|:-------------------------:|:------:|
| [apps](/manifests/apps) | General applications | 10 | 
| [database](/manifests/database) | PostgreSQL/Redis | 2 |
| [homeops](/manifests/homeops) | Home Assistant and supporting apps | 10 |
| [media](/manifests/media) | Media apps (Plex/Radarr/Sonarr/etc) | 99 | 
| [monitoring](/manifests/monitoring) | Prometheus/Grafana/Loki etc | 15 | 
| [network](/manifests/network) | Cilium and other networking apps | 1 |
| [system](/manifests/system) | System-related apps | 1 |