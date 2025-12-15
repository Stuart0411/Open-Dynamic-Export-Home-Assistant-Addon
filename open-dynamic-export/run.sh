
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
export SERVER_HOST="0.0.0.0"   # Changed from 127.0.0.1 for better compatibility
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="/ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="/ode/config/sep2-key.pem"
export SEP2_PEN="12345"

echo "[INFO] Starting ODE backend on port ${SERVER_PORT}..."
cd /ode
node dist/src/app.js &
ODE_PID=$!

# Wait for ODE to start
echo "[INFO] Waiting for ODE backend to be ready..."
RETRIES=0
MAX_RETRIES=30
until curl -s http://localhost:${SERVER_PORT}/coordinator/status > /dev/null 2>&1; do
  RETRIES=$((RETRIES+1))
  if [ $RETRIES -ge $MAX_RETRIES ]; then
    echo "[ERROR] ODE backend failed to start after ${MAX_RETRIES} seconds"
    break
  fi
  echo "[INFO] Waiting... (${RETRIES}/${MAX_RETRIES})"
  sleep 1
done

echo "[INFO] ODE backend is ready!"

# Start Ingress web interface
echo "[INFO] Starting Ingress web interface on port ${INGRESS_PORT:-8099}..."
cd /app
export INGRESS_PORT=${INGRESS_PORT:-8099}
python3 app.py &
WEB_PID=$!

echo "[INFO] =========================================="
echo "[INFO] All services started successfully"
echo "[INFO] ODE Backend: http://localhost:${SERVER_PORT}"
echo "[INFO] Web Interface: Ingress managed by Home Assistant"
echo "[INFO] =========================================="

# Wait for both processes
wait $ODE_PID $WEB_PID
