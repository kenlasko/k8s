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