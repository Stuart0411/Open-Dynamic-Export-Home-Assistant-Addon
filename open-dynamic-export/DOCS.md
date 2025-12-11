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
      "username": "your_username",
      "password": "your_password",
      "topic": "inverters/1"
    }
  ],
  "inverterControl": {
    "enabled": true
  },
  "meter": {
    "type": "mqtt",
    "host": "mqtt://core-mosquitto",
    "username": "your_username",
    "password": "your_password",
    "topic": "site"
  },
  "publish": {
    "mqtt": {
      "host": "mqtt://core-mosquitto",
      "username": "your_username",
      "password": "your_password",
      "topic": "ode/limits"
    }
  }
}
