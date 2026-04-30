#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  scripts/aws/run-asterisk-test.sh --host IP --key-file KEY.pem --trunk-user USER --trunk-password PASS [options]

Options:
  --ssh-user USER              Defaults to ubuntu.
  --trunk-name NAME            Defaults to nvoip-trunk.
  --sip-host HOST              Defaults to sip.nvoip.com.br.
  --external-ip IP             Public IP for Asterisk NAT settings.
  --apply-test-routing         Also create test inbound/outbound routes.
  --validate-sipp              Run SIPp OPTIONS smoke test.

Copies this repository to the EC2 host, provisions Asterisk, reloads it and prints validation output.
EOF
}

host=""
key_file=""
ssh_user="ubuntu"
trunk_user=""
trunk_password=""
trunk_name="nvoip-trunk"
sip_host="sip.nvoip.com.br"
external_ip=""
apply_test_routing=""
validate_sipp=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) host="$2"; shift 2 ;;
    --key-file) key_file="$2"; shift 2 ;;
    --ssh-user) ssh_user="$2"; shift 2 ;;
    --trunk-user) trunk_user="$2"; shift 2 ;;
    --trunk-password) trunk_password="$2"; shift 2 ;;
    --trunk-name) trunk_name="$2"; shift 2 ;;
    --sip-host) sip_host="$2"; shift 2 ;;
    --external-ip) external_ip="$2"; shift 2 ;;
    --apply-test-routing) apply_test_routing="--apply-test-routing"; shift ;;
    --validate-sipp) validate_sipp="--validate-sipp"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
  esac
done

[ -n "$host" ] || { printf 'Missing --host\n' >&2; exit 1; }
[ -n "$key_file" ] || { printf 'Missing --key-file\n' >&2; exit 1; }
[ -n "$trunk_user" ] || { printf 'Missing --trunk-user\n' >&2; exit 1; }
[ -n "$trunk_password" ] || { printf 'Missing --trunk-password\n' >&2; exit 1; }

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
remote_dir="/tmp/nvoip-pabx-provisioner"

ssh_opts="-i $key_file -o StrictHostKeyChecking=accept-new"

ssh $ssh_opts "$ssh_user@$host" "rm -rf '$remote_dir' && mkdir -p '$remote_dir'"
scp $ssh_opts -r "$root_dir"/bin "$root_dir"/lib "$root_dir"/tests "$root_dir"/README.md "$ssh_user@$host:$remote_dir/"

ssh $ssh_opts "$ssh_user@$host" "
  set -eu
  sudo chmod +x '$remote_dir/bin/nvoip-pabx-provisioner'
  sudo '$remote_dir/bin/nvoip-pabx-provisioner' detect
  sudo '$remote_dir/bin/nvoip-pabx-provisioner' provision \
    --engine asterisk \
    --trunk-user '$trunk_user' \
    --trunk-password '$trunk_password' \
    --trunk-name '$trunk_name' \
    --sip-host '$sip_host' \
    ${external_ip:+--external-ip '$external_ip'} \
    $apply_test_routing \
    --apply \
    --validate \
    $validate_sipp
  sudo asterisk -rx 'pjsip show registrations'
  sudo asterisk -rx 'pjsip show endpoint $trunk_name'
"
