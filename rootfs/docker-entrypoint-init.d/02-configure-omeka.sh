#!/bin/sh
set -eu

# Check for required tools
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not installed." >&2
    exit 1
fi

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
    fi

    chmod 600 "$config_file"
    chown nobody:nobody "$config_file"
}

install_items_from_names() {
    local kind="$1"
    local env_var="$2"
    local names

    names=$(eval "echo \${$env_var:-}")
    [ -z "$names" ] && echo "No $kind to install. Skipping." && return

    for name in $names; do
        [ -z "$name" ] && continue
        echo "Processing $name..."
        if omeka-s-cli "${kind%s}:download" "$name"; then
            if [ "$kind" = "modules" ]; then
                if omeka-s-cli "${kind%s}:install" "$name"; then
                    echo "$kind installed successfully: $name"
                else
                    echo "ERROR: Failed to install $kind: $name" >&2
                fi
            fi
        else
            echo "ERROR: Failed to download $kind: $name" >&2
        fi
    done
}

# Install Omeka S only if required environment variables are set and not empty
install_omeka() {
    [ -z "${OMEKA_ADMIN_EMAIL:-}" ] && return
    [ -z "${OMEKA_ADMIN_NAME:-}" ] && return
    [ -z "${OMEKA_ADMIN_PASSWORD:-}" ] && return
    [ -z "${OMEKA_SITE_TITLE:-}" ] && return

    echo "Installing Omeka S via CLI..."
    local cmd="php install_cli.php --email=\"$OMEKA_ADMIN_EMAIL\" --name=\"$OMEKA_ADMIN_NAME\" --password=\"$OMEKA_ADMIN_PASSWORD\" --title=\"$OMEKA_SITE_TITLE\""

    [ -n "${OMEKA_TIMEZONE:-}" ] && cmd="$cmd --timezone=\"$OMEKA_TIMEZONE\""
    [ -n "${OMEKA_LOCALE:-}" ] && cmd="$cmd --locale=\"$OMEKA_LOCALE\""

    eval "$cmd"
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
    install_items_from_names "modules" "CSVImport"

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

configure_database_ini

install_omeka

install_items_from_names "themes" "OMEKA_THEMES"
install_items_from_names "modules" "OMEKA_MODULES"

import_from_csv

echo "=== Omeka S Entrypoint completed ==="
exec "$@"
