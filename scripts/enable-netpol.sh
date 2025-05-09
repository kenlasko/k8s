#!/bin/sh

# Get the absolute path of the script's directory's parent
SCRIPT_PATH=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Find and rename all networkpolicy_DISABLED.yaml files
find "$SCRIPT_PATH" -type f -name 'networkpolicy_DISABLED.yaml' | while IFS= read -r file; do
  dir=$(dirname "$file")
  mv "$file" "$dir/networkpolicy.yaml"
  echo "Reverted: $file -> $dir/networkpolicy.yaml"
done
