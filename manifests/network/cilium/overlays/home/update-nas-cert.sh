#!/bin/sh

# Checks for updated LetsEncrypt wildcard cert, validates it, and copies to NAS via SCP.
# Then restarts necessary services on the NAS to pick up the new cert.

# For more information, see https://github.com/kenlasko/k8s/blob/main/docs/NASCONFIG.md#nas-letsencrypt-certificate-management


set -eu

CRT="/certs/tls.crt"
KEY="/certs/tls.key"
OUT_DIR="/scripts"

UCA_OUT="$OUT_DIR/uca.pem"
STUNNEL_OUT="$OUT_DIR/stunnel.pem"

# --- NAS settings ---
NAS_USER=$(cat /creds/nas-username)
NAS_HOST=$(cat /creds/nas-host)
NAS_UCA_PATH="/etc/stunnel/uca.pem"
NAS_STUNNEL_PATH="/etc/stunnel/stunnel.pem"
SSH_KEY="/creds/nas-sshkey"

# Track if any files were updated
FILES_UPDATED=0

# --- Helpers ---
fail() {
    echo "[ERROR] $1" >&2
    exit 1
}

check_exists() {
    [ -f "$1" ] || fail "Required file missing: $1"
}


restart_nas_services() {
    echo "[INFO] Restarting NAS services..."
    
    for service in Qthttpd thttpd stunnel; do
        if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "${NAS_USER}@${NAS_HOST}" "sudo /etc/init.d/${service}.sh restart"; then
            echo "[INFO] $service restarted successfully"
        else
            echo "[WARN] Failed to restart $service"
        fi
    done
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
    FILES_UPDATED=1
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

if [ "$FILES_UPDATED" -eq 1 ]; then
    echo "[INFO] Files were updated on NAS, restarting services..."
    restart_nas_services
else
    echo "[INFO] No files were updated on NAS, skipping service restart."
fi

echo "[INFO] All done — certificate processing and NAS sync completed."