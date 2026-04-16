ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Install dependencies needed to build ODE (and native node modules if any)
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

# Install pnpm (upstream uses pnpm)
RUN npm install -g pnpm

WORKDIR /ode

# Clone upstream ODE (main), patch Vite base for ingress-safe relative assets, then build
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    echo "[BUILD] ODE commit: $(git rev-parse --short HEAD)" && \
    echo "[BUILD] Patching Vite base for Home Assistant ingress (base: ./)..." && \
    # Insert `base: "./",` right after `defineConfig({` if not already present
    grep -q "base: ['./\"]\\./" vite.config.ts || \
      sed -i 's/defineConfig({/defineConfig({\\n  base: \"\\.\\/\",/' vite.config.ts && \
    echo "[BUILD] Installing deps (pnpm)..." && \
    pnpm install --no-frozen-lockfile && \
    echo "[BUILD] Building..." && \
    pnpm run build && \
    echo "[BUILD] Build complete"

# Copy startup script
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 3000

CMD ["/run.sh"]