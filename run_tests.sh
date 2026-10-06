#!/usr/bin/env sh
set -e
apk --no-cache add curl

for app in app app-sqlite; do
    echo "Waiting for $app to be ready"
    while ! nc -w 1 "$app" 8080; do
        # Show some progress
        echo -n '.';
        sleep 1;
    done
    echo "$app is ready"
done
# Give it another 3 seconds.
sleep 3;

# The title comes from the blueprint's settings, applied after the install.
curl --silent --fail http://app:8080 | grep 'Sites · Omeka S Blueprint Site'

# SQLite: installed with no database service, into the volume
curl --silent --fail http://app-sqlite:8080 | grep 'Sites · Omeka S SQLite Site'
test -s /sqlite/db/omeka.db
