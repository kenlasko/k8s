#!/bin/sh

set -eu

if [ $# -lt 3 ]; then
  echo "Usage: $0 <akeyless-export-file> <gitlab-project-id-or-path> <gitlab-token>"
  exit 1
fi

export_file="$1"
project="$2"   # project ID or path (e.g., "kenlasko/k8s")
gitlab_token="$3"
api_url="https://gitlab.com/api/v4"

current_path=""
buffer=""

# Normalize the project path into URL-safe format
project_encoded=$(echo "$project" | jq -sRr @uri)

# Check if a variable exists
variable_exists() {
  var_name="$1"
  curl -s -o /dev/null -w "%{http_code}" \
    --header "PRIVATE-TOKEN: $gitlab_token" \
    "$api_url/projects/$project_encoded/variables/$var_name" | grep -q '^200'
}

# Create or update a variable
flush_secret() {
  [ -z "$current_path" ] && return

  secret_prefix=$(echo "$current_path" \
    | sed 's|^/||; s|[-/]|_|g; s|[^A-Za-z0-9_]||g')

  # Trim trailing newline from buffer
  buffer=$(printf "%s" "$buffer")

  if variable_exists "$secret_prefix"; then
    payload=$(jq -n --arg value "$buffer" \
      '{ value: $value, masked: false, protected: false }')

    curl -s -X PUT "$api_url/projects/$project_encoded/variables/$secret_prefix" \
      --header "PRIVATE-TOKEN: $gitlab_token" \
      --header "Content-Type: application/json" \
      --data "$payload" >/dev/null
    echo "♻️ Updated variable: $secret_prefix"
  else
    payload=$(jq -n --arg key "$secret_prefix" --arg value "$buffer" \
      '{ key: $key, value: $value, masked: false, protected: false }')

    curl -s -X POST "$api_url/projects/$project_encoded/variables" \
      --header "PRIVATE-TOKEN: $gitlab_token" \
      --header "Content-Type: application/json" \
      --data "$payload" >/dev/null
    echo "✔ Created variable: $secret_prefix"
  fi

  sleep 0.3
  current_path=""
  buffer=""
}

# Parse the AKeyless export file
while IFS= read -r line || [ -n "$line" ]; do
  if echo "$line" | grep -qE '^# /'; then
    flush_secret
    current_path=$(echo "$line" | sed 's/^# //')
    buffer=""
  else
    buffer="${buffer}${line}
"
  fi
done < "$export_file"

flush_secret
