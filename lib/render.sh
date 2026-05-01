#!/bin/sh

nvoip_render_asterisk_pjsip() {
  trunk_name="$1"
  trunk_user="$2"
  trunk_password="$3"
  sip_host="$4"
  from_domain="$5"
  inbound_context="$6"
  include_transport="${7:-0}"
  external_ip="${8:-}"

  if [ "$include_transport" = "1" ]; then
    cat <<EOF
[${trunk_name}-transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
EOF

    if [ -n "$external_ip" ]; then
      cat <<EOF
external_signaling_address=${external_ip}
external_media_address=${external_ip}
local_net=10.0.0.0/8
local_net=172.16.0.0/12
local_net=192.168.0.0/16
EOF
    fi

    cat <<EOF

EOF
  fi

  cat <<EOF
[${trunk_name}-registration]
type=registration
outbound_auth=${trunk_name}-auth
server_uri=sip:${sip_host}
client_uri=sip:${trunk_user}@${from_domain}
retry_interval=60
forbidden_retry_interval=300
expiration=3600
EOF

  if [ "$include_transport" = "1" ]; then
    cat <<EOF
transport=${trunk_name}-transport-udp
EOF
  fi

  cat <<EOF

[${trunk_name}-auth]
type=auth
auth_type=userpass
username=${trunk_user}
password=${trunk_password}

[${trunk_name}-aor]
type=aor
contact=sip:${sip_host}
qualify_frequency=60

[${trunk_name}]
type=endpoint
context=${inbound_context}
disallow=all
allow=ulaw,alaw
outbound_auth=${trunk_name}-auth
aors=${trunk_name}-aor
from_user=${trunk_user}
from_domain=${from_domain}
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
timers=yes
EOF

  if [ "$include_transport" = "1" ]; then
    cat <<EOF
transport=${trunk_name}-transport-udp
EOF
  fi

  cat <<EOF

[${trunk_name}-identify]
type=identify
endpoint=${trunk_name}
match=${sip_host}
EOF
}

nvoip_render_asterisk_extensions() {
  trunk_name="$1"
  inbound_context="$2"
  test_context="$3"
  outbound_prefix="$4"
  inbound_did="$5"
  apply_test_routing="$6"
  dial_tech="${7:-PJSIP}"

  if [ "$apply_test_routing" != "1" ]; then
    cat <<EOF
; Trunk ${trunk_name} criado. Rotas de entrada/saida nao foram alteradas.
EOF
    return 0
  fi

  cat <<EOF
[${inbound_context}]
exten => s,1,NoOp(Nvoip inbound test through ${trunk_name})
 same => n,Answer()
 same => n,Playback(demo-congrats)
 same => n,Hangup()
exten => ${inbound_did},1,NoOp(Nvoip inbound test through ${trunk_name})
 same => n,Answer()
 same => n,Playback(demo-congrats)
 same => n,Hangup()
EOF

  if [ "$inbound_did" != "_X." ]; then
    cat <<EOF
exten => _X.,1,NoOp(Nvoip inbound fallback test through ${trunk_name})
 same => n,Answer()
 same => n,Playback(demo-congrats)
 same => n,Hangup()
EOF
  fi

  cat <<EOF

[${test_context}]
exten => _${outbound_prefix}X.,1,NoOp(Nvoip outbound test through ${trunk_name})
 same => n,Dial(${dial_tech}/\${EXTEN:${#outbound_prefix}}@${trunk_name},60)
 same => n,Hangup()
EOF
}

nvoip_render_asterisk_chan_sip_register() {
  trunk_name="$1"
  trunk_user="$2"
  trunk_password="$3"
  sip_host="$4"

  cat <<EOF
register => ${trunk_user}:${trunk_password}@${sip_host}/${trunk_user}
EOF
}

nvoip_render_asterisk_chan_sip_peer() {
  trunk_name="$1"
  trunk_user="$2"
  trunk_password="$3"
  sip_host="$4"
  from_domain="$5"
  inbound_context="$6"

  cat <<EOF
[${trunk_name}]
type=peer
host=${sip_host}
defaultuser=${trunk_user}
username=${trunk_user}
secret=${trunk_password}
fromuser=${trunk_user}
fromdomain=${from_domain}
context=${inbound_context}
insecure=port,invite
qualify=yes
disallow=all
allow=ulaw,alaw
dtmfmode=rfc2833
nat=force_rport,comedia
canreinvite=no
directmedia=no
trustrpid=yes
sendrpid=pai
EOF
}

nvoip_render_freepbx_trunk_sql() {
  trunk_name="$1"
  trunk_user="$2"
  trunk_password="$3"
  sip_host="$4"
  from_domain="$5"
  inbound_context="$6"
  asterisk_driver="$7"

  trunk_name_sql="$(nvoip_sql_escape "$trunk_name")"
  trunk_user_sql="$(nvoip_sql_escape "$trunk_user")"
  trunk_password_sql="$(nvoip_sql_escape "$trunk_password")"
  sip_host_sql="$(nvoip_sql_escape "$sip_host")"
  from_domain_sql="$(nvoip_sql_escape "$from_domain")"
  inbound_context_sql="$(nvoip_sql_escape "$inbound_context")"

  if [ "$asterisk_driver" = "chan_sip" ]; then
    tech="sip"
  else
    tech="pjsip"
  fi

  cat <<EOF
START TRANSACTION;
SET @nvoip_trunk_name := '${trunk_name_sql}';
SET @nvoip_trunk_id := (
  SELECT trunkid FROM trunks WHERE name = @nvoip_trunk_name ORDER BY trunkid LIMIT 1
);
SET @nvoip_trunk_id := COALESCE(
  @nvoip_trunk_id,
  (SELECT COALESCE(MAX(trunkid), 0) + 1 FROM trunks)
);
DELETE FROM trunks WHERE trunkid = @nvoip_trunk_id OR name = @nvoip_trunk_name;
INSERT INTO trunks
  (\`trunkid\`, \`tech\`, \`channelid\`, \`name\`, \`outcid\`, \`keepcid\`, \`maxchans\`, \`failscript\`, \`dialoutprefix\`, \`usercontext\`, \`provider\`, \`disabled\`, \`continue\`)
VALUES
  (@nvoip_trunk_id, '${tech}', '${trunk_name_sql}', '${trunk_name_sql}', '', 'off', '', '', '', '${trunk_name_sql}', 'Nvoip', 'off', 'off');
EOF

  if [ "$asterisk_driver" = "chan_sip" ]; then
    cat <<EOF
DELETE FROM sip WHERE id IN (@nvoip_trunk_id, CONCAT('tr-peer-', @nvoip_trunk_id), CONCAT('tr-reg-', @nvoip_trunk_id));
INSERT INTO sip (id, keyword, data, flags) VALUES
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'account', '${trunk_name_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'secret', '${trunk_password_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'defaultuser', '${trunk_user_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'username', '${trunk_user_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'fromuser', '${trunk_user_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'fromdomain', '${from_domain_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'host', '${sip_host_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'type', 'peer', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'context', '${inbound_context_sql}', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'insecure', 'port,invite', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'qualify', 'yes', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'disallow', 'all', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'allow', 'ulaw&alaw', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'dtmfmode', 'rfc2833', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'nat', 'force_rport,comedia', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'canreinvite', 'no', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'directmedia', 'no', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'trustrpid', 'yes', 0),
  (CONCAT('tr-peer-', @nvoip_trunk_id), 'sendrpid', 'pai', 0),
  (CONCAT('tr-reg-', @nvoip_trunk_id), 'register', '${trunk_user_sql}:${trunk_password_sql}@${sip_host_sql}/${trunk_user_sql}', 0);
EOF
  else
    cat <<EOF
DELETE FROM pjsip WHERE id = @nvoip_trunk_id;
INSERT INTO pjsip (id, keyword, data, flags) VALUES
  (@nvoip_trunk_id, 'trunk_name', '${trunk_name_sql}', 0),
  (@nvoip_trunk_id, 'username', '${trunk_user_sql}', 0),
  (@nvoip_trunk_id, 'auth_username', '${trunk_user_sql}', 0),
  (@nvoip_trunk_id, 'secret', '${trunk_password_sql}', 0),
  (@nvoip_trunk_id, 'authentication', 'outbound', 0),
  (@nvoip_trunk_id, 'sip_server', '${sip_host_sql}', 0),
  (@nvoip_trunk_id, 'sip_server_port', '5060', 0),
  (@nvoip_trunk_id, 'client_uri', 'sip:${trunk_user_sql}@${from_domain_sql}', 0),
  (@nvoip_trunk_id, 'server_uri', 'sip:${sip_host_sql}', 0),
  (@nvoip_trunk_id, 'registration', 'send', 0),
  (@nvoip_trunk_id, 'max_retries', '10000', 0),
  (@nvoip_trunk_id, 'expiration', '3600', 0),
  (@nvoip_trunk_id, 'retry_interval', '60', 0),
  (@nvoip_trunk_id, 'fatal_retry_interval', '0', 0),
  (@nvoip_trunk_id, 'forbidden_retry_interval', '300', 0),
  (@nvoip_trunk_id, 'context', '${inbound_context_sql}', 0),
  (@nvoip_trunk_id, 'from_user', '${trunk_user_sql}', 0),
  (@nvoip_trunk_id, 'from_domain', '${from_domain_sql}', 0),
  (@nvoip_trunk_id, 'match', '${sip_host_sql}', 0),
  (@nvoip_trunk_id, 'qualify_frequency', '60', 0),
  (@nvoip_trunk_id, 'dtmfmode', 'rfc4733', 0),
  (@nvoip_trunk_id, 'codecs', 'ulaw,alaw', 0),
  (@nvoip_trunk_id, 'disallow', 'all', 0),
  (@nvoip_trunk_id, 'allow', 'ulaw,alaw', 0),
  (@nvoip_trunk_id, 'direct_media', 'no', 0),
  (@nvoip_trunk_id, 'rtp_symmetric', 'yes', 0),
  (@nvoip_trunk_id, 'force_rport', 'yes', 0),
  (@nvoip_trunk_id, 'rewrite_contact', 'yes', 0),
  (@nvoip_trunk_id, 'timers', 'yes', 0);
EOF
  fi

  cat <<EOF
COMMIT;
EOF
}

nvoip_render_freeswitch_gateway() {
  trunk_name="$1"
  trunk_user="$2"
  trunk_password="$3"
  sip_host="$4"

  cat <<EOF
<include>
  <gateway name="${trunk_name}">
    <param name="username" value="${trunk_user}"/>
    <param name="password" value="${trunk_password}"/>
    <param name="realm" value="${sip_host}"/>
    <param name="proxy" value="${sip_host}"/>
    <param name="register" value="true"/>
    <param name="register-transport" value="udp"/>
    <param name="expire-seconds" value="3600"/>
    <param name="retry-seconds" value="60"/>
    <param name="caller-id-in-from" value="true"/>
  </gateway>
</include>
EOF
}

nvoip_render_freeswitch_dialplan() {
  trunk_name="$1"
  outbound_prefix="$2"
  inbound_did="$3"
  apply_test_routing="$4"
  inbound_expression="$inbound_did"

  case "$inbound_expression" in
    "_X."|"") inbound_expression=".*" ;;
  esac

  if [ "$apply_test_routing" != "1" ]; then
    cat <<EOF
<include>
  <!-- Gateway ${trunk_name} criado. Rotas de entrada/saida nao foram alteradas. -->
</include>
EOF
    return 0
  fi

  cat <<EOF
<include>
  <extension name="nvoip_inbound_test">
    <condition field="destination_number" expression="^(${inbound_expression})$">
      <action application="answer"/>
      <action application="playback" data="\$\${hold_music}"/>
      <action application="hangup"/>
    </condition>
  </extension>
  <extension name="nvoip_outbound_test">
    <condition field="destination_number" expression="^${outbound_prefix}([0-9]+)$">
      <action application="bridge" data="sofia/gateway/${trunk_name}/\$1"/>
    </condition>
  </extension>
</include>
EOF
}
