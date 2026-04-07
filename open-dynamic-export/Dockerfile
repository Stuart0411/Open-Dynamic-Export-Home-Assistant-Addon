ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Install Node.js, nginx, and supporting tools
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

# Patch vite.config.ts to use a relative base path.
# This makes Vite emit ./assets/... instead of /assets/... in index.html,
# which allows the <base> tag injected by nginx at runtime to resolve
# assets correctly regardless of the ingress sub-path HA assigns.
RUN grep -q "base: './'" vite.config.ts \
    || sed -i "s/defineConfig({/defineConfig({\n  base: '.\/\',/" vite.config.ts \
    && echo "[BUILD] Patched vite.config.ts with base: ./"

RUN echo "[BUILD] Building ODE..." && \
    npm ci && \
    npm run build && \
    echo "[BUILD] ODE built successfully"

# nginx ingress config template — INGRESS_PATH is substituted at startup
COPY ingress.conf.template /etc/nginx/ingress.conf.template

# Startup script
COPY run.sh /
RUN chmod a+x /run.sh

# Ingress port — HA Supervisor connects here
EXPOSE 8099

CMD ["/run.sh"]
