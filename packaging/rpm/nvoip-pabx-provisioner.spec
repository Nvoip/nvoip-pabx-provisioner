Name:           nvoip-pabx-provisioner
Version:        0.1.6
Release:        1%{?dist}
Summary:        Provisionador de trunk SIP Nvoip para PABX Linux
License:        GPL-3.0-only
URL:            https://www.nvoip.com.br/
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

%description
CLI para provisionar trunk SIP Nvoip em Asterisk, FreePBX, Issabel,
FreeSWITCH e FusionPBX, com modo interativo e validacao.

%prep
%setup -q

%build

%install
mkdir -p %{buildroot}/usr/lib/nvoip-pabx-provisioner
mkdir -p %{buildroot}/usr/bin
cp -R bin lib README.md LICENSE %{buildroot}/usr/lib/nvoip-pabx-provisioner/
chmod +x %{buildroot}/usr/lib/nvoip-pabx-provisioner/bin/nvoip-pabx-provisioner
ln -s /usr/lib/nvoip-pabx-provisioner/bin/nvoip-pabx-provisioner %{buildroot}/usr/bin/nvoip-pabx-provisioner

%files
/usr/bin/nvoip-pabx-provisioner
/usr/lib/nvoip-pabx-provisioner

%changelog
* Fri May 01 2026 Nvoip <suporte@nvoip.com.br> - 0.1.6-1
- Provisiona trunks FreePBX/Issabel pelo banco nativo do PBX

* Fri May 01 2026 Nvoip <suporte@nvoip.com.br> - 0.1.5-1
- Ajusta deteccao e provisionamento para Issabel classico com chan_sip

* Thu Apr 30 2026 Nvoip <suporte@nvoip.com.br> - 0.1.0-1
- Release inicial
