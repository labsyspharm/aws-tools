set -e

if [[ -z "$1" ]]; then
    echo "Usage: $(basename $0) <path> [path2 ...]"
    exit 1
fi

# jq was behaving oddly when using the simpler "find | xargs gunzip -c | jq -r",
# which is unfortunate as it's much faster than invoking gunzip once for each
# file as below. The extra newlines aded by the "echo" are required to fix the
# odd jq behavior.

(for f in $(find "$@" -name '*.json.gz'); do
     gunzip -c "$f"; echo;
 done) |
    jq -s '[ .[] | .Records | .[] ]'
