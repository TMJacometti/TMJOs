#!/bin/sh
# Vendor TMJOs assets into the tmjos-installer .deb source.
#
# v1.3.4: ships a TMJOs-branded replacement for ubiquity's
# "Installation complete" image (`ubuntu_installed.png`). The
# replacement is installed in tmjos-installer's own dir and the
# postinst dpkg-diverts the original ubiquity path to use ours.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$REPO_ROOT/packages/sources/tmjos-installer"
VENDOR="$PKG/vendor"

SRC_LOGO="$REPO_ROOT/assets/logos/TMJOs_Logo_Rounded.png"
[ -f "$SRC_LOGO" ] || {
    echo "ERROR: $SRC_LOGO not found." >&2
    exit 1
}

echo "Vendoring TMJOs installer assets → $VENDOR/"
rm -rf "$VENDOR"
mkdir -p "$VENDOR"

# Match ubiquity's ubuntu_installed.png exactly: 234x165 (horizontal,
# NOT square). Resize logo to fit height (165), center horizontally,
# pad with transparent background so the dialog layout doesn't shift.
if command -v convert >/dev/null 2>&1; then
    MAGICK=convert
elif command -v magick >/dev/null 2>&1; then
    MAGICK=magick
else
    echo "ERROR: ImageMagick (convert or magick) required." >&2
    echo "Install with: sudo apt install imagemagick" >&2
    exit 1
fi

$MAGICK "$SRC_LOGO" \
    -resize x165 \
    -gravity center \
    -background none \
    -extent 234x165 \
    "$VENDOR/tmjos_installed.png"

# === Generate ubiquity-replacement SVG ===
# Substitui /usr/share/icons/hicolor/*/apps/ubiquity.svg (logo do
# ubiquity na top bar do GNOME quando o installer está rodando).
# GTK icon theme espera SVG nesses paths — então criamos um SVG
# wrapper com o PNG do logo TMJOs embedded em base64. PNG é
# resizado pra 128x128 (cap razoável pra reduzir size do .svg).
$MAGICK "$SRC_LOGO" -resize 128x128 "$VENDOR/tmjos-icon-128.png"
LOGO_B64=$(base64 -w 0 "$VENDOR/tmjos-icon-128.png")
cat > "$VENDOR/tmjos-ubiquity.svg" << SVG
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="128" height="128" viewBox="0 0 128 128">
  <image xlink:href="data:image/png;base64,${LOGO_B64}" x="0" y="0" width="128" height="128"/>
</svg>
SVG
rm "$VENDOR/tmjos-icon-128.png"

# === Partitioner icons (4 PNGs 64x64) ===
# Source files são partitioner-{install,manual,reinstall,sidebyside}.png
# em apps/tmjos-installer/assets/partitioner/. Resize pra 64x64
# (size original do ubiquity) — assets vieram 1024x1024 da Nano Banana.
SRC_PARTITIONER="$REPO_ROOT/apps/tmjos-installer/assets/partitioner"
mkdir -p "$VENDOR/partitioner"
for icon in install manual reinstall sidebyside; do
    src="$SRC_PARTITIONER/partitioner-${icon}.png"
    if [ -f "$src" ]; then
        $MAGICK "$src" -resize 64x64 "$VENDOR/partitioner/${icon}.png"
    else
        echo "WARNING: $src not found, skipping ${icon}.png" >&2
    fi
done

# === Banner installing (1024x1024) ===
# Guardado em /usr/share/tmjos-installer/ pra uso futuro (v1.4+
# pode trazer tmjos-slideshow.deb). Hoje não tem onde renderizar
# porque ubuntu-slideshow-ubuntu foi removido pelo customize.sh.
SRC_BANNER="$REPO_ROOT/apps/tmjos-installer/assets/tmjos-installing.png"
if [ -f "$SRC_BANNER" ]; then
    cp "$SRC_BANNER" "$VENDOR/tmjos-installing.png"
fi

echo "✓ vendor/ populated."
ls -lah "$VENDOR/"
file "$VENDOR/tmjos_installed.png"
