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

# Set up certificate directories
CERT_DIR="/data/certs"
ODE_CONFIG_DIR="/ode/config"

mkdir -p "${CERT_DIR}"
mkdir -p "${ODE_CONFIG_DIR}"

echo "[INFO] =========================================="
echo "[INFO] Certificate Setup"
echo "[INFO] =========================================="
echo "[INFO] Persistent storage: ${CERT_DIR}"
echo "[INFO] ODE config directory: ${ODE_CONFIG_DIR}"

# Handle SEP2 certificates
if [ -f "${CERT_DIR}/sep2-cert.pem" ] && [ -f "${CERT_DIR}/sep2-key.pem" ]; then
    echo "[INFO] ✓ Found SEP2 certificates in ${CERT_DIR}"
    cp "${CERT_DIR}/sep2-cert.pem" "${ODE_CONFIG_DIR}/sep2-cert.pem"
    cp "${CERT_DIR}/sep2-key.pem" "${ODE_CONFIG_DIR}/sep2-key.pem"
    echo "[INFO] ✓ Certificates copied to ${ODE_CONFIG_DIR}"
    
    # Show certificate info
    echo "[INFO] Certificate details:"
    openssl x509 -in "${ODE_CONFIG_DIR}/sep2-cert.pem" -noout -subject -dates 2>/dev/null || echo "[INFO] Unable to parse certificate details"
else
    echo "[WARNING] ⚠ No SEP2 certificates found!"
    echo "[WARNING] To enable CSIP-AUS, place certificates in:"
    echo "[WARNING]   ${CERT_DIR}/sep2-cert.pem"
    echo "[WARNING]   ${CERT_DIR}/sep2-key.pem"
    echo "[WARNING] See add-on documentation for instructions"
    
    # Create placeholder files so ODE doesn't crash
    echo "# SEP2 Certificate Placeholder" > "${ODE_CONFIG_DIR}/sep2-cert.pem"
    echo "# SEP2 Key Placeholder" > "${ODE_CONFIG_DIR}/sep2-key.pem"
    echo "[INFO] Created placeholder certificate files"
fi

# Set environment variables
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
echo "[INFO] LOG_LEVEL: ${LOG_LEVEL}"
echo "[INFO] CONFIG_PATH: ${CONFIG_PATH}"
echo "[INFO] SEP2_CERT_FILE: ${SEP2_CERT_FILE}"
echo "[INFO] SEP2_KEY_FILE: ${SEP2_KEY_FILE}"
echo "[INFO] SERVER_HOST:PORT: ${SERVER_HOST}:${SERVER_PORT}"
echo "[INFO] =========================================="
echo "[INFO] Starting ODE Backend"
echo "[INFO] =========================================="

# Start ODE
cd /ode
exec node dist/src/app.js
