#!/bin/sh

# Output file to store all secrets
OUTPUT_FILE="$HOME/akeyless_secrets_export.json"

# Recursively list all secrets
akeyless list-items > $OUTPUT_FILE

echo "Secrets exported to $OUTPUT_FILE"
