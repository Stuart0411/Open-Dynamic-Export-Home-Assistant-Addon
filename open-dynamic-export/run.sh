#!/usr/bin/env bash
set -e

echo "[INFO] =========================================="
echo "[INFO] Open Dynamic Export Starting"
echo "[INFO] =========================================="

# Create data directory
mkdir -p /data

# Write config file
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json
echo "[INFO] Configuration written to /data/config.json"

# Set environment variables for ODE
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="127.0.0.1"  # Only listen on localhost
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="/ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="/ode/config/sep2-key.pem"
export SEP2_PEN="12345"

echo "[INFO] Starting ODE backend on port 3000..."
cd /ode
node dist/src/app.js &
ODE_PID=$!

# Wait for ODE to start
echo "[INFO] Waiting for ODE backend to be ready..."
RETRIES=0
MAX_RETRIES=30
until curl -s http://localhost:3000/coordinator/status > /dev/null 2>&1; do
    RETRIES=$((RETRIES+1))
    if [ $RETRIES -ge $MAX_RETRIES ]; then
        echo "[ERROR] ODE backend failed to start after ${MAX_RETRIES} seconds"
        echo "[ERROR] Checking if process is running..."
        ps aux | grep node
        echo "[ERROR] Attempting to fetch status anyway..."
        curl -v http://localhost:3000/coordinator/status || true
        break
    fi
    echo "[INFO] Waiting... (${RETRIES}/${MAX_RETRIES})"
    sleep 1
done

if [ $RETRIES -lt $MAX_RETRIES ]; then
    echo "[INFO] ODE backend is ready!"
else
    echo "[WARNING] Continuing anyway - ODE might still be starting..."
fi

echo "[INFO] Starting Ingress web interface on port 8099..."
cd /app
python3 app.py &
WEB_PID=$!

echo "[INFO] =========================================="
echo "[INFO] All services started successfully"
echo "[INFO] ODE Backend: http://localhost:3000"
echo "[INFO] Web Interface: http://localhost:8099"
echo "[INFO] =========================================="

# Wait for both processes
wait $ODE_PID $WEB_PID
