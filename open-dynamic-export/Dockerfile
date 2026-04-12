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

# Remove any default nginx configs that might intercept our requests
RUN rm -f /etc/nginx/http.d/default.conf /etc/nginx/conf.d/default.conf

# Our nginx config — serves static UI files directly, proxies /api/* to ODE
COPY ingress.conf.template /etc/nginx/http.d/ingress.conf

COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8099
CMD ["/run.sh"]
