> [!WARNING]
> Sealed Secrets has been deprecated in favour of [External Secrets Operator](/manifests/system/external-secrets). ESO makes it much simpler to manage large number of secrets. I used to dread having to change any secrets due to the work involved. ESO makes it much simpler.

# Summary
This provides a web UI for [sealing secrets](/manifests/system/sealed-secrets). I mainly use it for a template to create new sealed secrets via command line using `kubeseal`. While you can seal secrets in the UI, it won't use the same default sealing key that is available on all clusters. This means that the secret can't be decrypted on other clusters, or after a cluster rebuild.

Since this site doesn't have any authentication and exposes extremely sensitive information, I've made it only available via a workload proxy through https://omni.ucdialplans.com. Navigate to the `Home` cluster and click on the `Sealed Secrets` option under `Exposed Services`.