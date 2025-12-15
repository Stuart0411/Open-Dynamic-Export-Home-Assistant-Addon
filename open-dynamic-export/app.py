#!/usr/bin/env python3
import os
import re
import requests
from flask import Flask, send_from_directory, request, jsonify, send_file
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

# ODE backend API
ODE_API = "http://localhost:3000"

# Path to React UI build
ODE_UI_PATH = "/ode/dist/ui"  # Note: ODE builds to dist/ui, not just dist

# -------------------------------
# Serve React UI (SPA)
# -------------------------------
@app.route('/')
def serve_index():
    """
    Serve index.html with injected base path for Ingress compatibility.
    """
    ingress_path = request.headers.get('X-Ingress-Path', '')
    
    index_path = os.path.join(ODE_UI_PATH, 'index.html')
    
    if not os.path.exists(index_path):
        return jsonify({"error": "UI not found", "path": index_path}), 404
    
    with open(index_path, 'r') as f:
        html = f.read()
    
    # Inject base tag for Ingress path
    if ingress_path:
        base_tag = f'<base href="{ingress_path}/">'
        html = html.replace('<head>', f'<head>\n    {base_tag}')
    
    return html, 200, {'Content-Type': 'text/html'}

@app.route('/<path:path>')
def serve_static(path):
    """
    Serve static assets from the UI build.
    """
    return send_from_directory(ODE_UI_PATH, path)

# -------------------------------
# API Proxy Routes
# -------------------------------
@app.route('/coordinator/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
@app.route('/sep2/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
@app.route('/docs/<path:path>', methods=['GET'])
def proxy_api(path):
    """
    Proxy API requests to ODE backend.
    Matches ODE's actual API routes.
    """
    try:
        # Reconstruct the full path including the route prefix
        route_prefix = request.path.split('/')[1]  # Get 'coordinator', 'sep2', or 'docs'
        url = f"{ODE_API}/{route_prefix}/{path}"
        
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
        print(f"[ERROR] Connection error: {e}")
        return jsonify({"error": "ODE backend not available", "details": str(e)}), 502
    except requests.exceptions.Timeout as e:
        print(f"[ERROR] Timeout: {e}")
        return jsonify({"error": "ODE backend timeout", "details": str(e)}), 504
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}")
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
    except Exception as e:
        print(f"[ERROR] Health check failed: {e}")
        return jsonify({"status": "error", "ode": "offline"}), 503

# -------------------------------
# Start Flask App
# -------------------------------
if __name__ == '__main__':
    port = int(os.getenv("INGRESS_PORT", 8099))
    print(f"[INFO] Starting ODE Ingress Web Interface on port {port}")
    print(f"[INFO] UI Path: {ODE_UI_PATH}")
    print(f"[INFO] ODE API: {ODE_API}")
    
    # Check if UI exists
    if os.path.exists(ODE_UI_PATH):
        print(f"[INFO] UI directory found")
    else:
        print(f"[ERROR] UI directory not found at {ODE_UI_PATH}")
    
    app.run(host='0.0.0.0', port=port, debug=False)
