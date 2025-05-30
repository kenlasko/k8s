#!/bin/sh

# Output file to store all secrets
OUTPUT_FILE="$HOME/akeyless_secrets_export.txt"

# Empty the output file if it exists
: > "$OUTPUT_FILE"

# Recursively list all secrets using "item_name" instead of "path"
akeyless list-items --json | awk '
/"item_name":/ {
    gsub(/[",]/, "", $2)
    print $2
}' | while IFS= read -r secret_path; do
    # Fetch the secret value
    secret_value=$(akeyless get-secret-value --name "$secret_path" 2>/dev/null)
    if [ $? -eq 0 ]; then
        printf "# %s\n%s\n\n" "$secret_path" "$secret_value" >> "$OUTPUT_FILE"
    else
        printf "# %s\n[ERROR retrieving secret]\n\n" "$secret_path" >> "$OUTPUT_FILE"
    fi
done

echo "✅ Secrets exported to $OUTPUT_FILE"
