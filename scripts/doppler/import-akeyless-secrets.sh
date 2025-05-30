#!/bin/sh
# Path to the exported AKeyless secrets
FILE="$HOME/akeyless_secrets_export.txt"
# Ensure the file exists
[ ! -f "$FILE" ] && echo "File not found: $FILE" && exit 1
# Temp vars
current_path=""
buffer=""
# Read line by line
while IFS= read -r line || [ -n "$line" ]; do
  # Match path header like "# /cloudflare/api-token"
  if echo "$line" | grep -qE '^# /'; then
    # Flush previous secret if any
    if [ -n "$current_path" ] && [ -n "$buffer" ]; then
      # Check if buffer is valid JSON
      if echo "$buffer" | jq . >/dev/null 2>&1; then
        # Save as single JSON secret (minified)
        value=$(echo "$buffer" | jq -c .)
        key=$(echo "$current_path" | tr '/-' '__' | tr '[:lower:]' '[:upper:]')
        doppler secrets set "$key=$value" --type json
      else
        # Try to parse as key-value pairs (original behavior)
        if echo "$buffer" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null > /tmp/kv_pairs; then
          while IFS='=' read -r k v; do
            key=$(echo "${current_path}_${k}" | tr '/-' '__' | tr '[:lower:]' '[:upper:]')
            value=$(printf "%b" "$v") # decode \uXXXX
            doppler secrets set "$key=$value" 
          done < /tmp/kv_pairs
          rm -f /tmp/kv_pairs
        else
          # Fallback: single string secret
          value=$(printf "%b" "$buffer") # decode \uXXXX
          key=$(echo "$current_path" | tr '/-' '__' | tr '[:lower:]' '[:upper:]')
          doppler secrets set "$key=$value"
        fi
      fi
    fi
    # Reset for new block
    #current_path=$(echo "$line" | sed -E 's/^# (\/.*)/\1/')
    current_path=$(echo "$line" | sed -E 's/^# \/(.*)/\1/')
    buffer=""
  elif [ -n "$line" ]; then
    # Accumulate lines for value block
    buffer="$buffer$line"
  fi
done < "$FILE"
# Flush the final block
if [ -n "$current_path" ] && [ -n "$buffer" ]; then
  # Check if buffer is valid JSON
  if echo "$buffer" | jq . >/dev/null 2>&1; then
    # Save as single JSON secret (minified)
    value=$(echo "$buffer" | jq -c .)
    key=$(echo "$current_path" | tr '/-' '__' | tr '[:lower:]' '[:upper:]')
    doppler secrets set "$key=$value" --type json
  else
    # Try to parse as key-value pairs (original behavior)
    if echo "$buffer" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null > /tmp/kv_pairs; then
      while IFS='=' read -r k v; do
        key=$(echo "${current_path}_${k}" | tr '/-' '__' | tr '[:lower:]' '[:upper:]')
        value=$(printf "%b" "$v")
        doppler secrets set "$key=$value"
      done < /tmp/kv_pairs
      rm -f /tmp/kv_pairs
    else
      value=$(printf "%b" "$buffer")
      key=$(echo "$current_path" | tr '/-' '__' | tr '[:lower:]' '[:upper:]')
      doppler secrets set "$key=$value"
    fi
  fi
fi
echo "✅ All secrets imported into Doppler."