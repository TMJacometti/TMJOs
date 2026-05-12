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

BUILD_DIR="$HOME/tmjos-debian-build"
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
echo "→ archives/ (TMJOs + VSCode)"

cat > "$CONFIG/archives/tmjos.list.chroot" << 'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br trixie main apps
EOF
cp "$CONFIG/archives/tmjos.list.chroot" "$CONFIG/archives/tmjos.list.binary"

curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.asc \
    -o "$CONFIG/archives/tmjos.key.chroot"
cp "$CONFIG/archives/tmjos.key.chroot" "$CONFIG/archives/tmjos.key.binary"

cat > "$CONFIG/archives/microsoft.list.chroot" << 'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    -o "$CONFIG/archives/microsoft.key.chroot"

# === 2. package-lists/ ===
echo "→ package-lists/tmjos.list.chroot"

cat > "$CONFIG/package-lists/tmjos.list.chroot" << 'EOF'
tmjos
calamares
calamares-settings-debian
code
git
git-flow
docker.io
docker-compose
gnome-tweaks
dconf-editor
python3
python3-gi
python3-xlib
gir1.2-gtk-4.0
gir1.2-adw-1
curl
wget
htop
neofetch
vim
xdotool
imagemagick
fonts-jetbrains-mono
fonts-cantarell
live-boot
live-config
live-config-systemd
EOF

# === 3. hooks/normal/ ===
echo "→ hooks/normal/0900-tmjos-setup.hook.chroot"

mkdir -p "$CONFIG/hooks/normal"
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
