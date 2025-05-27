# Sample Secrets
Pull value from a single-item secret
```
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
spec:
  refreshInterval: 1h
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

Pull all values from a multi-item secret
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

Pull a single item out of a secret with multiple items
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

Pull items from a multiple-item secret and rename the keys
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
  - secretKey: resticrepo
    remoteRef:
      key: /s3/cloudflare
      property: RESTIC_REPOSITORY
  - secretKey: resticpass
    remoteRef:
      key: /s3/cloudflare
      property: RESTIC_PASSWORD
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