
#!/usr/bin/env bash
set -e

# Create data directory if it doesn't exist
mkdir -p /data

# Get config from options and write to file
echo "$(jq -r '.config_file' /data/options.json)" > /data/config.json

# Get log level
LOG_LEVEL=$(jq -r '.log_level // "info"' /data/options.json)
export LOG_LEVEL="${LOG_LEVEL}"

echo "[INFO] Starting Open Dynamic Export..."
echo "[INFO] Config file: /data/config.json"
echo "[INFO] Log level: ${LOG_LEVEL}"

# Start the application
cd /app
exec node dist/src/index.js
