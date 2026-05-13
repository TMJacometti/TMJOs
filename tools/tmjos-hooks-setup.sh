#!/bin/bash
# tmjos-hooks-setup.sh
#
# Popula config/ do build dir com:
# - package-lists/tmjos.list.chroot: lista de pacotes Debian instalados
#   pelo live-build (stage chroot_install-packages)
# - includes.chroot_before_packages/: defenses pré-install
#   (dpkg.cfg path-exclude, APT preferences blocklist, policy-rc.d)
# - hooks/normal/*.hook.chroot: customização pós-install
#   - 0500: adiciona repos TMJOs+VSCode, instala meta+code
#   - 0700: masking serviços + zramswap enable
#   - 0900: caches finais (icon, desktop-database)
#
# Espera BUILD_DIR no env. Sourced por tmjos-build.sh.
#
# Approach pra live-build moderno upstream (Debian, 20250505+):
# - SEM hooks .chroot_early (sufixo legacy, removido em moderno)
# - SEM shims systemctl/start-stop-daemon (live-build moderno já tem
#   policy-rc.d, em Debian host postinst não trava em chroot)
# - SEM workaround /root/isolinux/ (com --bootloader grub-efi)

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

echo "→ populando config/ em $CONFIG"

# Limpa estado legacy (hooks com sufixos antigos, archives manuais)
rm -rf "$CONFIG/hooks"
rm -rf "$CONFIG/package-lists"
rm -rf "$CONFIG/includes.chroot_before_packages"
rm -f "$CONFIG/archives/"tmjos.* "$CONFIG/archives/"microsoft.* 2>/dev/null || true
mkdir -p "$CONFIG/hooks/normal"
mkdir -p "$CONFIG/package-lists"
mkdir -p "$CONFIG/includes.chroot_before_packages"

# ─────────────────────────────────────────────────────────────────
# 1. package-lists/tmjos.list.chroot
# ─────────────────────────────────────────────────────────────────
# Live-build instala TODOS esses pacotes via stage chroot_install-packages
# ANTES dos hooks normais rodarem. Daí o hook 0500 tem curl/gpg disponível.
echo "→ package-lists/tmjos.list.chroot"
cat > "$CONFIG/package-lists/tmjos.list.chroot" << 'PKG'
# === Kernel + firmware (firmware vem via archive-areas non-free-firmware) ===
linux-image-amd64

# === GNOME desktop minimal (sem gnome-core meta — evita rygel/yelp/games) ===
gnome-session
gnome-shell
gnome-shell-extension-prefs
gnome-settings-daemon
gnome-control-center
gnome-terminal
nautilus
gdm3
eog
evince
gnome-text-editor
gnome-calculator
gnome-system-monitor
gnome-disk-utility
file-roller
network-manager-gnome
gvfs-backends
xdg-user-dirs-gtk
adwaita-icon-theme
fonts-noto

# === Audio (PipeWire) ===
pipewire
pipewire-pulse
pipewire-audio
wireplumber

# === RAM efficiency ===
zram-tools

# === Installer ===
calamares
calamares-settings-debian

# === Dev tools ===
git

# === Python + GTK (pra tmjmenu/tmjpad/tmjstore) ===
python3
python3-gi
python3-xlib
gir1.2-gtk-4.0
gir1.2-adw-1

# === CLI essenciais (hook 0500 precisa de curl/gpg/ca-certificates) ===
curl
wget
gpg
ca-certificates
htop
vim
xdotool
fonts-jetbrains-mono

# === Live system ===
live-boot
live-config
live-config-systemd
PKG

# ─────────────────────────────────────────────────────────────────
# 2. includes.chroot_before_packages/ — defenses copiadas pro chroot
#    ANTES dos pacotes serem instalados (afetam apt/dpkg behavior)
# ─────────────────────────────────────────────────────────────────

# 2a. dpkg.cfg.d — skip docs/man/locales (economiza 200-500MB)
echo "→ includes.chroot_before_packages/etc/dpkg/dpkg.cfg.d/01-tmjos-no-docs"
mkdir -p "$CONFIG/includes.chroot_before_packages/etc/dpkg/dpkg.cfg.d"
cat > "$CONFIG/includes.chroot_before_packages/etc/dpkg/dpkg.cfg.d/01-tmjos-no-docs" << 'DPKG'
# TMJOs: skip docs/man/locales-extras
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

# 2b. APT preferences — blocklist rygel (Recommends de gnome-shell, trava
# o build em chroot se entrar)
echo "→ includes.chroot_before_packages/etc/apt/preferences.d/tmjos-blocklist"
mkdir -p "$CONFIG/includes.chroot_before_packages/etc/apt/preferences.d"
cat > "$CONFIG/includes.chroot_before_packages/etc/apt/preferences.d/tmjos-blocklist" << 'PREFS'
# TMJOs: rygel é problemático em chroot. Bloqueia totalmente.
Package: rygel rygel-playbin rygel-tracker rygel-tracker3
Pin: release *
Pin-Priority: -1
PREFS

# ─────────────────────────────────────────────────────────────────
# 3. Hook 0500 — adiciona repos TMJOs + Microsoft VSCode, instala
#    `tmjos` (meta) + `code`. Tudo Debian já foi instalado via
#    package-list, então curl/gpg/ca-certificates estão disponíveis.
# ─────────────────────────────────────────────────────────────────
echo "→ hooks/normal/0500-tmjos-apt-install.hook.chroot"
cat > "$CONFIG/hooks/normal/0500-tmjos-apt-install.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs apt repos + install ==="

export DEBIAN_FRONTEND=noninteractive

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

# tmjos meta puxa tmjos-branding, tmjos-os-identity, tmjos-defaults,
# tmjmenu, tmjpad via Depends; tmjos-calamares-branding via Recommends.
apt-get install -y \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    tmjos code

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

# ─────────────────────────────────────────────────────────────────
# 4. Hook 0700 — slim aggressive + service masking
# ─────────────────────────────────────────────────────────────────
echo "→ hooks/normal/0700-tmjos-slim.hook.chroot"
cat > "$CONFIG/hooks/normal/0700-tmjos-slim.hook.chroot" << 'HOOK'
#!/bin/sh
set -e
echo "=== TMJOs slim hook ==="

export DEBIAN_FRONTEND=noninteractive

# Safety net — purga só o que talvez tenha entrado por Depends de terceiros
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
# 5. Hook 0900 — caches finais
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
