# Introduction
Initially, I used [Sealed Secrets](/manifests/system/sealed-secrets) for secure secret management. However, as my processes have matured, it has become more and more onerous to maintain, especially when secrets were shared between multiple applications. I decided to move to an external secret provider to ease this burden. I chose [External Secrets Operator](https://external-secrets.io/latest/) because it has a rich, customizable API that plugs into all of the big external secret providers. I can easily add additional providers, and migration between them should be simpler than if I used each specific provider's operator.

ESO has varying support for many providers, but not all are created equal. Many providers only allow for searching by name. For my needs, I require support for finding by tags. I tested several different providers that don't support tag search (Infisical, Bitwarden, Doppler) before coming to this realization. This requirement limited my options to a much smaller subset (as documented [here](https://external-secrets.io/latest/introduction/stability-support/)).

I settled on [AKeyless](https://www.akeyless.io/), which also has a generous free tier and meets all my needs. It has a useful folder option which makes organizing secrets easier. For backup, or for migrating to another provider, I created a [ChatGPT-written script to export all the AKeyless secrets to a text file](/scripts/akeyless/export-akeyless-secrets.sh) that can then be imported into another provider.

As a backup, in case AKeyless changes their free-tier policy, I've synced all secrets to [Gitlab CI/CD Variables](https://docs.gitlab.com/ci/variables/) using a [ChatGPT-written script](/scripts/gitlab/import-akeyless-secrets.sh). The [ESO Gitlab Variables provider](https://external-secrets.io/latest/provider/gitlab-variables/) supports both name and tag search. However, it does not support folders and all secret names must not include dashes (some of mine do). If I ever do need to move to Gitlab Variables, I will create a script that will convert my existing secrets to match the Gitlab requirements. One other minor issue is that Gitlab doesn't deal with secret names or tags with dots in it. This will need dealing with. The only secret affected is the `keypass.txt` reference in my [UCDialplans codesign-cert secret](/manifests/apps/ucdialplans/base/external-secrets.yaml).

# Installation
After installing ESO via Helm chart, you must install the manifests that store the secrets for accessing the secret stores. This is stored in NixOS and is normally installed via my [cluster bootstrap script](/scripts/bootstrap-cluster.sh). It contains the secrets for all my secret stores. To install manually, run:
```
kubectl apply -f /run/secrets/eso-secretstore-secrets.yaml
```

# Sample Secrets
These samples have helped me build my secret manifests.

## Pull value from a single-item secret
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: cloudflare-api-token
  data:
  - secretKey: api-token 
    remoteRef:
      key: /cloudflare/api-token
```

## Pull all values from a multi-item secret
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: adguard-creds
  namespace: adguard
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: adguard-creds
  dataFrom:
  - extract:
      key: /adguard

```

## Pull a single item out of a secret with multiple items
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: adguard-s3-cloudflare-template
  namespace: adguard
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: adguard-test
  data:
  - secretKey: RESTIC_REPOSITORY
    remoteRef:
      key: /s3/cloudflare
      property: RESTIC_REPOSITORY
```

## Pull items from a multiple-item secret and rename the keys
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: adguard-s3-cloudflare-template
  namespace: adguard
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: adguard-test
  data:
  - secretKey: resticrepo
    remoteRef:
      key: /s3/cloudflare
      property: RESTIC_REPOSITORY
  - secretKey: resticpass
    remoteRef:
      key: /s3/cloudflare
      property: RESTIC_PASSWORD
```

## Mix dataFrom and data for things that have to be handled slightly differently
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: codesign-cert
  namespace: ucdialplans
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: codesign-cert
  dataFrom:
  - extract:
      key: /ucdialplans/codesign-cert
      conversionStrategy: Default
      decodingStrategy: Base64
      metadataPolicy: None
  data:
  - secretKey: keypass.txt
    remoteRef:
      key: /ucdialplans/codesign-cert
      property: keypass.txt
```

## Build a secret using templates
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: kite-cnpg-dsn
  namespace: kube-system
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: kite-cnpg-dsn
    template:
      engineVersion: v2
      data:
        DB_DSN: "host=home-rw.cnpg.svc.cluster.local port=5432 user={{ .dbUsername }} password={{ .dbPassword }} dbname=kite"
  data:
  - secretKey: dbUsername
    remoteRef:
      key: /database/kite
      property: username
  - secretKey: dbPassword
    remoteRef:
      key: /database/kite
      property: password
```

```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: adguard-s3-cloudflare-template
  namespace: adguard
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    template:
      engineVersion: v2
      data:
        name: admin
        s3destination: "{{ .mysecret }}/adguard"
  data:
  - secretKey: mysecret
    remoteRef:
      key: /s3/cloudflare
      property: RESTIC_REPOSITORY
```

## Don't double-encode a secret that's already stored in Base64
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: kubeconfig-cloud
  namespace: kube-system
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: kubeconfig-cloud
  data:
  - secretKey: kubeconfig-cloud
    remoteRef:
      key: /kite/kubeconfig-cloud
      decodingStrategy: Base64
```