#!/bin/bash

# Script to seal a secret and copy it to a namespace-specific folder

# --- Configuration ---
SECRET_FILE="secret.yaml"          # Path to your secret.yaml file
CERT_FILE="sealed-secret-signing-key.crt" # Path to your sealed-secret-signing-key.crt file
MANIFESTS_DIR="k8s/manifests"      # Base directory for manifests
SEALED_SECRET_FILENAME="sealed-secrets.yaml" # Name of the sealed secret file
TEMP_SEALED_SECRET_FILE="temp-sealed-secret.yaml" # Temporary file for the new sealed secret

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
TEMP_OUTPUT_FILE="$TARGET_DIR/$TEMP_SEALED_SECRET_FILE"

# Create the namespace directory if it doesn't exist
mkdir -p "$TARGET_DIR"

echo "Sealing secret from '$SECRET_FILE' to '$TEMP_OUTPUT_FILE' for namespace '$NAMESPACE'..."

# Execute kubeseal command
kubeseal -f "$SECRET_FILE" -w "$TEMP_OUTPUT_FILE" --cert "$CERT_FILE"

if [ $? -ne 0 ]; then
  echo "Error: kubeseal command failed. Please check the output above."
  exit 1
fi

# Check if the secret already exists in the sealed-secrets.yaml
SECRET_NAME=$(yq e '.metadata.name' "$TEMP_OUTPUT_FILE")

# Merge the new sealed secret into the existing sealed-secrets.yaml
if [ -f "$OUTPUT_FILE" ]; then
  echo "Merging new $SECRET_NAME sealed secret into existing '$OUTPUT_FILE'..."
  # Save all documents in sealed-secrets.yaml EXCEPT for the one we want to ad
  yq eval "select(.metadata.name != \"$SECRET_NAME\")" -i $OUTPUT_FILE
  # Append the new sealed secret to the sealed-secrets.yaml
  cat "$TEMP_OUTPUT_FILE" >> "$OUTPUT_FILE"
else # No existing sealed-secrets.yaml. Just copy the new sealed secret.
  echo "Copying new sealed secret to '$OUTPUT_FILE'..."
  mv "$TEMP_OUTPUT_FILE" "$OUTPUT_FILE"
  echo "Successfully sealed secret and saved to '$OUTPUT_FILE'"
fi

# Clean up temporary file
rm -f "$TEMP_OUTPUT_FILE"

echo "Done."