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

# Get dynamic ingress port (critical!)
export INGRESS_PORT=${INGRESS_PORT:-8099}

echo "[INFO] ODE Backend will listen on: 127.0.0.1:3000"
echo "[INFO] Flask UI will listen on: 0.0.0.0:${INGRESS_PORT}"

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

# Wait a moment for Flask to start
sleep 2

# Check if Flask started
if ! ps -p $WEB_PID > /dev/null; then
    echo "[ERROR] Flask failed to start!"
    echo "[ERROR] Flask logs:"
    cat /tmp/flask.log
    exit 1
fi

echo "[INFO] =========================================="
echo "[INFO] All services started successfully!"
echo "[INFO] ODE Backend PID: $ODE_PID"
echo "[INFO] Flask UI PID: $WEB_PID"
echo "[INFO] Flask listening on port: ${INGRESS_PORT}"
echo "[INFO] =========================================="

# Function to cleanup on exit
cleanup() {
    echo "[INFO] Shutting down services..."
    kill $ODE_PID $WEB_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep script running and show logs
echo "[INFO] Tailing logs (Ctrl+C to stop)..."
tail -f /tmp/ode.log /tmp/flask.log &
TAIL_PID=$!

# Wait for processes
wait $ODE_PID $WEB_PID

# If we get here, a process died
echo "[ERROR] A service has stopped unexpectedly!"
echo "[ERROR] ODE logs:"
cat /tmp/ode.log
echo "[ERROR] Flask logs:"
cat /tmp/flask.log
exit 1
