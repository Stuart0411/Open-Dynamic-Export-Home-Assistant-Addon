# app.py

import os
import logging
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS

# Set up structured logging
logging.basicConfig(
    format='%(asctime)s %(levelname)s: %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Load environment-based configuration
STATIC_FOLDER = os.getenv('STATIC_FOLDER', 'static')
DYNAMIC_PATH = os.getenv('DYNAMIC_PATH', '/dynamic')

# Validate static asset path
if not os.path.exists(STATIC_FOLDER):
    logger.error("Static folder '%s' does not exist.", STATIC_FOLDER)
    raise FileNotFoundError(f"Static folder '{STATIC_FOLDER}' does not exist.")

# Enable CORS with enhanced security
CORS(app, resources={r"/*": {"origins": [os.getenv('CORS_ALLOWED_ORIGINS', '*')]}})

@app.route(f"{DYNAMIC_PATH}/config", methods=['GET'])
def dynamic_config():
    try:
        # Example dynamic configuration can be extended
        config = {
            "version": "1.0.0",
            "features": ["featureA", "featureB"]
        }
        logger.info("Dynamic configuration fetched successfully.")
        return jsonify(config)
    except Exception as e:
        logger.error("Error fetching dynamic configuration: %s", e)
        return jsonify({"error": "Failed to fetch configuration."}), 500

@app.route(f"{DYNAMIC_PATH}/static/<path:filename>", methods=['GET'])
def static_files(filename):
    try:
        return send_from_directory(STATIC_FOLDER, filename)
    except FileNotFoundError:
        logger.warning("Request for non-existent file: %s", filename)
        return jsonify({"error": "File not found."}), 404
    except Exception as e:
        logger.error("Error serving static file '%s': %s", filename, e)
        return jsonify({"error": "Internal server error."}), 500

if __name__ == '__main__':
    # App entrypoint
    logger.info("Starting the application.")
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port)