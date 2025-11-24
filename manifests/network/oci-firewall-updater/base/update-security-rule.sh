#!/bin/bash
set -euo pipefail

PUBLIC_IP_SERVICE="https://ifconfig.me"
SECURITY_LIST_ID="ocid1.securitylist.oc1.ca-toronto-1.aaaaaaaajhnvoq3w4nsfb2pigc2icp4vczxcufq7v3b42jjunubdc6oma7sa"
RULE_DESC="Allow all for home access"
CHECK_INTERVAL_MINUTES=2
CACHE_FILE="/tmp/oci_home_ip.cache"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

get_public_ip() {
  local providers=(
    "https://ifconfig.me"
    "https://api.ipify.org"
    "https://icanhazip.com"
    "https://checkip.amazonaws.com"
  )

  for url in "${providers[@]}"; do
    local ip
    ip=$(curl -s --max-time 5 "$url" || true)

    # Trim whitespace
    ip=$(echo "$ip" | tr -d "[:space:]")

    if [[ -z "$ip" ]]; then
      log "Provider $url returned nothing"
      continue
    fi

    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$ip"
      return 0
    else
      log "Provider $url returned invalid IP: $ip"
    fi
  done

  log "❌ All public IP providers failed."
  return 1
}

get_cached_ip() {
  [[ -f "$CACHE_FILE" ]] && cat "$CACHE_FILE" || echo ""
}

save_cached_ip() {
  echo "$1" > "$CACHE_FILE"
}

get_oci_ip() {
  oci network security-list get --security-list-id "$SECURITY_LIST_ID" 2>/dev/null \
    | jq -r --arg desc "$RULE_DESC" '.data."ingress-security-rules"[] | select(.description==$desc) | .source' \
    | sed 's#/32##'
}

update_oci_ip() {
  local old_ip="$1"
  local new_ip="$2"

  log "Replacing rule IP $old_ip → $new_ip"

  local rules updated
  rules=$(oci network security-list get --security-list-id "$SECURITY_LIST_ID" | jq '.data."ingress-security-rules"')

  updated=$(echo "$rules" | sed "s#${old_ip}/32#${new_ip}/32#")

  if [[ -z "$updated" ]]; then
    log "❌ Failed to generate updated rule JSON"
    return 1
  fi

  if oci network security-list update \
       --security-list-id "$SECURITY_LIST_ID" \
       --ingress-security-rules "$updated" --force; then
    log "✅ OCI security list updated"
    save_cached_ip "$new_ip"
  else
    log "❌ Failed to update OCI"
    return 1
  fi
}

# --- Main Loop --------------------------------------------------------

log "Starting OCI Home-IP updater (interval: $CHECK_INTERVAL_MINUTES minutes)"

while true; do
  log "--- Checking IP ---"

  PUBLIC_IP=$(get_public_ip || true)
  if [[ -z "$PUBLIC_IP" ]]; then
    log "Skipping round due to public IP error"
    sleep "${CHECK_INTERVAL_MINUTES}m"
    continue
  fi

  CACHED_IP=$(get_cached_ip)

  if [[ -z "$CACHED_IP" ]]; then
    log "No cached IP found; retrieving from OCI..."
    CACHED_IP=$(get_oci_ip)

    if [[ -z "$CACHED_IP" || "$CACHED_IP" == "null" ]]; then
      log "❌ Could not get current IP from OCI"
      sleep "${CHECK_INTERVAL_MINUTES}m"
      continue
    fi

    save_cached_ip "$CACHED_IP"
    log "Cached OCI IP initialized: $CACHED_IP"
  fi

  log "Current public IP: $PUBLIC_IP"
  log "Cached OCI IP:     $CACHED_IP"

  if [[ "$PUBLIC_IP" != "$CACHED_IP" ]]; then
    log "IP changed → Updating OCI"
    if update_oci_ip "$CACHED_IP" "$PUBLIC_IP"; then
      log "New IP saved to cache"
    fi
  else
    log "No update needed"
  fi

  log "Sleeping ${CHECK_INTERVAL_MINUTES} minutes..."
  sleep "${CHECK_INTERVAL_MINUTES}m"
done