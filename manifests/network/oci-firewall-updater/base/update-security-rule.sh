#!/bin/bash
set -euo pipefail

# This script updates the OCI ingress security list to allow access from the current home IP address.
# It checks the current public IP address and updates the security list if the IP has changed.
# Works in conjunction with DDNS-Updater running at home which ensures the public DNS name always points to the current home IP.

DNS_NAME="home.ucdialplans.com"
PUBLIC_IP_SERVICE="ifconfig.me"
SECURITY_LIST_ID="ocid1.securitylist.oc1.ca-toronto-1.aaaaaaaajhnvoq3w4nsfb2pigc2icp4vczxcufq7v3b42jjunubdc6oma7sa"
RULE_DESC="Allow all for home access"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# --- Step 1: Resolve DNS ---
HOME_IP=$(curl -s "$PUBLIC_IP_SERVICE" || true)
if [[ -z "$HOME_IP" ]]; then
  log "❌ Failed to retrieve public IP from $PUBLIC_IP_SERVICE"
  exit 1
fi
log "Public IP detected via curl: $HOME_IP"

# --- Step 1b: Check if it's a public IP ---
if [[ "$HOME_IP" =~ ^192\.168\. ]]; then
  log "❌ Resolved IP $HOME_IP is a private 192.168.x.x address, aborting update."
  exit 1
fi

# --- Step 2: Get current ingress rules from OCI ---
if ! INGRESS_RULES=$(oci network security-list get --security-list-id "$SECURITY_LIST_ID" 2>/dev/null | jq '.data."ingress-security-rules"'); then
  log "❌ Failed to fetch ingress rules from OCI"
  exit 1
fi

# --- Step 3: Extract current home IP from ingress rules ---
CURRENT_IP=$(echo "$INGRESS_RULES" \
  | jq -r --arg desc "$RULE_DESC" '.[] | select(.description==$desc) | .source' \
  | sed 's#/32##' || true)

if [[ -z "$CURRENT_IP" || "$CURRENT_IP" == "null" ]]; then
  log "❌ Could not find a rule with description \"$RULE_DESC\""
  exit 1
fi
log "Current OCI rule IP: $CURRENT_IP"

# --- Step 4: Compare and update if needed ---
if [[ "$HOME_IP" != "$CURRENT_IP" ]]; then
  log "Updating security list. Old IP: $CURRENT_IP, New IP: $HOME_IP"

  # Replace only the matching rule's IP
  UPDATED_RULES=$(echo "$INGRESS_RULES" | sed "s#${CURRENT_IP}/32#${HOME_IP}/32#")

  if [[ -z "$UPDATED_RULES" ]]; then
    log "❌ Failed to build updated rules JSON"
    exit 1
  fi

  if oci network security-list update \
       --security-list-id "$SECURITY_LIST_ID" \
       --ingress-security-rules "$UPDATED_RULES" --force; then
    log "✅ Security list updated successfully."
  else
    log "❌ Failed to update security list."
    exit 1
  fi
else
  log "No update needed. Current IP matches: $CURRENT_IP"
fi