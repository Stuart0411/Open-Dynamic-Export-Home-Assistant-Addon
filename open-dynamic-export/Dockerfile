ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

# Install Node.js and Python
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

# Build ODE backend
WORKDIR /ode
RUN git clone --depth 1 https://github.com/longzheng/open-dynamic-export.git . && \
    npm ci && \
    npm run build

# Set up Ingress web interface
WORKDIR /app
COPY requirements.txt ./
RUN pip3 install --break-system-packages --no-cache-dir -r requirements.txt

COPY app.py ./
COPY templates/ ./templates/

# Create empty static directory (for future use)
RUN mkdir -p ./static

# Copy startup script
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8099

CMD ["/run.sh"]
