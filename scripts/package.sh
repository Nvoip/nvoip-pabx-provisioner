#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version="${VERSION:-0.1.0}"
dist_dir="$root_dir/dist"
work_dir="${TMPDIR:-/tmp}/nvoip-pabx-package.$$"

rm -rf "$work_dir"
mkdir -p "$dist_dir" "$work_dir"
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

make_payload() {
  payload="$1"
  mkdir -p "$payload/usr/lib/nvoip-pabx-provisioner" "$payload/usr/bin"
  cp -R "$root_dir/bin" "$root_dir/lib" "$root_dir/README.md" "$root_dir/LICENSE" "$payload/usr/lib/nvoip-pabx-provisioner/"
  chmod +x "$payload/usr/lib/nvoip-pabx-provisioner/bin/nvoip-pabx-provisioner"
  ln -s /usr/lib/nvoip-pabx-provisioner/bin/nvoip-pabx-provisioner "$payload/usr/bin/nvoip-pabx-provisioner"
}

make_tarball() {
  tarball="$dist_dir/nvoip-pabx-provisioner-$version.tar.gz"
  src="$work_dir/nvoip-pabx-provisioner-$version"
  mkdir -p "$src"
  cp -R "$root_dir/bin" "$root_dir/lib" "$root_dir/scripts" "$root_dir/docs" "$root_dir/examples" "$root_dir/tests" "$root_dir/packaging" "$root_dir/README.md" "$root_dir/LICENSE" "$root_dir/package.json" "$src/"
  tar -C "$work_dir" -czf "$tarball" "nvoip-pabx-provisioner-$version"
  printf '%s\n' "$tarball"
}

make_deb() {
  package_dir="$work_dir/deb"
  payload="$package_dir/payload"
  control="$package_dir/control"
  mkdir -p "$payload" "$control"
  make_payload "$payload"
  sed "s/^Version:.*/Version: $version/" "$root_dir/packaging/deb/control" > "$control/control"
  printf '2.0\n' > "$package_dir/debian-binary"
  tar -C "$control" -czf "$package_dir/control.tar.gz" .
  tar -C "$payload" -czf "$package_dir/data.tar.gz" .

  deb="$dist_dir/nvoip-pabx-provisioner_${version}_all.deb"
  (cd "$package_dir" && ar r "$deb" debian-binary control.tar.gz data.tar.gz >/dev/null)
  printf '%s\n' "$deb"
}

make_rpm() {
  rpm="$dist_dir/nvoip-pabx-provisioner-${version}-1.noarch.rpm"
  if command -v rpmbuild >/dev/null 2>&1; then
    rpmbuild_root="$work_dir/rpmbuild"
    mkdir -p "$rpmbuild_root/BUILD" "$rpmbuild_root/RPMS" "$rpmbuild_root/SOURCES" "$rpmbuild_root/SPECS" "$rpmbuild_root/SRPMS"
    src="$work_dir/nvoip-pabx-provisioner-$version"
    mkdir -p "$src"
    cp -R "$root_dir/bin" "$root_dir/lib" "$root_dir/README.md" "$root_dir/LICENSE" "$src/"
    tar -C "$work_dir" -czf "$rpmbuild_root/SOURCES/nvoip-pabx-provisioner-$version.tar.gz" "nvoip-pabx-provisioner-$version"
    sed "s/^Version:.*/Version:        $version/" "$root_dir/packaging/rpm/nvoip-pabx-provisioner.spec" > "$rpmbuild_root/SPECS/nvoip-pabx-provisioner.spec"
    rpmbuild --define "_topdir $rpmbuild_root" -bb "$rpmbuild_root/SPECS/nvoip-pabx-provisioner.spec" >/dev/null
    cp "$rpmbuild_root/RPMS/noarch/"*.rpm "$rpm"
    printf '%s\n' "$rpm"
  else
    printf 'WARN: rpmbuild nao encontrado; RPM sera gerado pelo workflow de release em Linux.\n' >&2
  fi
}

make_tarball
make_deb
make_rpm
