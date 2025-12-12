# ODE Web Interface Add-on

This add-on provides an Ingress-compatible web interface for Open Dynamic Export, allowing remote access through Nabu Casa.

## Installation

1. Add this folder (`ode-web-interface`) to your add-on repository
2. Install both add-ons:
   - **Open Dynamic Export** (the main add-on)
   - **ODE Web Interface** (this proxy add-on)
3. Start both add-ons
4. Access ODE through the sidebar or "OPEN WEB UI" button

## How It Works

This add-on creates a lightweight proxy server that:
- Works with Home Assistant Ingress
- Forwards all requests to the main ODE add-on (port 3000)
- Handles WebSocket connections
- Provides error pages if ODE is not running

## Configuration

- **ode_host**: Hostname of your Home Assistant instance (default: `homeassistant.local`)
- **ode_port**: Port where ODE is running (default: `3000`)

## Folder Structure

```
ode-web-interface/
├── config.yaml
├── Dockerfile
├── package.json
├── server.js
├── run.sh
└── README.md
```

## Requirements

- Open Dynamic Export add-on must be installed and running
- Port 3000 must be accessible from this add-on

## Remote Access

Once installed, you can access ODE:
- Locally: Through Home Assistant sidebar
- Remotely: Through your Nabu Casa URL automatically
