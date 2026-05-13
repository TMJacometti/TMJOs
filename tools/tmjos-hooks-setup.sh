#!/bin/bash
# tmjos-hooks-setup.sh
#
# Popula config/ do build dir com:
# - hook 0100 chroot_early: instala base GNOME + TMJOs stack
# - hook 0500 normal: adiciona repos TMJOs+VSCode, instala meta+code
# - hook 0700 normal: masking serviços + zramswap enable
# - hook 0900 normal: caches finais
# - apt preferences pra bloquear rygel
# - dpkg.cfg pra skip docs/man/locales extras
#
# Espera BUILD_DIR no env. Sourced por tmjos-build.sh.

set -euo pipefail

if [ -z "${BUILD_DIR:-}" ]; then
    echo "ERROR: BUILD_DIR não setado. Chama via tmjos-build.sh." >&2
    exit 1
fi

CONFIG="$BUILD_DIR/config"

if [ ! -d "$CONFIG" ]; then
    echo "ERROR: $CONFIG não existe. Roda lb config primeiro." >&2
    exit 1
fi

echo "→ populando hooks/ e preferences/ em $CONFIG"

# Limpa qualquer config legacy de tentativas anteriores
rm -rf "$CONFIG/package-lists"
rm -rf "$CONFIG/includes.chroot_before_packages" 2>/dev/null || true
rm -f "$CONFIG/archives/"tmjos.* "$CONFIG/archives/"microsoft.* 2>/dev/null || true
mkdir -p "$CONFIG/package-lists"
mkdir -p "$CONFIG/hooks"
mkdir -p "$CONFIG/hooks/normal"

# ─────────────────────────────────────────────────────────────────
# Hook 0100 — early chroot: instala base Debian + GNOME minimal
# ─────────────────────────────────────────────────────────────────
echo "→ hooks/0100-tmjos-debian-base.chroot_early"
cat > "$CONFIG/hooks/0100-tmjos-debian-base.chroot_early" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs Debian base packages ==="

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1
export APT_LISTCHANGES_FRONTEND=none

# ───── dpkg: skip docs/man/locales extras ─────
# Economiza 200-500MB e elimina trigger lerdo do man-db.
cat > /etc/dpkg/dpkg.cfg.d/01-tmjos-no-docs << 'DPKG'
path-exclude=/usr/share/man/*
path-exclude=/usr/share/doc/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/groff/*
path-exclude=/usr/share/lintian/*
path-exclude=/usr/share/linda/*
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/en_US/*
path-include=/usr/share/locale/pt_BR/*
path-include=/usr/share/locale/locale.alias
DPKG

# Desativa trigger do man-db (mesmo com path-exclude, ele ainda
# escaneia diretório vazio — debconf elimina de vez).
echo "man-db man-db/auto-update boolean false" | debconf-set-selections

# ───── policy-rc.d: deny daemon starts em chroot ─────
cat > /usr/sbin/policy-rc.d << 'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x /usr/sbin/policy-rc.d

# ───── PATH shimming pra binários que travam em chroot ─────
# Approach robusto: pasta de shims no PATH prependado. Quando um
# postinst chama `systemctl daemon-reload`, `start-stop-daemon ...`,
# ou `update-initramfs -u`, o shim intercepta antes do binário real
# e retorna 0 silenciosamente. Nada do sistema é tocado.
#
# Anterior tentamos `dpkg-divert` mas é frágil: se o build crashar
# no meio, o estado fica corrompido (binário real movido pra .distrib
# e nunca volta). PATH shim é 100% reversível por `rm -rf`.
mkdir -p /usr/local/sbin/tmjos-shims
cat > /usr/local/sbin/tmjos-shims/_shim.sh << 'SHIM'
#!/bin/sh
echo "[$(basename "$0")] $@" >> /tmp/tmjos-shims.log 2>/dev/null || true
exit 0
SHIM
chmod +x /usr/local/sbin/tmjos-shims/_shim.sh

for cmd in systemctl start-stop-daemon initctl invoke-rc.d update-initramfs; do
    ln -sf /usr/local/sbin/tmjos-shims/_shim.sh \
           /usr/local/sbin/tmjos-shims/"$cmd"
done

export PATH=/usr/local/sbin/tmjos-shims:$PATH

# ───── Bloquear pacotes problemáticos via apt preferences ─────
# Rygel trava o build (trigger postinst em chroot). É Recommends de
# gnome-shell, então mesmo sem gnome-core entra se não bloqueado.
mkdir -p /etc/apt/preferences.d
cat > /etc/apt/preferences.d/tmjos-blocklist << 'PREFS'
Package: rygel rygel-playbin rygel-tracker rygel-tracker3
Pin: release *
Pin-Priority: -1
PREFS

# ───── Pre-mask serviços problemáticos ─────
# Mascarar ANTES do install impede systemd presets de ativar.
PREMASK="rygel.service \
         fwupd.service fwupd-refresh.service fwupd-refresh.timer \
         ModemManager.service \
         packagekit.service packagekit-offline-update.service \
         apt-daily.service apt-daily.timer \
         apt-daily-upgrade.service apt-daily-upgrade.timer \
         plymouth-quit-wait.service \
         tracker-miner-fs-3.service tracker-miner-rss-3.service \
         tracker-extract-3.service tracker-writeback-3.service \
         man-db.timer man-db.service"

mkdir -p /etc/systemd/system
for svc in $PREMASK; do
    ln -sf /dev/null "/etc/systemd/system/$svc" 2>/dev/null || true
done

apt-get update

APT_INSTALL="apt-get install -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    -o APT::Install-Recommends=true"

APT_INSTALL_NOREC="apt-get install -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    --no-install-recommends"

# ───── Bloco GNOME minimal (sem gnome-core, sem bloat) ─────
# Lista cirúrgica. --no-install-recommends evita arrastar yelp,
# gnome-user-docs, rygel, gnome-games, totem, rhythmbox, cheese etc.
echo "=== TMJOs block: GNOME minimal ==="
$APT_INSTALL_NOREC \
    gnome-session \
    gnome-shell \
    gnome-shell-extension-prefs \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    gdm3 \
    eog \
    evince \
    gnome-text-editor \
    gnome-calculator \
    gnome-system-monitor \
    gnome-disk-utility \
    file-roller \
    network-manager-gnome \
    gvfs-backends \
    xdg-user-dirs-gtk \
    adwaita-icon-theme \
    fonts-noto \
    pipewire \
    pipewire-pulse \
    pipewire-audio \
    wireplumber

echo "=== TMJOs block: Calamares ==="
# calamares-settings-debian provê settings.conf + module configs
# (unpackfs, bootloader, displaymanager etc.). O .deb tmjos-calamares-
# branding (instalado pelo hook 0500) só sobrescreve o branding.
$APT_INSTALL \
    zram-tools \
    calamares \
    calamares-settings-debian

echo "=== TMJOs block: Dev tools ==="
$APT_INSTALL \
    git

echo "=== TMJOs block: Python GTK (pra tmjmenu/tmjpad) ==="
$APT_INSTALL \
    python3 \
    python3-gi \
    python3-xlib \
    gir1.2-gtk-4.0 \
    gir1.2-adw-1

echo "=== TMJOs block: CLI ==="
$APT_INSTALL \
    curl \
    wget \
    gpg \
    ca-certificates \
    htop \
    vim \
    xdotool \
    fonts-jetbrains-mono

# ───── Remove shims do PATH ─────
# Cleanup é simples: rm -rf na pasta. Nada do sistema foi tocado.
rm -rf /usr/local/sbin/tmjos-shims
export PATH="$(echo "$PATH" | sed 's|/usr/local/sbin/tmjos-shims:||g')"

echo "=== TMJOs base done ==="
HOOK
chmod +x "$CONFIG/hooks/0100-tmjos-debian-base.chroot_early"

# ─────────────────────────────────────────────────────────────────
# Hook 0500 — normal chroot: adiciona repos TMJOs + Microsoft VSCode
# ─────────────────────────────────────────────────────────────────
echo "→ hooks/normal/0500-tmjos-apt-install.hook.chroot"
cat > "$CONFIG/hooks/normal/0500-tmjos-apt-install.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs apt repos + install ==="

export DEBIAN_FRONTEND=noninteractive

mkdir -p /usr/share/keyrings

# TMJOs APT repo
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

apt-get install -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    tmjos code

# Ativa branding tmjos no Calamares
if [ -d /usr/share/calamares/branding/tmjos ] && [ -f /etc/calamares/settings.conf ]; then
    if grep -qE '^[[:space:]]*branding:' /etc/calamares/settings.conf; then
        sed -i 's/^[[:space:]]*branding:.*/branding: tmjos/' /etc/calamares/settings.conf
    else
        echo "branding: tmjos" >> /etc/calamares/settings.conf
    fi
fi

echo "=== TMJOs apt install done ==="
HOOK
chmod +x "$CONFIG/hooks/normal/0500-tmjos-apt-install.hook.chroot"

# ─────────────────────────────────────────────────────────────────
# Hook 0700 — slim service masking + zram
# ─────────────────────────────────────────────────────────────────
echo "→ hooks/normal/0700-tmjos-slim.hook.chroot"
cat > "$CONFIG/hooks/normal/0700-tmjos-slim.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs slim hook ==="

export DEBIAN_FRONTEND=noninteractive

# Safety net — purga só o que talvez tenha entrado por Depends
BLOAT="rygel rygel-playbin rygel-tracker rygel-tracker3 \
       libreoffice-core libreoffice-common"

for pkg in $BLOAT; do
    apt-get remove --purge -y "$pkg" 2>/dev/null || true
done
apt-get autoremove --purge -y || true

# Mascara serviços pesados pro sistema instalado
MASK="tracker-miner-fs-3.service tracker-miner-rss-3.service \
      tracker-extract-3.service tracker-writeback-3.service \
      packagekit.service packagekit-offline-update.service \
      apt-daily.service apt-daily.timer \
      apt-daily-upgrade.service apt-daily-upgrade.timer \
      plymouth-quit-wait.service"

for svc in $MASK; do
    systemctl mask "$svc" 2>/dev/null || true
done

# zram swap pro live + sistema instalado
systemctl enable zramswap.service 2>/dev/null || true

echo "=== TMJOs slim done ==="
HOOK
chmod +x "$CONFIG/hooks/normal/0700-tmjos-slim.hook.chroot"

# ─────────────────────────────────────────────────────────────────
# Hook 0900 — caches finais
# ─────────────────────────────────────────────────────────────────
echo "→ hooks/normal/0900-tmjos-caches.hook.chroot"
cat > "$CONFIG/hooks/normal/0900-tmjos-caches.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs caches ==="
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache --quiet --force /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database --quiet /usr/share/applications || true
echo "=== TMJOs caches done ==="
HOOK
chmod +x "$CONFIG/hooks/normal/0900-tmjos-caches.hook.chroot"

echo "✓ Hooks e preferences populados"