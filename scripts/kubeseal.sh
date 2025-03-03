#!/bin/bash

# Script to seal a secret and copy it to a namespace-specific folder

# --- Configuration ---
SECRET_FILE="secret.yaml"          # Path to your secret.yaml file
CERT_FILE="sealed-secret-signing-key.crt" # Path to your sealed-secret-signing-key.crt file
MANIFESTS_DIR="k8s/manifests"      # Base directory for manifests
SEALED_SECRET_FILENAME="sealed-secrets.yaml" # Name of the sealed secret file

# --- Input Validation ---
if [ -z "$1" ]; then
  echo "Error: Namespace is required as the first argument."
  echo "Usage: $0 <namespace>"
  exit 1
fi

NAMESPACE="$1"

if [ ! -f "$SECRET_FILE" ]; then
  echo "Error: Secret file '$SECRET_FILE' not found."
  exit 1
fi

if [ ! -f "$CERT_FILE" ]; then
  echo "Error: Certificate file '$CERT_FILE' not found."
  exit 1
fi

if ! command -v kubeseal &> /dev/null
then
    echo "Error: kubeseal command not found. Please ensure kubeseal is installed and in your PATH."
    exit 1
fi

# --- Script Logic ---

TARGET_DIR="$MANIFESTS_DIR/$NAMESPACE"
OUTPUT_FILE="$TARGET_DIR/$SEALED_SECRET_FILENAME"

# Create the namespace directory if it doesn't exist
mkdir -p "$TARGET_DIR"

echo "Sealing secret from '$SECRET_FILE' to '$OUTPUT_FILE' for namespace '$NAMESPACE'..."

# Execute kubeseal command
kubeseal -f "$SECRET_FILE" -w "$OUTPUT_FILE" --cert "$CERT_FILE"

if [ $? -eq 0 ]; then
  echo "Successfully sealed secret and saved to '$OUTPUT_FILE'"
else
  echo "Error: kubeseal command failed. Please check the output above."
  exit 1
fi

echo "Done."
