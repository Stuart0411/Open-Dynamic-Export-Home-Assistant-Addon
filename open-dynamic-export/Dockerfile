ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Install dependencies
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    bash \
    nginx \
    make \
    g++

# Build ODE backend
WORKDIR /ode
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    npm ci && \
    npm run build && \
    echo "[BUILD] ODE built successfully"

# Configure Nginx
COPY ingress.conf /etc/nginx/http.d/ingress.conf
RUN rm /etc/nginx/http.d/default.conf

# Copy startup script
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8099

CMD ["/run.sh"]
