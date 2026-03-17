#!/usr/bin/env bash
set -e

echo "[INFO] =========================================="
echo "[INFO] Open Dynamic Export Add-on v2.4.0"
echo "[INFO] =========================================="

# Create data directory
mkdir -p /data

# Write config file
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json
echo "[INFO] Configuration written to /data/config.json"

# -------------------------------------------------------
# Certificate Setup
# -------------------------------------------------------
# ODE looks for certs at /data/ode/config/ internally.
# We also support user-configurable paths relative to /config
# (the HA config folder, accessible via the File Editor addon).
# Default paths:  /config/ode/sep2-cert.pem
#                 /config/ode/sep2-key.pem
# These can be changed on the add-on Configuration page via
# the sep2_cert_path and sep2_key_path options.
# -------------------------------------------------------

# Read user-configured paths (relative to /config, no leading slash)
SEP2_CERT_REL=$(cat /data/options.json | jq -r '.sep2_cert_path // "ode/sep2-cert.pem"')
SEP2_KEY_REL=$(cat /data/options.json | jq -r '.sep2_key_path // "ode/sep2-key.pem"')

# Strip any accidental leading slash so the path joins cleanly
SEP2_CERT_REL="${SEP2_CERT_REL#/}"
SEP2_KEY_REL="${SEP2_KEY_REL#/}"

# Resolve full source paths under /config
SEP2_CERT_SRC="/config/${SEP2_CERT_REL}"
SEP2_KEY_SRC="/config/${SEP2_KEY_REL}"

# ODE expects certs at /data/ode/config/ — this matches what the app resolves internally
ODE_CONFIG_DIR="/data/ode/config"
mkdir -p "${ODE_CONFIG_DIR}"

echo "[INFO] =========================================="
echo "[INFO] Certificate Setup"
echo "[INFO] =========================================="
echo "[INFO] Looking for cert : ${SEP2_CERT_SRC}"
echo "[INFO] Looking for key  : ${SEP2_KEY_SRC}"
echo "[INFO] ODE config dir   : ${ODE_CONFIG_DIR}"

if [ -f "${SEP2_CERT_SRC}" ] && [ -f "${SEP2_KEY_SRC}" ]; then
    echo "[INFO] ✓ Found SEP2 certificates"
    cp "${SEP2_CERT_SRC}" "${ODE_CONFIG_DIR}/sep2-cert.pem"
    cp "${SEP2_KEY_SRC}"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    echo "[INFO] ✓ Certificates copied to ${ODE_CONFIG_DIR}"

    # Show certificate info
    echo "[INFO] Certificate details:"
    openssl x509 -in "${ODE_CONFIG_DIR}/sep2-cert.pem" -noout -subject -dates 2>/dev/null \
        || echo "[WARNING] Unable to parse certificate details — check the file is a valid PEM"
else
    echo "[WARNING] ⚠ SEP2 certificates not found!"
    echo "[WARNING] To enable CSIP-AUS, place your certificates at:"
    echo "[WARNING]   ${SEP2_CERT_SRC}"
    echo "[WARNING]   ${SEP2_KEY_SRC}"
    echo "[WARNING] You can change these paths on the add-on Configuration page"
    echo "[WARNING] (sep2_cert_path and sep2_key_path options)."
    echo "[WARNING] Files must be placed using the File Editor or SSH add-on."

    # Check for fallback in legacy /data/certs location from older installs
    if [ -f "/data/certs/sep2-cert.pem" ] && [ -f "/data/certs/sep2-key.pem" ]; then
        echo "[INFO] Found legacy certs in /data/certs — copying as fallback"
        cp "/data/certs/sep2-cert.pem" "${ODE_CONFIG_DIR}/sep2-cert.pem"
        cp "/data/certs/sep2-key.pem"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    else
        # Create placeholder files so ODE starts (it will fail at runtime on CSIP-AUS calls)
        echo "# SEP2 Certificate Placeholder — replace with your real cert" > "${ODE_CONFIG_DIR}/sep2-cert.pem"
        echo "# SEP2 Key Placeholder — replace with your real key"          > "${ODE_CONFIG_DIR}/sep2-key.pem"
        echo "[INFO] Created placeholder certificate files"
    fi
fi

# -------------------------------------------------------
# Environment
# -------------------------------------------------------
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="0.0.0.0"
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="${ODE_CONFIG_DIR}/sep2-cert.pem"
export SEP2_KEY_FILE="${ODE_CONFIG_DIR}/sep2-key.pem"
export SEP2_PEN="12345"

echo "[INFO] =========================================="
echo "[INFO] Environment Configuration"
echo "[INFO] =========================================="
echo "[INFO] LOG_LEVEL:         ${LOG_LEVEL}"
echo "[INFO] CONFIG_PATH:       ${CONFIG_PATH}"
echo "[INFO] SEP2_CERT_FILE:    ${SEP2_CERT_FILE}"
echo "[INFO] SEP2_KEY_FILE:     ${SEP2_KEY_FILE}"
echo "[INFO] SERVER_HOST:PORT:  ${SERVER_HOST}:${SERVER_PORT}"
echo "[INFO] =========================================="
echo "[INFO] Starting ODE Backend"
echo "[INFO] =========================================="

cd /ode
exec node dist/src/app.js
