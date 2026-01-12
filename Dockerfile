# Base image using alpine-php-webserver
ARG ARCH=
FROM ${ARCH}erseco/alpine-php-webserver:3.23.0

LABEL maintainer="Ernesto Serrano <info@ernesto.es>"

LABEL org.opencontainers.image.source="https://github.com/erseco/alpine-omeka-s" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="Alpine Omeka S"

# Set shell with pipefail for Alpine
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Install system dependencies as root
USER root
RUN apk add --no-cache \
    unzip wget jq ghostscript poppler-utils imagemagick \
    netcat-openbsd php84-pecl-imagick php84-xsl php84-intl php84-xmlwriter composer \
    && rm -rf /var/cache/apk/*

# Omeka S version configuration
ARG OMEKA_VERSION=develop

# Default environment variables
ENV APPLICATION_ENV=production \
    memory_limit=512M \
    upload_max_filesize=128M \
    post_max_size=128M \
    client_max_body_size=128M \
    max_execution_time=300 \
    HOME=/tmp

# Install Omeka-S-CLI
ADD https://github.com/GhentCDH/Omeka-S-Cli/releases/latest/download/omeka-s-cli.phar /usr/local/bin/omeka-s-cli
RUN chmod +x /usr/local/bin/omeka-s-cli

# Set working directory
WORKDIR /var/www/html

# Download, extract, and configure Omeka S in a single layer
RUN set -x && \
    \
    # 1. Download and extract Omeka S
    if [ "$OMEKA_VERSION" = "develop" ]; then \
      OMEKA_S_URL="https://github.com/omeka/omeka-s/archive/develop.tar.gz"; \
    else \
      OMEKA_S_URL="https://github.com/omeka/omeka-s/tarball/refs/tags/${OMEKA_VERSION}"; \
    fi && \
    echo "Downloading Omeka S from: $OMEKA_S_URL" && \
    curl -L "$OMEKA_S_URL" | tar xz --strip-components=1 -C . && \
    \
    # 2. Create the volume structure for persistent data
    mkdir -p volume/config \
             volume/files \
             volume/modules \
             volume/themes \
             volume/logs && \
    \
    # 3. Create symbolic links to the volume directories
    rm -rf config files modules themes logs && \
    ln -s volume/config . && \
    ln -s volume/files . && \
    ln -s volume/modules . && \
    ln -s volume/themes . && \
    ln -s volume/logs . && \
    \
    # 4. Set final permissions
    chown -R nobody:nobody volume . /usr/local/bin/omeka-s-cli

# Copy custom entrypoint scripts
COPY --chown=nobody rootfs/ /

# Switch to non-privileged user
USER nobody

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

HEALTHCHECK --interval=30s --timeout=5s --retries=10 CMD curl -fsS http://127.0.0.1:8080/ >/dev/null || exit 1
