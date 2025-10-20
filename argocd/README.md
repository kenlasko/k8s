# Introduction
[Argo CD](https://github.com/argoproj/argo-cd) is the tool that declaratively manages every application running in the Kubernetes cluster. Every configuration setting is stored in this Github repo, which means that the entire cluster can be rapidly rebuilt without much work.

This deployment makes use of [Argo CD ApplicationSets](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/) to easily deploy new applications. Each application is grouped into a folder denoted by type. Each type is assigned an Argo CD Sync-Wave number, which defines the order that applications are installed. The ApplicationSets for both cloud and home deployments are found at [/argocd-appsets](/argocd-appsets)

|     Type    |  Description              |Syncwave| 
|:-----------:|:-------------------------:|:------:|
| [apps](/manifests/apps) | General applications | 10 | 
| [database](/manifests/database) | PostgreSQL/Redis | 1 |
| [homeops](/manifests/homeops) | Home Assistant and supporting apps | 10 |
| [media](/manifests/media) | Media apps (Plex/Radarr/Sonarr/etc) | 99 | 
| [monitoring](/manifests/monitoring) | Prometheus/Grafana/Loki etc | 15 | 
| [network](/manifests/network) | Cilium and other networking apps | 1 |
| [system](/manifests/system) | System-related apps | 1 |

Whether or not a given application is deployed on the home, cloud or lab cluster depends on the presense of `overlays/home`, `overlays/cloud` or `overlays/lab` within the application folder. If any are present (along with a `kustomization.yaml` and a `argocd-override.yaml`), then the application will be deployed on the given cluster.

# Authentication
ArgoCD is configured to use Github authentication instead of the built-in admin account. Github authentication uses [Github OAuth Apps](https://github.com/settings/developers), which is found under `User - Settings - Developer settings - OAuth Apps`. Steps to configure: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#dex

If local authentication needs to be re-enabled, first set `data.admin.enabled = "true"` in [configmap.yaml](/manifests/argocd/configmap.yaml), then login with the normal credentials. If this is the first time logging in, get the initial admin password via
```
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

# Troubleshooting
## ArgoCD apps showing as `Unknown`
Restart ArgoCD pods in this order:
1. argocd-dex-server
2. argocd-application-controller
3. argocd-server

## ArgoCD seems very slow to sync
Probably due to Unifi blocking SSH traffic due to `ET SCAN Potential SSH Scan OUTBOUND`. Resolve by adding the node IP to the Signature Suppression for this rule: https://unifi.ucdialplans.com/network/default/settings/security/cybersecure