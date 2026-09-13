#!/bin/sh
set -eu
project_dir="$(dirname -- "$0")/.."
fixture=$(mktemp -d)
trap 'result=$?; if [ "$result" -ne 0 ]; then cat "$fixture/output" "$fixture/events" 2>/dev/null; fi; rm -rf "$fixture"' EXIT
mkdir "$fixture/bin" "$fixture/lib" "$fixture/mock"
cp "$project_dir/bin/nvoip-pabx-provisioner" "$fixture/bin/"
cp "$project_dir/lib/"*.sh "$fixture/lib/"
# Isolated command test: replace local config writes/reloads, never touch a PBX.
cat >> "$fixture/lib/common.sh" <<'EOF'
nvoip_show_or_apply_block() { if [ "$4" = 0 ]; then printf 'apply\n' >> "$TEST_EVENTS"; fi; }
nvoip_restart_asterisk() { [ "${RELOAD_FAIL:-0}" = 0 ]; }
nvoip_reload_asterisk_stack() { [ "${RELOAD_FAIL:-0}" = 0 ]; }
EOF
cat > "$fixture/mock/curl" <<'EOF'
#!/bin/sh
config=$(cat)
case "$config" in *'X-Nvoip-Provisioning-Token: '*) ;; *) exit 99 ;; esac
case "$*" in *'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'*) exit 98 ;; esac
case "$*" in
  *PROVISIONING*) printf 'PROVISIONING\n' >> "$TEST_EVENTS"; [ "${FAIL_START:-0}" = 0 ] || exit 1 ;;
  *PROVISIONED*) printf 'PROVISIONED\n' >> "$TEST_EVENTS" ;;
  *FAILED*) printf 'FAILED\n' >> "$TEST_EVENTS" ;;
  *) exit 97 ;;
esac
printf "%s" "${REPORT_HTTP_CODE:-200}"
EOF
cat > "$fixture/mock/asterisk" <<'EOF'
#!/bin/sh
if [ "${SIP_DRIVER:-pjsip}" = chan_sip ]; then
  printf 'sip.example.test:5060 N 1000 120 %s\n' "${SIP_STATE:-Registered}"
else
  printf '%s/sip:sip.example.test trunk-auth %s\n' "${SIP_TRUNK:-nvoip-registration}" "${SIP_STATE:-Registered}"
fi
EOF
printf '#!/bin/sh\nexit 0\n' > "$fixture/mock/sleep"
chmod +x "$fixture/mock/curl" "$fixture/mock/asterisk" "$fixture/mock/sleep"
export PATH="$fixture/mock:$PATH" TEST_EVENTS="$fixture/events"
printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n' > "$fixture/token"
run() {
  "$fixture/bin/nvoip-pabx-provisioner" "$@" --asterisk-driver "${SIP_DRIVER:-pjsip}" --engine asterisk --trunk-name nvoip --trunk-user 1000 \
    --trunk-password fixture --sip-host sip.example.test --no-auto-external-ip \
    --marketplace-token-file "$fixture/token" > "$fixture/output" 2>&1
}
: > "$TEST_EVENTS"
run provision --dry-run
[ ! -s "$TEST_EVENTS" ] || { cat "$TEST_EVENTS"; exit 1; }
run provision --apply
grep -q '^PROVISIONED$' "$TEST_EVENTS"
! grep -q '^FAILED$' "$TEST_EVENTS"
: > "$TEST_EVENTS"
if (SIP_STATE=Rejected run provision --apply); then exit 1; fi
grep -q '^FAILED$' "$TEST_EVENTS"
! grep -q '^PROVISIONED$' "$TEST_EVENTS"
: > "$TEST_EVENTS"
if (SIP_TRUNK=another-registration run provision --apply); then exit 1; fi
! grep -q '^PROVISIONED$' "$TEST_EVENTS"
: > "$TEST_EVENTS"
if (FAIL_START=1 run provision --apply); then exit 1; fi
! grep -q '^apply$' "$TEST_EVENTS"
: > "$TEST_EVENTS"
if (REPORT_HTTP_CODE=302 run provision --apply); then exit 1; fi
! grep -q '^apply$' "$TEST_EVENTS"
: > "$TEST_EVENTS"
if (RELOAD_FAIL=1 run provision --apply); then exit 1; fi
grep -q '^FAILED$' "$TEST_EVENTS"
! grep -q '^PROVISIONED$' "$TEST_EVENTS"
: > "$TEST_EVENTS"
run validate
[ "$(cat "$TEST_EVENTS")" = PROVISIONED ]
: > "$TEST_EVENTS"
SIP_DRIVER=chan_sip run validate --asterisk-driver chan_sip
[ "$(cat "$TEST_EVENTS")" = PROVISIONED ]
printf 'marketplace: 9 scenarios passed\n'
