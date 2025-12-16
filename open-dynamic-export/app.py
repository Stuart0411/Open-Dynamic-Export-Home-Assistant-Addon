#!/usr/bin/env python3
import os
import re
import mimetypes
import requests
from flask import Flask, send_file, request, jsonify, Response
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

# Initialize mimetypes
mimetypes.init()
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('text/css', '.css')

# ODE backend API
ODE_API = "http://localhost:3000"

# Path to React UI build
ODE_UI_PATH = "/ode/dist/ui"

# -------------------------------
# Serve React UI (SPA)
# -------------------------------
@app.route('/')
def serve_index():
    """
    Serve index.html with rewritten asset paths for Ingress.
    """
    ingress_path = request.headers.get('X-Ingress-Path', '')
    print(f"[DEBUG] Serving index.html, Ingress-Path: '{ingress_path}'")
    
    index_path = os.path.join(ODE_UI_PATH, 'index.html')
    
    if not os.path.exists(index_path):
        return jsonify({
            "error": "UI not found", 
            "path": index_path
        }), 404
    
    with open(index_path, 'r') as f:
        html = f.read()
    
    # Rewrite asset paths to include ingress prefix
    if ingress_path and ingress_path != '/':
        # Add base tag
        base_tag = f'<base href="{ingress_path}/">'
        html = html.replace('<head>', f'<head>\n    {base_tag}')
        
        # Rewrite absolute asset paths to relative
        html = re.sub(r'href="(/[^"]+)"', rf'href="{ingress_path}\1"', html)
        html = re.sub(r'src="(/[^"]+)"', rf'src="{ingress_path}\1"', html)
        
        print(f"[DEBUG] Rewrote paths with ingress prefix: {ingress_path}")
    
    return Response(html, mimetype='text/html')

@app.route('/assets/<path:filename>')
def serve_assets(filename):
    """
    Serve assets with correct MIME types.
    """
    file_path = os.path.join(ODE_UI_PATH, 'assets', filename)
    print(f"[DEBUG] Serving asset: /assets/{filename}")
    
    if not os.path.exists(file_path):
        print(f"[ERROR] Asset not found: {file_path}")
        return jsonify({"error": f"Asset not found: {filename}"}), 404
    
    # Guess MIME type
    mime_type, _ = mimetypes.guess_type(filename)
    if not mime_type:
        if filename.endswith('.js'):
            mime_type = 'application/javascript'
        elif filename.endswith('.css'):
            mime_type = 'text/css'
        elif filename.endswith('.json'):
            mime_type = 'application/json'
        else:
            mime_type = 'application/octet-stream'
    
    print(f"[DEBUG] Serving {filename} as {mime_type}")
    
    return send_file(file_path, mimetype=mime_type)

@app.route('/<path:path>')
def serve_static(path):
    """
    Serve other static files or SPA routes.
    """
    print(f"[DEBUG] Request for: /{path}")
    
    file_path = os.path.join(ODE_UI_PATH, path)
    
    # If file exists, serve it
    if os.path.exists(file_path) and os.path.isfile(file_path):
        mime_type, _ = mimetypes.guess_type(path)
        print(f"[DEBUG] Serving file: {path} as {mime_type}")
        return send_file(file_path, mimetype=mime_type)
    
    # Otherwise, serve index for SPA routing
    print(f"[DEBUG] SPA route, serving index.html")
    return serve_index()

# -------------------------------
# API Proxy Routes
# -------------------------------
@app.route('/coordinator/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
@app.route('/sep2/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
@app.route('/docs', methods=['GET'])
@app.route('/docs/<path:path>', methods=['GET'])
def proxy_api(path=''):
    """
    Proxy API requests to ODE backend.
    """
    try:
        route_prefix = request.path.split('/')[1]
        if path:
            url = f"{ODE_API}/{route_prefix}/{path}"
        else:
            url = f"{ODE_API}/{route_prefix}"
        
        print(f"[DEBUG] Proxying {request.method} {url}")
        
        if request.method == 'GET':
            response = requests.get(url, params=request.args, timeout=10)
        elif request.method == 'POST':
            response = requests.post(url, json=request.json, timeout=10)
        elif request.method == 'PUT':
            response = requests.put(url, json=request.json, timeout=10)
        elif request.method == 'DELETE':
            response = requests.delete(url, timeout=10)
        
        try:
            data = response.json()
            return jsonify(data), response.status_code
        except:
            return response.content, response.status_code, {
                'Content-Type': response.headers.get('Content-Type', 'text/plain')
            }
    except requests.exceptions.ConnectionError as e:
        print(f"[ERROR] Connection error: {e}")
        return jsonify({"error": "ODE backend not available"}), 502
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}")
        return jsonify({"error": str(e)}), 500

# -------------------------------
# Health Check
# -------------------------------
@app.route('/health')
def health():
    try:
        response = requests.get(f"{ODE_API}/coordinator/status", timeout=3)
        if response.ok:
            return jsonify({"status": "ok", "ode": "running"})
        return jsonify({"status": "degraded"}), 503
    except:
        return jsonify({"status": "error"}), 503

# -------------------------------
# Start Flask App
# -------------------------------
if __name__ == '__main__':
    port = int(os.getenv("INGRESS_PORT", 8099))
    print(f"[INFO] Starting ODE Ingress Web Interface on port {port}")
    print(f"[INFO] UI Path: {ODE_UI_PATH}")
    print(f"[INFO] ODE API: {ODE_API}")
    
    if os.path.exists(ODE_UI_PATH):
        print(f"[INFO] UI directory found")
        if os.path.exists(os.path.join(ODE_UI_PATH, 'assets')):
            print(f"[INFO] Assets directory found")
    else:
        print(f"[ERROR] UI directory not found at {ODE_UI_PATH}")
    
    app.run(host='0.0.0.0', port=port, debug=False)
