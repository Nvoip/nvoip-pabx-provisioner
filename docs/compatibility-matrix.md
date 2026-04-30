# Matriz de compatibilidade

Status inicial baseado em laboratório AWS e diferenças conhecidas de empacotamento.

| Stack | Distro base | Status | Observacao |
| --- | --- | --- | --- |
| Asterisk 18 | Ubuntu 22.04 | Validado | Pacote `asterisk` disponivel via apt. Precisa criar transport PJSIP em Asterisk puro e reiniciar para carregar transport novo. |
| FreePBX | Debian/CentOS/RHEL derivados | Pendente | Deve usar arquivos custom (`pjsip_custom_post.conf`, `extensions_custom.conf`) para nao sobrescrever configuracao gerada pelo FreePBX. |
| Issabel | CentOS/RHEL derivados | Pendente | Deve seguir padrao FreePBX/Elastix e evitar alterar arquivos gerados diretamente. |
| FreeSWITCH | Ubuntu 22.04 | Bloqueado via apt padrao | Repositorios padrao Jammy nao incluem `freeswitch`, `freeswitch-mod-sofia` e `freeswitch-music-default`. Precisa repo oficial FreeSWITCH, build source ou distro/installer alternativo. |
| FusionPBX | Debian recomendado pelo projeto | Pendente | Caminho recomendado e validar usando instalador oficial FusionPBX em Debian, nao Ubuntu puro. |

## Impactos por distro

- Ubuntu 22.04 funciona bem para Asterisk, mas nao e um alvo simples para FreeSWITCH sem repositorio adicional.
- Asterisk puro pode nao ter transport `transport-udp`; o provisionador cria um transport gerenciado.
- Transport PJSIP novo nao e recarregado de forma confiavel com `core reload`; o provisionador reinicia Asterisk puro ao aplicar.
- Em cloud/NAT, o provisionador tenta detectar IP publico automaticamente e preencher `external_signaling_address` e `external_media_address`.
- FreePBX/Issabel devem preferir arquivos custom para preservar o gerador interno do PABX.
