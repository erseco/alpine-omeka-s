#!/bin/sh
set -eu

# --- Functions ---

check_db_availability() {
    local db_host="$1"
    local db_port="$2"
    echo "Waiting for $db_host:$db_port to be ready..."
    while ! nc -w 1 "$db_host" "$db_port" >/dev/null 2>&1; do
        echo -n '.'
        sleep 1
    done
    echo "\nDatabase $db_host:$db_port is ready."
}

configure_database_ini() {
    local config_file="/var/www/html/volume/config/database.ini"

    if [ -n "${DB_USER:-}" ] || [ -n "${DB_PASSWORD:-}" ] || \
       [ -n "${DB_NAME:-}" ] || [ -n "${DB_HOST:-}" ]; then
        echo "Configuring $config_file from environment variables..."
        {
            echo "user     = ${DB_USER:-}"
            echo "password = ${DB_PASSWORD:-}"
            echo "dbname   = ${DB_NAME:-}"
            echo "host     = ${DB_HOST:-}"
            echo "port     = ${DB_PORT:-3306}"
            [ -n "${MYSQL_UNIX_PORT:-}" ] && echo "unix_socket = $MYSQL_UNIX_PORT" || echo ";unix_socket ="
            [ -n "${MYSQL_LOG_PATH:-}" ] && echo "log_path = $MYSQL_LOG_PATH" || echo ";log_path ="
        } > "$config_file"
    else
        echo "No database env vars found. Skipping database.ini generation."
        return
    fi

    chmod 600 "$config_file"
    chown nobody:nobody "$config_file"
}

install_items_from_names() {
    local kind="$1"
    local names="$2"

    [ -z "$names" ] && echo "No $kind to install. Skipping." && return

    for name in $names; do
        [ -z "$name" ] && continue
        echo "Processing $name..."

        if [ "$kind" = "modules" ]; then
            if omeka-s-cli module:download "$name" --install; then
                echo "Module installed successfully: $name"
            else
                echo "ERROR: Failed to download and install module: $name" >&2
            fi
        elif omeka-s-cli theme:download "$name"; then
            echo "Theme downloaded successfully: $name"
        else
            echo "ERROR: Failed to download theme: $name" >&2
        fi
    done
}

# Ensure a module is present (download+install if missing).
ensure_module() {
    local name="$1"
    if omeka-s-cli module:list | awk '{print $2}' | grep -qx "$name"; then
        echo "Module already installed: $name"
        return 0
    fi
    echo "Installing module: $name"
    omeka-s-cli module:download "$name" --install
}

# Install Omeka S only if required environment variables are set and not empty
install_omeka() {
    [ -z "${OMEKA_ADMIN_EMAIL:-}" ] && return
    [ -z "${OMEKA_ADMIN_PASSWORD:-}" ] && return
    [ -z "${OMEKA_SITE_TITLE:-}" ] && return

    if omeka-s-cli core:status --is-installed; then
        echo "Omeka S is already installed."
        return
    fi

    echo "Installing Omeka S via CLI..."
    omeka-s-cli core:install \
        --admin-email "$OMEKA_ADMIN_EMAIL" \
        --admin-name "${OMEKA_ADMIN_NAME:-Site Administrator}" \
        --admin-password "$OMEKA_ADMIN_PASSWORD" \
        --title "$OMEKA_SITE_TITLE" \
        --time-zone "${OMEKA_TIMEZONE:-UTC}" \
        --locale "${OMEKA_LOCALE:-en_US}"
}

# Automatically import data from a CSV file, if provided
import_from_csv() {
    [ -z "${OMEKA_CSV_IMPORT_FILE:-}" ] && return

    echo "CSV file specified: $OMEKA_CSV_IMPORT_FILE. Preparing for import..."

    # Check if the import file exists
    if [ ! -f "$OMEKA_CSV_IMPORT_FILE" ]; then
        echo "WARNING: CSV import file not found: $OMEKA_CSV_IMPORT_FILE. Skipping."
        return
    fi

    # Ensure the CSVImport module is installed
    ensure_module "CSVImport"

    echo "Starting CSV import from $OMEKA_CSV_IMPORT_FILE..."
    if php import_cli.php "$OMEKA_CSV_IMPORT_FILE"; then
        echo "CSV import completed successfully."
    else
        echo "WARNING: CSV import failed. Please check the logs for details."
    fi
}

# --- Main Execution ---

echo "=== Omeka S Entrypoint start ==="

[ -n "${DB_HOST:-}" ] && check_db_availability "$DB_HOST" "${DB_PORT:-3306}"

# Execute pre-configure commands if the variable is set
if [ -n "${PRE_CONFIGURE_COMMANDS:-}" ]; then
    echo "Executing pre-configure commands..."
    eval "$PRE_CONFIGURE_COMMANDS"
fi

configure_database_ini

install_omeka

install_items_from_names "themes" "${OMEKA_THEMES:-}"
install_items_from_names "modules" "${OMEKA_MODULES:-}"

import_from_csv

# Execute post-configure commands if the variable is set
if [ -n "${POST_CONFIGURE_COMMANDS:-}" ]; then
    echo "Executing post-configure commands..."
    eval "$POST_CONFIGURE_COMMANDS"
fi

echo "=== Omeka S Entrypoint completed ==="
exec "$@"
