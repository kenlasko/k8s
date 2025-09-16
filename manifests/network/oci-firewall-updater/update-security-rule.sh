#!/bin/bash
# This script updates the OCI ingress security list to allow access from the current home IP address.
# It checks the current public IP address of a specified DNS name and updates the security list if the IP has changed.
# Works in conjunction with DDNS-Updater running at home which ensures the public DNS name always points to the current home IP.

DNS_NAME="home.ucdialplans.com"
SECURITY_LIST_ID="ocid1.securitylist.oc1.ca-toronto-1.aaaaaaaajhnvoq3w4nsfb2pigc2icp4vczxcufq7v3b42jjunubdc6oma7sa"

# Get the current public IP address of the DNS name
HOME_IP=$(ping -c1 -w1 $DNS_NAME | awk -F'[()]' '/PING/{print $2}')

# Get the current security rules
INGRESS_RULES=$(oci network security-list get --security-list-id "$SECURITY_LIST_ID" | jq '.data."ingress-security-rules"')

# Extract the current home IP from the ingress rules
CURRENT_IP=$(echo "$INGRESS_RULES" \
  | jq -r '.[] | select(.description=="Allow all for home access") | .source' \
  | sed 's#/32##')

if [ "$HOME_IP" != "$CURRENT_IP" ]; then
    echo "Updating security list. Old IP: $CURRENT_IP, New IP: $HOME_IP"
    # Update the security list with the new IP
    UPDATED_RULES=$(echo "$INGRESS_RULES" | sed "s#${CURRENT_IP}#${HOME_IP}#")
    # Apply the updated rules
    oci network security-list update \
    --security-list-id "$SECURITY_LIST_ID" \
    --ingress-security-rules "$UPDATED_RULES"
else
    echo "No update needed. Current IP: $CURRENT_IP"
fi