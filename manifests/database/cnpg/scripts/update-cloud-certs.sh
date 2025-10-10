#!/bin/sh

# My PostgreSQL replication certificates expire every 3 months. I have to make sure the replication certificates match between the home and cloud clusters, or replication will break.
# This script pulls the latest certs from the home cluster and updates the Akeyless secret used by the cloud cluster if they have been changed.

echo "Pulling latest PostgreSQL replication certs from home cluster..."
SECRET_CONTENT=$(jq -n \
  --arg CACRT  "$(kubectl -n cnpg get secret home-ca -o jsonpath='{.data.ca\.crt}')" \
  --arg TLSCRT "$(kubectl -n cnpg get secret home-replication -o jsonpath='{.data.tls\.crt}')" \
  --arg TLSKEY "$(kubectl -n cnpg get secret home-replication -o jsonpath='{.data.tls\.key}')" \
  '{ "ca.crt": $CACRT, "tls.crt": $TLSCRT, "tls.key": $TLSKEY }')

echo "Comparing with existing Akeyless secret..."
EXISTING_SECRET_CONTENT=$(akeyless get-secret-value --name postgresql/replication-certs)

if [ "$SECRET_CONTENT" = "$EXISTING_SECRET_CONTENT" ]; then
  echo "No changes detected in the replication certs. Exiting."
  exit 0
else
  echo "Changes detected in the replication certs. Proceeding to update Akeyless secret."
  akeyless update-secret-val --name postgresql/replication-certs --value "$SECRET_CONTENT"
fi