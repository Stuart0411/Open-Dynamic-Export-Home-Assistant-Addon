FROM ghcr.io/longzheng/open-dynamic-export:latest

# Install bash and jq for Home Assistant integration
RUN apk add --no-cache bash jq

# Copy run script
COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
