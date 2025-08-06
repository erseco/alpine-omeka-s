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

get_github_zip_url() {
    local repo_url="$1"
    local clean_url=$(echo "$repo_url" | sed 's|/*$||')
    local owner repo api_url download_url

    owner=$(echo "$clean_url" | sed -n 's|https://github.com/\([^/]*\)/\([^/]*\)$|\1|p')
    repo=$(echo "$clean_url" | sed -n 's|https://github.com/\([^/]*\)/\([^/]*\)$|\2|p')

    if [ -z "$owner" ] || [ -z "$repo" ]; then
        echo "ERROR: Invalid GitHub URL: $repo_url" >&2
        return 1
    fi

    api_url="https://api.github.com/repos/$owner/$repo/releases/latest"
    download_url=$(curl -s "$api_url" | jq -r '.assets[] | select(.name | endswith(".zip")) | .browser_download_url' | head -n1)

    [ -n "$download_url" ] && [ "$download_url" != "null" ] && echo "$download_url" || {
        echo "ERROR: No ZIP found for $repo_url" >&2
        return 1
    }
}

process_download() {
    local url="$1"
    local type="$2"

    case "$url" in
        *.zip) echo "$url" ;;
        https://github.com/*) get_github_zip_url "$url" ;;
        *)
            echo "ERROR: Unsupported $type URL: $url" >&2
            return 1
            ;;
    esac
}

install_items_from_urls() {
    local kind="$1"
    local env_var="$2"
    local base_path="/var/www/html/volume/$kind"
    local urls value resolved name item_dir tmp_dir

    value=$(eval "echo \${$env_var:-}")
    [ -z "$value" ] && echo "No $kind URLs provided. Skipping." && return

    tmp_dir=$(mktemp -d)
    # echo "$value" | while IFS= read -r url; do
    for url in $value; do

        [ -z "$url" ] && continue

        resolved=$(process_download "$url" "$kind") || continue
        echo "Resolved $kind URL: $resolved"

        name=$(basename "$resolved" .zip | sed 's/^theme-//' | sed 's/^module-//')
        item_dir="$base_path/$name"

        [ -d "$item_dir" ] && echo "$kind '$name' already exists. Skipping." && continue

        curl -sL "$resolved" -o "$tmp_dir/item.zip" || {
            echo "ERROR: Failed downloading $kind from $resolved" >&2
            continue
        }

        unzip -oq "$tmp_dir/item.zip" -d "$base_path"
    done

    rm -rf "$tmp_dir"
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

# --- Main Execution ---

echo "=== Omeka S Entrypoint start ==="

[ -n "${DB_HOST:-}" ] && check_db_availability "$DB_HOST" "${DB_PORT:-3306}"

configure_database_ini

install_items_from_urls "themes" "OMEKA_THEMES"
install_items_from_urls "modules" "OMEKA_MODULES"

install_omeka

echo "=== Omeka S Entrypoint completed ==="
exec "$@"
