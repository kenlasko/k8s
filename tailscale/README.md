# Introduction
[Tailscale Operator](https://tailscale.com/kb/1236/kubernetes-operator) allows for secured access between workloads on different systems connected via a Tailscale network.

# Configuration
## ProxyClass
A Tailscale ProxyClass defines parameters that are to be applied to a Tailscale endpoint. Our single [run-on-worker](/tailscale/proxyclass.yaml) ProxyClass specifies the Tailscale pods should run on worker nodes only as well as use `/dev/tun/` devices exposed by [Smarter Device Manager](/smarter-device-manager).

## Services
To make a service available on a Tailnet, simply add the following label to the service: `tailscale.com/proxy-class: "run-on-worker"` 
