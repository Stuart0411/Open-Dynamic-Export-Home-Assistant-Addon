#!/usr/bin/env python3
import os
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
ODE_UI_PATH = "/ode/dist/ui"

# -------------------------------
# Serve React UI
# -------------------------------
@app.route('/')
def serve_index():
    """Serve index.html"""
    ingress_path = request.headers.get('X-Ingress-Path', '')
    print(f"[INDEX] Ingress-Path: '{ingress_path}'")
    
    index_path = os.path.join(ODE_UI_PATH, 'index.html')
    
    if not os.path.exists(index_path):
        return jsonify({"error": "UI not found"}), 404
    
    with open(index_path, 'r') as f:
        html = f.read()
    
    # Add base tag if ingress path exists
    if ingress_path and ingress_path != '/':
        base_tag = f'<base href="{ingress_path}/">'
        html = html.replace('<head>', f'<head>\n    {base_tag}')
    
    return Response(html, mimetype='text/html')

@app.route('/assets/<path:filename>')
def serve_assets(filename):
    """Serve assets"""
    file_path = os.path.join(ODE_UI_PATH, 'assets', filename)
    
    if not os.path.exists(file_path):
        print(f"[ASSET 404] {filename}")
        return "Asset not found", 404
    
    mime_type, _ = mimetypes.guess_type(filename)
    if not mime_type:
        if filename.endswith('.js'):
            mime_type = 'application/javascript'
        elif filename.endswith('.css'):
            mime_type = 'text/css'
        else:
            mime_type = 'application/octet-stream'
    
    print(f"[ASSET] {filename} -> {mime_type}")
    return send_file(file_path, mimetype=mime_type)

# -------------------------------
# API Proxy - CATCH ALL API ROUTES
# -------------------------------
@app.route('/coordinator', methods=['GET'])
@app.route('/coordinator/', methods=['GET'])
@app.route('/coordinator/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])
def proxy_coordinator(path='status'):
    """Proxy coordinator API calls"""
    return proxy_to_ode('coordinator', path)

@app.route('/sep2', methods=['GET'])
@app.route('/sep2/', methods=['GET'])
@app.route('/sep2/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])
def proxy_sep2(path=''):
    """Proxy SEP2 API calls"""
    return proxy_to_ode('sep2', path)

@app.route('/docs', methods=['GET'])
@app.route('/docs/', methods=['GET'])
@app.route('/docs/<path:path>', methods=['GET'])
def proxy_docs(path=''):
    """Proxy docs API calls"""
    return proxy_to_ode('docs', path)

def proxy_to_ode(prefix, path=''):
    """Helper to proxy requests to ODE backend"""
    try:
        if path:
            url = f"{ODE_API}/{prefix}/{path}"
        else:
            url = f"{ODE_API}/{prefix}"
        
        print(f"[API] {request.method} {url}")
        
        # Handle CORS preflight
        if request.method == 'OPTIONS':
            response = Response()
            response.headers['Access-Control-Allow-Origin'] = '*'
            response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
            response.headers['Access-Control-Allow-Headers'] = '*'
            return response
        
        # Forward the request
        if request.method == 'GET':
            response = requests.get(url, params=request.args, timeout=10)
        elif request.method == 'POST':
            response = requests.post(url, json=request.json, timeout=10)
        elif request.method == 'PUT':
            response = requests.put(url, json=request.json, timeout=10)
        elif request.method == 'DELETE':
            response = requests.delete(url, timeout=10)
        
        print(f"[API] {url} -> {response.status_code}")
        
        # Try to return JSON
        try:
            data = response.json()
            return jsonify(data), response.status_code
        except:
            return response.content, response.status_code, {
                'Content-Type': response.headers.get('Content-Type', 'application/json')
            }
            
    except requests.exceptions.ConnectionError as e:
        print(f"[API ERROR] Connection failed: {e}")
        return jsonify({"error": "ODE backend offline", "details": str(e)}), 502
    except requests.exceptions.Timeout as e:
        print(f"[API ERROR] Timeout: {e}")
        return jsonify({"error": "ODE backend timeout", "details": str(e)}), 504
    except Exception as e:
        print(f"[API ERROR] {e}")
        return jsonify({"error": str(e)}), 500

# -------------------------------
# Health endpoint
# -------------------------------
@app.route('/health')
def health():
    """Health check"""
    try:
        response = requests.get(f"{ODE_API}/coordinator/status", timeout=3)
        if response.ok:
            return jsonify({"status": "ok", "ode": "running"}), 200
        return jsonify({"status": "degraded", "ode_status": response.status_code}), 503
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 503

# -------------------------------
# Fallback for SPA routes
# -------------------------------
@app.route('/<path:path>')
def catch_all(path):
    """Catch-all for SPA routing"""
    file_path = os.path.join(ODE_UI_PATH, path)
    
    # If it's a file, serve it
    if os.path.exists(file_path) and os.path.isfile(file_path):
        mime_type, _ = mimetypes.guess_type(path)
        return send_file(file_path, mimetype=mime_type)
    
    # Otherwise serve index for SPA routing
    print(f"[SPA] {path} -> index.html")
    return serve_index()

# -------------------------------
# Start
# -------------------------------
if __name__ == '__main__':
    port = int(os.getenv("INGRESS_PORT", 8099))
    print(f"[INFO] Starting on port {port}")
    print(f"[INFO] UI: {ODE_UI_PATH}")
    print(f"[INFO] API: {ODE_API}")
    
    # Test ODE connection
    try:
        test = requests.get(f"{ODE_API}/coordinator/status", timeout=2)
        print(f"[INFO] ODE backend responding: {test.status_code}")
    except Exception as e:
        print(f"[WARNING] ODE backend not responding: {e}")
    
    app.run(host='0.0.0.0', port=port, debug=False)
