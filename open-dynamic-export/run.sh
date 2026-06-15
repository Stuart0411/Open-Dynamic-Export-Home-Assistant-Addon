#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] =========================================="
echo "[INFO] Open Dynamic Export (HA Add-on)"
echo "[INFO] =========================================="

mkdir -p /data

# ---------------------------
# Write config.json from add-on options
# ---------------------------
CONFIG_JSON="$(jq -r '.config_file // empty' /data/options.json)"

if [ -z "${CONFIG_JSON}" ] || [ "${CONFIG_JSON}" = "null" ]; then
  echo "[ERROR] config_file option is empty. Please set config_file in the add-on configuration."
  exit 1
fi

echo "${CONFIG_JSON}" > /data/config.json
echo "[INFO] Configuration written to /data/config.json"

# ---------------------------
# Certificate handling (optional)
# ---------------------------
# User-provided paths are relative to /config (HA /homeassistant)
SEP2_CERT_REL="$(jq -r '.sep2_cert_path // "ode/sep2-cert.pem"' /data/options.json)"
SEP2_KEY_REL="$(jq -r '.sep2_key_path  // "ode/sep2-key.pem"' /data/options.json)"

SEP2_CERT_REL="${SEP2_CERT_REL#/}"
SEP2_KEY_REL="${SEP2_KEY_REL#/}"

SEP2_CERT_SRC="/config/${SEP2_CERT_REL}"
SEP2_KEY_SRC="/config/${SEP2_KEY_REL}"
SEP2_CA_SRC="/config/ode/serca.pem"

ODE_CERT_DIR="/data/ode/config"
mkdir -p "${ODE_CERT_DIR}"

echo "[INFO] =========================================="
echo "[INFO] Certificate Setup"
echo "[INFO] =========================================="
echo "[INFO] Looking for cert: ${SEP2_CERT_SRC}"
echo "[INFO] Looking for key : ${SEP2_KEY_SRC}"
echo "[INFO] Looking for CA  : ${SEP2_CA_SRC}"
echo "[INFO] Dest dir        : ${ODE_CERT_DIR}"

if [ -f "${SEP2_CERT_SRC}" ] && [ -f "${SEP2_KEY_SRC}" ]; then
  cp "${SEP2_CERT_SRC}" "${ODE_CERT_DIR}/sep2-cert.pem"
  cp "${SEP2_KEY_SRC}"  "${ODE_CERT_DIR}/sep2-key.pem"
  echo "[INFO] ✓ SEP2 cert/key copied into ${ODE_CERT_DIR}"
  # Best-effort print certificate info
  openssl x509 -in "${ODE_CERT_DIR}/sep2-cert.pem" -noout -subject -dates 2>/dev/null || true
else
  echo "[WARNING] ⚠ SEP2 cert/key not found. CSIP-AUS features may not work until certs are provided."
fi

if [ -f "${SEP2_CA_SRC}" ]; then
  cp "${SEP2_CA_SRC}" "${ODE_CERT_DIR}/serca.pem"
  echo "[INFO] ✓ CA certificate copied to ${ODE_CERT_DIR}/serca.pem"
else
  echo "[WARNING] serca.pem not found (optional, but recommended for TLS validation)."
fi

# ---------------------------
# Environment for ODE
# ---------------------------

export TZ="$(jq -r '.tz // "Australia/Sydney"' /data/options.json)"

export LOG_LEVEL="$(jq -r '.log_level // "info"' /data/options.json)"
export CONFIG_PATH="/data/config.json"
export CONFIG_DIR="/data"

export SERVER_HOST="0.0.0.0"
export SERVER_PORT="3000"

export SEP2_CERT_FILE="ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="ode/config/sep2-key.pem"
export SEP2_PEN="$(jq -r '.sep2_pen // "12345"' /data/options.json)"

# Trust the SERCA CA if present
if [ -f "${ODE_CERT_DIR}/serca.pem" ]; then
  export NODE_EXTRA_CA_CERTS="${ODE_CERT_DIR}/serca.pem"
fi

# ---------------------------
# Optional InfluxDB integration
# ---------------------------
# Pass through INFLUXDB_* environment variables when influxdb_host is set.
# When unset, ODE skips InfluxDB logging (the data-history endpoints of the
# web UI will return "InfluxDB isn't available", which is harmless).
INFLUXDB_HOST_OPT="$(jq -r '.influxdb_host // ""' /data/options.json)"
if [ -n "${INFLUXDB_HOST_OPT}" ]; then
  export INFLUXDB_HOST="${INFLUXDB_HOST_OPT}"
  export INFLUXDB_PORT="$(jq -r '.influxdb_port // "8086"' /data/options.json)"
  export INFLUXDB_USERNAME="$(jq -r '.influxdb_username // ""' /data/options.json)"
  export INFLUXDB_PASSWORD="$(jq -r '.influxdb_password // ""' /data/options.json)"
  export INFLUXDB_ADMIN_TOKEN="$(jq -r '.influxdb_admin_token // ""' /data/options.json)"
  export INFLUXDB_ORG="$(jq -r '.influxdb_org // "open-dynamic-export"' /data/options.json)"
  export INFLUXDB_BUCKET="$(jq -r '.influxdb_bucket // "data"' /data/options.json)"
  echo "[INFO] InfluxDB logging enabled (host=${INFLUXDB_HOST}:${INFLUXDB_PORT}, org=${INFLUXDB_ORG}, bucket=${INFLUXDB_BUCKET})"
else
  echo "[INFO] InfluxDB logging disabled (influxdb_host option is empty)"
fi

export NODE_ENV=production

echo "[INFO] =========================================="
echo "[INFO] Environment"
echo "[INFO] =========================================="
echo "[INFO] LOG_LEVEL         : ${LOG_LEVEL}"
echo "[INFO] CONFIG_PATH       : ${CONFIG_PATH}"
echo "[INFO] SERVER            : ${SERVER_HOST}:${SERVER_PORT}"
echo "[INFO] SEP2_CERT_FILE    : ${SEP2_CERT_FILE}"
echo "[INFO] SEP2_KEY_FILE     : ${SEP2_KEY_FILE}"
echo "[INFO] SEP2_PEN          : ${SEP2_PEN}"
echo "[INFO] NODE_EXTRA_CA_CERTS: ${NODE_EXTRA_CA_CERTS:-<not set>}"
echo "[INFO] INFLUXDB_HOST     : ${INFLUXDB_HOST:-<not set>}"

cd /ode
exec pnpm start
