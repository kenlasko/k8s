# Introduction
[Cilium](https://cilium.io/) is the Kubernetes CNI (container network interface) used in this cluster. I selected it because it could handle multiple roles that previously required multiple tools:
* Gateway API for HTTP ingress to workloads. Replaced Traefik
* L2 Load Balancing. Replaced MetalLB
* Observability via Hubble
* eBPF for efficiency/speed
* Enhanced network policies

# Installation
Cilium has to be the first thing installed after the cluster is first created, because I am using Cilium's kube-proxy instead of the built-in one. Without this, the cluster is non-functional until Cilium is up and running.

Cilium is initially installed via [Ansible script](/_ansible), and maintained/updated via [Argo CD](/argocd).

Cilium requires that the [Gateway API](https://gateway-api.sigs.k8s.io/) CRDs are installed prior to enabling Cilium. This is done in two places:
* In `extraManifests` in the [Talos/Omni cluster definition](https://github.com/kenlasko/omni/blob/main/patches/cluster.yaml)
* In ArgoCD, via the [Cilium application definition](https://github.com/kenlasko/K3S/blob/main/argocd-apps/cilium.yaml)

# BGP Configuration
The UDM Pro is assigned ASN 64512 and the cluster uses ASN 65000 using the subnet `192.168.9.0/24` subnet.

1. Apply the [udm-kubecluster-bgp.conf](/cilium/udm-kubecluster-bgp.conf)[^1] to the UDM Pro. This is done in https://unifi.ucdialplans.com/network/default/settings/routing/bgp
2. The rest should be automatically applied via Cilium config

[^1]: Adapted from https://medium.com/@scaluch/unifi-os-4-1-and-kubernetes-loadbalancer-822b1dd4d745