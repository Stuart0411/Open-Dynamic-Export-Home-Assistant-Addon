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
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    echo "[BUILD] ODE commit: $(git rev-parse --short HEAD)" && \
    echo "[BUILD] Patching Vite base for HA ingress (base: ./)..." && \
    python3 - <<'PY' \
from pathlib import Path \
p = Path("vite.config.ts") \
s = p.read_text(encoding="utf-8") \
if "base:" not in s: \
    needle = "defineConfig({" \
    if needle in s: \
        s = s.replace(needle, needle + "\n  base: './',", 1) \
        p.write_text(s, encoding="utf-8") \
        print("[BUILD] Patched vite.config.ts (inserted base: './')") \
    else: \
        raise SystemExit("[BUILD] ERROR: defineConfig({ not found in vite.config.ts") \
else: \
    print("[BUILD] vite.config.ts already has base:, skipping") \
PY \
    && echo "[BUILD] Installing deps (pnpm)..." \
    && pnpm install --no-frozen-lockfile \
    && echo "[BUILD] Building..." \
    && pnpm run build \
    && echo "[BUILD] Build complete"

COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 3000
CMD ["/run.sh"]