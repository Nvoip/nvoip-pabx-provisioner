#!/bin/sh

nvoip_validate_asterisk_registration() {
  trunk_name="$1"
  if ! command -v asterisk >/dev/null 2>&1; then
    nvoip_warn "asterisk nao encontrado; pulando validacao de registro"
    return 0
  fi

  asterisk -rx "pjsip show registrations" | sed -n "/$trunk_name/p"
}

nvoip_validate_freeswitch_registration() {
  trunk_name="$1"
  if ! command -v fs_cli >/dev/null 2>&1; then
    nvoip_warn "fs_cli nao encontrado; pulando validacao de registro"
    return 0
  fi

  fs_cli -x "sofia status gateway $trunk_name"
}

nvoip_validate_sipp_options() {
  sip_host="$1"
  trunk_user="$2"

  if ! command -v sipp >/dev/null 2>&1; then
    nvoip_warn "sipp nao encontrado; instale sipp para teste SIP ativo"
    return 0
  fi

  sipp_cmd="sipp"
  if command -v timeout >/dev/null 2>&1; then
    sipp_cmd="timeout 20 sipp"
  fi

  $sipp_cmd "$sip_host" -sf /dev/stdin -m 1 -timeout 5 <<EOF
<?xml version="1.0" encoding="ISO-8859-1" ?>
<scenario name="Nvoip OPTIONS smoke test">
  <send retrans="500">
    <![CDATA[
      OPTIONS sip:${sip_host} SIP/2.0
      Via: SIP/2.0/UDP [local_ip]:[local_port];branch=[branch]
      From: <sip:${trunk_user}@[local_ip]>;tag=[call_number]
      To: <sip:${sip_host}>
      Call-ID: [call_id]
      CSeq: 1 OPTIONS
      Contact: <sip:${trunk_user}@[local_ip]:[local_port]>
      Max-Forwards: 70
      Content-Length: 0
    ]]>
  </send>
  <recv response="200"/>
</scenario>
EOF
}
