#!/usr/bin/env python3
import os
import requests
from flask import Flask, render_template, request, jsonify
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)

# Fix for Ingress proxy headers
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

ODE_API = "http://localhost:3000"

@app.route('/')
def index():
    """Serve the main dashboard"""
    ingress_path = request.headers.get('X-Ingress-Path', '')
    return render_template('index.html', ingress_path=ingress_path)

@app.route('/api/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def proxy_api(path):
    """Proxy all API requests to ODE backend"""
    try:
        url = f"{ODE_API}/{path}"
        
        # Forward the request to ODE
        if request.method == 'GET':
            response = requests.get(url, params=request.args, timeout=10)
        elif request.method == 'POST':
            response = requests.post(url, json=request.json, timeout=10)
        elif request.method == 'PUT':
            response = requests.put(url, json=request.json, timeout=10)
        elif request.method == 'DELETE':
            response = requests.delete(url, timeout=10)
        
        return response.content, response.status_code, response.headers.items()
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "ODE backend not available"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        response = requests.get(f"{ODE_API}/coordinator/status", timeout=3)
        if response.ok:
            return jsonify({"status": "ok", "ode": "running"})
        return jsonify({"status": "degraded", "ode": "error"}), 503
    except:
        return jsonify({"status": "error", "ode": "offline"}), 503

if __name__ == '__main__':
    print("[INFO] Starting ODE Ingress Web Interface on port 8099")
    app.run(host='0.0.0.0', port=8099, debug=False)
