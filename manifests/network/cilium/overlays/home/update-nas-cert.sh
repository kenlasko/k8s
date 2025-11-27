#!/bin/sh

# Checks for updated LetsEncrypt wildcard cert, validates it, and copies to NAS via SCP.
# If there is difficulty logging in to the NAS, ensure the NAS has the public key for the private key
# stored in the 'nas01-sshkey' secret. This is mounted at /share/homes/kenadmin/.ssh, but by default, SSH 
# creates a base home folder at /home/kenadmin. To fix this:
#  1. SSH to the NAS manually once: ssh -i nas01-sshkey kenadmin@192.168.1.3
#  2. Create a symlink: ln -s /share/CACHEDEV1_DATA/homes/kenadmin /home/kenadmin
#  3. Check that kenadmin has permissions to write to the /etc/stunnel folder on the NAS (sudo chmod 755 /etc/stunnel)
#  4. Make sure kenadmin has permissions to write to the .pem files in /etc/stunnel (sudo chown kenadmin:users /etc/stunnel/*.pem)
#  5. Exit and try running this script again.
# 
# Note: Until I figure out how to run sudo non-interactively over SSH, the next steps are required:
#  - SSH to the NAS manually and run:
#       sudo /etc/init.d/Qthttpd.sh restart
#       sudo /etc/init.d/thttpd.sh restart
#       sudo /etc/init.d/stunnel.sh restart

set -eu

CRT="/certs/tls.crt"
KEY="/certs/tls.key"
OUT_DIR="/scripts"

UCA_OUT="$OUT_DIR/uca.pem"
STUNNEL_OUT="$OUT_DIR/stunnel.pem"

# --- NAS settings ---
NAS_USER="kenadmin"
NAS_HOST="192.168.1.3"
NAS_UCA_PATH="/etc/stunnel/uca.pem"
NAS_STUNNEL_PATH="/etc/stunnel/stunnel.pem"
SSH_KEY="nas01-sshkey"

# --- Helpers ---
fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

check_exists() {
    [ -f "$1" ] || fail "Required file missing: $1"
}

scp_if_different() {
    LOCAL_FILE="$1"
    REMOTE_FILE="$2"

    TMP_REMOTE=$(mktemp)

    echo "[INFO] Checking if $REMOTE_FILE on NAS differs..."

    if scp -O -i "$SSH_KEY" -o StrictHostKeyChecking=no -q "${NAS_USER}@${NAS_HOST}:${REMOTE_FILE}" "$TMP_REMOTE" 2>/dev/null; then
        if cmp -s "$LOCAL_FILE" "$TMP_REMOTE"; then
            echo "[INFO] No change for $(basename "$REMOTE_FILE"), skipping upload."
            rm -f "$TMP_REMOTE"
            return
        fi
    else
        echo "[WARN] Remote file missing, will upload new one."
    fi

    echo "[INFO] Uploading $(basename "$LOCAL_FILE") → $REMOTE_FILE"
    scp -O -i "$SSH_KEY" -o StrictHostKeyChecking=no -q "$LOCAL_FILE" "${NAS_USER}@${NAS_HOST}:${REMOTE_FILE}" \
        || fail "Failed SCP upload for $REMOTE_FILE"

    rm -f "$TMP_REMOTE"
}

safe_write() {
    TMP=$(mktemp)
    printf "%s" "$2" > "$TMP"
    mv "$TMP" "$1"
}

echo "[INFO] Validating input files..."
check_exists "$CRT"
check_exists "$KEY"

# Create temporary workspace
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

CERT1="$TMPDIR/cert1.pem"
CERT2="$TMPDIR/cert2.pem"

echo "[INFO] Splitting certificate chain..."
awk '
/-----BEGIN CERTIFICATE-----/ {
    file=sprintf("'"$TMPDIR"'/cert%d.pem", ++count)
}
{ print > file }
' "$CRT"

# Count number of certs
CERT_COUNT=$(ls -1 "$TMPDIR"/cert*.pem 2>/dev/null | wc -l || true)
[ "$CERT_COUNT" -ge 1 ] || fail "No certificates found in tls.crt"
[ "$CERT_COUNT" -le 3 ] || echo "[WARN] More than 2 certificates found; using first two only."

# Pick first two
CERT1="$TMPDIR/cert1.pem"
CERT2="$TMPDIR/cert2.pem"

# Default ordering
LEAF="$CERT1"
INTERMEDIATE="$CERT2"

echo "[INFO] Detecting which cert is leaf and which is intermediate..."
# Detect using basicConstraints
if openssl x509 -noout -ext basicConstraints -in "$CERT1" 2>/dev/null | grep -q "CA:FALSE"; then
    LEAF="$CERT1"
    INTERMEDIATE="$CERT2"
elif openssl x509 -noout -ext basicConstraints -in "$CERT2" 2>/dev/null | grep -q "CA:FALSE"; then
    LEAF="$CERT2"
    INTERMEDIATE="$CERT1"
else
    echo "[WARN] Could not reliably detect which cert is leaf. Assuming first is leaf."
fi

# Validate leaf certificate
echo "[INFO] Validating leaf certificate..."
openssl x509 -noout -modulus -in "$LEAF" >/dev/null 2>&1 \
    || fail "Leaf certificate is invalid"

# Validate private key
echo "[INFO] Validating private key..."
openssl rsa -noout -modulus -in "$KEY" >/dev/null 2>&1 \
    || fail "Private key is invalid"

# Validate leaf matches private key
if [ "$(openssl x509 -noout -modulus -in "$LEAF")" != "$(openssl rsa -noout -modulus -in "$KEY")" ]; then
    fail "Leaf certificate does not match private key"
fi

# Validate intermediate (if exists)
if [ -f "$INTERMEDIATE" ]; then
    echo "[INFO] Validating intermediate certificate..."
    openssl x509 -noout -in "$INTERMEDIATE" >/dev/null 2>&1 \
        || fail "Intermediate certificate is invalid"
fi

# Write intermediate cert locally
echo "[INFO] Writing intermediate certificate → $UCA_OUT"
cp "$INTERMEDIATE" "$UCA_OUT"

# Create new stunnel.pem
echo "[INFO] Generating stunnel.pem..."
cat "$LEAF" "$KEY" > "$TMPDIR/stunnel.pem.new"

# If local output didn't change, don't rewrite it
if ! cmp -s "$TMPDIR/stunnel.pem.new" "$STUNNEL_OUT" 2>/dev/null; then
    cp "$TMPDIR/stunnel.pem.new" "$STUNNEL_OUT"
    echo "[INFO] Local stunnel.pem updated."
else
    echo "[INFO] No local change to stunnel.pem."
fi

echo "[INFO] Uploading files to NAS if needed..."

scp_if_different "$UCA_OUT" "$NAS_UCA_PATH"
scp_if_different "$STUNNEL_OUT" "$NAS_STUNNEL_PATH"

echo "[INFO] All done — certificate processing and NAS sync completed."