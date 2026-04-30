#!/bin/sh
set -eu

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y asterisk curl ca-certificates net-tools tcpdump
apt-get install -y sipp || apt-get install -y sip-tester || true

systemctl enable asterisk
systemctl restart asterisk

cat >/etc/motd <<'EOF'
Nvoip PABX test host

Installed:
- Asterisk
- SIPp
- tcpdump

Copy nvoip-pabx-provisioner to /opt/nvoip-pabx-provisioner and run:
  sudo /opt/nvoip-pabx-provisioner/bin/nvoip-pabx-provisioner detect
EOF
