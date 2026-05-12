#!/bin/bash
# tmjos-live-build-setup.sh
#
# Popula ~/tmjos-debian-build/config/ com configurações TMJOs:
# - TMJOs APT repo + GPG key (archives/)
# - VSCode repo (archives/)
# - Hook early com pacotes Debian base (hooks/0100-*.chroot_early)
# - Hooks pós-install TMJOs (hooks/normal/)
#
# Roda APÓS `lb config ...` ter sido executado.
# Usage: sudo ./tools/tmjos-live-build-setup.sh

set -euo pipefail

# Quando rodado via sudo, $HOME vira /root. O lb config foi rodado no home
# do user real, então resolvemos via SUDO_USER pra achar o build dir certo.
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    USER_HOME="$HOME"
fi

BUILD_DIR="${TMJOS_BUILD_DIR:-$USER_HOME/tmjos-debian-build}"
CONFIG="$BUILD_DIR/config"

if [ ! -d "$CONFIG" ]; then
    echo "ERROR: $CONFIG não existe. Roda 'lb config' primeiro."
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Roda com sudo (precisa escrever em config/ — lb config criou com root)"
    exit 1
fi

echo "Populando $CONFIG com TMJOs branding..."

# === 0. Fix vazamentos Ubuntu no `lb config` (quando rodado em host Ubuntu) ===
# Root cause: `lb config` em host Ubuntu seta LB_MODE="ubuntu", que faz
# live-build tratar o build como Ubuntu derivative. Isso vaza pra outras
# vars: LB_KEYRING_PACKAGES, LB_LINUX_PACKAGES, mirrors, labels.
# Fix manual em todos os config files.
echo "→ corrigindo vazamentos Ubuntu em config/*"

# config/common — LB_MODE é o root cause. Mudar pra debian fixa tudo
# implicitamente em runtime, mas as outras vars já foram persistidas
# pelo lb config — então precisamos mexer em cada uma também.
sed -i 's/^LB_MODE="ubuntu"$/LB_MODE="debian"/' "$CONFIG/common"

# config/chroot — keyring + kernel naming
sed -i 's/^LB_KEYRING_PACKAGES="ubuntu-keyring"$/LB_KEYRING_PACKAGES="debian-archive-keyring"/' "$CONFIG/chroot"
sed -i 's/^LB_LINUX_PACKAGES="linux"$/LB_LINUX_PACKAGES="linux-image"/' "$CONFIG/chroot"
sed -i 's/^LB_SECURITY="true"$/LB_SECURITY="false"/' "$CONFIG/chroot"

# config/bootstrap — mirrors. Security fica desativado no live-build
# porque esta versão gera `trixie/updates`, suite antiga que 404 em
# Debian moderno. O sistema instalado recebe updates via sources Debian.
sed -i 's|^LB_PARENT_MIRROR_CHROOT_SECURITY="http://security.ubuntu.com/ubuntu/"$|LB_PARENT_MIRROR_CHROOT_SECURITY="http://security.debian.org/debian-security/"|' "$CONFIG/bootstrap"
sed -i 's|^LB_PARENT_MIRROR_BINARY_SECURITY="http://security.ubuntu.com/ubuntu/"$|LB_PARENT_MIRROR_BINARY_SECURITY="http://security.debian.org/debian-security/"|' "$CONFIG/bootstrap"
sed -i 's|^LB_MIRROR_CHROOT_SECURITY="http://security.ubuntu.com/ubuntu/"$|LB_MIRROR_CHROOT_SECURITY="http://security.debian.org/debian-security/"|' "$CONFIG/bootstrap"
sed -i 's|^LB_MIRROR_BINARY_SECURITY="http://security.ubuntu.com/ubuntu/"$|LB_MIRROR_BINARY_SECURITY="http://security.debian.org/debian-security/"|' "$CONFIG/bootstrap"

# config/bootstrap — volatile mirrors (trixie-updates)
sed -i 's|^LB_MIRROR_CHROOT_VOLATILE="http://archive.ubuntu.com/ubuntu/"$|LB_MIRROR_CHROOT_VOLATILE="http://deb.debian.org/debian/"|' "$CONFIG/bootstrap"
sed -i 's|^LB_MIRROR_BINARY_VOLATILE="http://archive.ubuntu.com/ubuntu/"$|LB_MIRROR_BINARY_VOLATILE="http://deb.debian.org/debian/"|' "$CONFIG/bootstrap"

# config/binary — labels e syslinux theme
sed -i 's/^LB_HDD_LABEL="UBUNTU"$/LB_HDD_LABEL="TMJOS"/' "$CONFIG/binary"
sed -i 's|^LB_NET_ROOT_PATH="/srv/ubuntu-live"$|LB_NET_ROOT_PATH="/srv/tmjos-live"|' "$CONFIG/binary"
sed -i 's/^LB_SYSLINUX_THEME="ubuntu-oneiric"$/LB_SYSLINUX_THEME=""/' "$CONFIG/binary"

# === 1. APT repos extras — via hook 0500 (rodado depois do install pass) ===
# Tentamos archives/ e includes.chroot_before_packages/ — ambos falharam
# em live-build a57 por timing issues (keys não registradas a tempo do
# apt-get update interno).
#
# Solução robusta: hook early instala a base Debian main, e o hook 0500
# adiciona repos extras + faz apt install do `tmjos` e `code` depois do
# install pass. Mais controlado e evita bugs de package-list do live-build.
#
# Limpa qualquer config legacy de attempts anteriores:
rm -f "$CONFIG/archives/"tmjos.* "$CONFIG/archives/"microsoft.* 2>/dev/null || true
rm -rf "$CONFIG/includes.chroot_before_packages" 2>/dev/null || true

# === 2. Debian base packages — early hook ===
# Evita `config/package-lists/*.list.chroot`: live-build a57 em alguns
# hosts trava em lb_chroot_package-lists depois de instalar dctrl-tools.
# Instalar a base Debian via hook early pula essa etapa defeituosa.
# Kernel/firmware/live-boot ficam com as stages nativas do live-build
# (lb_chroot_linux-image/lb_chroot_live-packages), evitando disparar
# initramfs/firmware hooks cedo demais dentro deste hook.
rm -rf "$CONFIG/package-lists"
mkdir -p "$CONFIG/package-lists"
mkdir -p "$CONFIG/hooks"

echo "→ hooks/0100-tmjos-debian-base.chroot_early"
cat > "$CONFIG/hooks/0100-tmjos-debian-base.chroot_early" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs Debian base packages ==="

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

# === Speed up dpkg pre-install ===
# Skip man pages + docs + extra locales. Economiza:
#   - 200-500MB do tamanho final da ISO
#   - 5-15min de man-db trigger pós-install (regenera ~5000 manpages
#     toda vez que gnome-core+evolution chegam no chroot)
# Apps modernos usam Web Help / --help; manpages essenciais ficam em
# /usr/share/man/man1 dos coreutils que vêm no debootstrap base.
cat > /etc/dpkg/dpkg.cfg.d/01-tmjos-no-docs << 'DPKG'
# TMJOs: skip docs/man/locale-extras pra acelerar install + slim ISO
path-exclude=/usr/share/man/*
path-exclude=/usr/share/doc/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/groff/*
path-exclude=/usr/share/lintian/*
path-exclude=/usr/share/linda/*
# Mantém só locales en_US e pt_BR (TMJOs é BR-first)
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/en_US/*
path-include=/usr/share/locale/pt_BR/*
path-include=/usr/share/locale/locale.alias
DPKG

# === Reforça policy-rc.d ===
# Live-build já criou /usr/sbin/policy-rc.d com exit 101 (deny daemon
# starts), mas alguns scripts pós-install bypassam policy-rc.d e
# rodam systemctl direto. Stub do systemctl evita travas.
cat > /usr/sbin/policy-rc.d << 'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x /usr/sbin/policy-rc.d

# === Stub update-initramfs durante install ===
# Trigger update-initramfs em chroot pode travar tentando carregar
# módulos do kernel. Live-build regenera o initrd correto na binary
# stage de qualquer jeito — então durante install é seguro skipar.
# Restauramos no fim do hook pra que stages binary não quebrem.
if [ ! -f /usr/sbin/update-initramfs.real ]; then
    mv /usr/sbin/update-initramfs /usr/sbin/update-initramfs.real
    cat > /usr/sbin/update-initramfs << 'STUB'
#!/bin/sh
echo "[stub] update-initramfs $* skipped during chroot install (regenerated later by lb_binary)"
exit 0
STUB
    chmod +x /usr/sbin/update-initramfs
fi

# === Stub ldconfig durante install (opcional defesa) ===
# Ldconfig é fast normalmente, mas em chroots com bibliotecas
# corrompidas pode travar. Não vamos stub aqui — só se necessário.

# === Pre-mask daemons problemáticos ===
# Esses daemons tentam conectar D-Bus/Avahi/socket durante post-install
# e podem fazer dpkg ficar esperando indefinidamente em chroot.
# Mascarar ANTES do install impede que systemd presets ativem eles.
PREMASK="rygel.service \
         fwupd.service fwupd-refresh.service fwupd-refresh.timer \
         ModemManager.service \
         packagekit.service packagekit-offline-update.service \
         apt-daily.service apt-daily.timer \
         apt-daily-upgrade.service apt-daily-upgrade.timer \
         plymouth-quit-wait.service \
         tracker-miner-fs-3.service tracker-miner-rss-3.service \
         tracker-extract-3.service tracker-writeback-3.service"

mkdir -p /etc/systemd/system
for svc in $PREMASK; do
    ln -sf /dev/null "/etc/systemd/system/$svc" 2>/dev/null || true
done

apt-get update

APT_INSTALL="apt-get install -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    -o APT::Install-Recommends=true"

echo "=== TMJOs block: GNOME base ==="
$APT_INSTALL \
    gnome-core \
    gnome-tweaks \
    dconf-editor

echo "=== TMJOs block: Evolution ==="
$APT_INSTALL \
    evolution \
    evolution-ews

echo "=== TMJOs block: Calamares + RAM tools ==="
$APT_INSTALL \
    zram-tools \
    preload \
    calamares \
    calamares-settings-debian

echo "=== TMJOs block: Dev stack ==="
$APT_INSTALL \
    git \
    git-flow \
    docker.io \
    docker-compose

echo "=== TMJOs block: Python GTK ==="
$APT_INSTALL \
    python3 \
    python3-gi \
    python3-xlib \
    gir1.2-gtk-4.0 \
    gir1.2-adw-1

echo "=== TMJOs block: CLI + fonts ==="
$APT_INSTALL \
    dctrl-tools \
    curl \
    wget \
    gpg \
    ca-certificates \
    htop \
    fastfetch \
    vim \
    xdotool \
    imagemagick \
    fonts-jetbrains-mono \
    fonts-cantarell

# === Restore update-initramfs pra binary stage ===
if [ -f /usr/sbin/update-initramfs.real ]; then
    mv /usr/sbin/update-initramfs.real /usr/sbin/update-initramfs
fi

echo "=== TMJOs Debian base packages done ==="
HOOK
chmod +x "$CONFIG/hooks/0100-tmjos-debian-base.chroot_early"

# === 3. hooks/normal/ ===
mkdir -p "$CONFIG/hooks/normal"

# Hook 0500 — adiciona repos TMJOs + Microsoft VSCode e instala
# `tmjos` (meta) + `code`. Rodar isto AQUI (e não via package-list)
# evita timing issues do live-build a57 com archives/ e includes.
echo "→ hooks/normal/0500-tmjos-apt-install.hook.chroot"
cat > "$CONFIG/hooks/normal/0500-tmjos-apt-install.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs apt repos + install ==="

mkdir -p /usr/share/keyrings

# TMJOs APT repo (trixie)
curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.gpg \
    -o /usr/share/keyrings/tmjos-archive-keyring.gpg
cat > /etc/apt/sources.list.d/tmjos.list << 'SOURCES'
deb [arch=amd64 signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br trixie main apps extras
SOURCES

# Microsoft VSCode
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor > /usr/share/keyrings/microsoft.gpg
cat > /etc/apt/sources.list.d/vscode.list << 'SOURCES'
deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main
SOURCES

apt-get update

# Install tmjos meta (puxa tmjos-branding, tmjos-os-identity, tmjos-defaults,
# tmjmenu, tmjpad via Depends; tmjos-calamares-branding via Recommends)
# + code (VSCode oficial).
DEBIAN_FRONTEND=noninteractive apt-get install -y tmjos code

# Ativa branding tmjos no Calamares se o pacote foi instalado.
if [ -d /usr/share/calamares/branding/tmjos ] && [ -f /etc/calamares/settings.conf ]; then
    if grep -qE '^[[:space:]]*branding:' /etc/calamares/settings.conf; then
        sed -i 's/^[[:space:]]*branding:.*/branding: tmjos/' /etc/calamares/settings.conf
    else
        echo "branding: tmjos" >> /etc/calamares/settings.conf
    fi
    echo "  → Calamares branding ativado: tmjos"
fi

echo "=== TMJOs apt install done ==="
HOOK
chmod +x "$CONFIG/hooks/normal/0500-tmjos-apt-install.hook.chroot"

# Hook 0700 — slim aggressive + service masking + zram setup.
# Remove gnome-* não-essenciais que vieram via gnome-core deps +
# mascara serviços pesados pra rodar em 2GB RAM.
echo "→ hooks/normal/0700-tmjos-slim.hook.chroot"
cat > "$CONFIG/hooks/normal/0700-tmjos-slim.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs slim aggressive hook ==="

# Safety net: remove pacotes bloat se vieram via Recommends.
# Evolution NÃO está aqui — user usa Exchange.
BLOAT="yelp yelp-xsl gnome-music gnome-todo gnome-maps gnome-weather \
       gnome-contacts gnome-photos gnome-boxes \
       aisleriot gnome-mahjongg gnome-mines gnome-sudoku gnome-2048 \
       gnome-chess gnome-klotski gnome-nibbles gnome-robots \
       gnome-tetravex five-or-more four-in-a-row hitori iagno \
       lightsoff quadrapassel swell-foop tali \
       totem totem-common totem-plugins rhythmbox rhythmbox-data \
       cheese cheese-common transmission-gtk transmission-common \
       libreoffice-core libreoffice-common"

for pkg in $BLOAT; do
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "$pkg" 2>/dev/null || true
done
DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y || true

# Mascara serviços pesados (Tracker, PackageKit, auto-upgrade,
# plymouth-quit-wait). Cada `|| true` porque nem todos existem em
# todos os perfis.
MASK="tracker-miner-fs-3.service tracker-miner-rss-3.service \
      tracker-extract-3.service tracker-writeback-3.service \
      packagekit.service packagekit-offline-update.service \
      apt-daily-upgrade.service apt-daily-upgrade.timer \
      plymouth-quit-wait.service"

for svc in $MASK; do
    systemctl mask "$svc" 2>/dev/null || true
done

# Habilita zram swap (compressão RAM swap, crítico pra 2GB).
# zram-tools provê /etc/default/zramswap — defaults são razoáveis.
systemctl enable zramswap.service 2>/dev/null || true

echo "=== TMJOs slim hook done ==="
HOOK
chmod +x "$CONFIG/hooks/normal/0700-tmjos-slim.hook.chroot"

# Hook 0900 — caches finais (icon-cache, desktop-database).
echo "→ hooks/normal/0900-tmjos-setup.hook.chroot"
cat > "$CONFIG/hooks/normal/0900-tmjos-setup.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs setup hook ==="
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache --quiet --force /usr/share/icons/hicolor || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database --quiet /usr/share/applications || true
fi
echo "=== TMJOs setup hook done ==="
HOOK
chmod +x "$CONFIG/hooks/normal/0900-tmjos-setup.hook.chroot"

# === 4. Sumário ===
echo ""
echo "✓ TMJOs live-build config populado em $CONFIG"
echo ""
echo "Próximos passos:"
echo "  cd $BUILD_DIR"
echo "  sudo lb build 2>&1 | tee build.log"
echo ""
echo "ISO sai em $BUILD_DIR/*.iso (~30-60min de build)"
