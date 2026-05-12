#!/bin/bash
# tmjos-live-build-setup.sh
#
# Popula ~/tmjos-debian-build/config/ com configurações TMJOs:
# - TMJOs APT repo + GPG key (archives/)
# - VSCode repo (archives/)
# - Lista de pacotes (package-lists/tmjos.list.chroot)
# - Hooks pós-install (hooks/normal/)
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

# === 1. archives/ — APT repos extras ===
# Importante: SEM `signed-by=<path>` aqui porque live-build copia os
# `.key.chroot` pra /etc/apt/trusted.gpg.d/ no chroot. Apontar signed-by
# pra /usr/share/keyrings/ faria mismatch → repo unsigned → pacotes
# invisíveis. Em sistema instalado pelo customize.sh, signed-by é
# correto (key copiada explicitamente pra /usr/share/keyrings/).
echo "→ archives/ (TMJOs + VSCode)"

cat > "$CONFIG/archives/tmjos.list.chroot" << 'EOF'
deb [arch=amd64] https://packages.tmjos.com.br trixie main apps extras
EOF
cp "$CONFIG/archives/tmjos.list.chroot" "$CONFIG/archives/tmjos.list.binary"

curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.asc \
    -o "$CONFIG/archives/tmjos.key.chroot"
cp "$CONFIG/archives/tmjos.key.chroot" "$CONFIG/archives/tmjos.key.binary"

cat > "$CONFIG/archives/microsoft.list.chroot" << 'EOF'
deb [arch=amd64] https://packages.microsoft.com/repos/code stable main
EOF
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    -o "$CONFIG/archives/microsoft.key.chroot"

# === 2. package-lists/ ===
echo "→ package-lists/tmjos.list.chroot"

cat > "$CONFIG/package-lists/tmjos.list.chroot" << 'EOF'
# === Kernel + firmware ===
# Explícito porque `lb config` em algumas versões a57 gera nome errado
# (`linux-amd64` em vez de `linux-image-amd64`) na config interna.
linux-image-amd64
firmware-linux-free

# === GNOME desktop SLIM ===
# gnome-core é o meta minimal do GNOME (~1GB vs ~3GB do task-gnome-desktop).
# Traz gnome-shell, gdm3, nautilus, gnome-control-center, gnome-terminal,
# gnome-text-editor, gnome-calculator, eog, file-roller — o essencial.
# Sem LibreOffice, sem games, sem gnome-music/maps/weather/etc.
gnome-core
gnome-tweaks
dconf-editor

# === Evolution (Exchange compat) ===
evolution
evolution-ews

# === RAM efficiency (target idle ~700MB-1GB, OS roda em 2GB total) ===
zram-tools
preload

# === TMJOs meta (puxa branding, identity, defaults, tmjmenu, tmjpad) ===
tmjos

# === Installer ===
calamares
calamares-settings-debian

# === Dev stack ===
code
git
git-flow
docker.io
docker-compose

# === Python + GTK4 (pra apps TMJOs) ===
python3
python3-gi
python3-xlib
gir1.2-gtk-4.0
gir1.2-adw-1

# === CLI tools ===
curl
wget
htop
fastfetch
vim
xdotool
imagemagick

# === Fonts ===
fonts-jetbrains-mono
fonts-cantarell

# === Live system essentials ===
live-boot
live-config
live-config-systemd
EOF

# === 3. hooks/normal/ ===
mkdir -p "$CONFIG/hooks/normal"

# Hook 0500 — slim aggressive + service masking + zram setup.
# Roda DEPOIS dos pacotes serem instalados (package-lists rodam antes
# dos hooks). Remove gnome-* não-essenciais que vieram via gnome-core
# deps + mascara serviços pesados pra rodar em 2GB RAM.
echo "→ hooks/normal/0500-tmjos-slim.hook.chroot"
cat > "$CONFIG/hooks/normal/0500-tmjos-slim.hook.chroot" << 'HOOK'
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
chmod +x "$CONFIG/hooks/normal/0500-tmjos-slim.hook.chroot"

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
