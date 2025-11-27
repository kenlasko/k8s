# Introduction
[Cilium](https://cilium.io/) is the Kubernetes CNI (container network interface) used in this cluster. I selected it because it could handle multiple roles that previously required multiple tools:
* Gateway API for HTTP ingress to workloads. Replaced Traefik
* L2 Load Balancing. Replaced MetalLB
* Observability via Hubble
* eBPF for efficiency/speed
* Enhanced network policies

# Installation
Cilium has to be the first thing installed after the cluster is first created, because I am using Cilium's kube-proxy instead of the built-in one. Without this, the cluster is non-functional until Cilium is up and running.

Cilium is initially installed via my [bootstrap-cluster.sh](/scripts/bootstrap-cluster.sh) script, and maintained/updated via [Argo CD](/manifests/argocd).

Cilium requires that the [Gateway API](https://gateway-api.sigs.k8s.io/) CRDs are installed prior to enabling Cilium. This is done in two places:
* In `extraManifests` in the [Talos/Omni cluster definition](https://github.com/kenlasko/omni/blob/main/patches/cluster.yaml)
* In ArgoCD, via the [Cilium application definition](https://github.com/kenlasko/K3S/blob/main/argocd-apps/network/cilium.yaml)

# Service Routing via BGP
Externally accessible services use BGP to advertise the IPs. Previously, the cluster used L2Announcements via ARP, which does not load balance and is slow to respond to inaccessible nodes. BGP will balance traffic across all advertised nodes and should be much more resilient to node accessibility issues. 

Cilium is used to advertise all LoadBalancer services to the UDM Pro router using the worker nodes as next hops. The services are assigned IPs in the `192.168.10.0/24` subnet. The UDM Pro is assigned ASN 64512 and the cluster uses ASN 65000.

## BGP Configuration
1. Apply the [udm-kubecluster-bgp.conf](/manifests/network/cilium/udm-kubecluster-bgp.conf)[^1] to the UDM Pro. This is done in https://unifi.ucdialplans.com/network/default/settings/routing/bgp.
2. Make sure a network exists for the `192.168.10.0/24` subnet. This is done in https://unifi.ucdialplans.com/network/default/settings/networks
3. The rest should be automatically applied via Cilium config. The settings are defined in [bgp-config.yaml](/manifests/network/cilium/bgp-config.yaml).

[^1]: Adapted from https://medium.com/@scaluch/unifi-os-4-1-and-kubernetes-loadbalancer-822b1dd4d745

## LetsEncrypt Certificate Monitor for NAS
I created a process to use the LetsEncrypt wildcard certificate generated for Cilium HTTPRoutes on my QNAP NAS. For more information, see the relevant section in [NASCONFIG.md](/docs/NASCONFIG.md#nas-letsencrypt-certificate-management)

# Tips and Tricks
## Hubble flow monitoring
The Hubble UI doesn't show everything for some reason. A better approach is to use the Hubble CLI to observe traffic. This requires port forwarding from one CLI instance to another.

On instance #1, run:
```
cilium hubble port-forward
```
On instance #2, run:
```
hubble observe --namespace <desired-namespace> --follow --verdict DROPPED
```