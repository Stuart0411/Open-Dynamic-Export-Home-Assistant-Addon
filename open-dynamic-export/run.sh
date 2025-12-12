#!/usr/bin/env bash
set -e

echo "[INFO] Starting Open Dynamic Export..."

# Create data directory
mkdir -p /data

# Get config from options
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json

echo "[INFO] Configuration written to /data/config.json"

# Set environment variables
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="0.0.0.0"

echo "[INFO] Log level: ${LOG_LEVEL}"
echo "[INFO] Config path: ${CONFIG_PATH}"
echo "[INFO] Server will listen on: ${SERVER_HOST}:${SERVER_PORT}"

# Change to app directory
cd /app

echo "[INFO] Checking for app.js..."
if [ -f "dist/src/app.js" ]; then
    echo "[INFO] Found dist/src/app.js - starting application"
    exec node dist/src/app.js
else
    echo "[ERROR] dist/src/app.js not found!"
    echo "[ERROR] Directory contents:"
    ls -la dist/src/
    exit 1
fi
