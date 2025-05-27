#!/usr/bin/env bash

set -euo pipefail

# Usage check
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <secret-name> <namespace> [akeyless-path]"
  echo "Example: $0 my-secret default /k8s/my-secret"
  exit 1
fi

SECRET_NAME="$1"
NAMESPACE="$2"
AKEYLESS_PATH="${3:-/k8s-secrets/$SECRET_NAME}"

echo "Fetching secret '$SECRET_NAME' from namespace '$NAMESPACE'..."
SECRET_JSON=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json)

echo "Building key-value map from Kubernetes secret..."
SECRET_DATA_JSON=$(
  echo "$SECRET_JSON" |
    jq -r '
      .data | to_entries |
      map({key: .key, value: (.value | @base64d)}) |
      from_entries
    '
)

# Check if the secret already exists
echo "Checking if Akeyless secret already exists at $AKEYLESS_PATH..."
if akeyless get-secret-value --name "$AKEYLESS_PATH" >/dev/null 2>&1; then
  echo "Akeyless secret exists. Updating..."
  akeyless update-secret --name "$AKEYLESS_PATH" --value "$SECRET_DATA_JSON"
else
  echo "Akeyless secret does not exist. Creating..."
  akeyless create-secret --name "$AKEYLESS_PATH" --value "$SECRET_DATA_JSON"
fi

echo "✅ Done. Akeyless secret is set at $AKEYLESS_PATH"
