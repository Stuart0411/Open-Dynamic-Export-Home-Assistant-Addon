
# Use Home Assistant base image
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Set environment variables
ENV LANG=C.UTF-8

# Install Node.js, Python, and build tools
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    bash \
    jq \
    python3 \
    py3-pip \
    make \
    g++

# -------------------------------
# Build ODE backend and frontend
# -------------------------------
WORKDIR /ode
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    npm ci && \
    npm run build  # Builds both backend and React UI (dist folder)

# -------------------------------
# Set up Flask ingress interface
# -------------------------------
WORKDIR /app
COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy Flask app and templates
COPY app.py ./

# Copy startup script
COPY run.sh /
RUN chmod a+x /run.sh

