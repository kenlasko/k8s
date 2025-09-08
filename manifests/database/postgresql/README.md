# Summary
This is a highly-available PostgreSQL cluster using the excellent [CloudNativePG Operator](https://cloudnative-pg.io/). Its configured as a 3-node cluster using local storage. It has live replication to a remote PostgreSQL server running on Oracle Cloud.

# Replication
Replication is configured from the 3-node cluster to the cloud via streaming replica defined in the cloud cluster's [cluster.yaml](overlays/cloud/cluster.yaml).

For streaming to work, the cloud cluster needs to authenticate using the self-generated certificates on the home cluster. This is currently a manual process that has to be repeated every 3 months, until I can figure out how to automate this.

1. Run the following script to extract the certificates from the host cluster and update the AKeyless certificate
```bash
SECRET_CONTENT=$(jq -n \
  --arg CACRT  "$(kubectl -n postgresql get secret home-ca -o jsonpath='{.data.ca\.crt}')" \
  --arg TLSCRT "$(kubectl -n postgresql get secret home-replication -o jsonpath='{.data.tls\.crt}')" \
  --arg TLSKEY "$(kubectl -n postgresql get secret home-replication -o jsonpath='{.data.tls\.key}')" \
  '{ "ca.crt": $CACRT, "tls.crt": $TLSCRT, "tls.key": $TLSKEY }')

akeyless update-secret-val --name postgresql/replication-certs --value "$SECRET_CONTENT"
```
2. Delete the `replication-certs` external secret in the cloud to trigger a pull of the updated external secret data, or wait for the scheduled update to happen (every 24h).
3. Kill the `cloud-1` pod to initiate a fresh instance

## Backups
Constant backups are being made to a remote S3 bucket, which makes restoration very simple. This is defined in [cluster.yaml](overlays/home/cluster.yaml) and [backup.yaml](overlays/home/backup.yaml).

# Things I've Found
## Recovering from a failed node
I had a pod not come back properly after a node upgrade. Thankfully it was Home-3. The controller was throwing errors about being unable to connect to the pod, and the pod couldn't communicate with the controller. I tried to scale the cluster to 2 pods, but it kept failing to communicate with the pod.

I tried wiping out the local-disk contents, but that didn't work. Ultimately, the solution was to delete the PV/PVC associated with Home-3, and then scale the cluster back to 3 pods. Now that pod is known as Home-4, which is something CNPG or PG itself does to ensure a clean slate for the "new" pod.