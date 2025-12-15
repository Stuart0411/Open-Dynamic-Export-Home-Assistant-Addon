Open Dynamic Export - Home Assistant Add-on
Complete rebuild with Ingress support for remote access via Nabu Casa.

Features
✅ Ingress Support - Access through Home Assistant sidebar
✅ Nabu Casa Compatible - Works with Home Assistant Cloud
✅ Custom Web Interface - Lightweight dashboard
✅ Full ODE Backend - Complete functionality
✅ Single Add-on - No separate proxy needed
Installation
Add this repository to Home Assistant
Install "Open Dynamic Export"
Configure your inverters and meter (MQTT settings)
Start the add-on
Click "OPEN WEB UI" or access from sidebar
Architecture
This add-on runs two processes:

ODE Backend (port 3000) - Handles all logic and MQTT
Web Interface (port 8099) - Ingress-compatible dashboard
The web interface proxies API requests to the backend, allowing Ingress to work properly.

Configuration
Edit the config_file option with your MQTT broker details and inverter settings.

Folder Structure
open-dynamic-export/
├── config.yaml
├── Dockerfile
├── requirements.txt
├── app.py
├── run.sh
├── templates/
│   └── index.html
└── static/
    └── (empty, for future assets)
Remote Access
Once installed, you can access the dashboard:

Locally: Through Home Assistant sidebar
Remotely: Automatically works with Nabu Casa URL
No additional configuration needed!


