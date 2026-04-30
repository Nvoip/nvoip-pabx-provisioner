# Distribuicao do nvoip-pabx-provisioner

O provisionador deve atender dois publicos:

- operador Linux/PABX que quer copiar e rodar rapido no servidor
- integrador/devops que quer instalar por gerenciador de pacotes e automatizar

## Canais recomendados

### 1. Instalador via GitHub

Canal principal no inicio, porque funciona em qualquer distro Linux com `curl`, `tar` e shell.

Formato desejado:

```bash
curl -fsSL https://raw.githubusercontent.com/Nvoip/nvoip-pabx-provisioner/main/scripts/install.sh | sudo sh
sudo nvoip-pabx-provisioner configure
```

Para release publico, o ideal é o instalador baixar um tarball versionado do GitHub Releases em vez de depender da branch `main`.

### 2. Pacotes `.deb` e `.rpm`

Canal recomendado para PABX em produção.

Publicar primeiro em GitHub Releases:

- `nvoip-pabx-provisioner_VERSION_all.deb`
- `nvoip-pabx-provisioner_VERSION_noarch.rpm`

Depois criar repositórios apt/yum próprios da Nvoip:

```bash
sudo apt install nvoip-pabx-provisioner
sudo nvoip-pabx-provisioner configure
```

Entrar no repositório oficial do Ubuntu/Debian/Fedora é mais lento e exige manutenção de empacotamento por distribuição. Para adoção rápida, usar repo próprio da Nvoip é melhor.

O projeto inclui `scripts/package.sh`, que gera `tar.gz` e `.deb` localmente. O `.rpm` e gerado no workflow Linux de release quando `rpmbuild` esta disponivel.

### 3. Homebrew

Bom para laboratório, macOS e admins que já usam `brew`.

```bash
brew tap Nvoip/tap
brew install nvoip-pabx-provisioner
```

### 4. npm

Viável como canal de conveniência para times que já usam Node, apesar do provisionador ser shell.

```bash
npm install -g @nvoip/pabx-provisioner
sudo nvoip-pabx-provisioner configure
```

Não deve ser o canal principal para servidores PABX, porque muitos ambientes mínimos não têm Node.js.

## Experiencia recomendada do cliente

Fluxo interativo:

```bash
sudo nvoip-pabx-provisioner configure
```

O assistente deve:

1. Detectar PABX automaticamente.
2. Perguntar usuário do trunk.
3. Perguntar senha do trunk sem eco no terminal.
4. Usar `sip.nvoip.com.br` por padrão.
5. Perguntar se cria rotas de teste.
6. Perguntar se aplica ou só simula.
7. Validar registro depois de aplicar.

Fluxo automatizado:

```bash
sudo nvoip-pabx-provisioner provision \
  --trunk-user "$NVOIP_TRUNK_USER" \
  --trunk-password "$NVOIP_TRUNK_PASSWORD" \
  --apply \
  --validate
```

## Politica de seguranca

- `provision` continua sem prompt para automacao previsivel.
- `configure` é o unico modo interativo.
- senha pode vir por prompt ou env var, mas nunca deve ser impressa.
- `--dry-run` continua sendo o padrao.
- rotas de teste so entram com confirmacao explicita.
