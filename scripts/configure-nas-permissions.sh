#!/bin/sh

# This script configures the NAS permissions so the LetsEncrypt Certificate Management (/manifests/network/cilium/overlays/home/update-nas-cert.sh) script can function properly.
# It needs to be run after every NAS upgrade since the upgrade process resets permissions.

ADMINNAME="kenadmin"
HOMEDIR="/home/${ADMINNAME}"
SUDOERS_DIR="/usr/etc/sudoers.d"
SUDOERS_FILE_NAME="kenadmin-service-restart"
SUDOERS_FILE_PATH="${SUDOERS_DIR}/${SUDOERS_FILE_NAME}"

# Remove existing home directory and create a symlink to the NAS home directory
sudo rm -rf $HOMEDIR
sudo ln -s /share/CACHEDEV1_DATA/homes/$ADMINNAME $HOMEDIR

# Make sure the stunnel certificates are writable by kenadmin
sudo chmod 755 /etc/stunnel
sudo chown $ADMINNAME:administrators /etc/stunnel/*.pem

# Create sudoers.d directory
sudo mkdir -p "$SUDOERS_DIR"

# Set correct ownership and permissions on the directory
sudo chown admin:administrators "$SUDOERS_DIR"
sudo chmod 0755 "$SUDOERS_DIR"

# Create the sudoers file
cat <<'EOF' | sudo tee "$SUDOERS_FILE_PATH" > /dev/null
${ADMINNAME} ALL=(ALL) NOPASSWD: /etc/init.d/Qthttpd.sh restart, \
                             /etc/init.d/thttpd.sh restart, \
                             /etc/init.d/stunnel.sh restart
EOF

# Set correct ownership and permissions on the sudoers file
sudo chown admin:administrators "$SUDOERS_FILE_PATH"
sudo chmod 0440 "$SUDOERS_FILE_PATH"