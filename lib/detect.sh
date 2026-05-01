#!/bin/sh

nvoip_detect_engine() {
  if [ -d /var/www/fusionpbx ] || [ -f /etc/fusionpbx/config.php ]; then
    printf 'fusionpbx\n'
    return 0
  fi

  if [ -f /etc/issabel.conf ] || [ -d /var/www/html/modules/pbxadmin ]; then
    printf 'issabel\n'
    return 0
  fi

  if [ -d /etc/freepbx ] || [ -f /etc/amportal.conf ] || [ -d /var/www/html/admin/modules ]; then
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

nvoip_asterisk_has_pjsip() {
  if command -v asterisk >/dev/null 2>&1; then
    asterisk -rx 'module show like res_pjsip.so' 2>/dev/null | grep -qi 'res_pjsip.*Running' && return 0
    asterisk -rx 'pjsip show settings' >/dev/null 2>&1 && return 0
  fi

  [ -f /etc/asterisk/pjsip.conf ] || [ -f /etc/asterisk/pjsip_custom_post.conf ]
}

nvoip_detect_asterisk_driver() {
  engine="${1:-auto}"

  case "$engine" in
    issabel)
      if command -v asterisk >/dev/null 2>&1 && nvoip_asterisk_has_pjsip; then
        printf 'pjsip\n'
      else
        printf 'chan_sip\n'
      fi
      ;;
    asterisk|freepbx)
      printf 'pjsip\n'
      ;;
    *)
      printf 'pjsip\n'
      ;;
  esac
}

nvoip_print_detection() {
  engine="$(nvoip_detect_engine)"
  nvoip_log "engine=$engine"

  if command -v asterisk >/dev/null 2>&1; then
    asterisk -rx 'core show version' 2>/dev/null | sed 's/^/asterisk=/'
    nvoip_log "asterisk_driver=$(nvoip_detect_asterisk_driver "$engine")"
  fi

  if command -v fs_cli >/dev/null 2>&1; then
    fs_cli -x version 2>/dev/null | sed 's/^/freeswitch=/'
  fi
}
