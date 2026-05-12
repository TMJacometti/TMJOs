#!/bin/sh
# Vendor TMJStore upstream files into the .deb package source.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/apps/tmjstore"
PKG="$REPO_ROOT/packages/sources/tmjstore"
VENDOR="$PKG/vendor"

[ -d "$SRC/tmjstore" ] || {
    echo "ERROR: $SRC/tmjstore not found." >&2
    exit 1
}

echo "Vendoring TMJStore → packages/sources/tmjstore/vendor/"
rm -rf "$VENDOR"
mkdir -p "$VENDOR"

# 1. Python module (com assets embedded — fallback de dev)
cp -r "$SRC/tmjstore" "$VENDOR/tmjstore"

# 2. Desktop entry + AppStream
cp "$SRC/data/tmjstore.desktop"                       "$VENDOR/tmjstore.desktop"
cp "$SRC/data/br.com.tmjsistemas.tmjstore.appdata.xml" "$VENDOR/tmjstore.appdata.xml"

# 2b. Icon (PNG 1024x1024, será instalado em hicolor 512 + pixmaps)
cp "$SRC/assets/logo/tmjstore.png" "$VENDOR/tmjstore.png"

# 3. Wrapper script
cat > "$VENDOR/tmjstore-launcher.sh" << 'LAUNCHER'
#!/bin/sh
# TMJStore launcher — software center proprietário TMJOs.
exec python3 -c "
import sys
sys.path.insert(0, '/opt/tmjstore')
from tmjstore.app import main
sys.exit(main())
" "$@"
LAUNCHER

echo "✓ vendor/ populated."
ls -lah "$VENDOR/"
