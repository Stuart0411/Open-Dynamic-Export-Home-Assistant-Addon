#!/usr/bin/env bash
set -e

echo "[INFO] =========================================="
echo "[INFO] Open Dynamic Export Add-on v2.4.3-beta"
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
SEP2_CERT_REL=$(cat /data/options.json | jq -r '.sep2_cert_path // "ode/sep2-cert.pem"')
SEP2_KEY_REL=$(cat /data/options.json  | jq -r '.sep2_key_path  // "ode/sep2-key.pem"')
SEP2_CERT_REL="${SEP2_CERT_REL#/}"
SEP2_KEY_REL="${SEP2_KEY_REL#/}"
SEP2_CERT_SRC="/config/${SEP2_CERT_REL}"
SEP2_KEY_SRC="/config/${SEP2_KEY_REL}"
SEP2_CA_SRC="/config/ode/serca.pem"
ODE_CONFIG_DIR="/data/ode/config"
mkdir -p "${ODE_CONFIG_DIR}"

echo "[INFO] =========================================="
echo "[INFO] Certificate Setup"
echo "[INFO] =========================================="

if [ -f "${SEP2_CERT_SRC}" ] && [ -f "${SEP2_KEY_SRC}" ]; then
    echo "[INFO] ✓ Found SEP2 certificates"
    cp "${SEP2_CERT_SRC}" "${ODE_CONFIG_DIR}/sep2-cert.pem"
    cp "${SEP2_KEY_SRC}"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    openssl x509 -in "${ODE_CONFIG_DIR}/sep2-cert.pem" -noout -subject -dates 2>/dev/null \
        || echo "[WARNING] Unable to parse certificate"
else
    echo "[WARNING] ⚠ SEP2 certificates not found — using placeholders"
    if [ -f "/data/certs/sep2-cert.pem" ] && [ -f "/data/certs/sep2-key.pem" ]; then
        cp "/data/certs/sep2-cert.pem" "${ODE_CONFIG_DIR}/sep2-cert.pem"
        cp "/data/certs/sep2-key.pem"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    else
        echo "# Placeholder" > "${ODE_CONFIG_DIR}/sep2-cert.pem"
        echo "# Placeholder" > "${ODE_CONFIG_DIR}/sep2-key.pem"
    fi
fi

if [ -f "${SEP2_CA_SRC}" ]; then
    cp "${SEP2_CA_SRC}" "${ODE_CONFIG_DIR}/serca.pem"
    echo "[INFO] ✓ CA certificate copied"
fi

# -------------------------------------------------------
# Ingress path resolution
# -------------------------------------------------------
# Ask the HA Supervisor for the ingress entry path for this addon.
# This is the URL prefix HA uses to proxy requests to us, e.g.
#   /api/hassio_ingress/abc123def456
# We bake this into the nginx config so it can inject the correct
# <base href="..."> into every index.html response.
echo "[INFO] =========================================="
echo "[INFO] Resolving Ingress Path"
echo "[INFO] =========================================="

INGRESS_PATH=""
if SUPERVISOR_RESPONSE=$(curl -sf \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        "http://supervisor/addons/self/info" 2>/dev/null); then
    INGRESS_PATH=$(echo "${SUPERVISOR_RESPONSE}" | jq -r '.data.ingress_entry // ""')
    echo "[INFO] Ingress path from Supervisor: ${INGRESS_PATH}"
else
    echo "[WARNING] Could not reach Supervisor API — ingress <base> tag will be empty"
    echo "[WARNING] Direct port access may still work; ingress UI may not load assets correctly"
fi

# Export for envsubst
export INGRESS_PATH

# Generate the nginx config from the template, substituting the real ingress path
envsubst '${INGRESS_PATH}' \
    < /etc/nginx/ingress.conf.template \
    > /etc/nginx/http.d/ingress.conf

echo "[INFO] nginx config written with INGRESS_PATH=${INGRESS_PATH}"

# -------------------------------------------------------
# Environment for ODE
# -------------------------------------------------------
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="127.0.0.1"   # ODE only needs to be reachable by nginx locally
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="ode/config/sep2-key.pem"
export SEP2_PEN=$(cat /data/options.json | jq -r '.sep2_pen // "12345"')
export NODE_EXTRA_CA_CERTS="${ODE_CONFIG_DIR}/serca.pem"

echo "[INFO] =========================================="
echo "[INFO] Environment Configuration"
echo "[INFO] =========================================="
echo "[INFO] LOG_LEVEL:    ${LOG_LEVEL}"
echo "[INFO] SERVER_HOST:  ${SERVER_HOST}:${SERVER_PORT}  (nginx proxies → 8099)"
echo "[INFO] SEP2_PEN:     ${SEP2_PEN}"

# -------------------------------------------------------
# Start nginx (ingress proxy on port 8099)
# -------------------------------------------------------
echo "[INFO] =========================================="
echo "[INFO] Starting nginx (ingress on :8099)"
echo "[INFO] =========================================="
nginx -g "daemon off;" &
NGINX_PID=$!

# Give nginx a moment to bind
sleep 1
if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
    echo "[ERROR] nginx failed to start — check config above"
    exit 1
fi
echo "[INFO] ✓ nginx started (PID ${NGINX_PID})"

# -------------------------------------------------------
# Start ODE
# -------------------------------------------------------
echo "[INFO] =========================================="
echo "[INFO] Starting ODE Backend"
echo "[INFO] =========================================="
cd /ode

# If nginx exits unexpectedly, kill ODE too (and vice versa)
trap 'kill ${NGINX_PID} 2>/dev/null; exit' TERM INT

exec node dist/src/app.js
