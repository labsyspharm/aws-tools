set -e

year="$1"
month="$2"
# Should use getopts here.
if [[ -z "$3" ]]; then
    true #pass
elif [[ "$3" == "-a" ]]; then
    show_all=1
else
    opt_error=1
fi

if [[ -z "$year" || -z "$month" || -n "$opt_error" ]]; then
    echo "Usage: $(basename $0) <year> <month> [-a]"
    exit 1
fi

cd "$(dirname $0)/.."

# Normalize month to two-digits, zero-padded.
month=$(printf %02d "${month##0}")

cloudtrail_path="input/cloudtrail/$year/$month"
# Config paths use non-zero-padded months!
config_path="input/config/$year/${month##0}"

# Verify logs are present.
if [ ! -d "$cloudtrail_path" ]; then
    echo "No CloudTrail logs for $year/$month (looking in $cloudtrail_path)"
    logs_missing=1
fi
if [ ! -d "$config_path" ]; then
    echo "No Config logs for $year/$month (looking in $config_path)"
    logs_missing=1
fi
if [ -n "$logs_missing" ]; then
    exit 1
fi

# Explanation of jq options:
# -s: Slurp a stream of objects into a list.
# -r: Raw output (we want to emit actual TSV, not JSON-quoted strings).
# --argjson show_all....: Pass this script's -a option through to the jq code
#     as the boolean "show_all".
# --slurpfile configlog...: Load the config log data as $configlog.

# jq was behaving oddly when using the simpler "find | xargs gunzip -c | jq -r",
# which is unfortunate as it's much faster than invoking gunzip once for each
# file as below. The extra newlines aded by the "echo" are required to fix the
# odd jq behavior.

(for f in $(find "$cloudtrail_path" -name '*.json.gz'); do
     gunzip -c "$f"; echo;
 done) |
    jq -s \
        --argjson show_all "${show_all:-false}" \
        --slurpfile configlog \
        <(for f in $(find "$config_path" -name '*.json.gz'); do
              gunzip -c "$f"; echo;
          done) \
'
# Build a mapping from instanceId to key instance details.
map(
  .Records
  | .[]
  | select(.eventName=="RunInstances")
  | .userIdentity.userName as $userName
  | .eventTime as $eventTime
  | .responseElements.instancesSet.items
  | .[]?
  | {instanceId, instanceType, $userName, $eventTime}
)
| sort_by([.userName, .eventTime])
| reduce .[] as $i ({}; . + {($i.instanceId): $i})
| . as $instances

# Build a mapping from instanceId to the value of the "project" tag if present.
| $configlog
| map(
  .configurationItems
  | .[]
  | select(.resourceType=="AWS::EC2::Instance" and .tags.project)
  | {(.configuration.instanceId): {
      instanceId: .configuration.instanceId,
      project: .tags.project
    }}
)
| reduce .[] as $i ({}; . + $i)

# Hash join the instance details with the "project" tags.
| $instances * .
| .[]
# Filter for untagged instances, unless $show_all is true.
| select(if $show_all then . else (.userName and (.project | not)) end)
' |
    jq -s -r 'sort_by(.eventTime) | .[] | map(.) | @tsv'
