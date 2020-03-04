#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 year month"
    echo
    echo "Generates a report of AWS costs by service, with no project tag,"
    echo "for the given month."
    exit
fi

cd $(dirname $0)
mkdir -p data

year_start=$1
year_end=$year_start
month_start=$2
month_end=$((month_start + 1))
if ((month_end == 13)); then
    ((year_end++))
    month_end=1
fi

start=$(printf "%d-%02d-01" $year_start $month_start)
end=$(printf "%d-%02d-01" $year_end $month_end)
data_path=$(
    printf "data/by-service-no-project-%d-%02d.json" $year_start $month_start
)

if [ ! -e $data_path ]; then
    echo "Retrieving cost-and-usage report from AWS..." > /dev/stderr
    aws \
        --profile sudo \
        ce \
        get-cost-and-usage \
        --time-period Start=$start,End=$end \
        --granularity MONTHLY \
        --metrics BlendedCost UnblendedCost AmortizedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --filter file://filter_no_project.json \
        > $data_path
fi

echo 'Service,Cost'
jq \
    -r \
    '
    .ResultsByTime[0].Groups
    | map([
        (.Keys[0]),
        (.Metrics.AmortizedCost.Amount | tonumber)
    ])
    | .[]
    | @csv
    ' \
    < $data_path
