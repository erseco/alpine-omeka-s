# Base image using alpine-php-webserver
ARG ARCH=
FROM ${ARCH}erseco/alpine-php-webserver:3.20.7

LABEL maintainer="Ernesto Serrano <info@ernesto.es>"

# Install system dependencies as root
USER root
RUN apk add --no-cache \
    unzip wget jq ghostscript poppler-utils imagemagick \
    netcat-openbsd php83-pecl-imagick php83-xsl php83-intl php83-xmlwriter composer \
    && rm -rf /var/cache/apk/*

# Omeka S version configuration
ARG OMEKA_VERSION=develop

# Default environment variables
ENV APPLICATION_ENV=production \
    memory_limit=512M \
    upload_max_filesize=64M \
    post_max_size=64M \
    max_execution_time=300

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
    curl -L "$OMEKA_S_URL" | tar xz --strip-components=1 -C /var/www/html/ && \
    \
    # 2. Create the volume structure for persistent data
    mkdir -p /var/www/html/volume/config \
             /var/www/html/volume/files \
             /var/www/html/volume/modules \
             /var/www/html/volume/themes \
             /var/www/html/volume/logs && \
    \
    # 3. Create symbolic links to the volume directories
    rm -rf /var/www/html/config \
           /var/www/html/files \
           /var/www/html/modules \
           /var/www/html/themes \
           /var/www/html/logs && \
    cd /var/www/html && \
    ln -s volume/config . && \
    ln -s volume/files . && \
    ln -s volume/modules . && \
    ln -s volume/themes . && \
    ln -s volume/logs . && \
    \
    # 4. Set final permissions
    chown -R nobody:nobody /var/www/html/volume /var/www/html

# Copy custom entrypoint scripts
COPY --chown=nobody rootfs/ /

# Switch to non-privileged user
USER nobody

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction