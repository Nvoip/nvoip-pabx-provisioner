#!/bin/sh
set -eu

prefix="${PREFIX:-/usr/local}"
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
target_dir="${prefix}/lib/nvoip-pabx-provisioner"
bin_dir="${prefix}/bin"

if [ "$(id -u)" -ne 0 ] && [ ! -w "$prefix" ]; then
  echo "Execute com sudo ou informe PREFIX para um diretorio gravavel." >&2
  exit 1
fi

mkdir -p "$target_dir" "$bin_dir"
cp -R "$repo_dir/bin" "$repo_dir/lib" "$repo_dir/README.md" "$repo_dir/LICENSE" "$target_dir/"
chmod +x "$target_dir/bin/nvoip-pabx-provisioner"
ln -sf "$target_dir/bin/nvoip-pabx-provisioner" "$bin_dir/nvoip-pabx-provisioner"

echo "Instalado em: $target_dir"
echo "Comando: $bin_dir/nvoip-pabx-provisioner"
echo "Proximo passo: sudo nvoip-pabx-provisioner configure"
