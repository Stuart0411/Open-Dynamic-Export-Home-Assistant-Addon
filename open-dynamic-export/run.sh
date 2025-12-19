#!/usr/bin/env bash
set -e

echo "[INFO] Starting Open Dynamic Export"

# Write config
mkdir -p /data
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json

# Set ODE environment variables
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="127.0.0.1"
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="/ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="/ode/config/sep2-key.pem"
export SEP2_PEN="12345"

echo "[INFO] Starting ODE backend on port 3000..."
cd /ode
node dist/src/app.js &
ODE_PID=$!

# Wait for ODE
echo "[INFO] Waiting for ODE..."
for i in {1..30}; do
    if curl -s http://localhost:3000/coordinator/status > /dev/null 2>&1; then
        echo "[INFO] ODE is ready!"
        break
    fi
    sleep 1
done

echo "[INFO] Starting Nginx on port 8099..."
nginx -g 'daemon off;' &
NGINX_PID=$!

echo "[INFO] All services started"

# Cleanup on exit
trap "kill $ODE_PID $NGINX_PID 2>/dev/null" EXIT

wait $ODE_PID $NGINX_PID
