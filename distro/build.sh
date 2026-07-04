#!/bin/bash
# TMJOs Distro — build ISO using live-build
# Runs on Ubuntu host (GitHub Actions runner or local Docker)
# Target: amd64 only, XFCE, Ubuntu 26.04 base
set -euo pipefail

DISTRO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DISTRO_DIR/.." && pwd)"
# BUILD_DIR pode ser overridado via env var. Default /tmp/tmjos-build
# (compatibilidade CI). Builds locais geralmente passam BUILD_DIR
# apontando pro HOME pra escapar de /tmp pequeno/tmpfs.
BUILD_DIR="${BUILD_DIR:-/tmp/tmjos-build}"
ARCH="amd64"
SUITE="plucky"  # Ubuntu 26.04 codename

echo "========================================="
echo "  TMJOs Distro — ISO Builder"
echo "  Arch: $ARCH | Base: Ubuntu $SUITE"
echo "========================================="

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Initialize live-build (single lb config call — a second call resets the first).
# --security false: live-build a57 gera sources.list pro security archive
# com sintaxe antiga "plucky/updates" (Ubuntu pre-2020). Ubuntu plucky
# hoje usa "plucky-security" (hyphen). Path /plucky/updates/ retorna 404
# nos mirrors. Desabilitar evita o build quebrar — security updates serão
# puxados via apt update normal no sistema instalado.
lb config \
    --distribution "$SUITE" \
    --archive-areas "main restricted universe multiverse" \
    --architectures "$ARCH" \
    --binary-images iso-hybrid \
    --bootloader "syslinux" \
    --debian-installer false \
    --initsystem systemd \
    --linux-flavours "generic" \
    --memtest none \
    --security false \
    --iso-application "TMJOs" \
    --iso-publisher "TMJ Sistemas" \
    --iso-volume "TMJOs" \
    --parent-mirror-bootstrap "http://archive.ubuntu.com/ubuntu" \
    --mirror-bootstrap "http://archive.ubuntu.com/ubuntu"

# Live-build a57 (Ubuntu fork antigo) referencia pacotes Ubuntu 2011 que
# foram removidos no Ubuntu moderno:
#   - syslinux-themes-ubuntu-oneiric (era LB_SYSLINUX_THEME default)
#   - gfxboot-theme-ubuntu (hardcoded em lb_binary_syslinux:103 quando
#     LB_MODE=ubuntu)
#
# Fixes:
#   1. LB_SYSLINUX_THEME=live-build — valor especial que cai num case
#      no lb_binary_syslinux que só precisa de librsvg2-bin (existe).
#   2. LB_MODE=debian — força o case "ubuntu" do gfxboot-theme-ubuntu
#      check ser pulado. O resto do build continua usando Ubuntu mirrors
#      (LB_PARENT_MIRROR_* setados acima), só o package check não dispara.
sed -i 's/^LB_SYSLINUX_THEME=.*/LB_SYSLINUX_THEME="live-build"/' config/binary
sed -i 's/^LB_MODE="ubuntu"$/LB_MODE="debian"/' config/common

# DEBOOTSTRAP_OPTIONS é honrado pelo lb_bootstrap_debootstrap (concat
# antes do call). Forçar `--keyring=ubuntu-archive-keyring.gpg` (current)
# em vez do default que aponta pra removed-keys via script `gutsy` legacy.
# Sem isso debootstrap aborta com "Release signed by unknown key
# 871920D1991BC93C" em hosts com debootstrap antigo (1.0.142+).
export DEBOOTSTRAP_OPTIONS="--keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg"

# Package lists
mkdir -p config/package-lists
grep -v '^\s*#' "$DISTRO_DIR/packages.list" | grep -v '^\s*$' | sed 's/#.*//' \
    > config/package-lists/tmjos.list.chroot

# Hooks — run inside chroot during build
mkdir -p config/hooks/normal
cp "$DISTRO_DIR/hooks/01-remove-bloat.sh" config/hooks/normal/0100-remove-bloat.hook.chroot
cp "$DISTRO_DIR/hooks/02-install-dev-tools.sh" config/hooks/normal/0200-install-dev-tools.hook.chroot
cp "$DISTRO_DIR/hooks/03-apply-theme.sh" config/hooks/normal/0300-apply-theme.hook.chroot
cp "$DISTRO_DIR/hooks/04-setup-tmjmenu.sh" config/hooks/normal/0400-setup-tmjmenu.hook.chroot
cp "$DISTRO_DIR/hooks/05-branding-installer.sh" config/hooks/normal/0500-branding-installer.hook.chroot
chmod +x config/hooks/normal/*.hook.chroot

# Copy distro dir into chroot so hooks can access theme files and lists
mkdir -p config/includes.chroot/tmp/tmjos-distro
cp -r "$DISTRO_DIR"/* config/includes.chroot/tmp/tmjos-distro/
cp -r "$REPO_ROOT/assets" config/includes.chroot/tmp/tmjos-distro/

# Wallpaper and logo into final image
mkdir -p config/includes.chroot/usr/share/backgrounds/tmjos
cp "$REPO_ROOT/assets/wallpapers/tmjos_wallpaper_4k.png" \
    config/includes.chroot/usr/share/backgrounds/tmjos/
mkdir -p config/includes.chroot/usr/share/pixmaps
cp "$REPO_ROOT/assets/logos/TMJOs_Logo_Circular.png" \
    config/includes.chroot/usr/share/pixmaps/tmjos-logo.png

# Build
echo "[TMJOs] Starting live-build... this takes a while."
lb build 2>&1 | tee "$BUILD_DIR/build.log"

# Output — rename to our convention
ISO_FILE=$(find "$BUILD_DIR" -maxdepth 1 -name "*.iso" | head -1)
if [ -n "$ISO_FILE" ]; then
    FINAL_NAME="$BUILD_DIR/tmjos-26.04-${ARCH}.iso"
    mv "$ISO_FILE" "$FINAL_NAME"
    ISO_SIZE=$(du -h "$FINAL_NAME" | cut -f1)
    echo "========================================="
    echo "  ISO ready: $FINAL_NAME"
    echo "  Size: $ISO_SIZE"
    echo "========================================="
else
    echo "ERROR: ISO not found. Check build.log"
    exit 1
fi
