# Open Dynamic Export Add-on

Dynamic solar export management with CSIP-AUS support for Home Assistant.

## Features

- ✅ MQTT integration for inverter and meter data
- ✅ CSIP-AUS dynamic export control
- ✅ Persistent certificate storage
- ✅ Automatic updates

## Initial Setup

### 1. Configure MQTT Connection

Edit the add-on configuration with your MQTT broker details:

```json
{
  "inverters": [
    {
      "type": "mqtt",
      "host": "mqtt://core-mosquitto",
      "username": "your_mqtt_username",
      "password": "your_mqtt_password",
      "topic": "inverters/1"
    }
  ],
  "meter": {
    "type": "mqtt",
    "host": "mqtt://core-mosquitto",
    "username": "your_mqtt_username",
    "password": "your_mqtt_password",
    "topic": "site"
  }
}
```

### 2. Set Up Home Assistant Automations

You need to publish your inverter and meter data to MQTT. See the main README for example automations.

### 3. Start the Add-on

Click **Start** and check the logs for any errors.

---

## CSIP-AUS Certificate Setup

To enable CSIP-AUS dynamic export control, you need to provide your SEP2 certificates.

### Method 1: File Editor (Easiest)

1. **Install File Editor** add-on (if not already installed):
   - Settings → Add-ons → Add-on Store
   - Search for "File Editor"
   - Install and start it

2. **Navigate to certificate folder:**
   - Open File Editor
   - Click the folder icon (top left)
   - Navigate to: `/addon_configs/2b62df8a_open-dynamic-export/certs/`

3. **Create certificate files:**
   - Click the **+** icon to create new file
   - Name: `sep2-cert.pem`
   - Paste your CSIP certificate content
   - Save
   - Repeat for `sep2-key.pem` with your private key

4. **Restart the add-on:**
   - Go to Settings → Add-ons → Open Dynamic Export
   - Click **Restart**
   - Check logs - you should see: `[INFO] ✓ Found SEP2 certificates`

### Method 2: Studio Code Server

1. **Install Studio Code Server** add-on
2. **Navigate to:** `/addon_configs/2b62df8a_open-dynamic-export/certs/`
3. **Create files:**
   - Right-click → New File → `sep2-cert.pem`
   - Paste certificate content and save
   - Repeat for `sep2-key.pem`
4. **Restart the add-on**

### Method 3: SSH/Terminal

1. **SSH into your Home Assistant:**
   ```bash
   ssh root@homeassistant.local
   ```

2. **Create certificate directory:**
   ```bash
   cd /addon_configs/2b62df8a_open-dynamic-export
   mkdir -p certs
   cd certs
   ```

3. **Create certificate files:**
   ```bash
   nano sep2-cert.pem
   # Paste your certificate, then Ctrl+X, Y, Enter
   
   nano sep2-key.pem
   # Paste your private key, then Ctrl+X, Y, Enter
   ```

4. **Restart the add-on**

### Method 4: Samba Share

1. **Install Samba share** add-on (if not already installed)
2. **From your computer, navigate to:**
   - Windows: `\\homeassistant\addon_configs\2b62df8a_open-dynamic-export\certs\`
   - Mac: `smb://homeassistant/addon_configs/2b62df8a_open-dynamic-export/certs/`
3. **Copy your certificate files:**
   - `sep2-cert.pem`
   - `sep2-key.pem`
4. **Restart the add-on**

### Verify Certificates

After restarting, check the add-on logs. You should see:

```
[INFO] ✓ Found SEP2 certificates in /data/certs
[INFO] ✓ Certificates copied to /ode/config
[INFO] Certificate details:
subject=...
notBefore=...
notAfter=...
```

If you see a warning about missing certificates, check:
- File names are exactly `sep2-cert.pem` and `sep2-key.pem`
- Files are in the correct directory
- Files contain valid PEM-formatted certificates

---

### For Remote Access

If you've set up Nginx Proxy Manager for remote access, update the URL:

```yaml
url: "http://homeassistant.local:81"  # Or your proxy port
```

---

## Remote Access Setup

The add-on runs on port 3000, which works locally. For remote access via Nabu Casa:

### Option 1: Nginx Proxy Manager (Untested)

1. **Install Nginx Proxy Manager** add-on
2. **Create a Proxy Host:**
   - Forward Hostname: `homeassistant.local`
   - Forward Port: `3000`
   - Enable Websockets
3. **Access remotely** through the proxy port (usually 81)

See the main README for detailed Nginx Proxy Manager setup.

### Option 2: Port Forwarding

If you have a static IP:
1. Forward port 3000 on your router to your Home Assistant IP
2. Access at `http://your-public-ip:3000`

---

## Configuration Options

### config_file

JSON configuration for ODE. See [ODE documentation](https://github.com/longzheng/open-dynamic-export) for all options.

**Key sections:**
- `setpoints` - CSIP-AUS and other control setpoints
- `inverters` - Your inverter connection (MQTT, Modbus, etc.)
- `meter` - Your meter connection
- `inverterControl` - Enable/disable control
- `publish` - Publish active limits to MQTT

### log_level

Logging verbosity: `trace`, `debug`, `info`, `warning`, `error`

**Default:** `info`

---

## Troubleshooting

### Add-on won't start

1. **Check logs** for error messages
2. **Verify MQTT credentials** are correct
3. **Ensure Mosquitto** add-on is running
4. **Check config.json** syntax is valid

### Web UI not accessible

1. **Verify add-on is running**
2. **Try:** `http://homeassistant.local:3000`
3. **Check port 3000** is exposed in config
4. **Check firewall** isn't blocking port 3000

### Certificates not loading

1. **Check file names** are exactly:
   - `sep2-cert.pem`
   - `sep2-key.pem`
2. **Check location:** `/addon_configs/2b62df8a_open-dynamic-export/certs/`
3. **Check permissions** - files should be readable
4. **Check logs** for certificate errors
5. **Verify PEM format** - files should start with `-----BEGIN CERTIFICATE-----`

### MQTT not working

1. **Test MQTT broker** with MQTT Explorer
2. **Verify credentials** in add-on config
3. **Check topic names** match your automations
4. **Ensure data is being published** to topics

---

## Support

- **ODE Issues:** https://github.com/longzheng/open-dynamic-export/issues
- **Add-on Issues:** https://github.com/Stuart0411/Open-Dynamic-Export-Home-Assistant-Addon/issues
- **Home Assistant Community:** https://community.home-assistant.io/

---
