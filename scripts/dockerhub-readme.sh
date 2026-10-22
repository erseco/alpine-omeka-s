#!/bin/sh
# Prints README.md with the list of image tags between <!-- tags:start --> and
# <!-- tags:end -->: the newest vX.Y.Z of each minor with its floating tags.
# Reads the published versions (one git tag per line) from stdin, and takes
# the tags of the develop image (comma separated) as the second argument:
#   git tag | sh scripts/dockerhub-readme.sh README.md develop,main,beta,4.3 > dockerhub-README.md
set -eu

FLOATING_SINCE=v4.1 # older minors were only published as vX.Y.Z

versions=$(grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -rV)
newest=$(echo "$versions" | head -n 1 | cut -d. -f1,2)

sed '/<!-- tags:start -->/q' "$1"
for minor in $(echo "$versions" | cut -d. -f1,2 | uniq); do
    v=$(echo "$versions" | grep -m 1 -F "$minor.")
    tags="\`$v\`"
    if [ "$(printf '%s\n%s\n' "$FLOATING_SINCE" "$minor" | sort -V | head -n 1)" = "$FLOATING_SINCE" ]; then
        tags="$tags, \`${minor#v}\`"
    fi
    if [ "$minor" = "$newest" ]; then tags="$tags, \`latest\`"; fi
    echo "- $tags"
done
echo "${2:-develop,main,beta}" | sed 's/[^,]*/`&`/g; s/,/, /g; s/^/- /'
sed -n '/<!-- tags:end -->/,$p' "$1"
