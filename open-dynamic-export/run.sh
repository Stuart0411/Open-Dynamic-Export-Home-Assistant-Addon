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

# Debug: Show directory structure
echo "[INFO] Application directory structure:"
ls -la
if [ -d "dist/src" ]; then
    echo "[INFO] dist/src contents:"
    ls -la dist/src/
fi

# Try to find and run the entry point
if [ -f "dist/src/index.js" ]; then
    echo "[INFO] Starting from dist/src/index.js"
    exec node dist/src/index.js
elif [ -f "dist/index.js" ]; then
    echo "[INFO] Starting from dist/index.js"
    exec node dist/index.js
else
    echo "[ERROR] Cannot find application entry point"
    echo "[ERROR] Searching for JavaScript files:"
    find /app -type f -name "*.js" | head -20
    exit 1
fi
