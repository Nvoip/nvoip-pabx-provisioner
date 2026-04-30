#!/bin/sh

nvoip_detect_engine() {
  if [ -d /var/www/fusionpbx ] || [ -f /etc/fusionpbx/config.php ]; then
    printf 'fusionpbx\n'
    return 0
  fi

  if [ -d /etc/freepbx ] || [ -f /etc/amportal.conf ] || [ -d /var/www/html/admin/modules ]; then
    if [ -f /etc/issabel.conf ] || [ -d /var/www/html/modules/pbxadmin ]; then
      printf 'issabel\n'
      return 0
    fi
    printf 'freepbx\n'
    return 0
  fi

  if command -v asterisk >/dev/null 2>&1 || [ -d /etc/asterisk ]; then
    printf 'asterisk\n'
    return 0
  fi

  if command -v freeswitch >/dev/null 2>&1 || [ -d /etc/freeswitch ]; then
    printf 'freeswitch\n'
    return 0
  fi

  printf 'unknown\n'
}

nvoip_print_detection() {
  engine="$(nvoip_detect_engine)"
  nvoip_log "engine=$engine"

  if command -v asterisk >/dev/null 2>&1; then
    asterisk -rx 'core show version' 2>/dev/null | sed 's/^/asterisk=/'
  fi

  if command -v fs_cli >/dev/null 2>&1; then
    fs_cli -x version 2>/dev/null | sed 's/^/freeswitch=/'
  fi
}
