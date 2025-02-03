# Windows Workstation Prep
These instructions are for configuring Linux-based tools in an Ubuntu Windows Subsystem for Linux (WSL) virtual machine. If you are using a native machine, you can skip the WSL-specific bits

## Install WSL and supporting tools
From Windows Terminal:
```
wsl --install
```

Install Visual Studio Code from Microsoft Store, then install required extensions:
```
https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl
https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform
```
## Install Base Prerequisites
```
sudo apt update
sudo apt install nano git ssh -y
```

## Create Github token
Follow instructions on https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
```
ssh-keygen -t ed25519 -C "ken.lasko@gmail.com"  # Make sure to use 'id_rsa' for name 
# Start ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```
Copy the contents of id_rsa.pub to Github SSH keys at https://github.com/settings/keys

## Configure Git and clone repos
```
git config --global user.email "ken.lasko@gmail.com"
git config --global user.name "Ken Lasko"
git clone git@github.com:kenlasko/k8s.git k8s
git clone git@github.com:kenlasko/k8s-lab.git
git clone git@github.com:kenlasko/k8s-cloud.git
git clone git@github.com:kenlasko/omni.git
git clone git@github.com:kenlasko/docker.git
git clone git@github.com:kenlasko/omni-public.git
git clone git@github.com:kenlasko/pxeboot.git
```

## Install Ansible
```
sudo apt install ansible pip python3-all -y
ansible-galaxy collection install community.general
ansible-galaxy collection install kubernetes.core
pip install kubernetes

# Copy Ansible Hosts
sudo mkdir /etc/ansible
sudo cp ~/k8s/_ansible/resources/hosts /etc/ansible/hosts
```

## Run Ansible script to install tools
This will install almost everything needed to start working with Kubernetes on the workstation.
```
ansible-playbook ~/k8s/_ansible/workstation-build.yaml --ask-become-pass
source ~/.bashrc
```

## Final Manual Change
A few things can't be done via Ansible script, like installing Krew
```
source ~/.bashrc
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Add Krew path to ~/.bashrc
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install OIDC-Login in Kubectl
kubectl krew install oidc-login
```

## Important Connection Note
If you are connecting via SSH to the terminal (ie not via WSL), add the following to your ```~/.ssh/config``` on your local machine you're using to connect to `myhost`
```
Host myhost
  LocalForward 8000 127.0.0.1:8000
  LocalForward 18000 127.0.0.1:18000
```
Or alternatively, connect directly via SSH using:
```
ssh -i "~/.ssh/id_rsa" ken@rpi1. -L 8000:localhost:8000
```
Otherwise, Omni authentication won't work in kubectl. This isn't an issue if connecting directly to the cluster


# Manual instructions (ONLY IF ANSIBLE DOESN'T WORK)
For reference, or if the Ansible script doesn't work, here are the manual steps to get everything installed.
## Install Terraform
```
# Get the Hashicorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Add Hashicorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
sudo apt update
sudo apt install terraform
touch ~/.bashrc
terraform -install-autocomplete
```

## Install Kubectl
Get kubeconfig from Onedrive Vault and copy to ~/.kube/config
From https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
```
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg jq
sudo mkdir /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
sudo apt-get update
sudo apt-get install -y kubectl
```

## Install Kubectl Autocomplete and alias kubectl to k
```
# Install bash-completion
sudo apt install -y bash-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Alias kubectl to k
echo "alias k=kubectl" >> ~/.bashrc
echo "complete -F __start_kubectl k" >> ~/.bashrc
source ~/.bashrc
```

## Install K9S on Linux
```
curl -sS https://webinstall.dev/k9s | bash
```

## Install K9S on Windows
```
curl.exe -A MS https://webinstall.dev/k9s | powershell
```

## Install KubeSeal
```
# Make sure jq is installed
sudo apt install jq -y

# Get the architecture
ARCH_TYPE=$(dpkg --print-architecture)

# Fetch the latest sealed-secrets version using GitHub API
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/tags | jq -r '.[0].name' | cut -c 2-)

# Check if the version was fetched successfully
if [ -z "$KUBESEAL_VERSION" ]; then
    echo "Failed to fetch the latest KUBESEAL_VERSION"
    exit 1
fi

curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-${ARCH_TYPE}.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-${ARCH_TYPE}.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm kubeseal*
```
Copy `sealed-secret-signing-key.crt` from OneDrive Vault `/certificates` folder to `/home/ken`



## Install Helm
```
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

## Install Docker for container building
From https://docs.docker.com/engine/install/ubuntu/
```
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
docker login
```

## Enable multi-arch container builds
From https://docs.docker.com/build/building/multi-platform/#install-qemu-manually
```
docker run --privileged --rm tonistiigi/binfmt --install all
```
Follow https://docs.docker.com/engine/storage/containerd/

Finally, install Docker extension for Visual Studio and restart VSCode

## Install Omni/Talos Tools
Install tools as per [Omni installation instructions](https://github.com/kenlasko/omni)

## Install Cilium/Hubble CLI Tools
```
sudo apt install golang-go -y
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
GOOS=$(go env GOOS)
GOARCH=$(go env GOARCH)
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${GOOS}-${GOARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-${GOOS}-${GOARCH}.tar.gz.sha256sum
sudo tar -C /usr/local/bin -xzvf cilium-${GOOS}-${GOARCH}.tar.gz
rm cilium-${GOOS}-${GOARCH}.tar.gz{,.sha256sum}

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

# Set default namespace for Cilium commands in .bashrc
echo "alias cilium='cilium --namespace=cilium'" >> ~/.bashrc
. ~/.bashrc
```

## Install Kubent
[Kube No Trouble](https://github.com/doitintl/kube-no-trouble) is a handy way to check cluster readiness for new Kubernetes versions. 

To install:
```
sh -c "$(curl -sSL https://git.io/install-kubent)"
```

To use against the current Kube context:
```
kubent
```

## Install Popeye Kubernetes Resource Linter
[Popeye](https://github.com/derailed/popeye) is a utility that scans live Kubernetes clusters and reports potential issues with deployed resources and configurations.

To install:
```
POPEYE_VERSION=$(curl -s https://api.github.com/repos/derailed/popeye/tags | jq -r '.[0].name' | cut -c 2-)

# Get the architecture
ARCH_TYPE=$(dpkg --print-architecture)

# Check if the version was fetched successfully
if [ -z "$POPEYE_VERSION" ]; then
    echo "Failed to fetch the latest POPEYE_VERSION"
    exit 1
fi

curl -OL "https://github.com/derailed/popeye/releases/download/v${POPEYE_VERSION}/popeye_linux_${ARCH_TYPE}.tar.gz"
tar -xzf popeye_linux_${ARCH_TYPE}.tar.gz
sudo mv popeye /usr/local/bin
rm popeye*
```

Basic usage (outputs results to HTML file):
```
popeye -A -o html > popeye.html
```