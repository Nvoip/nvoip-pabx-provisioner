#!/bin/sh

NVOIP_PABX_VERSION="0.1.5"
NVOIP_SIP_HOST_DEFAULT="sip.nvoip.com.br"
NVOIP_TRUNK_NAME_DEFAULT="nvoip-trunk"
NVOIP_ASTERISK_CONTEXT_DEFAULT="from-nvoip"
NVOIP_TEST_CONTEXT_DEFAULT="nvoip-test"

nvoip_log() {
  printf '%s\n' "$*"
}

nvoip_warn() {
  printf 'WARN: %s\n' "$*" >&2
}

nvoip_die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

nvoip_require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    nvoip_die "comando obrigatorio nao encontrado: $1"
  fi
}

nvoip_has_command() {
  command -v "$1" >/dev/null 2>&1
}

nvoip_quote_sed() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

nvoip_sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

nvoip_read_amp_conf_value() {
  key="$1"

  for conf in /etc/freepbx.conf /etc/amportal.conf /etc/asterisk/freepbx.conf; do
    [ -f "$conf" ] || continue
    value="$(awk -F= -v key="$key" '
      $1 == key || index($0, "['\''" key "'\'']") || index($0, "[\"" key "\"]") {
        value = $0
        sub("^[^=]*=", "", value)
        gsub(/^[ \t'\''"]+|[ \t'\''";]+$/, "", value)
        print value
        exit
      }
    ' "$conf" 2>/dev/null || true)"
    [ -n "$value" ] && printf '%s\n' "$value" && return 0
  done

  return 1
}

nvoip_mysql_asterisk() {
  sql_file="$1"
  db_name="$(nvoip_read_amp_conf_value AMPDBNAME || true)"
  db_user="$(nvoip_read_amp_conf_value AMPDBUSER || true)"
  db_pass="$(nvoip_read_amp_conf_value AMPDBPASS || true)"
  db_host="$(nvoip_read_amp_conf_value AMPDBHOST || true)"

  [ -n "$db_name" ] || db_name="asterisk"

  if [ -n "$db_user" ]; then
    defaults_file="${sql_file}.mysql.cnf"
    {
      printf '[client]\n'
      printf 'user=%s\n' "$db_user"
      [ -n "$db_pass" ] && printf 'password=%s\n' "$db_pass"
      [ -n "$db_host" ] && printf 'host=%s\n' "$db_host"
    } > "$defaults_file" || return 1
    chmod 600 "$defaults_file" 2>/dev/null || true
    mysql --defaults-extra-file="$defaults_file" "$db_name" < "$sql_file"
    rc="$?"
    rm -f "$defaults_file"
    return "$rc"
  else
    mysql "$db_name" < "$sql_file"
  fi
}

nvoip_timestamp() {
  date '+%Y%m%d%H%M%S'
}

nvoip_make_backup() {
  file="$1"
  backup_dir="$2"

  [ -f "$file" ] || return 0
  mkdir -p "$backup_dir" || return 1
  cp "$file" "$backup_dir/$(basename "$file").$(nvoip_timestamp).bak" || return 1
}

nvoip_replace_managed_block() {
  file="$1"
  begin="$2"
  end="$3"
  block_file="$4"
  backup_dir="$5"

  tmp_file="${file}.nvoip.tmp"
  nvoip_make_backup "$file" "$backup_dir" || return 1

  if [ -f "$file" ]; then
    awk -v begin="$begin" -v end="$end" '
      $0 == begin { skip = 1; next }
      $0 == end { skip = 0; next }
      skip != 1 { print }
    ' "$file" > "$tmp_file" || return 1
  else
    : > "$tmp_file" || return 1
  fi

  {
    printf '\n%s\n' "$begin"
    cat "$block_file"
    printf '%s\n' "$end"
  } >> "$tmp_file" || return 1

  mv "$tmp_file" "$file" || return 1
}

nvoip_show_or_apply_block() {
  title="$1"
  target="$2"
  block_file="$3"
  dry_run="$4"
  begin="$5"
  end="$6"
  backup_dir="$7"

  if [ "$dry_run" = "1" ]; then
    nvoip_log "### $title"
    nvoip_log "# target: $target"
    nvoip_log "$begin"
    cat "$block_file"
    nvoip_log "$end"
    nvoip_log ""
    return 0
  fi

  nvoip_replace_managed_block "$target" "$begin" "$end" "$block_file" "$backup_dir"
}

nvoip_reload_asterisk() {
  if nvoip_has_command asterisk; then
    asterisk -rx 'core reload' >/dev/null 2>&1 || return 1
  fi
}

nvoip_reload_asterisk_stack() {
  engine="${1:-asterisk}"

  if [ "$engine" = "freepbx" ] && nvoip_has_command fwconsole; then
    fwconsole reload >/dev/null 2>&1 || return 1
    return 0
  fi

  if [ "$engine" = "issabel" ]; then
    if nvoip_has_command fwconsole; then
      fwconsole reload >/dev/null 2>&1 || return 1
      return 0
    fi

    if nvoip_has_command amportal; then
      amportal reload >/dev/null 2>&1 || return 1
      return 0
    fi
  fi

  nvoip_reload_asterisk
}

nvoip_restart_asterisk() {
  if nvoip_has_command systemctl; then
    systemctl restart asterisk >/dev/null 2>&1 || return 1
    return 0
  fi

  if nvoip_has_command service; then
    service asterisk restart >/dev/null 2>&1 || return 1
    return 0
  fi

  nvoip_reload_asterisk
}

nvoip_detect_public_ip() {
  nvoip_has_command curl || return 1

  public_ip="$(curl -fsS --connect-timeout 1 --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
  if [ -n "$public_ip" ]; then
    printf '%s\n' "$public_ip"
    return 0
  fi

  public_ip="$(curl -fsS --connect-timeout 2 --max-time 4 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]' || true)"
  if [ -n "$public_ip" ]; then
    printf '%s\n' "$public_ip"
    return 0
  fi

  public_ip="$(curl -fsS --connect-timeout 2 --max-time 4 https://api.ipify.org 2>/dev/null | tr -d '[:space:]' || true)"
  if [ -n "$public_ip" ]; then
    printf '%s\n' "$public_ip"
    return 0
  fi

  return 1
}

nvoip_is_tty() {
  [ -t 0 ] && [ -t 1 ]
}

nvoip_prompt() {
  label="$1"
  default_value="${2:-}"
  answer=""

  if [ -n "$default_value" ]; then
    printf '%s [%s]: ' "$label" "$default_value" >/dev/tty
  else
    printf '%s: ' "$label" >/dev/tty
  fi

  IFS= read -r answer </dev/tty || return 1
  if [ -z "$answer" ]; then
    printf '%s\n' "$default_value"
  else
    printf '%s\n' "$answer"
  fi
}

nvoip_prompt_secret() {
  label="$1"
  answer=""

  printf '%s: ' "$label" >/dev/tty
  stty -echo </dev/tty 2>/dev/null || true
  IFS= read -r answer </dev/tty || {
    stty echo </dev/tty 2>/dev/null || true
    return 1
  }
  stty echo </dev/tty 2>/dev/null || true
  printf '\n' >/dev/tty
  printf '%s\n' "$answer"
}

nvoip_prompt_yes_no() {
  label="$1"
  default_value="${2:-n}"
  answer=""
  hint="[s/N]"

  case "$default_value" in
    s|S|y|Y) hint="[S/n]" ;;
  esac

  printf '%s %s: ' "$label" "$hint" >/dev/tty
  IFS= read -r answer </dev/tty || return 1
  [ -n "$answer" ] || answer="$default_value"

  case "$answer" in
    s|S|sim|SIM|y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

nvoip_reload_freeswitch() {
  if nvoip_has_command fs_cli; then
    fs_cli -x 'reloadxml' >/dev/null 2>&1 || return 1
    fs_cli -x 'sofia profile external restart reloadxml' >/dev/null 2>&1 || true
  fi
}
