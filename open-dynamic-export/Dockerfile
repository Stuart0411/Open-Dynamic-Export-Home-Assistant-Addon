ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Install Node.js, nginx, and build tools
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    bash \
    jq \
    make \
    g++ \
    openssl \
    nginx

# -------------------------------------------------------
# Build ODE
# -------------------------------------------------------
WORKDIR /ode
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    echo "[BUILD] ODE commit: $(git rev-parse --short HEAD)"

# Install pnpm (corepack is not available in Alpine's nodejs package)
RUN npm install -g pnpm

# Patch vite.config.ts to use base: './' so Vite emits relative asset paths
RUN grep -q "base: './'" vite.config.ts \
    || sed -i "s/defineConfig({/defineConfig({\n    base: '.\/',/" vite.config.ts \
    && echo "[BUILD] Patched vite.config.ts with base: ./"

RUN echo "[BUILD] Installing dependencies..." && \
    pnpm install --no-frozen-lockfile && \
    echo "[BUILD] Building ODE..." && \
    pnpm run build && \
    echo "[BUILD] ODE built successfully"

# Patch dist/ui/index.html with ingress compatibility script at build time.
# This is more reliable than nginx sub_filter which silently fails on chunked
# or compressed HTTP responses. The script self-detects the ingress path from
# window.location.pathname at runtime so no nginx magic is needed.
COPY patch-index.cjs /ode/patch-index.js
RUN node /ode/patch-index.cjs

# nginx ingress proxy config (simple reverse proxy, no sub_filter needed)
COPY ingress.conf.template /etc/nginx/ingress.conf.template

# Startup script
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8099
CMD ["/run.sh"]
