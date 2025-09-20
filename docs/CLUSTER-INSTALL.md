# Cluster Installation Prerequisites
Before installing the cluster, ensure you have the following:

- SideroLabs Omni must be ready to go. Installation steps are in the repository link below:
[Omni On-Prem installation and configuration](https://github.com/kenlasko/omni/)

- You will need a workstation (preferably Linux-based) with several tools to get things rolling. Choose one of the following approaches:
    - [Workstation Prep Instructions for Ubuntu-based distributions](/docs/WORKSTATION.md)
    - [NixOS Workstation Build](https://github.com/kenlasko/nixos-wsl/)

- Most of the workloads use NAS-based storage for persistent data. The [NAS Configuration](/docs/NASCONFIG.md) doc shows the configuration for the various things that need to be ready before the cluster can be spun up.

# Kubernetes Install
Ensure that Omnictl/Talosctl is available and connected to your Omni installation and associated servers. Installation steps are [in my Omni repo](https://github.com/kenlasko/omni/).

## Initial Cluster Setup
This guide assumes you're using a NixOS distribution that is configured to securely store and present all required certificates. For more information, see [my NixOS repo](https://github.com/kenlasko/nixos-wsl/). Otherwise, you will have to manually ensure all supporting files are present.

Initially, I used tools like Ansible/Terraform to bootstrap the cluster, which worked when each cluster had its own repo. After my changes to use Kustomize and Helm to manage all my clusters from one repo, this no longer worked. After a lot of trial-and-error, I gave up on Terraform and used ChatGPT to create [a rather robust Bash script](/scripts/bootstrap-cluster.sh) to take care of the entire cluster bootstrapping process. 

> [!CAUTION] 
> If this is a rebuild of either the home or cloud clusters, make sure to delete all [Tailscale machines](/manifests/network/tailscale) related to the cluster. Otherwise, Tailscale will create duplicate machines with `-1` appended to them. Causes all sorts of weird issues.

Now, all that is needed is to run the following and wait for completion:
```
~/k8s/scripts/bootstrap-cluster.sh
```
The script will take care of the following:
- Use `omnictl` to spin up the cluster
- Apply initial manifests to get the cluster to the point where ArgoCD can take over. These manifests include:
  - [Cilium](/manifests/network/cilium)
  - [Cert-Manager](/manifests/system/cert-manager)
  - [External Secrets](/manifests/system/external-secrets)
  - [CSI Drivers](/manifests/system/csi-drivers)
  - [Redis](/manifests/database/redis)
  - [ArgoCD](/manifests/argocd)

## Argo App Install
Once the `bootstrap-cluster.sh` script bootstraps the cluster, ArgoCD should take over and install all the remaining applications. ArgoCD sync-waves should install apps in the correct order. The full list of apps and their relative order can be found [here](/argocd-apps).

## Get Kubernetes token for token-based authentication
Cluster connectivity can be done via OIDC through Omni, but its a good idea to have secondary access through standard token-based authentication. The cluster is configured for this using [Talos Shared VIP](https://www.talos.dev/v1.9/talos-guides/network/vip/), which makes cluster API access via a shared IP that is advertised by one of the control plane nodes. The address for this is `https://192.168.1.11:6443` and is defined in my [Omni](https://github.com/kenlasko/omni/) repo's [controlplane.yaml](https://github.com/kenlasko/omni/blob/main/patches/controlplane.yaml) patch.

The service account is configured via [kubeapi-serviceaccount.yaml](/manifests/argocd/kubeapi-serviceaccount.yaml) and gets its token when the service account is created.

For configuring your `kubeconfig` file with the token-based authentication information, you need the service account token as well as the certificate authority public certificate. To get these, run:
```bash
echo
echo "Service Account Token:"
kubectl -n kube-system get secret kubeapi-service-account-secret -o jsonpath="{.data.token}" | base64 -d; echo
echo
echo "Certificate Authority:"
kubectl -n kube-system get secret kubeapi-service-account-secret -o jsonpath="{.data.ca\.crt}"
```

Add these to your `.kube/config` file like this:
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: 
    *********************************** ADD-CERT-AUTH-BASE64-STRING-HERE ***********************************
    server: https://192.168.1.11:6443
  name: home
- cluster:
    server: https://omni.ucdialplans.com:8100/
  name: omni-home
contexts:
- context:
    cluster: home
    user: home-user
  name: home
- context:
    cluster: omni-home
    user: onprem-omni-home-ken.lasko@gmail.com
  name: omni-home
current-context: home
kind: Config
preferences: {}
users:
- name: home-user
  user:
    token: *********************************** ADD-SERVICE-ACCOUNT-TOKEN-HERE ***********************************
- name: onprem-omni-home-ken.lasko@gmail.com
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=https://omni.ucdialplans.com/oidc
      - --oidc-client-id=native
      - --browser-command=wslview
      - --oidc-extra-scope=cluster:home
      command: kubectl
      env: null
      interactiveMode: IfAvailable
      provideClusterInfo: false
```

Switch context between the OIDC-based authenticated access and the token-based access with:
```bash
# To use OIDC
kubectl config use-context omni-home

# To use the token
kubectl config use-context home
```
