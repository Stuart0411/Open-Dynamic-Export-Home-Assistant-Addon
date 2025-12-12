const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 8099;

// Read configuration
const options = JSON.parse(fs.readFileSync('/data/options.json', 'utf8'));
const ODE_HOST = options.ode_host || 'homeassistant.local';
const ODE_PORT = options.ode_port || 3000;
const ODE_URL = `http://${ODE_HOST}:${ODE_PORT}`;

console.log(`[INFO] Proxying to ODE at: ${ODE_URL}`);

// Serve static files
app.use('/static', express.static(path.join(__dirname, 'public')));

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', target: ODE_URL });
});

// Proxy all requests to ODE
app.use('/', createProxyMiddleware({
    target: ODE_URL,
    changeOrigin: true,
    ws: true, // Proxy websockets
    logLevel: 'info',
    onError: (err, req, res) => {
        console.error('[ERROR] Proxy error:', err.message);
        res.status(502).send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>ODE Connection Error</title>
                <style>
                    body {
                        font-family: Arial, sans-serif;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        height: 100vh;
                        margin: 0;
                        background: #1a1a1a;
                        color: #e0e0e0;
                    }
                    .error-box {
                        background: #2a2a2a;
                        padding: 40px;
                        border-radius: 8px;
                        text-align: center;
                        max-width: 500px;
                    }
                    h1 { color: #f44336; margin-bottom: 20px; }
                    button {
                        margin-top: 20px;
                        padding: 10px 20px;
                        background: #4CAF50;
                        color: white;
                        border: none;
                        border-radius: 4px;
                        cursor: pointer;
                        font-size: 16px;
                    }
                    button:hover { background: #45a049; }
                </style>
            </head>
            <body>
                <div class="error-box">
                    <h1>Cannot Connect to ODE</h1>
                    <p>Unable to connect to Open Dynamic Export at:</p>
                    <p><strong>${ODE_URL}</strong></p>
                    <p>Make sure the "Open Dynamic Export" add-on is running.</p>
                    <button onclick="location.reload()">Retry</button>
                </div>
            </body>
            </html>
        `);
    },
    onProxyReq: (proxyReq, req, res) => {
        // Add ingress headers
        const ingressPath = req.headers['x-ingress-path'] || '';
        proxyReq.setHeader('X-Ingress-Path', ingressPath);
    }
}));

app.listen(PORT, '0.0.0.0', () => {
    console.log(`[INFO] ODE Ingress Proxy listening on port ${PORT}`);
    console.log(`[INFO] Forwarding to: ${ODE_URL}`);
});
