ARG BUILD_FROM
FROM ghcr.io/longzheng/open-dynamic-export:latest

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install bashio for Home Assistant integration
RUN apk add --no-cache bash jq curl

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

# Expose port
EXPOSE 3000

# Run
CMD ["/run.sh"]
