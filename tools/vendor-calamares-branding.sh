#!/bin/sh
# Vendor Calamares branding assets into the tmjos-calamares-branding .deb source.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$REPO_ROOT/packages/sources/tmjos-calamares-branding"
VENDOR="$PKG/vendor"

[ -f "$REPO_ROOT/assets/logos/TMJOs_Logo_Rounded.png" ] || {
    echo "ERROR: $REPO_ROOT/assets/logos/TMJOs_Logo_Rounded.png not found." >&2
    exit 1
}

echo "Vendoring Calamares branding → packages/sources/tmjos-calamares-branding/vendor/"
rm -rf "$VENDOR"
mkdir -p "$VENDOR"

# Logo (sidebar + slideshow header)
cp "$REPO_ROOT/assets/logos/TMJOs_Logo_Rounded.png" "$VENDOR/logo.png"

# Welcome image (productWelcome em branding.desc)
cp "$REPO_ROOT/assets/logos/TMJOs_Logo_Square.png" "$VENDOR/welcome.png"

echo "✓ vendor/ populated."
ls -lah "$VENDOR/"
