#!/usr/bin/env node
// Patches dist/ui/index.html with an ingress compatibility script.
// Runs at Docker build time after `pnpm run build`.
//
// The injected script runs before React initialises and:
//   1. Detects the HA ingress path from window.location.pathname by matching
//      /api/hassio_ingress/<token> or /hassio/ingress/<token>
//   2. Calls history.replaceState to strip the prefix so TanStack Router
//      sees "/" and matches routes correctly (fixes blank Home page)
//   3. Wraps window.fetch to prepend the ingress path to same-origin API
//      calls so ODE's openapi-fetch (baseUrl: '/') reaches ODE not HA's API

const fs = require('fs');

const indexPath = '/ode/dist/ui/index.html';
let html = fs.readFileSync(indexPath, 'utf8');

if (html.includes('hassio_ingress_patch')) {
    console.log('[PATCH] index.html already patched, skipping');
    process.exit(0);
}

const script = `<script id="hassio_ingress_patch">(function(){
  var m = location.pathname.match(/^(\\/(?:api\\/hassio_ingress|hassio\\/ingress)\\/[^\\/]+)/);
  if (!m) return;
  var ig = m[1];
  // Fix router: strip ingress prefix so TanStack Router sees "/"
  history.replaceState(null, '', location.pathname.slice(ig.length) || '/');
  // Fix API calls: prepend ingress prefix to all same-origin fetch requests
  var _f = window.fetch;
  window.fetch = function(input, init) {
    if (typeof input === 'string' && input.startsWith('/') && !input.startsWith(ig)) {
      input = ig + input;
    }
    return _f.call(this, input, init);
  };
})();</script>`;

// Also inject a <base> tag so relative assets (./assets/...) resolve correctly
const base = '<base id="hassio_base" href="/">';

if (!html.includes('<head>')) {
    console.error('[PATCH] ERROR: <head> tag not found in index.html');
    console.error('[PATCH] index.html contents:');
    console.error(html.substring(0, 500));
    process.exit(1);
}

html = html.replace('<head>', '<head>' + base + script);
fs.writeFileSync(indexPath, html);
console.log('[PATCH] Successfully patched dist/ui/index.html');
