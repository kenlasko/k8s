# Prerequisites 
[Workstation Prep Instructions](WORKSTATION.md)

[NAS Configuration](NASCONFIG.md)

# Kubernetes Install
Ensure that Omnictl/Talosctl is ready to go. Installation steps are [here](https://github.com/kenlasko/omni/).
## Install Kubernetes
1. Copy `default-sealing-key.yaml` and `global-sealed-secrets-key.yaml` from Onedrive Vault `certificates` folder to `/home/ken`
2. Make sure all Talos nodes are in maintenance mode and appearing in Omni, then create cluster:
```
omnictl cluster template sync -f ~/omni/cluster-template-home.yaml
```
3. Set the proper context with kubectl and verify you see the expected nodes
```
kubectl config use-context omni-home
kubectl get nodes
```
4. Install Cilium, Cert-Manager, Sealed-Secrets and ArgoCD
```
ansible-playbook ~/k3s/_ansible/k3s-apps.yaml
```
5. Get initial ArgoCD password
```
kubectl -n argocd get secret argocd-initial-admin-secret \
          -o jsonpath="{.data.password}" | base64 -d; echo
```

## Argo App Install Order
ArgoCD sync-waves should install apps in the correct order. The full list of apps and their relative order can be found [here](/argocd-apps).

## Get Kubernetes token
```
kubectl -n kube-system get secret kubeapi-service-account-secret \
          -o jsonpath="{.data.token}" | base64 -d; echo
```

# Handy commands to know
## Check for open port without tools
```
(echo > /dev/tcp/<servicename>/<port>) >/dev/null 2>&1 \
    && echo "It's up" || echo "It's down"
```