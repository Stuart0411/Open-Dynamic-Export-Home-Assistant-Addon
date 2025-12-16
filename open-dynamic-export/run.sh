#!/usr/bin/env bash
set -e

echo "[INFO] =========================================="
echo "[INFO] Open Dynamic Export Add-on Starting"
echo "[INFO] =========================================="

# Create data directory
mkdir -p /data

# Write config file
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json
echo "[INFO] Configuration written to /data/config.json"

# Set environment variables for ODE backend
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="127.0.0.1"
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="/ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="/ode/config/sep2-key.pem"
export SEP2_PEN="12345"

# CRITICAL: Read the actual ingress port set by Home Assistant
# Home Assistant sets this when ingress_port: 0 in config
if [ -z "$INGRESS_PORT" ]; then
    echo "[WARNING] INGRESS_PORT not set by supervisor, using default 8099"
    export INGRESS_PORT=8099
fi

echo "[INFO] ODE Backend will listen on: 127.0.0.1:3000"
echo "[INFO] Flask UI will listen on: 0.0.0.0:${INGRESS_PORT}"
echo "[INFO] INGRESS_PORT from environment: ${INGRESS_PORT}"

# Start ODE backend
echo "[INFO] Starting ODE backend..."
cd /ode
node dist/src/app.js > /tmp/ode.log 2>&1 &
ODE_PID=$!

# Wait for ODE to be ready
echo "[INFO] Waiting for ODE backend to start..."
RETRIES=0
MAX_RETRIES=30
until curl -s http://localhost:3000/coordinator/status > /dev/null 2>&1; do
    RETRIES=$((RETRIES+1))
    if [ $RETRIES -ge $MAX_RETRIES ]; then
        echo "[ERROR] ODE backend failed to start!"
        echo "[ERROR] ODE logs:"
        cat /tmp/ode.log
        exit 1
    fi
    sleep 1
done

echo "[INFO] ODE backend is ready!"

# Start Flask UI
echo "[INFO] Starting Flask UI on port ${INGRESS_PORT}..."
cd /app
python3 app.py > /tmp/flask.log 2>&1 &
WEB_PID=$!

# Wait for Flask to start (check if port is listening)
echo "[INFO] Waiting for Flask to start..."
sleep 3

# Check if Flask port is listening (BusyBox compatible)
if netstat -tln 2>/dev/null | grep -q ":${INGRESS_PORT}"; then
    echo "[INFO] Flask is listening on port ${INGRESS_PORT}"
elif ss -tln 2>/dev/null | grep -q ":${INGRESS_PORT}"; then
    echo "[INFO] Flask is listening on port ${INGRESS_PORT}"
else
    echo "[WARNING] Cannot verify Flask port, checking process..."
    if kill -0 $WEB_PID 2>/dev/null; then
        echo "[INFO] Flask process is running (PID: $WEB_PID)"
    else
        echo "[ERROR] Flask process died!"
        echo "[ERROR] Flask logs:"
        cat /tmp/flask.log
        exit 1
    fi
fi

echo "[INFO] =========================================="
echo "[INFO] All services started successfully!"
echo "[INFO] ODE Backend PID: $ODE_PID"
echo "[INFO] Flask UI PID: $WEB_PID"
echo "[INFO] Flask listening on: 0.0.0.0:${INGRESS_PORT}"
echo "[INFO] =========================================="

# Show initial logs
echo "[INFO] Recent Flask output:"
tail -n 10 /tmp/flask.log

# Function to cleanup on exit
cleanup() {
    echo "[INFO] Shutting down services..."
    kill $ODE_PID $WEB_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep script running and tail logs
tail -f /tmp/ode.log /tmp/flask.log &
wait $ODE_PID $WEB_PID
