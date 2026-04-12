// Patches dist/ui/index.html with a fetch interceptor for HA ingress.
// .cjs extension = CommonJS, bypassing ODE's "type":"module" in package.json.
// No <base> tag — with vite base:'./', relative asset paths (./assets/...)
// resolve correctly from the ingress URL without needing a base tag.
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
    console.error('[PATCH] ERROR: <head> not found. HTML start: ' + html.substring(0, 200));
    process.exit(1);
}

// Detect ingress path from window.location.pathname at runtime.
// Matches /api/hassio_ingress/<token> or /hassio/ingress/<token>.
// 1. Strips prefix via history.replaceState so TanStack Router sees "/"
// 2. Wraps window.fetch to prepend ingress path to same-origin API calls
//    so ODE's openapi-fetch (baseUrl:'/') reaches ODE, not HA's own API.
const script = `<script id="hassio_ingress_patch">(function(){
  var m=location.pathname.match(/^(\\/(?:api\\/hassio_ingress|hassio\\/ingress)\\/[^\\/]+)/);
  if(!m)return;
  var ig=m[1];
  history.replaceState(null,'',location.pathname.slice(ig.length)||'/');
  var _f=window.fetch;
  window.fetch=function(input,init){
    if(typeof input==='string'&&input.startsWith('/')&&!input.startsWith(ig)){input=ig+input;}
    return _f.call(this,input,init);
  };
})();</script>`;

html = html.replace('<head>', '<head>' + script);
fs.writeFileSync(indexPath, html);
console.log('[PATCH] Successfully patched ' + indexPath);
