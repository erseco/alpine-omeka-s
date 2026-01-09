#!/bin/sh
set -eu

# Configure OPcache based on environment variables
# This script runs before other entrypoint scripts to set up OPcache configuration

echo "=== Configuring OPcache ==="

# Determine OPcache configuration directory
# Detect PHP version dynamically, fallback to php84 if detection fails
PHP_VERSION=$(php -r "echo 'php' . PHP_MAJOR_VERSION . PHP_MINOR_VERSION;" 2>/dev/null || echo "php84")
PHP_CONF_DIR="/etc/${PHP_VERSION}/conf.d"
OPCACHE_INI="${PHP_CONF_DIR}/opcache.ini"

# Check if we should configure OPcache for development
DEVELOPMENT_MODE=false

# Option 1: Explicit OPCACHE_ENABLE variable
if [ "${OPCACHE_ENABLE:-}" = "0" ]; then
    echo "OPCACHE_ENABLE=0 detected. Enabling OPcache timestamp validation for development."
    DEVELOPMENT_MODE=true
fi

# Option 2: APPLICATION_ENV=development
if [ "${APPLICATION_ENV:-production}" = "development" ]; then
    echo "APPLICATION_ENV=development detected. Configuring OPcache for development."
    DEVELOPMENT_MODE=true
fi

# Configure OPcache based on the determined setting
if [ "$DEVELOPMENT_MODE" = "true" ]; then
    echo "Setting OPcache for development mode (validate timestamps on every request)"
    cat > "$OPCACHE_INI" <<EOF
; OPcache configuration for development
opcache.enable=1
opcache.enable_cli=1
opcache.validate_timestamps=1
opcache.revalidate_freq=0
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.fast_shutdown=1
EOF
else
    echo "Using production OPcache settings (no timestamp validation for maximum performance)"
    cat > "$OPCACHE_INI" <<EOF
; OPcache configuration for production
opcache.enable=1
opcache.enable_cli=1
opcache.validate_timestamps=0
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.fast_shutdown=1
EOF
fi

echo "OPcache configuration written to $OPCACHE_INI"
echo "=== OPcache configuration completed ==="
