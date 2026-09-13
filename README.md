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

- banco MySQL/MariaDB `asterisk`, tabelas `trunks` e `pjsip`/`sip`
- `/etc/asterisk/extensions_custom.conf` apenas para rotas de teste opcionais

Em Issabel classico com `chan_sip`:

- banco MySQL/MariaDB `asterisk`, tabelas `trunks` e `sip`
- `/etc/asterisk/extensions_custom.conf` apenas para rotas de teste opcionais

Em Issabel com PJSIP:

- banco MySQL/MariaDB `asterisk`, tabelas `trunks` e `pjsip`
- `/etc/asterisk/extensions_custom.conf` apenas para rotas de teste opcionais

No FreePBX/Issabel, o trunk e gravado no mecanismo nativo do PBX para aparecer na tela web. O reload do PBX gera arquivos como `sip_additional.conf`, `sip_registrations.conf` e `extensions_additional.conf`.

Em FreeSWITCH puro:

- `/etc/freeswitch/sip_profiles/external/nvoip-trunk.xml`
- `/etc/freeswitch/dialplan/default/nvoip-trunk.xml`

Em FusionPBX, o provisionador nao aplica XML direto porque isso nao garante exibicao no painel. O stack precisa de handler nativo de banco/API do FusionPBX.

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

- handler especifico para banco/API do FusionPBX para o gateway aparecer no painel web
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

## Acompanhar no marketplace (NN-4514)

Com o backend e o Painel atualizados, abra o PABX em Integrações → Configuração
e baixe uma credencial de acompanhamento. Ela é válida por 30 minutos e vinculada
à conta e ao PABX selecionado. Uma nova credencial substitui a anterior.

Transfira o arquivo com segurança ao servidor do PABX e acrescente
`--marketplace-token-file /caminho/privado/nvoip-asterisk-provisioning.txt`
ao comando `provision --apply` habitual. Use um arquivo acessível somente ao
operador; não coloque o token em argumentos, tickets, logs ou repositórios.

O acompanhamento é opcional, limitado a Asterisk, FreePBX e Issabel. `--dry-run`
não envia relatórios. O CLI recusa o início se a credencial não puder ser aceita
antes de aplicar configurações. Depois da aplicação, aguarda até 28 segundos
pela confirmação do registro SIP do trunk; falha de recarga ou registro ausente
não é informada como sucesso. O acompanhamento não faz ligações nem envia SIP OPTIONS.

Se o registro foi confirmado mas o envio final falhou, repita `validate` com
as mesmas opções de engine, trunk e arquivo, dentro da validade da credencial.
Esse caminho não reaplica configurações nem reinicia serviços. Ele serve para
repetir o relatório de uma execução iniciada; não transforma uma credencial
recém-gerada em prova de instalação. Apague o arquivo após o uso.

A informação no marketplace é o último resultado declarado pelo provisionador,
não um monitoramento contínuo nem uma verificação independente da Nvoip.
Instalações antigas/manuais aparecem sem informação até uma execução acompanhada.
Migration/SQL neste repositório: none. Publicação depende da migration e da API
NN-4514 no `painel-back-v5`; nenhuma release é publicada por este PR.
