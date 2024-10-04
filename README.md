## On Workstation
```
sudo apt install ansible nano pip -y
ansible-galaxy collection install community.general
ansible-galaxy collection install kubernetes.core
pip install kubernetes
```

## Copy Ansible Hosts
```
sudo mkdir /etc/ansible
sudo cp ~/k3s/_ansible/hosts /etc/ansible/hosts
```

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
1. nfs-provisioner
2. mariadb (then follow [MariaDB restore procedures](mariadb/README.md))
3. longhorn (once up and running, restore volumes)
4. adguard
5. external-dns
6. media-tools (installs all media apps - ONLY DO AFTER LONGHORN VOLUMES ARE RESTORED)

## Get Kubernetes token
```
kubectl -n kube-system get secret kubeapi-service-account-secret \
          -o jsonpath="{.data.token}" | base64 -d; echo
```

## Install remote admin tools on non-Kubernetes server
From https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
```
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
sudo apt-get update
sudo apt-get install -y kubectl
```

## Install Kubectl Autocomplete
```
sudo apt install -y bash-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc
source ~/.bashrc
```

## Alias kubectl to k
```
alias k=kubectl
complete -F __start_kubectl k
```

## Install K9S on Linux
```
curl -sS https://webinstall.dev/k9s | bash
```

## Install K9S on Windows
```
curl.exe -A MS https://webinstall.dev/k9s | powershell
```