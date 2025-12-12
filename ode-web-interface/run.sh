#!/usr/bin/env bash
set -e

echo "[INFO] Starting ODE Ingress Proxy..."

cd /app
exec node server.js
