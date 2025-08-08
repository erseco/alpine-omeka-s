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
| `OMEKA_THEMES`         | List of theme names                        |              |
| `OMEKA_MODULES`        | List of module names                       |              |
| `OMEKA_CSV_IMPORT_FILE`| Path to a CSV file for initial data import.| `null`       |

**Note:** The Omeka S installation will only run if `OMEKA_ADMIN_EMAIL`, `OMEKA_ADMIN_PASSWORD`, and `OMEKA_SITE_TITLE` are all set.

### Automatic CSV Import

If you specify the `OMEKA_CSV_IMPORT_FILE` environment variable, the container will automatically import data from the given CSV file at startup.

**Example:**

```yaml
environment:
  OMEKA_CSV_IMPORT_FILE: /path/to/your/data.csv
```

The CSV file should be mounted into the container. For example, you can add this to your `docker-compose.yml`:

```yaml
volumes:
  - ./my-data.csv:/path/to/your/data.csv
```

**CSV Format Recommendations:**

*   **Encoding:** The file must be UTF-8 encoded.
*   **Headers:** Use headers that match Omeka S properties, like `dcterms:title`, `dcterms:creator`, etc., for automatic mapping.
*   For more details, refer to the official [Omeka S CSV Import documentation](https://omeka.org/s/docs/user-manual/modules/csvimport/).

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

This image includes the [Omeka-S-CLI](https://github.com/GhentCDH/Omeka-S-Cli) tool, which simplifies the management of modules and themes. You can automatically install them by providing space-separated names in the `OMEKA_MODULES` and `OMEKA_THEMES` environment variables.

**Example:**
```yaml
environment:
  OMEKA_THEMES: "default"
  OMEKA_MODULES: "Common EasyAdmin"
```

### Advanced Management with `omeka-s-cli`

For more advanced tasks, you can use `omeka-s-cli` directly within the container. This allows you to list, install, uninstall, and manage modules and themes.

**Example Commands:**

*   **List all installed modules:**
    ```bash
    docker compose exec omeka-s omeka-s-cli module:list
    ```

*   **Install a new theme:**
    ```bash
    docker compose exec omeka-s omeka-s-cli theme:download foundation
    ```

After changing the version, rebuild the image:
```bash
docker compose build omeka-s
```


### Automatic CSV Import (`OMEKA_CSV_IMPORT_FILE`)

If you set `OMEKA_CSV_IMPORT_FILE`, the container will import data at startup using the **CSVImport** module and the bundled `import_cli.php`. The importer is configured as an **upsert**:

- If an item with the same **title** (`dcterms:title`) already exists, it will be **updated**.
- If not found, a **new item** will be **created**.

#### How to enable

```yaml
services:
  omeka-s:
    environment:
      # ...
      OMEKA_CSV_IMPORT_FILE: /data/sample_data.csv
    volumes:
      - ./data:/data:ro
````

> The entrypoint ensures the `CSVImport` module is present and runs the import once on startup.
> The importer makes a **temporary copy** of your CSV before dispatching the job, so your original file is not deleted.

#### Expected CSV format

* **Encoding:** UTF-8 (no BOM).
* **Delimiter:** `,` (comma).
* **Quote:** `"` (double quote).
* **Escape:** `\` (backslash).
* **Header row:** required.

Minimum headers supported by the default mapping included in this image:

| Column Name           | Required | Purpose                                                         |
| --------------------- | -------- | --------------------------------------------------------------- |
| `dcterms:title`       | Yes      | Used as the **identifier** for upsert (update vs create).       |
| `dcterms:creator`     | No       | Creator (example mapping).                                      |
| `dcterms:description` | No       | Description (example mapping).                                  |
| `media_url`           | No       | A direct URL to a media file; ingested with the `url` ingester. |

**Upsert behavior:**

* Action: `update`
* Identifier property: `dcterms:title`
* If no match by title: `create`

If multiple items share the same title, the module’s default lookup can update the first match. Prefer unique titles for deterministic results.

#### Example CSV

```csv
dcterms:title,dcterms:creator,dcterms:description,media_url
Eiffel Tower,Gustave Eiffel,"A wrought-iron lattice tower in Paris, France.",https://upload.wikimedia.org/wikipedia/commons/a/a8/Tour_Eiffel_Wikimedia_Commons.jpg
Mona Lisa,Leonardo da Vinci,"A portrait painting by the Italian Renaissance artist.",https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/Mona_Lisa%2C_by_Leonardo_da_Vinci%2C_from_C2RMF_retouched.jpg/800px-Mona_Lisa%2C_by_Leonardo_da_Vinci%2C_from_C2RMF_retouched.jpg
Statue of Liberty,Frédéric Auguste Bartholdi,"A neoclassical sculpture on Liberty Island, New York Harbor.",https://upload.wikimedia.org/wikipedia/commons/a/a1/Statue_of_Liberty_7.jpg
```

#### What the importer does under the hood

* Loads Omeka S and the `CSVImport` module.
* Authenticates using the admin configured during installation.
* Reads the header row to build the column list.
* Applies a built-in mapping:

  * `dcterms:title` → property id `1`
  * `dcterms:creator` → property id `2`
  * `dcterms:description` → property id `4`
  * `media_url` → ingester `url`
* Dispatches `CSVImport\Job\Import` with:

  * `action=update`
  * `identifier_property=dcterms:title`
  * `action_unidentified=create`
  * batches of `rows_by_batch=20`


### Running Commands as Root

If you need to run commands as `root` inside the container (e.g., to install system packages), use `docker compose exec`:

```bash
docker compose exec --user root omeka-s sh
```
