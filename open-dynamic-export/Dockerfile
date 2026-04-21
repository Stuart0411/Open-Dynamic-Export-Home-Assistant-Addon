ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    bash \
    jq \
    make \
    g++ \
    openssl \
    python3

RUN npm install -g pnpm

WORKDIR /ode

# 1) Clone upstream
RUN git clone --depth 1 --branch patch-1 https://github.com/Stuart0411/open-dynamic-export.git . && \
    echo "[BUILD] ODE commit: $(git rev-parse --short HEAD)"

# 2) Patch Vite base so asset URLs are relative
RUN echo "[BUILD] Patching Vite base for HA ingress (base: ./)..." && \
    python3 - <<'PY'
from pathlib import Path

p = Path("vite.config.ts")
s = p.read_text(encoding="utf-8")

if "base:" not in s:
    needle = "defineConfig({"
    if needle in s:
        s = s.replace(needle, needle + "\n  base: './',", 1)
        p.write_text(s, encoding="utf-8")
        print("[BUILD] Patched vite.config.ts (inserted base: './')")
    else:
        raise SystemExit("[BUILD] ERROR: defineConfig({ not found in vite.config.ts")
else:
    print("[BUILD] vite.config.ts already has base:, skipping")
PY

# 3) Install + build
RUN echo "[BUILD] Installing deps (pnpm)..." && \
    pnpm install --no-frozen-lockfile && \
    echo "[BUILD] Building..." && \
    pnpm run build && \
    echo "[BUILD] Build complete"

# 4) Patch built UI bundles: make API calls relative
RUN echo "[BUILD] Patching built UI bundles to avoid absolute /api/ paths..." && \
    (grep -R "api/coordinator/status" -n dist/ui/assets || true) && \
    find dist/ui/assets -type f -name "*.js" -print0 | xargs -0 sed -i \
      -e 's|"\/api\/|"api\/|g' \
      -e "s|'\/api\/|'api\/|g" \
      -e 's|`\/api\/|`api\/|g' \
    && echo "[BUILD] UI bundle patch complete"

# 5) Patch dist/ui/index.html to keep absolute /api/* calls inside the ingress path
RUN echo "[BUILD] Injecting ingress-safe fetch() rewrite into dist/ui/index.html..." && \
    python3 - <<'PY'
from pathlib import Path

index = Path("dist/ui/index.html")
html = index.read_text(encoding="utf-8")

marker = "<head>"
if marker not in html:
    raise SystemExit("[BUILD] ERROR: <head> not found in dist/ui/index.html")

snippet = r"""
<script>
// SPA route fix for Home Assistant ingress: redirect root/unknown to Home
(() => {
  function redirectIfNeeded() {
    const path = window.location.pathname.replace(/^\/api\/hassio_ingress\/[^/]+/, "");
    if (path === "/" || path === "") {
      // Try hash router first
      if (window.location.hash && window.location.hash !== "#/") return;
      // Try pushState router: redirect to /home (adjust if needed)
      window.history.replaceState({}, "", window.location.pathname + "#/home");
    }
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", redirectIfNeeded);
  } else {
    redirectIfNeeded();
  }
})();
</script>
"""

# Inject right after <head>
html = html.replace(marker, marker + snippet, 1)
index.write_text(html, encoding="utf-8")
print("[BUILD] Injected SPA route fix for Home Assistant ingress")
PY

COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 3000
CMD ["/run.sh"]
