# Open-Dynamic-Export-Home-Assistant-Addon
Dynamic solar export management with CSIP-AUS support for Home Assistant.
This repository contains a Home Assistant add-on for [Open Dynamic Export](https://github.com/longzheng/open-dynamic-export).

(This has been developed for MQTT, but should also work for other configurations supported by ODE)

## Installation

1. **Add this repository to Home Assistant:**
   - Go to Settings → Add-ons → Add-on Store
   - Click the three dots (⋮) in the top right
   - Click "Repositories"
   - Add this URL: `[https://github.com/Stuart0411/Open-Dynamic-Export-Home-Assistant-Addon]`
   - Click "Add"

2. **Install the add-on:**
   - Find "Open Dynamic Export" in the add-on store
   - Click on it and press "Install"

3. **Configure the add-on:**
   - Go to the Configuration tab
   - Edit the `config_file` with your settings
   - Update MQTT credentials to match your Mosquitto setup
   - Save the configuration

## Prerequisites

- Mosquitto MQTT broker add-on installed
- MQTT user configured in Mosquitto
- Home Assistant automations to publish meter/inverter data to MQTT

## UI
The default open dynamic exports UI can be accessed locally from your home assistant IP address or homeassistant.local:3000
eg. 192.168.1.5:3000

## CSIP-AUS Setup (Optional)
For CSIP-AUS dynamic export control:

Get your certificates from your DNSP
Place them in: /addon_configs/2b62df8a_open-dynamic-export/certs/

sep2-cert.pem
sep2-key.pem


Update config with your CSIP credentials
Restart the add-on

## Configuration Example

```json
{
  "setpoints": {
    "csipAus": {
      "enabled": true,
      "controlMode": "opModExpLimW",
      "siteId": "YOUR_SITE_ID",
      "auth": {
        "clientId": "YOUR_CLIENT_ID",
        "clientSecret": "YOUR_CLIENT_SECRET"
      }
    }
  },
  "inverters": [
    {
      "type": "mqtt",
      "host": "mqtt://core-mosquitto",
      "username": "user",
      "password": "password",
      "topic": "inverters/1"
    }
  ],
  "inverterControl": {
    "enabled": true
  },
  "meter": {
    "type": "mqtt",
    "host": "mqtt://core-mosquitto",
    "username": "user",
    "password": "password",
    "topic": "site"
  },
  "publish": {
    "mqtt": {
      "host": "mqtt://core-mosquitto",
      "username": "user",
      "password": "password",
      "topic": "ode/limits"
    }
  }
}
```
## Support

For issues with Open Dynamic Export itself, see: https://github.com/longzheng/open-dynamic-export

For add-on specific issues, please open an issue in this repository.
