# Use Home Assistant base image
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Set environment variables
ENV LANG=C.UTF-8

# Install Node.js, Python, and build tools
RUN apk add --no-cache \
    nodejs=16.20.0 \
    npm \
    git \
    bash \
    jq \
    python3 \
    py3-pip \
    make \
    g++ \
    curl

# -------------------------------
# Build ODE backend and frontend
# -------------------------------
WORKDIR /ode
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    npm ci && \
    npm run build && \
    echo "[BUILD] ODE built successfully" && \
    ls -la dist/assets && \
    test -f dist/assets/index-DmTm1MAP.css && \
    test -f dist/assets/index-j2rvzFcy.js

# -------------------------------
# Set up Python virtual environment for Flask
# -------------------------------
WORKDIR /app
COPY requirements.txt ./

# Create virtual environment and install dependencies inside it
RUN python3 -m venv /venv \
    && . /venv/bin/activate \
    && pip install --no-cache-dir -r requirements.txt

# Add venv to PATH so Python and pip use the virtual environment
ENV PATH="/venv/bin:$PATH"

# Copy Flask app
COPY app.py ./

# Copy startup script
COPY run.sh /
RUN chmod a+x /run.sh

# Validate asset copy
COPY dist /ode/dist

# -------------------------------
# Health Check
# -------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s \
    CMD curl -f http://localhost:${PORT:-8099}/health || exit 1

# -------------------------------
# Entrypoint
# -------------------------------
ENTRYPOINT ["/run.sh"]
