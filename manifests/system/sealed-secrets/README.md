# Introduction
To prevent secret leakage since the entire cluster configuration is on Github, I use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to safely encrypt my secrets so they can be openly shared on Github.

# Configuration
Basically everything in the cluster uses Sealed Secrets, so it must be available soon after the cluster has been created. The initial configuration is done via the [Ansible bootstrap script](/ansible/k3s-apps.yaml). Post-bootstrap management/updates are handled via [Argo CD](/manifests/argocd).

Prior to running the Ansible script, the `global-sealed-secrets-key.yaml` MUST be copied from the OneDrive Vault folder to the `~` home directory where you are running the Ansible script. This is the key that is used to decrypt the sealed secrets. **IT MUST NOT BE SAVED IN THE REPO. DO NOT PLACE IT ANYWHERE IN THE `k3s` folder.**

# Secret Sealing
Make sure to use `sealed-secret-signing-key.crt` for all new sealed secrets. This is stored in OneDrive Vault for safe-keeping.
```
kubeseal -f secret.yaml -w sealed-secrets.yaml --cert sealed-secret-signing-key.crt
```