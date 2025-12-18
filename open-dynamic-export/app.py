#!/usr/bin/env python3
import os
import mimetypes
import logging
from flask import Flask, send_file, request, jsonify, Response
from werkzeug.middleware.proxy_fix import ProxyFix

# Configure Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

# Initialize mimetypes
mimetypes.init()
mimetypes.add_type('application/javascript', '.js')
mimetypes.add_type('text/css', '.css')

# ODE backend API
ODE_API = os.getenv('ODE_API', "http://localhost:3000")
ODE_UI_PATH = os.getenv('ODE_UI_PATH', "/ode/dist/ui")

# ---------------------------------
# Serve React UI
# ---------------------------------
@app.route('/')
def serve_index():
    """Serve index.html"""
    ingress_path = request.headers.get('X-Ingress-Path', '')
    logger.info(f"[INDEX] Ingress-Path: '{ingress_path}'")

    index_path = os.path.join(ODE_UI_PATH, 'index.html')

    if not os.path.exists(index_path):
        logger.error(f"[INDEX ERROR] UI not found: {index_path}")
        return jsonify({"error": "UI not found"}), 404

    with open(index_path, 'r') as f:
        html = f.read()

    # Add base tag for ingress path
    if ingress_path and ingress_path != '/':
        base_tag = f'<base href="{ingress_path}/">'
        html = html.replace('<head>', f'<head>\n    {base_tag}')

    return Response(html, mimetype='text/html')


@app.route('/assets/<path:filename>')
def serve_assets(filename):
    """Serve static assets like CSS and JS"""
    file_path = os.path.join(ODE_UI_PATH, 'assets', filename)
    logger.info(f"[ASSETS REQUEST] Requested asset: {file_path}")

    if not os.path.exists(file_path):
        logger.warning(f"[ASSET 404] Asset not found: {file_path}")
        return "Asset not found", 404

    mime_type, _ = mimetypes.guess_type(file_path)
    if not mime_type and filename.endswith('.css'):
        mime_type = 'text/css'
    elif not mime_type and filename.endswith('.js'):
        mime_type = 'application/javascript'

    logger.info(f"[ASSET SERVE] {filename} -> {mime_type}")
    return send_file(file_path, mimetype=mime_type)


# ---------------------------------
# Health Endpoint
# ---------------------------------
@app.route('/health')
def health():
    """Check backend health"""
    try:
        response = requests.get(f"{ODE_API}/coordinator/status", timeout=3)
        if response.ok:
            return jsonify({"status": "ok", "ode": "running"}), 200
        return jsonify({"status": "degraded", "ode_status": response.status_code}), 503
    except Exception as e:
        logger.error(f"[HEALTH CHECK ERROR] {e}")
        return jsonify({"status": "error", "error": str(e)}), 503


# ---------------------------------
# Start
# ---------------------------------
if __name__ == '__main__':
    port = int(os.getenv("INGRESS_PORT", 8099))
    logger.info(f"[INFO] Starting on port {port}")
    logger.info(f"[INFO] UI Path: {ODE_UI_PATH}")
    logger.info(f"[INFO] Backend API: {ODE_API}")

    app.run(host='0.0.0.0', port=port, debug=False)
