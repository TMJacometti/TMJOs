#!/bin/sh
# Vendor branding assets into the tmjos-branding .deb source.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$REPO_ROOT/packages/sources/tmjos-branding"
VENDOR="$PKG/vendor/branding"

[ -f "$REPO_ROOT/assets/wallpapers/tmjos_wallpaper.png" ] || {
    echo "ERROR: $REPO_ROOT/assets/wallpapers/tmjos_wallpaper.png not found." >&2
    exit 1
}

echo "Vendoring branding → packages/sources/tmjos-branding/vendor/branding/"
rm -rf "$PKG/vendor"
mkdir -p "$VENDOR/wallpapers" "$VENDOR/logos" "$VENDOR/plymouth"

# Wallpapers
cp "$REPO_ROOT/assets/wallpapers/tmjos_wallpaper.png"     "$VENDOR/wallpapers/"
cp "$REPO_ROOT/assets/wallpapers/tmjos_wallpaper_4k.png"  "$VENDOR/wallpapers/"

# Logos (3 variantes)
cp "$REPO_ROOT/assets/logos/TMJOs_Logo_Circular.png" "$VENDOR/logos/"
cp "$REPO_ROOT/assets/logos/TMJOs_Logo_Rounded.png"  "$VENDOR/logos/"
cp "$REPO_ROOT/assets/logos/TMJOs_Logo_Square.png"   "$VENDOR/logos/"

# Plymouth theme files
cp -r "$REPO_ROOT/assets/plymouth/tmjos/." "$VENDOR/plymouth/"

echo "✓ vendor/branding/ populated."
ls -lah "$VENDOR/wallpapers" "$VENDOR/logos" "$VENDOR/plymouth"
