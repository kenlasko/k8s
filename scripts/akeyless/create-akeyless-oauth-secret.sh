#!/usr/bin/env bash

# Creates or updates an Akeyless oauth secret using CLI-provided values only.

set -euo pipefail

# Usage check
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <secret-name> <client-id> <client-secret>"
  echo "Example: $0 oauth2-proxy my-client-id my-client-secret"
  exit 1
fi

SECRET_NAME="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
COOKIE_SECRET="g7E4dqSVGkDzSWp9fePfS9JYkSETenbVwz-yLFylHh0="

echo "Building Akeyless secret payload..."

SECRET_DATA_JSON=$(jq -n \
  --arg client_id "$CLIENT_ID" \
  --arg client_secret "$CLIENT_SECRET" \
  --arg cookie_secret "$COOKIE_SECRET" \
  '{
    OAUTH2_PROXY_CLIENT_ID: $client_id,
    OAUTH2_PROXY_CLIENT_SECRET: $client_secret,
    OAUTH2_PROXY_COOKIE_SECRET: $cookie_secret
  }'
)

echo "Checking if Akeyless secret already exists at '$SECRET_NAME'..."
if akeyless get-secret-value --name "$SECRET_NAME" >/dev/null 2>&1; then
  echo "Akeyless secret exists. Updating..."
  akeyless update-secret-val \
    --name "$SECRET_NAME" \
    --value "$SECRET_DATA_JSON"
else
  echo "Akeyless secret does not exist. Creating..."
  akeyless create-secret \
    --name "$SECRET_NAME" \
    --value "$SECRET_DATA_JSON"
fi

echo "✅ Done. Akeyless secret '$SECRET_NAME' is set."
