# Introduction
[Tailscale Operator](https://tailscale.com/kb/1236/kubernetes-operator) allows for secured access between workloads on different systems connected via a Tailscale network.

# Configuration
## ProxyClass
A Tailscale ProxyClass defines parameters that are to be applied to a Tailscale endpoint. Our single [run-on-worker](/manifests/network/tailscale/proxyclass.yaml) ProxyClass specifies the Tailscale pods should run on worker nodes only as well as use `/dev/tun/` devices exposed by [Smarter Device Manager](/manifests/system/smarter-device-manager).

## Services
To make a service available on a Tailnet, simply add the following annotation to the service: `tailscale.com/proxy-class: "run-on-worker"`

The following services are exposed on my tailnet:

|     Service    |  Namespace  | Cluster |  Tailnet Name  |      Purpose                                        |
:---------------:|:-----------:|:--------------:|:---------:|:----------------------------------------------------|
|[adguard-service](/manifests/apps/adguard/overlays/home/values-adguard.yaml) |adguard | home | home-adguard | For external-dns cloud automatic DNS record updating|
| [mariadb](/manifests/database/mariadb/values.yaml) | mariadb | home | home-mariadb | For cloud MariaDB replication |
| [postgresql-service](/manifests/database/postgresql/overlays/home/cluster.yaml)) | postgresql | home | home-postgresql | For cloud PostgreSQL replication |



## Connecting to service on Tailnet
To connect to a remote service via Tailnet, you need to define an `ExternalName` service in the namespace you want to connect from. 

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
