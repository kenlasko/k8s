# Important
Make sure to use ```sealed-secret-signing-key.crt``` for all new sealed secrets. This is stored in Onedrive Vault for safe-keeping
```
kubeseal -f secret.yaml -w sealed-secrets.yaml --cert sealed-secret-signing-key.crt
```