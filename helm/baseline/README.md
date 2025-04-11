This is an extremely opinionated chart that vastly simplifies the deployment of applications that themselves do not have a default Helm chart. 

It allows me to deploy new applications in my cluster that meet pretty much any custom requirements/options in my cluster, such as:
- Adding a media PVC for [media-apps](/manifests/media-apps)
- Adding a [Tailscale](/manifests/network/tailscale) external name service for connecting to a matching Tailscale connection on the [Cloud K8S](https://github.com/kenlasko/cloud-k8s) cluster
- Creating [VolSync](/manifests/system/volsync) backups on remote S3 buckets
- Create consistently-named PV/PVCs for either [Longhorn](/manifests/system/longhorn), NFS or local volumes

## Testing chart updates
```
helm template plex ~/k8s/helm/baseline -n media-apps -f ~/k8s/manifests/media-tools/plex/values.yaml > ~/chart-test.yaml
```
