# Matriz de compatibilidade

Status inicial baseado em laboratório AWS e diferenças conhecidas de empacotamento.

| Stack | Distro base | Status | Observacao |
| --- | --- | --- | --- |
| Asterisk 18 | Ubuntu 22.04 | Validado | Pacote `asterisk` disponivel via apt. Precisa criar transport PJSIP em Asterisk puro e reiniciar para carregar transport novo. |
| FreePBX | Debian/CentOS/RHEL derivados | Ajustado | Grava trunk no banco `asterisk`, tabelas `trunks` + `pjsip`/`sip`, para aparecer na tela web. Dialplan de teste continua em `extensions_custom.conf`. |
| Issabel classico | CentOS/RHEL derivados | Ajustado | Grava trunk `chan_sip` no banco `asterisk`, tabelas `trunks` + `sip`, para aparecer na tela web. |
| Issabel | CentOS/RHEL derivados | Ajustado | Segue o mecanismo FreePBX/Issabel: banco `asterisk` -> geracao de arquivos `*_additional.conf` pelo reload do PBX. |
| FreeSWITCH | Ubuntu 22.04 | Bloqueado via apt padrao | Repositorios padrao Jammy nao incluem `freeswitch`, `freeswitch-mod-sofia` e `freeswitch-music-default`. Precisa repo oficial FreeSWITCH, build source ou distro/installer alternativo. |
| FusionPBX | Debian recomendado pelo projeto | Pendente | Deve receber handler de banco/API do FusionPBX para aparecer no painel; XML direto pode carregar no FreeSWITCH, mas nao garante exibicao no front. |

## Impactos por distro

- Ubuntu 22.04 funciona bem para Asterisk, mas nao e um alvo simples para FreeSWITCH sem repositorio adicional.
- Asterisk puro pode nao ter transport `transport-udp`; o provisionador cria um transport gerenciado.
- Transport PJSIP novo nao e recarregado de forma confiavel com `core reload`; o provisionador reinicia Asterisk puro ao aplicar.
- Em cloud/NAT, o provisionador tenta detectar IP publico automaticamente e preencher `external_signaling_address` e `external_media_address`.
- FreePBX/Issabel usam o banco `asterisk` como fonte do painel web; escrever apenas em `*_custom*.conf` funciona no Asterisk, mas nao aparece para o cliente.
- FusionPBX segue a mesma preocupacao de front: o provisionamento por XML fica funcional no FreeSWITCH, mas precisa de handler nativo para refletir no painel FusionPBX.
