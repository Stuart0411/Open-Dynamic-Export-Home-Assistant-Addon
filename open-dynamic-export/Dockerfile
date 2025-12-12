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
    jq \
    python3 \
    make \
    g++

# Verify Node.js installation
RUN node --version && npm --version

# Clone Open Dynamic Export
WORKDIR /app
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    echo "Repository cloned. Contents:" && \
    ls -la

# Install ALL dependencies (including dev dependencies for building)
RUN npm ci && \
    echo "Dependencies installed. Checking for TypeScript:" && \
    npx tsc --version || echo "TypeScript not found"

# Build the project
RUN npm run build && \
    echo "Build command completed. Checking output:" && \
    ls -la && \
    if [ -d "dist" ]; then \
        echo "dist folder exists:" && \
        ls -la dist/ && \
        if [ -d "dist/src" ]; then \
            echo "dist/src exists:" && \
            ls -la dist/src/ && \
            if [ -f "dist/src/index.js" ]; then \
                echo "SUCCESS: Entry point found at dist/src/index.js"; \
            else \
                echo "ERROR: dist/src/index.js not found" && exit 1; \
            fi; \
        else \
            echo "ERROR: dist/src folder not found" && exit 1; \
        fi; \
    else \
        echo "ERROR: dist folder not created" && exit 1; \
    fi

# Create .env file for ODE
RUN echo "SERVER_PORT=3000" > /app/.env && \
    echo "SERVER_HOST=0.0.0.0" >> /app/.env && \
    cat /app/.env

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

# Expose port
EXPOSE 3000

WORKDIR /app

# Run
CMD ["/run.sh"]
