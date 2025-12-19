#!/usr/bin/env bash
set -e

echo "[INFO] Starting Open Dynamic Export"

# Write config
mkdir -p /data
CONFIG=$(cat /data/options.json | jq -r '.config_file')
echo "${CONFIG}" > /data/config.json
echo "[INFO] Config written to /data/config.json"

# Set environment variables
export LOG_LEVEL=$(cat /data/options.json | jq -r '.log_level // "info"')
export CONFIG_PATH="/data/config.json"
export SERVER_PORT="3000"
export SERVER_HOST="0.0.0.0"
export TZ="UTC"
export CONFIG_DIR="/data"
export SEP2_CERT_FILE="/ode/config/sep2-cert.pem"
export SEP2_KEY_FILE="/ode/config/sep2-key.pem"
export SEP2_PEN="12345"

echo "[INFO] Starting ODE on http://0.0.0.0:3000"

cd /ode
exec node dist/src/app.js
```

**Remove these files** (no longer needed):
- `app.py`
- `requirements.txt`
- `ingress.conf`
- `templates/` directory

Commit, push, and rebuild the add-on (version 2.3.0). The add-on will now run ODE's original UI on port 3000.

---

## Step 2: Install Nginx Proxy Manager

1. **Add the add-on:**
   - Go to **Settings → Add-ons → Add-on Store**
   - Search for **"Nginx Proxy Manager"**
   - Click **Install**

2. **Start it:**
   - Once installed, click **Start**
   - Click **"OPEN WEB UI"**

3. **Initial login:**
   - Email: `admin@example.com`
   - Password: `changeme`
   - **Change these immediately!**

---

## Step 3: Create Proxy Host for ODE

1. **In Nginx Proxy Manager**, click **"Hosts" → "Proxy Hosts" → "Add Proxy Host"**

2. **Details tab:**
   - **Domain Names:** Leave empty for now (we'll use path-based routing)
   - **Scheme:** `http`
   - **Forward Hostname / IP:** `homeassistant.local` (or your HA IP like `192.168.1.x`)
   - **Forward Port:** `3000`
   - **Cache Assets:** ✅ (optional)
   - **Block Common Exploits:** ✅
   - **Websockets Support:** ✅ (important for ODE)

3. **Click Save**

---

## Step 4: Access ODE Remotely

### Option A: Via Nginx Proxy Manager Port

You can now access ODE at:
- **Locally:** `http://homeassistant.local:81` (Nginx Proxy Manager UI)
- Then navigate to your proxy host

### Option B: Custom Location (Better for Nabu Casa)

To make it work through Nabu Casa with a clean URL:

1. **In Nginx Proxy Manager**, click your proxy host → **Edit**

2. **Go to "Custom Locations" tab → Add location:**
   - **Define Location:** `/ode`
   - **Scheme:** `http`
   - **Forward Hostname / IP:** `homeassistant.local`
   - **Forward Port:** `3000`
   - **Forward Path:** `/`

3. **Save**

Now you can access ODE through Nabu Casa at:
```
https://your-nabu-casa-url.ui.nabu.casa:81/ode
