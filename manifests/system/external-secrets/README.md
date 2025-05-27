# Sample Secrets
Pull all values from a single secret
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: adguard-creds
  namespace: adguard
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: akeyless
    kind: ClusterSecretStore
  target:
    name: adguard-creds
  dataFrom:
  - extract:
      key: /adguard

```

Pull a single value out of a secret with multiple values
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: adguard-s3-cloudflare-template
  namespace: adguard
spec:
  refreshInterval: 1h
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

Use a template to modify the secret
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: adguard-s3-cloudflare-template
  namespace: adguard
spec:
  refreshInterval: 1h
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