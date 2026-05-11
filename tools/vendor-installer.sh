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

echo "✓ vendor/ populated."
ls -lah "$VENDOR/"
file "$VENDOR/tmjos_installed.png"
