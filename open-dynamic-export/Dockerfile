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

# Patch vite.config.ts with base:'./' AND build in one layer (never cached separately).
# base:'./' makes Vite emit ./assets/... instead of /assets/...
# Relative paths resolve correctly from the ingress URL in the browser.
# Absolute /assets/... would resolve to the HA/Nabu Casa root and 404.
RUN grep -q "base: './'" vite.config.ts \
        || sed -i "s/defineConfig({/defineConfig({\n    base: '.\/',/" vite.config.ts \
    && echo "[BUILD] Patched vite.config.ts with base: ./" \
    && pnpm install --no-frozen-lockfile \
    && pnpm run build \
    && echo "[BUILD] Build complete"

# Patch dist/ui/index.html with fetch interceptor for API calls.
# Placed at / (outside /ode) so ODE's "type":"module" doesn't affect it.
COPY patch-index.cjs /patch-index.cjs
RUN node /patch-index.cjs

# Remove any default nginx configs that might intercept requests
RUN rm -f /etc/nginx/http.d/default.conf /etc/nginx/conf.d/default.conf

# nginx: serve static UI files directly, proxy /api/* to ODE
COPY ingress.conf.template /etc/nginx/http.d/ingress.conf

COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8099
CMD ["/run.sh"]
