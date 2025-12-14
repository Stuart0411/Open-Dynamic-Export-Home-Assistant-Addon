ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Node.js and dependencies
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    bash \
    jq \
    python3 \
    make \
    g++

# Verify versions
RUN node --version && npm --version

# Clone repository
WORKDIR /app
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git .

# Install dependencies and build
RUN npm ci && npm run build

# Set environment variable to allow all hosts
ENV VITE_ALLOWED_HOSTS="all"

# Create .env file
RUN echo "SERVER_PORT=3000" > /app/.env && \
    echo "SERVER_HOST=0.0.0.0" >> /app/.env && \
    echo "TZ=UTC" >> /app/.env && \
    echo "CONFIG_DIR=/data" >> /app/.env && \
    echo "SEP2_CERT_FILE=/app/config/sep2-cert.pem" >> /app/.env && \
    echo "SEP2_KEY_FILE=/app/config/sep2-key.pem" >> /app/.env && \
    echo "SEP2_PEN=12345" >> /app/.env && \
    cat /app/.env

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 3000
WORKDIR /app

CMD ["/run.sh"]
