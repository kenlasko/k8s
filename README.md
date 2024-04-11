## On Workstation
```
sudo apt install ansible nano pip -y
ansible-galaxy collection install community.general
ansible-galaxy collection install kubernetes.core
pip install kubernetes
```

## Create SSH key and push to other nodes
```
ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@nuc1
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@nuc2
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@nuc3
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@nuc4
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@nuc5
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@nuc6
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@rpi1
ssh-copy-id -i ~/.ssh/id_rsa.pub ken@rpi2
```

## Copy Ansible Hosts
```
sudo mkdir /etc/ansible
sudo cp ~/k3s/hosts /etc/ansible/hosts
```

## Run workstation prep
```
ansible-playbook ~/k3s/_ansible/workstation-prep.yaml --ask-become-pass
```

## Run first Ansible script
```
ansible-playbook ~/k3s/_ansible/k3s-node-prep.yaml --ask-become-pass
```

## Install K3S
```
ansible-playbook ~/k3s/_ansible/k3s-node-install.yaml --ask-become-pass
```

## Install apps
```
ansible-playbook ~/k3s/_ansible/k3s-apps.yaml
```

## Get initial ArgoCD password
```
kubectl -n argocd get secret argocd-initial-admin-secret \
          -o jsonpath="{.data.password}" | base64 -d; echo
```

## Get K3S token
```
kubectl -n kube-system get secret api-service-account-secret \
          -o jsonpath="{.data.token}" | base64 -d; echo
```

## Create first server
```
curl -sfL https://get.k3s.io | K3S_TOKEN=***REMOVED*** sh -s - server --cluster-init --disable servicelb,traefik,local-storage --write-kubeconfig-mode 644 --disable-cloud-controller --flannel-backend=none --disable-network-policy 
```

## Add nodes 2/3
```
curl -sfL https://get.k3s.io | K3S_TOKEN=***REMOVED*** sh -s - server --server https://192.168.1.4:6443 --disable servicelb,traefik,local-storage --write-kubeconfig-mode 644 --disable-cloud-controller --flannel-backend=none --disable-network-policy 
```

## Add worker nodes
```
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.4:6443 K3S_TOKEN=***REMOVED*** sh -

cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/192.168.1.4/g'
```

## Install Autocomplete
```
sudo apt install -y bash-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc
source ~/.bashrc
```


## May have to follow this for Longhorn volume creation issues:
https://longhorn.io/kb/troubleshooting-volume-with-multipath/



## Install remote admin tools on non-K3S server
```
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubectl
```
