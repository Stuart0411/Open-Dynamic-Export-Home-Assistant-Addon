#!/usr/bin/env bash
set -e

echo "[INFO] =========================================="
echo "[INFO] Open Dynamic Export Add-on v2.4.2"
echo "[INFO] =========================================="

# Create data directory
mkdir -p /data

# Write config file
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json
echo "[INFO] Configuration written to /data/config.json"

# -------------------------------------------------------
# Certificate Setup
# -------------------------------------------------------
SEP2_CERT_REL=$(cat /data/options.json | jq -r '.sep2_cert_path // "ode/sep2-cert.pem"')
SEP2_KEY_REL=$(cat /data/options.json  | jq -r '.sep2_key_path  // "ode/sep2-key.pem"')
SEP2_CERT_REL="${SEP2_CERT_REL#/}"
SEP2_KEY_REL="${SEP2_KEY_REL#/}"
SEP2_CERT_SRC="/config/${SEP2_CERT_REL}"
SEP2_KEY_SRC="/config/${SEP2_KEY_REL}"
SEP2_CA_SRC="/config/ode/serca.pem"
ODE_CONFIG_DIR="/data/ode/config"
mkdir -p "${ODE_CONFIG_DIR}"

echo "[INFO] =========================================="
echo "[INFO] Certificate Setup"
echo "[INFO] =========================================="

if [ -f "${SEP2_CERT_SRC}" ] && [ -f "${SEP2_KEY_SRC}" ]; then
    echo "[INFO] ✓ Found SEP2 certificates"
    cp "${SEP2_CERT_SRC}" "${ODE_CONFIG_DIR}/sep2-cert.pem"
    cp "${SEP2_KEY_SRC}"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    openssl x509 -in "${ODE_CONFIG_DIR}/sep2-cert.pem" -noout -subject -dates 2>/dev/null \
        || echo "[WARNING] Unable to parse certificate"
else
    echo "[WARNING] ⚠ SEP2 certificates not found — using placeholders"
    if [ -f "/data/certs/sep2-cert.pem" ] && [ -f "/data/certs/sep2-key.pem" ]; then
        cp "/data/certs/sep2-cert.pem" "${ODE_CONFIG_DIR}/sep2-cert.pem"
        cp "/data/certs/sep2-key.pem"  "${ODE_CONFIG_DIR}/sep2-key.pem"
    else
        echo "# Placeholder" > "${ODE_CONFIG_DIR}/sep2-cert.pem"
        echo "# Placeholder" > "${ODE_CONFIG_DIR}/sep2-key.pem"
    fi
fi

if [ -f "${SEP2_CA_SRC}" ]; then
    cp "${SEP2_CA_SRC}" "${ODE_CONFIG_DIR}/serca.pem"
    echo "[INFO] ✓ CA certificate copied"
fi

# Write a complete nginx.conf that includes mime.types at the http level.
# The HA base image's default nginx.conf may not include mime.types, causing
# all files to be served as text/plain regardless of extension.
cat > /etc/nginx/nginx.conf << 'NGINXEOF'
worker_processes auto;
pid /var/run/nginx/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile      on;
    keepalive_timeout 65;
    access_log    /dev/stdout;
    error_log     /dev/stderr warn;

    server {
        listen 8099;
        server_name _;

        allow 172.30.32.2;
        deny all;

        root /ode/dist/ui;

        # Static assets — served directly by nginx
        location /assets/ {
            try_files $uri =404;
            add_header Cache-Control "public, max-age=31536000, immutable";
        }

        # ODE backend API — proxied to Node.js
        location /api/ {
            proxy_pass         http://127.0.0.1:3000;
            proxy_http_version 1.1;
            proxy_set_header   Host              $host;
            proxy_set_header   X-Real-IP         $remote_addr;
            proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header   X-Ingress-Path    $http_x_ingress_path;
            proxy_set_header   Upgrade           $http_upgrade;
            proxy_set_header   Connection        "upgrade";
            proxy_buffering    off;
            proxy_read_timeout 300s;
        }

        # SPA fallback
        location / {
            try_files $uri /index.html;
            add_header Cache-Control "no-cache, no-store, must-revalidate";
        }
    }
}
NGINXEOF
echo "[INFO] nginx.conf written"

# -------------------------------------------------------
# Environment for ODE
# -------------------------------------------------------
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="127.0.0.1"   # ODE only needs to be reachable by nginx locally
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="ode/config/sep2-key.pem"
export SEP2_PEN=$(cat /data/options.json | jq -r '.sep2_pen // "12345"')
export NODE_EXTRA_CA_CERTS="${ODE_CONFIG_DIR}/serca.pem"

echo "[INFO] =========================================="
echo "[INFO] Environment Configuration"
echo "[INFO] =========================================="
echo "[INFO] LOG_LEVEL:    ${LOG_LEVEL}"
echo "[INFO] SERVER_HOST:  ${SERVER_HOST}:${SERVER_PORT}  (nginx proxies → 8099)"
echo "[INFO] SEP2_PEN:     ${SEP2_PEN}"

# -------------------------------------------------------
# Start nginx (ingress proxy on port 8099)
# -------------------------------------------------------
echo "[INFO] =========================================="
echo "[INFO] Starting nginx (ingress on :8099)"
echo "[INFO] =========================================="
echo "[INFO] nginx configs in http.d/:"
ls -la /etc/nginx/http.d/ 2>/dev/null || echo "[INFO] (none)"
echo "[INFO] UI dist files:"
ls /ode/dist/ui/ 2>/dev/null || echo "[ERROR] /ode/dist/ui/ not found!"
echo "[INFO] UI assets:"
ls /ode/dist/ui/assets/ 2>/dev/null | head -5 || echo "[ERROR] No assets found"
nginx -t 2>&1 && echo "[INFO] nginx config OK"
nginx -g "daemon off;" &
NGINX_PID=$!

# Give nginx a moment to bind
sleep 1
if ! kill -0 "${NGINX_PID}" 2>/dev/null; then
    echo "[ERROR] nginx failed to start — check config above"
    exit 1
fi
echo "[INFO] ✓ nginx started (PID ${NGINX_PID})"

# -------------------------------------------------------
# Start ODE
# -------------------------------------------------------
echo "[INFO] =========================================="
echo "[INFO] Starting ODE Backend"
echo "[INFO] =========================================="

# If nginx exits unexpectedly, kill ODE too (and vice versa)
trap 'kill ${NGINX_PID} 2>/dev/null; exit' TERM INT

# Entry point confirmed from ODE's package.json: "start": "NODE_ENV=production node dist/app.js"
# Server TS (tsconfig.server.json) compiles src/ → dist/, so src/app.ts → dist/app.js
# Vite UI build outputs to dist/ui/ (separate from server output)
export NODE_ENV=production
exec node dist/app.js
