This is an extremely opinionated chart that vastly simplifies the deployment of applications that themselves do not have a default Helm chart. 

It allows me to deploy new applications in my cluster that meet pretty much any custom requirements/options in my cluster, such as:
- Adding a media PVC for [media-apps](/manifests/media)
- Creating default HTTPRoutes for web access
- Adding a [Tailscale](/manifests/network/tailscale) external name service for connecting to a matching Tailscale connection on the Cloud K8S cluster
- Creating [VolSync](/manifests/system/volsync) backups on remote S3 buckets
- Create consistently-named PV/PVCs for either [Longhorn](/manifests/system/longhorn), NFS or local volumes
- Creating an [OAuth2Proxy](https://oauth2-proxy.github.io/oauth2-proxy/) sidecar container to provide [Pocket-ID](/manifests/system/pocket-id) managed OIDC authentication for applications without OIDC support

Pretty much any application that doesn't have a managed external Helm chart uses this custom Helm chart. It includes:
- [Adguard Home](/manifests/apps/adguard)
- [Cloudflare Tunnel](/manifests/network/cloudflare)
- [All homeops apps](/manifests/homeops)
- [All media apps](/manifests/media)
- [Paperless](/manifests/apps/paperless)
- [Vaultwarden](/manifests/apps/vaultwarden)

## Testing chart updates
```
helm template plex ~/k8s/helm/baseline -n media -f ~/k8s/manifests/media/plex/values.yaml > ~/chart-test.yaml
```
