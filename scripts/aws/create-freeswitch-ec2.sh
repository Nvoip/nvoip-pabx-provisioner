#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$script_dir/create-asterisk-ec2.sh" \
  --name "${NVOIP_AWS_NAME:-nvoip-freeswitch-test}" \
  --user-data "$script_dir/user-data-freeswitch.sh" \
  "$@"
