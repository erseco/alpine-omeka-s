#!/bin/sh
#
# apply-sqlite-support.sh <OMEKA_VERSION>
#
# Build-time helper, as in erseco/alpine-moodle: patches the Omeka S tree in the
# current directory with the experimental SQLite support of the
# ateeducacion/omeka-s fork. Each PR targets its own branch:
#   develop -> PR #2 (targets develop)
#   v4.2.x  -> PR #5 (targets release-4.2)
#   v4.1.x  -> PR #4 (targets release-4.1)
# Other versions are left as they are, without SQLite (not an error).
#
# Unlike alpine-moodle, a hunk that does not apply fails the build: these patches
# also change code that MySQL runs (e.g. a `use` line in application/Module.php),
# so a half-applied patch could break MySQL installs too. --fuzz=3 is needed for
# v4.2.0, whose Module.php differs from release-4.2 next to that line.
set -euo pipefail

case "${1:?usage: apply-sqlite-support.sh <OMEKA_VERSION>}" in
  develop) pr=2 ;;
  v4.2.*) pr=5 ;;
  v4.1.*) pr=4 ;;
  *)
    echo "No SQLite patch for OMEKA_VERSION=$1: DB_DRIVER=pdo_sqlite will not be available."
    exit 0
    ;;
esac

url="https://github.com/ateeducacion/omeka-s/pull/$pr.diff"
echo "Applying SQLite support from $url"
curl -fsSL --retry 5 --retry-all-errors "$url" | patch -p1 --forward --fuzz=3 --no-backup-if-mismatch
