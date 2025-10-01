# Introduction
This folder contains the Argo CD application definitions for all the Kubernetes workloads.

All software updates (excluding Kubernetes and OS) are managed via [Renovate](https://github.com/renovatebot/renovate). Renovate watches the Github repo and checks for software version updates on any Helm chart, ArgoCD application manifest or deployment manifest. If an update is found, Renovate will update the version in the repo and let ArgoCD handle the actual upgrade. All updates are logged in the repo as commits.

The configuration for Renovate is stored in [renovate.json](/renovate.json). The dashboard is available at https://developer.mend.io/github/kenlasko

The [00-disabled](/argocd-apps/00-disabled) folder is used to put applications that I don"t want to use anymore, but might want to in the future.

## Sync Wave -5
Apps that basically everything else depends on:
* [Cert Manager](/manifests/system/cert-manager)
* [Cilium](/manifests/network/cilium)
* [Kubelet Serving Cert Approver](https://github.com/alex1989hu/kubelet-serving-cert-approver)
* [External Secrets](/manifests/system/external-secrets)

## Sync Wave 1
* [Cloudflare Tunnel](/manifests/network/cloudflare-tunnel)
* [Longhorn](/manifests/system/longhorn)
* [PostgreSQL](/manifests/database/postgresql)
* [Registry](/manifests/system/registry)

## Sync Wave 2
* [AdGuard Home](/manifests/apps/adguard)
* [External DNS](/manifests/network/external-dns)
* [Smarter Device Manager](/manifests/system/smarter-device-manager)
* [UCDialplans](/manifests/apps/ucdialplans)
* [VaultWarden](/manifests/apps/vaultwarden)

## Sync Wave 10
* [Metrics Server](/manifests/system/metrics-server)
* [Uptime Kuma](/manifests/monitoring/uptime-kuma)

## Sync Wave 15
* [Alert Manager/Grafana/Prometheus/Loki](/manifests/monitoring/promstack)
