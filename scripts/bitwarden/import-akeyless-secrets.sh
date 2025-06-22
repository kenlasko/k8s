#!/bin/sh

set -eu

if [ $# -ne 2 ]; then
  echo "Usage: $0 <akeyless-export-file> <project-name>"
  exit 1
fi

export_file="$1"
project_name="$2"
current_path=""
buffer=""

# Look up and normalize project ID
project_id=$(bws project list --output json | jq -r --arg name "$project_name" '.[] | select(.name == $name) | .id | sub("^urn:uuid:"; "")')

if [ -z "$project_id" ]; then
  echo "❌ Project \"$project_name\" not found"
  exit 1
fi

secret_exists() {
  secret_key="$1"
  # Try to get secret info, suppress output
  if bws secret get "$secret_key" "$project_id" >/dev/null 2>&1; then
    return 0  # exists
  else
    return 1  # not exists
  fi
}

flush_secret() {
  [ -z "$current_path" ] && return
  secret_name=$(echo "$current_path" | sed 's|^/||')

  if echo "$buffer" | jq . >/dev/null 2>&1; then
    compact_json=$(echo "$buffer" | jq -c .)
    if secret_exists "$secret_name"; then
      bws secret edit "$secret_name" "$compact_json" "$project_id" >/dev/null
      echo "♻️ Updated JSON secret: $secret_name"
    else
      bws secret create "$secret_name" "$compact_json" "$project_id" >/dev/null
      echo "✔ Created JSON secret: $secret_name"
    fi
  else
    if secret_exists "$secret_name"; then
      bws secret edit "$secret_name" "$buffer" "$project_id" >/dev/null
      echo "♻️ Updated raw secret: $secret_name"
    else
      bws secret create "$secret_name" "$buffer" "$project_id" >/dev/null
      echo "✔ Created raw secret: $secret_name"
    fi
  fi

  sleep 0.5
  current_path=""
  buffer=""
}

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
