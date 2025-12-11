#!/usr/bin/env bash
set -e

echo "[INFO] Starting Open Dynamic Export..."

# Create data directory
mkdir -p /data

# Get config from options
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json

echo "[INFO] Configuration written to /data/config.json"

# Set log level
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"

echo "[INFO] Log level: ${LOG_LEVEL}"
echo "[INFO] Config path: ${CONFIG_PATH}"

# The pre-built image has the app in /app
cd /app

# Check what files exist
echo "[INFO] Application directory contents:"
ls -la

# Find and run the correct entry point
if [ -f "dist/index.js" ]; then
    echo "[INFO] Starting application from dist/index.js"
    exec node dist/index.js
elif [ -f "dist/src/index.js" ]; then
    echo "[INFO] Starting application from dist/src/index.js"
    exec node dist/src/index.js
elif [ -f "index.js" ]; then
    echo "[INFO] Starting application from index.js"
    exec node index.js
else
    echo "[ERROR] Cannot find application entry point"
    echo "[ERROR] Directory structure:"
    find /app -name "*.js" -type f
    exit 1
fi
