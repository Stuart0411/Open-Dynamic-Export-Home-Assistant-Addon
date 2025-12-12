ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Node.js and dependencies (Alpine Linux uses apk)
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    bash \
    jq

# Verify Node.js installation
RUN node --version && npm --version

# Clone and build Open Dynamic Export
WORKDIR /app
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    npm ci && \
    npm run build && \
    echo "Build complete. Checking output:" && \
    ls -la && \
    ls -la dist/ || echo "No dist folder" && \
    ls -la dist/src/ || echo "No dist/src folder"

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

# Expose port
EXPOSE 3000

WORKDIR /app

# Run
CMD ["/run.sh"]
