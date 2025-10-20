# Introduction
This folder contains the Argo CD ApplicationSet definitions for all Kubernetes workloads. There are three sets of ApplicationSets: one each for the home, cloud and lab clusters. The main difference is that the cloud cluster doesn't have ApplicationSets for HomeOps or Media workloads.

Each application requires the presence of a file called `argocd-override.yaml`. This file can be used to add ArgoCD application overrides for the apps that require it. In most cases, its used to add informational links about the app. 

It makes use of [Argo CD sync-waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) to ensure that apps like [PostgreSQL databases](/manifests/database/cnpg) and [Longhorn](/manifests/system/longhorn) are up before the apps that depend on them (like [VaultWarden](/manifests/apps/vaultwarden) and others). The lower the number, the earlier in the process the app gets deployed.

All software updates (excluding Kubernetes and OS) are managed via [Renovate](https://github.com/renovatebot/renovate). Renovate watches the Github repo and checks for software version updates on any Helm chart, ArgoCD application manifest or deployment manifest. If an update is found, Renovate will update the version in the repo and let ArgoCD handle the actual upgrade. All updates are logged in the repo as commits.

The configuration for Renovate is stored in [renovate.json](/renovate.json). The dashboard is available at https://developer.mend.io/github/kenlasko

|     Type    |  Description              |Syncwave| 
|:-----------:|:-------------------------:|:------:|
| [apps](/manifests/apps) | General applications | 10 | 
| [database](/manifests/database) | PostgreSQL/Redis | 1 |
| [homeops](/manifests/homeops) | Home Assistant and supporting apps | 10 |
| [media](/manifests/media) | Media apps (Plex/Radarr/Sonarr/etc) | 99 | 
| [monitoring](/manifests/monitoring) | Prometheus/Grafana/Loki etc | 15 | 
| [network](/manifests/network) | Cilium and other networking apps | 1 |
| [system](/manifests/system) | System-related apps | 1 |