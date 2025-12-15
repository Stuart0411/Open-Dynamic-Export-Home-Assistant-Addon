
#!/usr/bin/env bash
set -e

echo "[INFO] Starting Open Dynamic Export Add-on"

# Activate virtual environment
. /venv/bin/activate

# Start ODE backend
echo "[INFO] Starting ODE backend on port 3000"
cd /ode
node dist/src/app.js &
ODE_PID=$!

# Start Flask ingress UI
export INGRESS_PORT=${INGRESS_PORT:-8099}
echo "[INFO] Starting Flask on port $INGRESS_PORT"
python3 /app/app.py &
WEB_PID=$!

# Wait for both processes
wait $ODE_PID $WEB_PID

