# nvoip-pabx-provisioner

Provisionador oficial da Nvoip para criar trunk SIP em PABX Linux, começando por Asterisk, FreePBX, Issabel, FreeSWITCH e FusionPBX.

O objetivo é reduzir a integração ao mínimo: informar usuário e senha do trunk Nvoip, detectar o PABX e criar a configuração necessária para chamadas de entrada e saída. Rotas de teste só são criadas quando você passa `--apply-test-routing`.

## Estado atual

- Asterisk puro via `pjsip.conf` e `extensions.conf`
- FreePBX via `pjsip_custom_post.conf` e `extensions_custom.conf`
- Issabel via `sip_custom_post.conf` em instalacoes classicas `chan_sip`, ou `pjsip_custom_post.conf` quando PJSIP estiver disponivel
- FreeSWITCH via gateway XML e dialplan XML
- FusionPBX com arquivos FreeSWITCH compatíveis
- modo `--dry-run` por padrão
- backups antes de escrever arquivos
- validação básica de registro por CLI local
- smoke test SIP opcional com `sipp`

## Uso rapido

```bash
cd nvoip-pabx-provisioner
chmod +x bin/nvoip-pabx-provisioner tests/syntax.sh scripts/install.sh
```

Instalar localmente:

```bash
sudo scripts/install.sh
sudo nvoip-pabx-provisioner configure
```

Ou usar sem instalar:

```bash
sudo bin/nvoip-pabx-provisioner configure
```

Detectar o PABX:

```bash
bin/nvoip-pabx-provisioner detect
```

Assistente interativo:

```bash
sudo bin/nvoip-pabx-provisioner configure
```

Em Asterisk puro, se `--external-ip` nao for informado, o CLI tenta detectar o IP publico automaticamente para configurar NAT no transport PJSIP. Use `--no-auto-external-ip` se quiser desativar essa deteccao.

Ver o que seria aplicado:

```bash
bin/nvoip-pabx-provisioner provision \
  --trunk-user "SEU_USUARIO_NVOIP" \
  --trunk-password "SUA_SENHA_NVOIP"
```

Aplicar somente o trunk:

```bash
sudo bin/nvoip-pabx-provisioner provision \
  --trunk-user "SEU_USUARIO_NVOIP" \
  --trunk-password "SUA_SENHA_NVOIP" \
  --apply
```

Forcar Issabel classico com `chan_sip`:

```bash
sudo bin/nvoip-pabx-provisioner provision \
  --engine issabel \
  --asterisk-driver chan_sip \
  --trunk-user "SEU_USUARIO_NVOIP" \
  --trunk-password "SUA_SENHA_NVOIP" \
  --apply
```

Aplicar trunk mais rotas minimas de teste:

```bash
sudo bin/nvoip-pabx-provisioner provision \
  --trunk-user "SEU_USUARIO_NVOIP" \
  --trunk-password "SUA_SENHA_NVOIP" \
  --apply-test-routing \
  --apply \
  --validate
```

Com teste SIP ativo, se `sipp` estiver instalado:

```bash
sudo bin/nvoip-pabx-provisioner provision \
  --trunk-user "SEU_USUARIO_NVOIP" \
  --trunk-password "SUA_SENHA_NVOIP" \
  --apply \
  --validate \
  --validate-sipp
```

## Variaveis de ambiente

```bash
export NVOIP_TRUNK_USER="SEU_USUARIO_NVOIP"
export NVOIP_TRUNK_PASSWORD="SUA_SENHA_NVOIP"
export NVOIP_TRUNK_NAME="nvoip-trunk"
export NVOIP_SIP_HOST="sip.nvoip.com.br"
```

## Rotas de teste

Por padrao, o comando cria apenas o trunk. Isso evita mexer em dialplan de produção sem consentimento.

Quando `--apply-test-routing` é usado:

- entrada: chamadas recebidas caem em um audio padrao de teste
- saida: chamadas com prefixo `0` saem pelo trunk Nvoip

Exemplo: para chamar `11999999999`, disque `011999999999` no contexto de teste gerado. O prefixo pode ser alterado com `--outbound-prefix`.

## Arquivos alterados

Em Asterisk puro:

- `/etc/asterisk/pjsip.conf`
- `/etc/asterisk/extensions.conf`

No Asterisk puro, o provisionador tambem cria um transport UDP PJSIP gerenciado e reinicia o Asterisk ao aplicar, porque transports PJSIP novos normalmente nao entram apenas com `core reload`.

Em FreePBX:

- `/etc/asterisk/pjsip_custom_post.conf`
- `/etc/asterisk/extensions_custom.conf`

Em Issabel classico com `chan_sip`:

- `/etc/asterisk/sip_general_custom.conf`
- `/etc/asterisk/sip_custom_post.conf`
- `/etc/asterisk/extensions_custom.conf`

Em Issabel com PJSIP:

- `/etc/asterisk/pjsip_custom_post.conf`
- `/etc/asterisk/extensions_custom.conf`

Em FreeSWITCH e FusionPBX:

- `/etc/freeswitch/sip_profiles/external/nvoip-trunk.xml`
- `/etc/freeswitch/dialplan/default/nvoip-trunk.xml`

Backups ficam em `/var/backups/nvoip-pabx`, ou no diretório informado com `--backup-dir`.

## Validacao

Validar registro depois de aplicar:

```bash
bin/nvoip-pabx-provisioner validate \
  --engine asterisk \
  --trunk-user "$NVOIP_TRUNK_USER" \
  --trunk-password "$NVOIP_TRUNK_PASSWORD"
```

Para Asterisk, a validação usa:

```bash
asterisk -rx "pjsip show registrations"
```

Para FreeSWITCH:

```bash
fs_cli -x "sofia status gateway nvoip-trunk"
```

O `--validate-sipp` faz um smoke test SIP OPTIONS contra o servidor configurado. Ele não substitui um teste fim a fim com DID real e chamada externa, mas ajuda a validar rede, DNS e resposta SIP.

## Proximos incrementos

- handlers especificos para bancos do FusionPBX e FreePBX quando for melhor usar API/DB em vez de arquivos custom
- cenarios `sipp` para INVITE autenticado de saida
- teste de entrada com DID real e callback por CLI/AMI/Event Socket
- empacotamento `.deb`, `.rpm` e instalador one-line
- matriz de compatibilidade por distro e versão do PABX

## Laboratorio AWS

Para subir uma EC2 Ubuntu com Asterisk e SIPp:

```bash
scripts/aws/create-asterisk-ec2.sh \
  --region us-east-1 \
  --key-name SUA_KEYPAIR \
  --ssh-cidr SEU_IP/32
```

Depois execute o provisionamento remoto:

```bash
scripts/aws/run-asterisk-test.sh \
  --host IP_PUBLICO \
  --key-file ~/.ssh/SUA_KEYPAIR.pem \
  --trunk-user "SEU_USUARIO_NVOIP" \
  --trunk-password "SUA_SENHA_NVOIP" \
  --apply-test-routing \
  --validate-sipp
```

O security group libera SSH apenas para o CIDR informado e libera SIP/RTP UDP para o CIDR informado em `--sip-cidr` ou `0.0.0.0/0` no laboratorio. Encerre a instancia ao terminar os testes.
