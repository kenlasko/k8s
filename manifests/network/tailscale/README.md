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
|[adguard-service](/manifests/apps/adguard/overlays/home/values-adguard.yaml) |adguard | home | home-adguard | For external-dns cloud automatic DNS record updating |
| [mariadb](/manifests/database/mariadb/values.yaml) | mariadb | home | home-mariadb | For cloud MariaDB replication |
| [postgresql-service](/manifests/database/postgresql/overlays/home/cluster.yaml) | postgresql | home | home-postgresql | For cloud PostgreSQL replication |
| [adguard-service](/manifests/apps/adguard/overlays/cloud/values.yaml) | adguard | cloud | cloud-adguard |For web access via home cluster |
| [argocd-server](/argocd/overlays/cloud/values.yaml) | argocd | cloud | cloud-argocd | For web access via home cluster |
| [mariadb](/manifests/database/mariadb-cloud/values.yaml) | mariadb | cloud | cloud-mariadb | For PHPMyAdmin access via home cluster |
| [postgresql-service](/manifests/database/postgresql/overlays/cloud/cluster.yaml) | postgresql | cloud | cloud-postgresql | For PGAdmin access via home cluster |
| [vaultwarden-service](/manifests/apps/vaultwarden/overlays/cloud/values.yaml) | vaultwarden | cloud | cloud-vaultwarden | For web access via home cluster |


## Connecting to remote services on Tailnet
To connect to a remote service via Tailnet, you need to define an `ExternalName` service in the source namespace you want to connect from.  The service must have the following annotations:
```
annotations:
  tailscale.com/proxy-class: <run-on-worker|enable-tun>
  tailscale.com/tailnet-fqdn: <fqdn-of-tailnet-service-to-attach-to>
```

The associated application uses the external name to connect to the remote service. Example below:

```
---
apiVersion: v1
kind: Service
metadata:
  labels:
    tailscale.com/proxy-class: "run-on-worker"
  annotations:
    tailscale.com/tailnet-fqdn: 'cloud-mariadb.tailb7050.ts.net'  # This is the FQDN of the Tailnet service you want to connect to
  name: cloud-mariadb-egress  # This is the name your application will connect to in order to reach the external Tailnet service
  namespace: mariadb
spec:
  externalName: cloud-mariadb-egress
  type: ExternalName
```

The following external name services and associated Tailnet machines are configured in my clusters:
|     Service            |  Namespace   | Cluster |  Tailnet Machine Name  |      Attached To      |
|:----------------------:|:------------:|:-------:|:----------------------:|:---------------------:|
| cloud-egress-adguard   | external-dns |  cloud  | cloud-egress-adguard   | home-adguard          |