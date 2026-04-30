#!/bin/sh
set -eu

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y freeswitch freeswitch-mod-sofia freeswitch-music-default curl ca-certificates net-tools tcpdump
apt-get install -y sipp || apt-get install -y sip-tester || true

systemctl enable freeswitch
systemctl restart freeswitch

cat >/etc/motd <<'EOF'
Nvoip FreeSWITCH test host

Installed:
- FreeSWITCH
- mod_sofia
- SIPp/sip-tester when available
- tcpdump

Copy nvoip-pabx-provisioner to /opt/nvoip-pabx-provisioner and run:
  sudo /opt/nvoip-pabx-provisioner/bin/nvoip-pabx-provisioner detect
EOF
