# Introduction
To prevent secret leakage since the entire cluster configuration is on Github, I use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to safely encrypt my secrets so they can be openly shared on Github.

Basically everything in the cluster uses Sealed Secrets, so it must be available soon after the cluster has been created. The initial configuration is done via the [Ansible bootstrap script](/_ansible/k3s-apps.yaml). Post-bootstrap management/updates are handled via [Argo CD](/argocd).

# Configuration
Prior to running the script, the 

Make sure to use ```sealed-secret-signing-key.crt``` for all new sealed secrets. This is stored in Onedrive Vault for safe-keeping
```
kubeseal -f secret.yaml -w sealed-secrets.yaml --cert sealed-secret-signing-key.crt
```