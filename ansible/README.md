> [!WARNING]
> Ansible usage has been deprecated in favour of Terraform/Opentofu. Refer to the [k8s-bootstrap](https://github.com/kenlasko/k8s-bootstrap) repository for more information.


# Introduction
This contains an Ansible script that is used for bootstrapping a new Kubernetes cluster. [Omni](https://github.com/kenlasko/omni) takes care of the initial setup of the nodes, but the [k8s-apps.yaml](/ansible/k8s-apps.yaml) script handles getting the cluster to a usable state by installing the following (in order):
* [Cilium](/manifests/network/cilium)
* [Sealed Secrets](/manifests/system/sealed-secrets)
* [Cert Manager](/manifests/system/cert-manager)
* [Argo CD](/manifests/argocd)

Once at this stage, Argo CD can take over and install everything else.