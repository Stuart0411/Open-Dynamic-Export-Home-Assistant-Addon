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
    nginx

WORKDIR /ode

RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    echo "[BUILD] ODE commit: $(git rev-parse --short HEAD)"

RUN npm install -g pnpm

# Patch vite.config.ts AND build in the same RUN layer so they cannot be
# cached independently — the patch must always precede the build.
RUN grep -q "base: './'" vite.config.ts \
        || sed -i "s/defineConfig({/defineConfig({\n    base: '.\/',/" vite.config.ts \
    && echo "[BUILD] Patched vite.config.ts with base: ./" \
    && pnpm install --no-frozen-lockfile \
    && pnpm run build \
    && echo "[BUILD] Build complete"

# Patch dist/ui/index.html with ingress compatibility script at build time.
# Uses .cjs extension so Node treats it as CommonJS (ODE package.json has "type":"module").
COPY patch-index.cjs /patch-index.cjs
RUN node /patch-index.cjs

COPY ingress.conf.template /etc/nginx/ingress.conf.template
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8099
CMD ["/run.sh"]
