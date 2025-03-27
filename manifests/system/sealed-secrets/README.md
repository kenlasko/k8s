# Introduction
To prevent secret leakage since the entire cluster configuration is on Github, I use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to safely encrypt my secrets so they can be openly shared on Github.

# Configuration
Basically everything in the cluster uses Sealed Secrets, so it must be available soon after the cluster has been created. The initial configuration is done via the [Ansible bootstrap script](/ansible/k3s-apps.yaml). Post-bootstrap management/updates are handled via [Argo CD](/manifests/argocd).

# Secret Sealing
Make sure to use `/run/secrets/sealed-secrets-signing-key` for all new sealed secrets. The secret is securely stored in NixOS.
```
kubeseal -f secret.yaml -w sealed-secrets.yaml --cert /run/secrets/sealed-secrets-signing-key
```
Alternatively, use the [kubeseal.sh](scripts/kubeseal.sh) script to automate the process of generating the secret. Requires the following:
- secret to be sealed must be called `secret.yaml`
- add the relative path under `manifests` to the location of the `sealed-secrets.yaml` file. Will append to any existing secrets

Example:
```
# Encrypt the secret.yaml file and places it into /manifests/adguard/sealed-secrets.yaml
./kubeseal.sh adguard
```