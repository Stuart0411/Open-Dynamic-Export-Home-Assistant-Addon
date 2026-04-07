ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Install Node.js, nginx, gettext (for envsubst), and build tools
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    bash \
    jq \
    make \
    g++ \
    openssl \
    nginx \
    gettext

# -------------------------------------------------------
# Build ODE
# -------------------------------------------------------
WORKDIR /ode
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    echo "[BUILD] ODE commit: $(git rev-parse --short HEAD)"

# Install pnpm (corepack is not available in Alpine's nodejs package)
RUN npm install -g pnpm

# Patch vite.config.ts to use a relative base path so Vite emits
# ./assets/... instead of /assets/... in index.html.
# This lets the <base> tag nginx injects at runtime resolve assets
# correctly under HA's dynamic ingress sub-path.
RUN grep -q "base: './'" vite.config.ts \
    || sed -i "s/defineConfig({/defineConfig({\n    base: '.\/',/" vite.config.ts \
    && echo "[BUILD] Patched vite.config.ts with base: ./"

RUN echo "[BUILD] Installing dependencies..." && \
    pnpm install --no-frozen-lockfile && \
    echo "[BUILD] Building ODE..." && \
    pnpm run build && \
    echo "[BUILD] ODE built successfully"

# nginx ingress config template — INGRESS_PATH substituted at startup
COPY ingress.conf.template /etc/nginx/ingress.conf.template

# Startup script
COPY run.sh /
RUN chmod a+x /run.sh

# Ingress port — HA Supervisor connects here
EXPOSE 8099

CMD ["/run.sh"]
