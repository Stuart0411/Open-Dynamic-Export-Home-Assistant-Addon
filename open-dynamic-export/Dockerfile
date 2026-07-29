# Use the multi-arch Home Assistant base image so Supervisor can resolve
# the correct platform (e.g. aarch64 on HA Green, amd64 on x86).
ARG BUILD_FROM=ghcr.io/home-assistant/base:latest
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
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    echo "[BUILD] ODE commit: $(git rev-parse --short HEAD)"

# 2) Patch CSIP-AUS DER discovery to avoid crashing during onboarding
RUN echo "[BUILD] Patching CSIP-AUS DER list handling (graceful when empty)..." && \
  python3 - <<'PY'
from pathlib import Path

p = Path("src/setpoints/csipAus/index.ts")
s = p.read_text(encoding="utf-8")

old = """            if (derList.ders.length !== 1) {
        throw new Error(
          `DERS list length is not 1, actual length ${derList.ders.length}`,
        );
      }

      const der = derList.ders.at(0)!;
"""

new = """            if (derList.ders.length === 0) {
        this.logger.warn(
          'No DERs found in DER list yet; waiting for CSIP-AUS provisioning',
        );
        return;
      }

      if (derList.ders.length > 1) {
        throw new Error(
          `DERS list length is not 1, actual length ${derList.ders.length}`,
        );
      }

      const der = derList.ders.at(0)!;
"""

if old not in s:
  raise SystemExit("[BUILD] ERROR: Expected DER list block not found in csipAus/index.ts")

s = s.replace(old, new, 1)
p.write_text(s, encoding="utf-8")
print("[BUILD] Patched csipAus/index.ts DER list handling")
PY

# 3) Patch Vite base so asset URLs are relative
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

# 4) Install + build
RUN echo "[BUILD] Installing deps (pnpm)..." && \
    pnpm install --no-frozen-lockfile && \
    echo "[BUILD] Building..." && \
    pnpm run build && \
    echo "[BUILD] Build complete"

# 5) Patch built UI bundles: make API calls relative
RUN echo "[BUILD] Patching built UI bundles to avoid absolute /api/ paths..." && \
    (grep -R "api/coordinator/status" -n dist/ui/assets || true) && \
    find dist/ui/assets -type f -name "*.js" -print0 | xargs -0 sed -i \
      -e 's|"\/api\/|"api\/|g' \
      -e "s|'\/api\/|'api\/|g" \
      -e 's|`\/api\/|`api\/|g' \
    && echo "[BUILD] UI bundle patch complete"

# 6) Patch dist/ui/index.html to keep absolute /api/* calls inside the ingress path
RUN echo "[BUILD] Injecting ingress-safe fetch() rewrite into dist/ui/index.html..." && \
    python3 - <<'PY'
from pathlib import Path
import re

index = Path("dist/ui/index.html")
html = index.read_text(encoding="utf-8")

marker = "<head>"
if marker not in html:
    raise SystemExit("[BUILD] ERROR: <head> not found in dist/ui/index.html")

snippet = r"""
<script>
(() => {
  // Detect Home Assistant ingress base, e.g. /api/hassio_ingress/<token>
  const m = window.location.pathname.match(/^(\/api\/hassio_ingress\/[^/]+)/);
  const ingressBase = m ? m[1] : "";

  // Some HA ingress launches land on "/api/hassio_ingress/<token>" (no trailing slash),
  // which can make the SPA router render Not Found on first load.
  // Normalize to "/api/hassio_ingress/<token>/" before the app boots.
  if (ingressBase && window.location.pathname === ingressBase) {
    const target = ingressBase + "/" + window.location.search + window.location.hash;
    window.history.replaceState(window.history.state, "", target);
  }

  // If the UI still lands on a Not Found route under ingress, auto-navigate
  // to the same Home route that works when users click the Home nav item.
  const repairNotFoundRoute = () => {
    if (!ingressBase) return;
    if (sessionStorage.getItem("ode_ingress_route_repair_done") === "1") return;

    const pageText = (document.body && document.body.textContent || "").toLowerCase();
    if (!pageText.includes("not found")) return;

    const homeLink = Array.from(document.querySelectorAll("a[href]"))
      .find((a) => a.textContent && a.textContent.trim().toLowerCase() === "home");

    if (homeLink && homeLink.getAttribute("href")) {
      sessionStorage.setItem("ode_ingress_route_repair_done", "1");
      const href = homeLink.getAttribute("href");
      const target = new URL(href, window.location.href);
      window.history.replaceState(window.history.state, "", target.pathname + target.search + target.hash);
      window.dispatchEvent(new PopStateEvent("popstate"));
    }
  };

  // Run after mount and once more after initial async rendering.
  window.addEventListener("load", repairNotFoundRoute);
  setTimeout(repairNotFoundRoute, 800);

  const origFetch = window.fetch.bind(window);

  window.fetch = (input, init) => {
    try {
      // Rewrite string URLs like "/api/..."
      if (typeof input === "string" && input.startsWith("/api/") && ingressBase) {
        input = ingressBase + input;
      }

      // Rewrite Request objects targeting same-origin "/api/..."
      if (input instanceof Request && ingressBase) {
        const url = new URL(input.url);
        if (url.origin === window.location.origin && url.pathname.startsWith("/api/")) {
          const newUrl = ingressBase + url.pathname + url.search;
          input = new Request(newUrl, input);
        }
      }
    } catch (e) {
      // Ignore and fall back to original request
    }
    return origFetch(input, init);
  };
})();
</script>
"""

# Inject right after <head>
html = html.replace(marker, marker + snippet, 1)
index.write_text(html, encoding="utf-8")
print("[BUILD] Injected fetch() rewrite into dist/ui/index.html")
PY

COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 3000
CMD ["/run.sh"]
