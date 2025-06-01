# Introduction
Initially, I used [Sealed Secrets](/manifests/system/sealed-secrets) for secure secret management. However, as my processes have matured, it has become more and more onerous to maintain, especially when secrets were shared between multiple applications. I decided to move to an external secret provider to ease this burden. I chose [External Secrets Operator](https://external-secrets.io/latest/) because it has a rich, customizable API that plugs into all of the big external secret providers. I can easily add additional providers, and migration between them should be simpler than if I used each specific provider's operator. 

I initially tried [Infisical](https://infisical.com/), which seemed promising and has a generous free tier, but I ran into issues with the ESO plugin that have not been resolved yet. I then settled on [AKeyless](https://www.akeyless.io/), which also has a generous free tier and worked much better.

# Installation
After installing ESO via Helm chart, you must install the manifests that store the secrets for accessing the secret stores. This is stored in NixOS and is normally installed via Terraform. It contains the secrets for all my secret stores. To install manually, run:
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

## Use a template to modify the secret
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