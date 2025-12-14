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

console.log(`[INFO] ODE Web Interface starting...`);
console.log(`[INFO] Target: ${ODE_URL}`);

// Serve a custom HTML page that embeds ODE
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Open Dynamic Export</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body, html {
            height: 100%;
            overflow: hidden;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
        }
        
        #loading {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            background: #1a1a1a;
            color: #e0e0e0;
            z-index: 9999;
        }
        
        .spinner {
            width: 50px;
            height: 50px;
            border: 4px solid #333;
            border-top-color: #4CAF50;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-bottom: 20px;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        #error {
            display: none;
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: #2a2a2a;
            color: #e0e0e0;
            padding: 40px;
            border-radius: 8px;
            max-width: 600px;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }
        
        #error h2 {
            color: #f44336;
            margin-bottom: 20px;
        }
        
        #error button {
            margin-top: 20px;
            padding: 12px 24px;
            background: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
        }
        
        #error button:hover {
            background: #45a049;
        }
        
        #content {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
        }
        
        #ode-frame {
            width: 100%;
            height: 100%;
            border: none;
        }
        
        .info {
            font-size: 14px;
            color: #999;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div id="loading">
        <div class="spinner"></div>
        <div>Loading Open Dynamic Export...</div>
        <div class="info">Connecting to ${ODE_URL}</div>
    </div>
    
    <div id="error">
        <h2>⚠️ Connection Error</h2>
        <p id="error-message"></p>
        <button onclick="location.reload()">🔄 Retry</button>
    </div>
    
    <div id="content">
        <iframe id="ode-frame"></iframe>
    </div>

    <script>
        const ODE_URL = '${ODE_URL}';
        const loading = document.getElementById('loading');
        const error = document.getElementById('error');
        const errorMessage = document.getElementById('error-message');
        const content = document.getElementById('content');
        const frame = document.getElementById('ode-frame');
        
        let retryCount = 0;
        const maxRetries = 3;
        
        async function checkODE() {
            try {
                console.log('Checking ODE availability...');
                const response = await fetch('/health');
                const data = await response.json();
                
                if (data.status === 'ok') {
                    return true;
                }
                return false;
            } catch (err) {
                console.error('Health check failed:', err);
                return false;
            }
        }
        
        async function loadODE() {
            const isAvailable = await checkODE();
            
            if (!isAvailable) {
                if (retryCount < maxRetries) {
                    retryCount++;
                    console.log(\`Retry \${retryCount}/\${maxRetries}...\`);
                    setTimeout(loadODE, 2000);
                    return;
                }
                
                loading.style.display = 'none';
                error.style.display = 'block';
                errorMessage.innerHTML = \`
                    <p>Cannot connect to Open Dynamic Export at:</p>
                    <p style="font-family: monospace; background: #1a1a1a; padding: 10px; border-radius: 4px; margin: 15px 0;">\${ODE_URL}</p>
                    <p>Please ensure the "Open Dynamic Export" add-on is:</p>
                    <ul style="text-align: left; display: inline-block; margin-top: 10px;">
                        <li>✓ Installed</li>
                        <li>✓ Started</li>
                        <li>✓ Running without errors</li>
                    </ul>
                \`;
                return;
            }
            
            // ODE is available, load it in iframe
            console.log('ODE is available, loading interface...');
            frame.src = ODE_URL;
            
            frame.onload = () => {
                console.log('ODE interface loaded successfully');
                loading.style.display = 'none';
                content.style.display = 'block';
            };
            
            frame.onerror = () => {
                console.error('Failed to load ODE interface');
                loading.style.display = 'none';
                error.style.display = 'block';
                errorMessage.textContent = 'Failed to load the ODE interface. The add-on may be starting up.';
            };
            
            // Fallback timeout
            setTimeout(() => {
                if (loading.style.display !== 'none') {
                    loading.style.display = 'none';
                    content.style.display = 'block';
                }
            }, 5000);
        }
        
        // Start loading
        loadODE();
    </script>
</body>
</html>
    `);
});

// Health check endpoint
app.get('/health', async (req, res) => {
    try {
        const fetch = (await import('node-fetch')).default;
        const response = await fetch(`${ODE_URL}/coordinator/status`, {
            timeout: 3000
        });
        
        if (response.ok) {
            res.json({ status: 'ok', target: ODE_URL });
        } else {
            res.status(502).json({ status: 'error', target: ODE_URL, message: 'ODE returned error' });
        }
    } catch (error) {
        console.error('[ERROR] Health check failed:', error.message);
        res.status(502).json({ status: 'error', target: ODE_URL, message: error.message });
    }
});

// Proxy API requests
app.use('/api', createProxyMiddleware({
    target: ODE_URL,
    changeOrigin: true,
    pathRewrite: {
        '^/api': ''
    }
}));

app.listen(PORT, '0.0.0.0', () => {
    console.log(`[INFO] ========================================`);
    console.log(`[INFO] ODE Web Interface Ready`);
    console.log(`[INFO] ========================================`);
    console.log(`[INFO] Listening on: 0.0.0.0:${PORT}`);
    console.log(`[INFO] Forwarding to: ${ODE_URL}`);
    console.log(`[INFO] ========================================`);
});
