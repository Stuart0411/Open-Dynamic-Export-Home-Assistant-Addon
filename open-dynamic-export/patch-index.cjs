#!/usr/bin/env node
// Patches dist/ui/index.html with an ingress compatibility script.
// Runs at Docker build time after `pnpm run build`.
// Uses .cjs extension so Node treats it as CommonJS even though ODE's
// package.json has "type": "module".
//
// NOTE: We do NOT inject a <base> tag. With vite base:'./', assets are
// referenced as ./assets/... which the browser resolves relative to the
// document URL — which already contains the ingress path through Nabu Casa
// or local HA ingress. A static <base href="/"> would break this by forcing
// resolution from the domain root.
//
// The injected script runs before React and:
//   1. Detects the ingress prefix from window.location.pathname
//   2. Strips it via history.replaceState so TanStack Router sees "/"
//   3. Wraps window.fetch to re-add the prefix to API calls

const fs = require('fs');

const indexPath = '/ode/dist/ui/index.html';

if (!fs.existsSync(indexPath)) {
    console.error('[PATCH] ERROR: ' + indexPath + ' not found');
    process.exit(1);
}

let html = fs.readFileSync(indexPath, 'utf8');

if (html.includes('hassio_ingress_patch')) {
    console.log('[PATCH] Already patched, skipping');
    process.exit(0);
}

if (!html.includes('<head>')) {
    console.error('[PATCH] ERROR: <head> not found in index.html');
    console.error(html.substring(0, 500));
    process.exit(1);
}

const script = `<script id="hassio_ingress_patch">(function(){
  var m = location.pathname.match(/^(\\/(?:api\\/hassio_ingress|hassio\\/ingress)\\/[^\\/]+)/);
  if (!m) return;
  var ig = m[1];
  history.replaceState(null, '', location.pathname.slice(ig.length) || '/');
  var _f = window.fetch;
  window.fetch = function(input, init) {
    if (typeof input === 'string' && input.startsWith('/') && !input.startsWith(ig)) {
      input = ig + input;
    }
    return _f.call(this, input, init);
  };
})();</script>`;

html = html.replace('<head>', '<head>' + script);
fs.writeFileSync(indexPath, html);
console.log('[PATCH] Successfully patched dist/ui/index.html');
