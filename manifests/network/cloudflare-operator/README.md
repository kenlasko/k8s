# Introduction
[Cloudflare Operator](https://github.com/adyanth/cloudflare-operator) manages [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) through Kubernetes CRDs. It lets me expose web services to the Internet without opening any ports on my firewall, with Cloudflare providing security and protection in front of each service.

This replaces my previous [Cloudflared Tunnel](/archive/network/cloudflare) deployment. Instead of a statically-defined `cloudflared` Deployment, the operator watches `ClusterTunnel` resources and creates/manages the underlying tunnel, its credentials, and the `cloudflared` Deployment for me. Each cluster owns its own tunnel.

# Configuration
The operator is pulled directly from the upstream `config/default` kustomize base and patched in [base/kustomization.yaml](/manifests/network/cloudflare-operator/base/kustomization.yaml). The notable patches:
* The upstream base ships its own `cloudflare-operator-system` namespace. Pod-security labels are added to it via patch rather than shipping a second `Namespace` object that would collide with the overlay's `namespace:` transformer.
* cert-manager `Certificate` `dnsNames` and the `cert-manager.io/inject-ca-from` annotation are retargeted from the hardcoded `cloudflare-operator-system` namespace to `cloudflare` so the webhook serving cert and CA injection match the relocated webhook Service.
* The controller's `--cluster-resource-namespace` is set to `cloudflare`. This controls leader-election **and** where `ClusterTunnel`s create their `cloudflared` Deployment and credentials.

## Authentication
The operator needs a Cloudflare API token to create and manage tunnels. This is delivered via External Secrets Operator in [base/external-secrets.yaml](/manifests/network/cloudflare-operator/base/external-secrets.yaml), which writes a secret named `cloudflare-operator-secret` containing the `CLOUDFLARE_API_TOKEN` key. The secret name must match `spec.cloudflare.secret` in each `ClusterTunnel`.

## ClusterTunnels
Each overlay defines a single `ClusterTunnel` that the operator reconciles into a real Cloudflare tunnel:

|     Cluster    |  Tunnel Name  | Protocol | Manifest |
|:--------------:|:-------------:|:--------:|:---------|
| home  | `k8s-home`  | auto (QUIC) | [overlays/home/clustertunnel.yaml](/manifests/network/cloudflare-operator/overlays/home/clustertunnel.yaml) |
| cloud | `k8s-cloud` | http2       | [overlays/cloud/clustertunnel.yaml](/manifests/network/cloudflare-operator/overlays/cloud/clustertunnel.yaml) |

Notes:
* The cloud cluster forces `protocol: http2` (TCP 7844) because its network drops outbound UDP 7844, so the default auto/QUIC transport can't reach the Cloudflare edge.
* Each `ClusterTunnel` carries the `argocd.argoproj.io/sync-wave: "1"` annotation so it is applied only after the operator (wave 0) is Healthy — the conversion webhook must be up and cert-manager must have injected the CA bundle first.

## Network Policy
[base/networkpolicy.yaml](/manifests/network/cloudflare-operator/base/networkpolicy.yaml) defines a `CiliumNetworkPolicy` restricting operator egress to in-cluster traffic, kube-apiserver, DNS, and the Cloudflare edge FQDNs (`*.cloudflare.com`, `*.argotunnel.com`, `*.cloudflareaccess.com`) on ports 443 and 7844 (TCP/UDP). It is currently commented out of the kustomization while tunnel connectivity is validated.

# Exposing a Service
Services are routed through a tunnel declaratively with a `TunnelBinding` manifest — no clicking around the Cloudflare Dashboard. The operator watches `TunnelBinding`s, creates the public hostname on the referenced tunnel, and points it at the named Kubernetes `Service`. The DNS record is created automatically with the binding.

Drop a `cloudflare-tunnel.yaml` alongside the app's other manifests:

```yaml
apiVersion: networking.cfargotunnel.com/v1alpha1
kind: TunnelBinding
metadata:
  name: monize
  namespace: monize
subjects:
- kind: Service
  name: monize-frontend-service   # the in-cluster Service to expose
  spec:
    fqdn: monize.laskonet.com      # the public hostname to publish
tunnelRef:
  kind: ClusterTunnel
  name: k8s-home                   # k8s-home or k8s-cloud
```

The binding lives in the **same namespace as the target Service**, and `tunnelRef.name` selects which cluster tunnel carries the traffic (`k8s-home` or `k8s-cloud`). Services currently exposed this way include:

|     Service    |  Namespace  | Tunnel | FQDN | Manifest |
|:--------------:|:-----------:|:------:|:-----|:---------|
| monize-frontend-service | monize | k8s-home | monize.laskonet.com | [monize/overlays/home](/manifests/apps/monize/overlays/home/cloudflare-tunnel.yaml) |
| monize-frontend-service | monize | k8s-cloud | monize-demo.laskonet.com | [monize/overlays/cloud](/manifests/apps/monize/overlays/cloud/cloudflare-tunnel.yaml) |
| homeassist-service | homeops | k8s-home | ha-ext.laskonet.com | [homeassist/base](/manifests/homeops/homeassist/base/cloudflare-tunnel.yaml) |
| pocket-id-service | pocket-id | k8s-home | auth.laskonet.com | [pocket-id/base](/manifests/system/pocket-id/base/cloudflare-tunnel.yaml) |
| calibre-service | media | k8s-home | books.laskonet.com | [calibre/base](/manifests/media/calibre/base/cloudflare-tunnel.yaml) |
| seerr-service | media | k8s-home | seerr.laskonet.com | [seerr/base](/manifests/media/seerr/base/cloudflare-tunnel.yaml) |

Protecting an exposed service with Cloudflare Access (identity providers, policies, App Launcher) is still configured in the [Cloudflare Dashboard](https://dash.cloudflare.com) — see the [archived Cloudflare README](/archive/network/cloudflare/README.md) for that walkthrough.
