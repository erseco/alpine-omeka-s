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
# apply-sqlite-support.sh --pr <OMEKA_VERSION> only prints the PR number (empty
# when there is none), so the build workflow can pass the PR head commit as the
# SQLITE_SUPPORT_SHA build arg and rebuild this layer whenever the patch changes.
#
# Unlike alpine-moodle, a hunk that does not apply fails the build: these patches
# also change code that MySQL runs (e.g. a `use` line in application/Module.php),
# so a half-applied patch could break MySQL installs too. --fuzz=3 is needed for
# v4.2.0, whose Module.php differs from release-4.2 next to that line.
set -euo pipefail

print_pr=
if [ "${1:-}" = --pr ]; then
  print_pr=1
  shift
fi

case "${1:?usage: apply-sqlite-support.sh [--pr] <OMEKA_VERSION>}" in
  develop) pr=2 ;;
  v4.2.*) pr=5 ;;
  v4.1.*) pr=4 ;;
  *)
    [ -n "$print_pr" ] && exit 0
    echo "No SQLite patch for OMEKA_VERSION=$1: DB_DRIVER=pdo_sqlite will not be available."
    exit 0
    ;;
esac

if [ -n "$print_pr" ]; then
  echo "$pr"
  exit 0
fi

url="https://github.com/ateeducacion/omeka-s/pull/$pr.diff"
echo "Applying SQLite support from $url"
curl -fsSL --retry 5 --retry-all-errors "$url" | patch -p1 --forward --fuzz=3 --no-backup-if-mismatch
