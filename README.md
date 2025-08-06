# Omeka S on Alpine Linux

[![Docker Pulls](https://img.shields.io/docker/pulls/erseco/alpine-omeka-s.svg)](https://hub.docker.com/r/erseco/alpine-omeka-s/)
![Docker Image Size](https://img.shields.io/docker/image-size/erseco/alpine-omeka-s)
![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

A lightweight and secure Omeka S setup for Docker, built on Alpine Linux. This image is optimized for performance and size, making it an ideal choice for development and production environments.

Repository: https://github.com/erseco/alpine-omeka-s

## Key Features

- **Lightweight:** Built on the `erseco/alpine-php-webserver` base image for a minimal footprint (+/- 70MB).
- **Performant:** Uses PHP-FPM with an `ondemand` process manager to optimize resource usage.
- **Secure:** Services run under a non-privileged user (`nobody`). Logs are directed to the container's STDOUT.
- **Multi-Arch Support:** `amd64`, `arm/v6`, `arm/v7`, `arm64`, `ppc64le`, `s390x`.
- **Configurable:** Easily configure the container using environment variables.
- **Extensible:** Automatically install themes and modules on startup.
- **Simple & Transparent:** Follows the KISS principle for easy understanding and customization.

## Usage

Here is a minimal `docker-compose.yml` example to get you started:

```yaml
---
services:
  mariadb:
    image: mariadb:lts
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=omeka_s
      - MYSQL_DATABASE=omeka_s
      - MYSQL_USER=omeka_s
      - MYSQL_PASSWORD=omeka_s
    volumes:
      - mariadb_data:/var/lib/mysql

  omeka-s:
    image: erseco/alpine-omeka-s:latest
    build:
      context: .
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      # Omeka S Installation Details
      OMEKA_ADMIN_EMAIL: admin@example.com
      OMEKA_ADMIN_PASSWORD: PLEASE_CHANGEME
      OMEKA_SITE_TITLE: "My Omeka S Site"
      # Database Connection
      DB_HOST: mariadb
      DB_NAME: omeka_s
      DB_USER: omeka_s
      DB_PASSWORD: omeka_s
    volumes:
      - omeka_data:/var/www/html/volume
    depends_on:
      - mariadb

volumes:
  mariadb_data: null
  omeka_data: null
```

To start the services, run:
```bash
docker compose up
```
Once the container is running, Omeka S will be installed and accessible at `http://localhost:8080`.

## Configuration

You can configure the container using the following environment variables in your `docker-compose.yml` file.

### Omeka S Installation

| Variable Name          | Description                                | Default      |
|------------------------|--------------------------------------------|--------------|
| `OMEKA_ADMIN_EMAIL`    | Email for the primary administrator user.  | `null`       |
| `OMEKA_ADMIN_PASSWORD` | Password for the administrator.            | `null`       |
| `OMEKA_SITE_TITLE`     | Public title of the Omeka S site.          | `null`       |
| `OMEKA_ADMIN_NAME`     | Name of the administrator.                 | `Site Administrator` |
| `OMEKA_TIMEZONE`       | Installation timezone (e.g., `America/New_York`). | `UTC`        |
| `OMEKA_LOCALE`         | Interface locale for the installation.     | `en_US`      |

**Note:** The Omeka S installation will only run if `OMEKA_ADMIN_EMAIL`, `OMEKA_ADMIN_PASSWORD`, and `OMEKA_SITE_TITLE` are all set.

### Database Connection

| Variable Name   | Description                   | Default   |
|-----------------|-------------------------------|-----------|
| `DB_HOST`       | Database host.                | `null`    |
| `DB_USER`       | Database user.                | `null`    |
| `DB_PASSWORD`   | Database password.            | `null`    |
| `DB_NAME`       | Database name.                | `null`    |
| `DB_PORT`       | Database port.                | `3306`    |

### PHP & Webserver

| Variable Name         | Description                               | Default   |
|-----------------------|-------------------------------------------|-----------|
| `APPLICATION_ENV`     | Set to `development` for debug mode.      | `production` |
| `memory_limit`        | PHP memory limit.                         | `512M`    |
| `upload_max_filesize` | Max size for uploaded files.              | `128M`    |
| `post_max_size`       | Max size of POST data.                    | `128M`    |
| `max_execution_time`  | PHP max execution time in seconds.        | `300`     |

## Advanced Features

### Installing Modules and Themes

You can automatically install modules and themes by providing space-separated URLs in the `OMEKA_MODULES` and `OMEKA_THEMES` environment variables. Both direct `.zip` file URLs and GitHub repository URLs are supported.

```yaml
environment:
  OMEKA_THEMES: "https://github.com/omeka-s-themes/default"
  OMEKA_MODULES: |
    https://github.com/Daniel-KM/Omeka-S-module-Common
    https://github.com/Daniel-KM/Omeka-S-module-EasyAdmin
```

After changing the version, rebuild the image:
```bash
docker compose build omeka-s
```

### Running Commands as Root

If you need to run commands as `root` inside the container (e.g., to install system packages), use `docker compose exec`:

```bash
docker compose exec --user root omeka-s sh
```
