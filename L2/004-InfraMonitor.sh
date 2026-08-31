#!/usr/bin/env bash
set -euo pipefail

# =================================================================
# NETDATA CONFIGURATION
# =================================================================

NETDATA_PORT="9998"
NETDATA_DISABLE_TELEMETRY="true"

KICKSTART="/tmp/netdata-kickstart.sh"

# =================================================================
# ROOT CHECK
# =================================================================

if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

echo "================================================================"
echo "📊 NETDATA INSTALLATION"
echo "================================================================"
echo "Port                  : ${NETDATA_PORT}"
echo "Startup               : Enabled"
echo "Non-interactive       : Yes"
echo "Anonymous telemetry   : ${NETDATA_DISABLE_TELEMETRY}"
echo "================================================================"

# =================================================================
# DOWNLOAD KICKSTART
# =================================================================

echo "[INFO] Downloading Netdata installer..."

wget -q -O "${KICKSTART}" \
    https://get.netdata.cloud/kickstart.sh

chmod +x "${KICKSTART}"

# =================================================================
# INSTALL NETDATA
# =================================================================

echo "[INFO] Installing Netdata..."

if [[ "${NETDATA_DISABLE_TELEMETRY}" == "true" ]]; then
    "${KICKSTART}" \
        --non-interactive \
        --disable-telemetry
else
    "${KICKSTART}" \
        --non-interactive
fi

# =================================================================
# NETDATA CONFIGURATION
# =================================================================

echo "[INFO] Configuring Netdata..."

mkdir -p /etc/netdata

cat > /etc/netdata/netdata.conf <<EOF
[web]
    default port = ${NETDATA_PORT}
    bind to = *
EOF

# =================================================================
# DISABLE ANONYMOUS TELEMETRY
# =================================================================

if [[ "${NETDATA_DISABLE_TELEMETRY}" == "true" ]]; then
    echo "[INFO] Disabling anonymous telemetry..."

    touch /etc/netdata/.opt-out-from-anonymous-statistics

    chown netdata:netdata \
        /etc/netdata/.opt-out-from-anonymous-statistics 2>/dev/null || true
fi

# =================================================================
# SYSTEMD
# =================================================================

echo "[INFO] Reloading systemd..."
systemctl daemon-reload

echo "[INFO] Enabling Netdata at boot..."
systemctl enable netdata

echo "[INFO] Restarting Netdata..."
systemctl restart netdata

# =================================================================
# WAIT FOR NETDATA
# =================================================================

echo "[INFO] Waiting for Netdata..."

for i in {1..20}; do

    if systemctl is-active --quiet netdata; then

        NETDATA_LISTENING="$(ss -lntp 2>/dev/null || true)"

        if grep -Fq ":${NETDATA_PORT}" <<< "${NETDATA_LISTENING}"; then
            echo "[INFO] Netdata is active and listening on port ${NETDATA_PORT} after ${i}s."
            break
        fi

    fi

    sleep 1
done

# =================================================================
# VALIDATION
# =================================================================

echo
echo "================================================================"
echo "🔍 NETDATA VALIDATION"
echo "================================================================"

if ! systemctl is-enabled --quiet netdata; then
    echo "[ERROR] Netdata is not enabled for startup."
    exit 1
fi

if ! systemctl is-active --quiet netdata; then
    echo "[ERROR] Netdata is not running."
    systemctl --no-pager -l status netdata || true
    exit 1
fi

# =================================================================
# NETDATA PORT VALIDATION
# =================================================================

NETDATA_LISTENING="$(ss -lntp 2>/dev/null || true)"

echo "[DEBUG] NETDATA_PORT=[${NETDATA_PORT}]"
echo "[DEBUG] NETDATA_LISTENING:"
printf '%s\n' "${NETDATA_LISTENING}"

if grep -Fq ":${NETDATA_PORT}" <<< "${NETDATA_LISTENING}"; then
    echo "[PASS] Netdata is listening on port ${NETDATA_PORT}."
else
    echo "[ERROR] Netdata is not listening on port ${NETDATA_PORT}."
    ss -lntp | grep netdata || true
    exit 1
fi

# =================================================================
# CLEANUP
# =================================================================

rm -f "${KICKSTART}"

# =================================================================
# FINAL STATUS
# =================================================================

echo
echo "================================================================"
echo "✅ NETDATA READY"
echo "================================================================"
echo "Service               : netdata"
echo "Port                  : ${NETDATA_PORT}"
echo "Startup               : Enabled"
echo "Status                : $(systemctl is-active netdata)"
echo "Telemetry             : ${NETDATA_DISABLE_TELEMETRY}"
echo "Dashboard             : http://SERVER_IP:${NETDATA_PORT}"
echo "================================================================"
