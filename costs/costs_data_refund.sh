#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 year month"
    echo
    echo "Computes the AWS DataTransfer-Out refund for the given month."
    exit
fi

cd $(dirname $0)
mkdir -p data

year_start=${1##0}
year_end=$year_start
month_start=${2##0}
month_end=$((month_start + 1))
if ((month_end == 13)); then
    ((year_end++))
    month_end=1
fi

start=$(printf "%d-%02d-01" $year_start $month_start)
end=$(printf "%d-%02d-01" $year_end $month_end)
data_path=$(printf "data/datatransfer-out-%d-%02d.json" $year_start $month_start )

if [ ! -e $data_path ]; then
    echo "Retrieving cost-and-usage report from AWS..." > /dev/stderr
    aws \
        --profile sudo \
        ce \
        get-cost-and-usage \
        --time-period Start=$start,End=$end \
        --granularity MONTHLY \
        --metrics BlendedCost UnblendedCost AmortizedCost \
        --filter file://filter_datatransfer_out.json \
        > $data_path
fi

# Factor of 0.88 accounts for 12% EDP discount.
jq '.ResultsByTime[-1].Total.AmortizedCost.Amount | tonumber | .* 0.88' < $data_path
