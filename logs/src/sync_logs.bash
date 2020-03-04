set -e

cd "$(dirname $0)/.."

acct="292075781285"
input="input"
opts="--no-check-md5 -v"

s3cmd sync \
      "s3://cloudtrail-$acct/AWSLogs/$acct/CloudTrail/us-east-1/" \
      "$input"/cloudtrail/ \
      $opts

s3cmd sync \
      "s3://config-$acct/AWSLogs/$acct/Config/us-east-1/" \
      "$input"/config/ \
      $opts
