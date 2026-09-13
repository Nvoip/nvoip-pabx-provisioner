#!/bin/sh

# Optional account-scoped reporting. Never send SIP credentials or command output.
nvoip_marketplace_report() {
  report_state="$1"
  report_token=$(cat "$marketplace_token_file") || return 1
  case "$report_token" in *[!A-Za-z0-9_-]*|'') return 1 ;; esac
  [ "${#report_token}" -eq 43 ] || return 1
  # The capability travels through stdin, not process arguments or redirects.
  report_http_code=$(printf 'header = "X-Nvoip-Provisioning-Token: %s"\n' "$report_token" |
    curl --disable --config - --silent --show-error --fail --proto '=https' \
      --connect-timeout 5 --max-time 15 --output /dev/null --write-out '%{http_code}' \
      --header 'Content-Type: application/json' \
      --data "{\"slug\":\"$engine\",\"state\":\"$report_state\"}" \
      'https://painel.nvoip.com.br/api/public/pabx-provisioning/report') || return 1
  [ "$report_http_code" = 200 ]
}

nvoip_marketplace_registered() {
  command -v asterisk >/dev/null 2>&1 || return 1
  if [ "$asterisk_driver" = "chan_sip" ]; then
    registration_output=$(asterisk -rx 'sip show registry') || return 1
    printf '%s\n' "$registration_output" | awk -v host="$sip_host" -v user="$trunk_user" '
      { split($1, parts, ":"); if (parts[1] == host && $3 == user && $5 == "Registered") ok=1 }
      END { exit !ok }'
  else
    registration_output=$(asterisk -rx 'pjsip show registrations') || return 1
    printf '%s\n' "$registration_output" | awk -v name="$trunk_name" -v host="$sip_host" '
      { split($1, parts, "/"); server=parts[2]; sub(/^sip:/, "", server); sub(/:5060$/, "", server); if ((parts[1] == name || parts[1] == name "-registration") && server == host && $3 == "Registered") ok=1 }
      END { exit !ok }'
  fi
}

nvoip_marketplace_start() {
  [ -n "$marketplace_token_file" ] || return 0
  case "$engine" in asterisk|freepbx|issabel) ;; *) nvoip_die 'PABX não suportado pelo acompanhamento do marketplace' ;; esac
  command -v curl >/dev/null 2>&1 || nvoip_die 'curl necessário para acompanhar o provisionamento'
  [ -r "$marketplace_token_file" ] || nvoip_die 'Arquivo de credencial do marketplace indisponível'
  nvoip_marketplace_report PROVISIONING || nvoip_die 'Não foi possível iniciar o acompanhamento; nenhuma configuração aplicada'
  marketplace_started=1
}

nvoip_marketplace_finish() {
  [ "$marketplace_started" = 1 ] || return 0
  # A successful reload alone does not prove registration; dry runs never reach here.
  registration_attempt=0
  until nvoip_marketplace_registered; do
    registration_attempt=$((registration_attempt + 1))
    [ "$registration_attempt" -lt 15 ] || break
    sleep 2
  done
  [ "$registration_attempt" -lt 15 ] || nvoip_die 'Registro SIP não confirmado; consulte o PABX antes de repetir a validação'
  if ! nvoip_marketplace_report PROVISIONED; then
    nvoip_warn 'Registro SIP confirmado, mas o marketplace não recebeu a confirmação. Repita validate com a mesma credencial dentro de 30 minutos.'
    marketplace_started=0
    return 1
  fi
  marketplace_started=0
}
