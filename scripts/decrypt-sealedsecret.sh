#!/bin/sh

# Decrypt Sealed Secrets using kubeseal

# Check for input file argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 path/to/sealed-secret.yaml"
  exit 1
fi

SEALED_SECRETS_FILE=$1
PRIVATE_KEY="/run/secrets/sealed-secrets-private-key"

# Check if file exists
if [ ! -f "$SEALED_SECRETS_FILE" ]; then
  echo "❌ File not found: $SEALED_SECRETS_FILE" >&2
  exit 1
fi

# Create temp directory
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Split multi-doc YAML into individual files
awk '
  BEGIN { doc = 0 }
  /^---/ { doc++ }
  { print > "'"$TMPDIR"'/doc_" doc ".yaml" }
' "$SEALED_SECRETS_FILE"

# Loop over and decrypt
for docfile in "$TMPDIR"/doc_*.yaml; do
  if kubeseal --recovery-unseal --recovery-private-key "$PRIVATE_KEY" < "$docfile" > "$TMPDIR/unsealed.yaml" 2>/dev/null; then
    name=$(yq -r '.metadata.name' "$TMPDIR/unsealed.yaml")
    echo "${name}:"
    yq -r '.data // {} | to_entries[] | "  \(.key): \(.value | @base64d)"' "$TMPDIR/unsealed.yaml"
    echo
  fi
done
