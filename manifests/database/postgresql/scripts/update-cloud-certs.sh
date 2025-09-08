#!/bin/sh

# My PostgreSQL replication certificates expire every 3 months. I have to make sure the replication certificates match between the home and cloud clusters, or replication will break.
# This script pulls the latest certs from the home cluster and updates the Akeyless secret used by the cloud cluster.

echo "Pulling latest PostgreSQL replication certs from home cluster..."
SECRET_CONTENT=$(jq -n \
  --arg CACRT  "$(kubectl -n postgresql get secret home-ca -o jsonpath='{.data.ca\.crt}')" \
  --arg TLSCRT "$(kubectl -n postgresql get secret home-replication -o jsonpath='{.data.tls\.crt}')" \
  --arg TLSKEY "$(kubectl -n postgresql get secret home-replication -o jsonpath='{.data.tls\.key}')" \
  '{ "ca.crt": $CACRT, "tls.crt": $TLSCRT, "tls.key": $TLSKEY }')

echo "Updating Akeyless secret used by cloud cluster..."
sleep infinity
akeyless update-secret-val --name postgresql/replication-certs --value "$SECRET_CONTENT"