# Introduction
This contains an Ansible script that is used for bootstrapping a new Kubernetes cluster. [Omni](https://github.com/kenlasko/omni) takes care of the initial setup of the nodes, but the [k3s-apps.yaml](/ansible/k3s-apps.yaml) script handles getting the cluster to a usable state by installing the following (in order):
* [Cilium](/manifests/network/cilium)
* [Sealed Secrets](/manifests/system/sealed-secrets)
* [Cert Manager](/manifests/system/cert-manager)
* [Argo CD](/manifests/argocd)

Once at this stage, Argo CD can take over and install everything else.