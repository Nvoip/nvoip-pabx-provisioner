#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh -n "$root_dir/bin/nvoip-pabx-provisioner"
sh -n "$root_dir/lib/common.sh"
sh -n "$root_dir/lib/detect.sh"
sh -n "$root_dir/lib/render.sh"
sh -n "$root_dir/lib/validate.sh"
sh -n "$root_dir/scripts/install.sh"
sh -n "$root_dir/scripts/package.sh"
sh -n "$root_dir/scripts/aws/create-asterisk-ec2.sh"
sh -n "$root_dir/scripts/aws/create-freeswitch-ec2.sh"
sh -n "$root_dir/scripts/aws/run-asterisk-test.sh"
sh -n "$root_dir/scripts/aws/run-freeswitch-test.sh"
sh -n "$root_dir/scripts/aws/user-data-asterisk.sh"
sh -n "$root_dir/scripts/aws/user-data-freeswitch.sh"

"$root_dir/bin/nvoip-pabx-provisioner" provision \
  --engine asterisk \
  --trunk-user "1000" \
  --trunk-password "secret" \
  --dry-run >/dev/null

"$root_dir/bin/nvoip-pabx-provisioner" provision \
  --engine issabel \
  --asterisk-driver chan_sip \
  --trunk-user "1000" \
  --trunk-password "secret" \
  --dry-run >/dev/null

"$root_dir/bin/nvoip-pabx-provisioner" provision \
  --engine freeswitch \
  --trunk-user "1000" \
  --trunk-password "secret" \
  --apply-test-routing \
  --dry-run >/dev/null

printf 'ok\n'
