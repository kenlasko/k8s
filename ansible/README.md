# Introduction
This contains an Ansible script that is used for bootstrapping a new Kubernetes cluster. [Omni](https://github.com/kenlasko/omni) takes care of the initial setup of the nodes, but the [k3s-apps.yaml](/_ansible/k3s-apps.yaml) script handles getting the cluster to a usable state by installing the following (in order):
* [Cilium](/cilium)
* [Sealed Secrets](/sealed-secrets)
* [Cert Manager](/cert-manager)
* [Argo CD](/argocd)

Once at this stage, Argo CD can take over and install everything else.