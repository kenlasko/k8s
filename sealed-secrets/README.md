# Important
Make sure to use ```sealed-secret-signing-key.crt``` for all new sealed secrets
```
kubeseal -f secret.yaml -w sealed-secrets.yaml --cert sealed-secret-signing-key.crt
```