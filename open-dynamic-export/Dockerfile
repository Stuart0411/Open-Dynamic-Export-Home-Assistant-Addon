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

RUN pnpm install --no-frozen-lockfile && \
    pnpm run build && \
    echo "[BUILD] ODE built successfully"

# nginx serves static UI files directly from dist/ui/ on port 8099.
# API calls (/api/*) are proxied to ODE's Node.js server on port 3000.
# This avoids all sub_filter/base-tag complexity and works with Nabu Casa.
COPY ingress.conf.template /etc/nginx/http.d/ingress.conf

COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8099
CMD ["/run.sh"]
