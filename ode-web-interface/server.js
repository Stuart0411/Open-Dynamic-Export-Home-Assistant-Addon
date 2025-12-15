const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const fs = require('fs');

const app = express();
const PORT = 8099;

// Read configuration
const options = JSON.parse(fs.readFileSync('/data/options.json', 'utf8'));
const ODE_HOST = options.ode_host || 'homeassistant.local';
const ODE_PORT = options.ode_port || 3000;
const ODE_URL = `http://${ODE_HOST}:${ODE_PORT}`;

console.log(`[INFO] ODE Proxy starting...`);
console.log(`[INFO] Target: ${ODE_URL}`);

// Proxy all requests to ODE
app.use('/', createProxyMiddleware({
    target: ODE_URL,
    changeOrigin: true,
    ws: true,
    logLevel: 'info',
    
    onProxyReq: (proxyReq, req, res) => {
        // Rewrite Host header to match ODE's expected host
        proxyReq.setHeader('Host', `${ODE_HOST}:${ODE_PORT}`);
        
        // Remove X-Forwarded-* headers that might confuse Vite
        proxyReq.removeHeader('X-Forwarded-Host');
        proxyReq.removeHeader('X-Forwarded-Proto');
        proxyReq.removeHeader('X-Forwarded-For');
        
        console.log(`[PROXY] ${req.method} ${req.url}`);
    },
    
    onProxyRes: (proxyRes, req, res) => {
        console.log(`[RESPONSE] ${proxyRes.statusCode} for ${req.url}`);
    },
    
    onError: (err, req, res) => {
        console.error(`[ERROR] Proxy error: ${err.message}`);
        res.status(502).send(`
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>ODE Connection Error</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        min-height: 100vh;
                        margin: 0;
                        background: #1a1a1a;
                        color: #e0e0e0;
                        padding: 20px;
                    }
                    .error-box {
                        background: #2a2a2a;
                        padding: 40px;
                        border-radius: 8px;
                        text-align: center;
                        max-width: 600px;
                        box-shadow: 0 4px 6px rgba(0,0,0,0.3);
                    }
                    h1 { color: #f44336; margin: 0 0 20px 0; font-size: 24px; }
                    p { margin: 15px 0; line-height: 1.6; }
                    code {
                        background: #1a1a1a;
                        padding: 4px 8px;
                        border-radius: 4px;
                        font-family: 'Courier New', monospace;
                        font-size: 14px;
                    }
                    ul {
                        text-align: left;
                        display: inline-block;
                        margin: 15px 0;
                    }
                    li { margin: 8px 0; }
                    button {
                        margin-top: 25px;
                        padding: 12px 32px;
                        background: #4CAF50;
                        color: white;
                        border: none;
                        border-radius: 6px;
                        cursor: pointer;
                        font-size: 16px;
                        font-weight: 500;
                        transition: background 0.2s;
                    }
                    button:hover { background: #45a049; }
                </style>
            </head>
            <body>
                <div class="error-box">
                    <h1>⚠️ Cannot Connect to Open Dynamic Export</h1>
                    <p>Unable to connect to ODE at:</p>
                    <p><code>${ODE_URL}</code></p>
                    <p><strong>Please check:</strong></p>
                    <ul>
                        <li>✓ "Open Dynamic Export" add-on is installed</li>
                        <li>✓ The add-on is started and running</li>
                        <li>✓ No errors in the ODE add-on logs</li>
                        <li>✓ Port ${ODE_PORT} is accessible</li>
                    </ul>
                    <button onclick="location.reload()">🔄 Retry Connection</button>
                </div>
            </body>
            </html>
        `);
    }
}));

app.listen(PORT, '0.0.0.0', () => {
    console.log(`[INFO] ========================================`);
    console.log(`[INFO] ODE Web Interface Proxy Ready`);
    console.log(`[INFO] ========================================`);
    console.log(`[INFO] Listening on: 0.0.0.0:${PORT}`);
    console.log(`[INFO] Forwarding to: ${ODE_URL}`);
    console.log(`[INFO] Host header: ${ODE_HOST}:${ODE_PORT}`);
    console.log(`[INFO] ========================================`);
});
