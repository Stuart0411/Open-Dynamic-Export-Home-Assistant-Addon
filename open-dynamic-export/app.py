
#!/usr/bin/env python3
import os
import requests
from flask import Flask, send_from_directory, request, jsonify
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

# ODE backend API
ODE_API = "http://localhost:3000"

# Path to React UI build
ODE_UI_PATH = "/ode/dist"

# -------------------------------
# Serve React UI (SPA)
# -------------------------------
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_ui(path):
    """
    Serve the React UI from /ode/dist.
    If the requested file exists, serve it.
    Otherwise, serve index.html for SPA routing.
    """
    full_path = os.path.join(ODE_UI_PATH, path)
    if path != "" and os.path.exists(full_path):
        return send_from_directory(ODE_UI_PATH, path)
    return send_from_directory(ODE_UI_PATH, 'index.html')

# -------------------------------
# API Proxy Routes
# -------------------------------
@app.route('/api/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def proxy_api(path):
    """
    Proxy API requests to ODE backend.
    """
    try:
        url = f"{ODE_API}/{path}"
        print(f"[DEBUG] Proxying {request.method} {url}")

        if request.method == 'GET':
            response = requests.get(url, params=request.args, timeout=10)
        elif request.method == 'POST':
            response = requests.post(url, json=request.json, timeout=10)
        elif request.method == 'PUT':
            response = requests.put(url, json=request.json, timeout=10)
        elif request.method == 'DELETE':
            response = requests.delete(url, timeout=10)

        # Return JSON if possible
        try:
            data = response.json()
            return jsonify(data), response.status_code
        except:
            return response.content, response.status_code, {
                'Content-Type': response.headers.get('Content-Type', 'text/plain')
            }
    except requests.exceptions.ConnectionError as e:
        return jsonify({"error": "ODE backend not available", "details": str(e)}), 502
    except requests.exceptions.Timeout as e:
        return jsonify({"error": "ODE backend timeout", "details": str(e)}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# -------------------------------
# Health Check
# -------------------------------
@app.route('/health')
def health():
    """
    Health check endpoint for HA supervisor.
    """
    try:
        response = requests.get(f"{ODE_API}/coordinator/status", timeout=3)
        if response.ok:
            return jsonify({"status": "ok", "ode": "running"})
        return jsonify({"status": "degraded", "ode": "error"}), 503
    except:
        return jsonify({"status": "error", "ode": "offline"}), 503

# -------------------------------
# Start Flask App
# -------------------------------
if __name__ == '__main__':
    port = int(os.getenv("INGRESS_PORT", 8099))  # Dynamic ingress port
    print(f"[INFO] Starting ODE Ingress Web Interface on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)

