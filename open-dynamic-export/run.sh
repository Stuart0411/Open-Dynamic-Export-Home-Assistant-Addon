#!/usr/bin/env bash
set -e

echo "[INFO] =========================================="
echo "[INFO] Open Dynamic Export Add-on v2.4.5-beta"
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
# ODE resolves cert paths as: CONFIG_DIR + "/" + SEP2_CERT_FILE
# So SEP2_CERT_FILE must be RELATIVE (no leading /data/).
# We copy user-supplied certs from /config (= /homeassistant
# in File Editor) into /data/ode/config/ so ODE can find them.
# -------------------------------------------------------

# Read user-configured paths from addon options (relative to /config)
SEP2_CERT_REL=$(cat /data/options.json | jq -r '.sep2_cert_path // "ode/sep2-cert.pem"')
SEP2_KEY_REL=$(cat /data/options.json  | jq -r '.sep2_key_path  // "ode/sep2-key.pem"')

# Strip any accidental leading slash
SEP2_CERT_REL="${SEP2_CERT_REL#/}"
SEP2_KEY_REL="${SEP2_KEY_REL#/}"

# Full source paths (from the HA config folder)
SEP2_CERT_SRC="/config/${SEP2_CERT_REL}"
SEP2_KEY_SRC="/config/${SEP2_KEY_REL}"

# CA cert — server root CA (fixed name, must be in /homeassistant/ode/)
SEP2_CA_SRC="/config/ode/serca.pem"

# Destination: /data/ode/config/ — ODE prepends /data/ to the relative env vars below
ODE_CONFIG_DIR="/data/ode/config"
mkdir -p "${ODE_CONFIG_DIR}"

echo "[INFO] =========================================="
echo "[INFO] Certificate Setup"
echo "[INFO] =========================================="
echo "[INFO] Looking for cert  : ${SEP2_CERT_SRC}"
echo "[INFO] Looking for key   : ${SEP2_KEY_SRC}"
echo "[INFO] Looking for CA    : ${SEP2_CA_SRC}"
echo "[INFO] ODE config dir    : ${ODE_CONFIG_DIR}"

if [ -f "${SEP2_CERT_SRC}" ] && [ -f "${SEP2_KEY_SRC}" ]; then
    echo "[INFO] ✓ Found SEP2 certificates"
    cp "${SEP2_CERT_SRC}" "${ODE_CONFIG_DIR}/sep2-cert.pem"
    cp "${SEP2_KEY_SRC}"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    echo "[INFO] ✓ Certificates copied to ${ODE_CONFIG_DIR}"

    echo "[INFO] Certificate details:"
    openssl x509 -in "${ODE_CONFIG_DIR}/sep2-cert.pem" -noout -subject -dates 2>/dev/null \
        || echo "[WARNING] Unable to parse certificate — check the file is a valid PEM"
else
    echo "[WARNING] ⚠ SEP2 certificates not found!"
    echo "[WARNING] Place your certificates at (using File Editor or SSH):"
    echo "[WARNING]   /homeassistant/${SEP2_CERT_REL}  (rename from fullchain.pem)"
    echo "[WARNING]   /homeassistant/${SEP2_KEY_REL}   (rename from key.pem)"
    echo "[WARNING] Or change the paths on the add-on Configuration page."

    # Fallback: legacy /data/certs location from older installs
    if [ -f "/data/certs/sep2-cert.pem" ] && [ -f "/data/certs/sep2-key.pem" ]; then
        echo "[INFO] Found legacy certs in /data/certs — using as fallback"
        cp "/data/certs/sep2-cert.pem" "${ODE_CONFIG_DIR}/sep2-cert.pem"
        cp "/data/certs/sep2-key.pem"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    else
        echo "# Placeholder — replace with real cert" > "${ODE_CONFIG_DIR}/sep2-cert.pem"
        echo "# Placeholder — replace with real key"  > "${ODE_CONFIG_DIR}/sep2-key.pem"
        echo "[INFO] Created placeholder certificate files"
    fi
fi

# Copy server CA certificate if present
if [ -f "${SEP2_CA_SRC}" ]; then
    cp "${SEP2_CA_SRC}" "${ODE_CONFIG_DIR}/serca.pem"
    echo "[INFO] ✓ CA certificate (serca.pem) copied to ${ODE_CONFIG_DIR}"
else
    echo "[WARNING] serca.pem not found at ${SEP2_CA_SRC}"
    echo "[WARNING] TLS verification of the server may fail."
    echo "[WARNING] Place serca.pem in /homeassistant/ode/"
fi

# -------------------------------------------------------
# Environment
# NOTE: SEP2_CERT_FILE and SEP2_KEY_FILE must be RELATIVE.
# ODE prepends CONFIG_DIR (/data) to these paths internally.
# NODE_EXTRA_CA_CERTS tells Node.js to trust the server CA.
# SEP2_PEN is your inverter vendor's IANA Private Enterprise Number.
# -------------------------------------------------------
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="0.0.0.0"
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="ode/config/sep2-key.pem"
export SEP2_PEN=$(cat /data/options.json | jq -r '.sep2_pen // "12345"')
export NODE_EXTRA_CA_CERTS="${ODE_CONFIG_DIR}/serca.pem"

# -------------------------------------------------------
# InfluxDB (optional)
# -------------------------------------------------------
# The HA InfluxDB v1 add-on uses username/password auth.
# Set influxdb_host, influxdb_port, influxdb_username, influxdb_password.
# Leave influxdb_admin_token, influxdb_org, influxdb_bucket blank for v1.
#
# InfluxDB v2 users: fill in all fields including token, org, and bucket.
#
# ODE reads these exact env var names from its environment:
#   INFLUXDB_HOST, INFLUXDB_PORT, INFLUXDB_USERNAME, INFLUXDB_PASSWORD,
#   INFLUXDB_ADMIN_TOKEN, INFLUXDB_ORG, INFLUXDB_BUCKET
# -------------------------------------------------------
INFLUXDB_ENABLED=$(cat /data/options.json | jq -r '.influxdb_enabled // false')

echo "[INFO] =========================================="
echo "[INFO] InfluxDB Configuration"
echo "[INFO] =========================================="

if [ "${INFLUXDB_ENABLED}" = "true" ]; then
    INFLUXDB_HOST=$(cat /data/options.json     | jq -r '.influxdb_host          // ""')
    INFLUXDB_PORT=$(cat /data/options.json     | jq -r '.influxdb_port          // "8086"')
    INFLUXDB_USERNAME=$(cat /data/options.json | jq -r '.influxdb_username      // ""')
    INFLUXDB_PASSWORD=$(cat /data/options.json | jq -r '.influxdb_password      // ""')
    INFLUXDB_ADMIN_TOKEN=$(cat /data/options.json | jq -r '.influxdb_admin_token // ""')
    INFLUXDB_ORG=$(cat /data/options.json      | jq -r '.influxdb_org           // ""')
    INFLUXDB_BUCKET=$(cat /data/options.json   | jq -r '.influxdb_bucket        // ""')
    INFLUXDB_DB=$(cat /data/options.json       | jq -r '.influxdb_db            // ""')    

    # host is always required
    if [ -z "${INFLUXDB_HOST}" ]; then
        echo "[ERROR] influxdb_host is required when influxdb_enabled is true."
        echo "[ERROR] For the HA InfluxDB add-on, use its IP address or hostname (e.g. a0d7b954-influxdb)."
        exit 1
    fi

    # Determine auth mode and validate accordingly
    if [ -n "${INFLUXDB_ADMIN_TOKEN}" ]; then
        # Token auth (InfluxDB v2)
        echo "[INFO] InfluxDB auth mode  : token (v2)"
        if [ -z "${INFLUXDB_ORG}" ] || [ -z "${INFLUXDB_BUCKET}" ]; then
            echo "[ERROR] influxdb_org and influxdb_bucket are required when using token auth."
            exit 1
        fi
    else
        # Username/password auth (InfluxDB v1 — HA add-on default)
        echo "[INFO] InfluxDB auth mode  : username/password (v1)"
        if [ -z "${INFLUXDB_USERNAME}" ] || [ -z "${INFLUXDB_PASSWORD}" ]; then
            echo "[ERROR] influxdb_username and influxdb_password are required when not using a token."
            echo "[ERROR] Find these in the HA InfluxDB add-on configuration."
            exit 1
        fi
    fi

    export INFLUXDB_HOST
    export INFLUXDB_PORT
    export INFLUXDB_USERNAME
    export INFLUXDB_PASSWORD
    export INFLUXDB_ADMIN_TOKEN
    export INFLUXDB_ORG
    export INFLUXDB_BUCKET
    export INFLUXDB_DB

    echo "[INFO] InfluxDB logging    : ENABLED"
    echo "[INFO] INFLUXDB_HOST       : ${INFLUXDB_HOST}"
    echo "[INFO] INFLUXDB_PORT       : ${INFLUXDB_PORT}"
    echo "[INFO] INFLUXDB_USERNAME   : ${INFLUXDB_USERNAME}"
    echo "[INFO] INFLUXDB_PASSWORD   : (set, not shown)"
    echo "[INFO] INFLUXDB_ADMIN_TOKEN: $([ -n "${INFLUXDB_ADMIN_TOKEN}" ] && echo "(set, not shown)" || echo "(not set)")"
    echo "[INFO] INFLUXDB_ORG        : ${INFLUXDB_ORG}"
    echo "[INFO] INFLUXDB_BUCKET     : ${INFLUXDB_BUCKET}"
    echo "[INFO] INFLUXDB_DB         : ${INFLUXDB_DB}"
else
    echo "[INFO] InfluxDB logging    : DISABLED"
    echo "[INFO] Set influxdb_enabled: true on the Configuration page to enable."
fi

echo "[INFO] =========================================="
echo "[INFO] Environment Configuration"
echo "[INFO] =========================================="
echo "[INFO] LOG_LEVEL:              ${LOG_LEVEL}"
echo "[INFO] CONFIG_PATH:            ${CONFIG_PATH}"
echo "[INFO] SEP2_CERT_FILE:         ${CONFIG_DIR}/${SEP2_CERT_FILE}  (resolved by ODE)"
echo "[INFO] SEP2_KEY_FILE:          ${CONFIG_DIR}/${SEP2_KEY_FILE}   (resolved by ODE)"
echo "[INFO] SEP2_PEN:               ${SEP2_PEN}"
echo "[INFO] NODE_EXTRA_CA_CERTS:    ${NODE_EXTRA_CA_CERTS}"
echo "[INFO] SERVER_HOST:PORT:       ${SERVER_HOST}:${SERVER_PORT}"
echo "[INFO] =========================================="
echo "[INFO] Starting ODE Backend"
echo "[INFO] =========================================="

cd /ode
exec node dist/src/app.js
