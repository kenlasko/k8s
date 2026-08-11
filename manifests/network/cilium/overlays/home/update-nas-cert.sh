#!/bin/sh

# Checks for updated LetsEncrypt wildcard cert, validates it, and copies to NAS via SCP.
# Then restarts necessary services on the NAS to pick up the new cert.
#
# Runs one check immediately on startup, then (unless WATCH_MODE=0) watches the
# mounted secret directory and re-runs the check whenever Kubernetes rotates it.
#
# Environment:
#   WATCH_MODE=0        run a single check and exit (exit code reflects the check)
#   WATCH_INTERVAL=3600 seconds before re-checking even if no change was detected
#
# For more information, see https://github.com/kenlasko/k8s/blob/main/docs/NASCONFIG.md#nas-letsencrypt-certificate-management


set -eu

CRT="/certs/tls.crt"
KEY="/certs/tls.key"
OUT_DIR="/scripts"

# Watch the directory, not the file: Kubernetes updates a secret mount by
# atomically swapping the "..data" symlink, so the tls.crt inode itself never
# changes and a watch on the file path alone never fires.
WATCH_DIR="/certs"
WATCH_MODE="${WATCH_MODE:-1}"
WATCH_INTERVAL="${WATCH_INTERVAL:-3600}"

UCA_OUT="$OUT_DIR/uca.pem"
STUNNEL_OUT="$OUT_DIR/stunnel.pem"

# --- NAS settings ---
NAS_USER=$(cat /creds/nas-username)
NAS_HOST=$(cat /creds/nas-host)
NAS_UCA_PATH="/etc/stunnel/uca.pem"
NAS_STUNNEL_PATH="/etc/stunnel/stunnel.pem"
SSH_KEY="/scripts/nas-sshkey"

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

# Runs in a subshell so that fail() aborts only this check, not the watch loop,
# and so each run gets its own temp workspace and trap.
run_check() (
    # Re-arm errexit: the shell suspends it for commands in an "if" condition,
    # and that suspension is inherited by this subshell.
    set -eu

    # Track if any files were updated
    FILES_UPDATED=0

    echo "[INFO] Validating input files..."
    check_exists "$CRT"
    check_exists "$KEY"

    # Create temporary workspace
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT

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

    echo "[INFO] Certificate processing and NAS sync completed."
)

# --- Main ---

echo "[INFO] Running startup certificate check..."
if run_check; then
    STARTUP_RC=0
else
    STARTUP_RC=$?
    echo "[WARN] Startup certificate check failed (exit $STARTUP_RC)."
fi

if [ "$WATCH_MODE" = "0" ]; then
    exit "$STARTUP_RC"
fi

command -v inotifywait >/dev/null 2>&1 \
    || fail "WATCH_MODE enabled but inotifywait is not installed"

echo "[INFO] Watching $WATCH_DIR for certificate changes (re-check every ${WATCH_INTERVAL}s regardless)..."
while true; do
    # Exit 2 means the timeout elapsed with no event; anything else means a
    # change fired. Either way, re-run the check — it is a no-op when nothing
    # actually changed.
    if inotifywait -q -t "$WATCH_INTERVAL" -e create,delete,modify,move "$WATCH_DIR"; then
        echo "[INFO] Certificate secret changed, running check..."
    else
        RC=$?
        if [ "$RC" -eq 2 ]; then
            echo "[INFO] Watch interval elapsed, running periodic check..."
        else
            echo "[WARN] inotifywait exited with $RC, running check and retrying watch..."
        fi
    fi

    run_check || echo "[WARN] Certificate check failed, continuing to watch."
done
