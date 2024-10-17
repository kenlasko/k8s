# Prerequisites 
[Workstation Prep Instructions](WORKSTATION.md)

[NAS file/folder locations](NASCONFIG.md)

# Kubernetes Install
Ensure that Omnictl/Talosctl is ready to go. Installation steps are [here](https://github.com/kenlasko/omni/).
## Install Kubernetes
1. Make sure all Talos nodes are in maintenance mode and are available in Omni, then create cluster:
```
omnictl cluster template sync -f ~/omni/cluster-template-home.yaml
```
2. Install Cilium, Cert-Manager, Sealed-Secrets and ArgoCD
```
ansible-playbook ~/k3s/_ansible/k3s-apps.yaml
```
3. Get initial ArgoCD password
```
kubectl -n argocd get secret argocd-initial-admin-secret \
          -o jsonpath="{.data.password}" | base64 -d; echo
```

## Argo App Install Order
I'm working on using SyncWaves to automate this, but in the meantime follow these general procedures for app install order.
1. nfs-provisioner
2. mariadb (then follow [MariaDB restore procedures](mariadb/README.md))
3. longhorn (once up and running, restore volumes)
4. adguard
5. external-dns
6. media-tools (installs all media apps - ONLY DO AFTER LONGHORN VOLUMES ARE RESTORED)
7. Everything else

## Get Kubernetes token
```
kubectl -n kube-system get secret kubeapi-service-account-secret \
          -o jsonpath="{.data.token}" | base64 -d; echo
```
