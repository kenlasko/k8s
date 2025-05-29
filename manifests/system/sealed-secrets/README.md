> [!WARNING]
> Sealed Secrets has been deprecated in favour of [External Secrets Operator](/manifests/system/external-secrets). ESO makes it much simpler to manage large number of secrets. I used to dread having to change any secrets due to the work involved. ESO makes it much simpler.

# Introduction
To prevent secret leakage since the entire cluster configuration is on Github, I use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to safely encrypt my secrets so they can be openly shared on Github.

# Configuration
Basically everything in the cluster uses Sealed Secrets, so it must be available soon after the cluster has been created. The initial configuration is done via the [Terraform bootstrap sequence](https://github.com/kenlasko/k8s-bootstrap). Post-bootstrap management/updates are handled via [Argo CD](/manifests/argocd).

# Secret Sealing
Make sure to use `/run/secrets/sealed-secrets-signing-key` for all new sealed secrets. The secret is securely stored in NixOS.
```
kubeseal -f secret.yaml -w sealed-secrets.yaml --cert /run/secrets/sealed-secrets-signing-key
```
Alternatively, use the [kubeseal.sh](scripts/kubeseal.sh) script to automate the process of generating the secret. Requires the following:
- secret to be sealed must be called `secret.yaml`
- add the relative path under `manifests` to the location of the `sealed-secrets.yaml` file. Will append to any existing secrets

Example:
```bash
# Encrypt the secret.yaml file and places it into /manifests/adguard/sealed-secrets.yaml
./kubeseal.sh adguard
```

# Tips and Tricks
How to read the contents of a sealed secret that isn't deployed in the cluster using [decrypt-sealedsecret.sh](/scripts/decrypt-sealedsecret.sh)
```
./k8s/scripts/decrypt-sealedsecret.sh ~/k8s/manifests/database/postgresql/sealed-secrets_DISABLED.yaml
```
