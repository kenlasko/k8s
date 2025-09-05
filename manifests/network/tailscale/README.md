# Introduction
[Tailscale Operator](https://tailscale.com/kb/1236/kubernetes-operator) allows for secured access between workloads on different systems connected via a Tailscale network.

I use Tailscale to directly access services on remote clusters for things like replication and updates. I also use it to access cloud cluster HTTP resources via `HTTPRoutes` published on the home cluster.

# Configuration
## Authentication
To authorize my cluster to create machines on the Tailnet, a secret called `operator-oauth` is required that contains OAuth credentials for my Tailnet. The Tailscale Operator will use these credentials for all created machines. This is created via External Secrets Operator. The ESO object is called [external-secrets.yaml](/manifests/network/tailscale/base/external-secrets.yaml).

## ProxyClass
A Tailscale ProxyClass defines parameters that are to be applied to a Tailscale endpoint. Our single [run-on-worker](/manifests/network/tailscale/proxyclass.yaml) ProxyClass specifies the Tailscale pods should run on worker nodes only as well as use `/dev/tun/` devices exposed by [Smarter Device Manager](/manifests/system/smarter-device-manager).

Each cluster has a custom ProxyClass. For the home cluster, the ProxyClass name is `run-on-worker`. The cloud cluter uses `enable-tun`.

## Services
To make a service available on a Tailnet, simply add the following annotations to the service: 
```
annotations:
  tailscale.com/expose: true
  tailscale.com/hostname: <name-to-show-on-tailnet>
  tailscale.com/proxy-class: <run-on-worker|enable-tun>
```
This will create a machine on the Tailnet attached to the service.

The following services are exposed on my Tailnet:

|     Service    |  Namespace  | Cluster |  Tailnet Machine Name  | Purpose                                |
|:--------------:|:-----------:|:-------:|:----------------------:|:---------------------------------------|
|[adguard-service](/manifests/apps/adguard/overlays/home/values-adguard.yaml) |adguard | home | home-adguard | External-DNS cloud automatic DNS record updating |
| [mariadb](/manifests/database/mariadb/values.yaml) | mariadb | home | home-mariadb | Cloud MariaDB replication |
| [postgresql-service](/manifests/database/postgresql/overlays/home/cluster.yaml) | postgresql | home | home-postgresql | Cloud PostgreSQL replication |
| [adguard-service](/manifests/apps/adguard/overlays/cloud/values.yaml) | adguard | cloud | cloud-adguard | Web access via home cluster |
| [argocd-server](/argocd/overlays/cloud/values.yaml) | argocd | cloud | cloud-argocd | Web access via home cluster |
| [mariadb](/manifests/database/mariadb-cloud/values.yaml) | mariadb | cloud | cloud-mariadb | PHPMyAdmin access via home cluster |
| [postgresql-service](/manifests/database/postgresql/overlays/cloud/cluster.yaml) | postgresql | cloud | cloud-postgresql | PGAdmin access via home cluster |


## Connecting to remote services on Tailnet
To connect to a remote service via Tailnet, you need to define an `ExternalName` service in the source namespace you want to connect from.  The service must have the following annotations:
```
annotations:
  tailscale.com/tailnet-fqdn: <fqdn-of-tailnet-service-to-attach-to>
  tailscale.com/hostname: <name-to-show-on-tailnet>
```

The associated application uses the external name to connect to the remote service. Example below:

```
apiVersion: v1
kind: Service
metadata:
  annotations:
    tailscale.com/tailnet-fqdn: 'home-mariadb.tailb7050.ts.net' # The FQDN of the remote Tailnet service to connect to
    tailscale.com/hostname: home-mariadb-link                   # The name to use for the Tailnet machine
  name: home-mariadb-link                                       # The name your application will use to connect to the service
spec:
  externalName: home-mariadb-link
  type: ExternalName
```

The following external name services and associated Tailnet machines are configured in my clusters:
|     Service            |  Namespace   | Cluster |  Tailnet Machine Name  |      Attached To      | Purpose         |
|:----------------------:|:------------:|:-------:|:----------------------:|:---------------------:|:----------------|
| [home-adguard-link](/manifests/network/external-dns/overlays/cloud/service.yaml) | external-dns | cloud | home-adguard-link | home-adguard | External-DNS cloud automatic DNS record updating |
| [home-mariadb-link](/manifests/database/mariadb-cloud/service.yaml) | mariadb | cloud | home-mariadb-link | home-mariadb | Cloud MariaDB replication |
| [home-postgresql](/manifests/database/postgresql/overlays/cloud/service.yaml) | postgresql | cloud | home-postgresql-link | home-postgresql | Cloud PostgreSQL replication |
| [cloud-adguard-link](/manifests/network/tailscale/overlays/home/tunnel-cloud-adguard.yaml) | tailscale | home | cloud-adguard-link | cloud-adguard | Web access via home cluster |
| [cloud-argocd-egress](/manifests/network/tailscale/overlays/home/tunnel-cloud-argocd.yaml) | tailscale | home | cloud-argocd-egress | cloud-argocd | Web access via home cluster |
| [cloud-mariadb-link](/manifests/database/phpmyadmin/service.yaml) | mariadb | home | cloud-mariadb-link | cloud-mariadb | PHPMyAdmin access via home cluster |
| [cloud-postgresql-link](/manifests/database/postgresql/overlays/home/service.yaml) | postgresql | home | cloud-postgresql-link | cloud-postgresql | PGAdmin access via home cluster |
| [cloud-uptime-kuma-link](/manifests/network/tailscale/overlays/home/tunnel-cloud-uptime-kuma.yaml) | tailscale | home | cloud-uptime-kuma-link | cloud-uptime-kuma | Web access via home cluster |

## Accessing remote HTTP resources via Tailnet
Accessing remote HTTP resources via Tailnet introduced some challenges. Setting up `HTTPRoutes` against `ExternalName` service types doesn't work, so an additional layer has to be used. I used [socat](https://linux.die.net/man/1/socat) as an intermediary pod to proxy HTTP requests from a local HTTPRoute. The general flow looks like this:

HTTPRoute ---> Socat Service ---> Socat Pod ---> | Tailnet Machine | ---> Remote Service

This format works well for the limited number of cloud services I want to access via HTTP from my home network. The services that use this format include:
- [ArgoCD](/manifests/network/tailscale/overlays/home/tunnel-cloud-argocd.yaml)
- [VaultWarden](/manifests/network/tailscale/overlays/home/tunnel-cloud-vaultwarden.yaml)