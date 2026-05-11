#!/bin/sh
# Vendor TMJMenu/TMJDock upstream files into the .deb package source.
# Roda antes de dpkg-buildpackage (CI + local dev).

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/apps/tmjmenu"
PKG="$REPO_ROOT/packages/sources/tmjmenu"
VENDOR="$PKG/vendor"

[ -d "$SRC/tmjmenu" ] || {
    echo "ERROR: $SRC/tmjmenu not found. Run from repo root." >&2
    exit 1
}

echo "Vendoring TMJMenu → packages/sources/tmjmenu/vendor/"
rm -rf "$VENDOR"
mkdir -p "$VENDOR"

# 1. Python module (inclui assets/ embedded)
cp -r "$SRC/tmjmenu" "$VENDOR/tmjmenu"

# 2. Desktop entries + first-run script
cp "$SRC/data/tmjmenu.desktop"              "$VENDOR/tmjmenu.desktop"
cp "$SRC/data/tmjdock.desktop"              "$VENDOR/tmjdock.desktop"
cp "$SRC/data/tmjmenu-first-run.desktop"    "$VENDOR/tmjmenu-first-run.desktop"
cp "$SRC/data/tmjmenu-first-run"            "$VENDOR/tmjmenu-first-run"

# 3. Wrapper scripts — gerados aqui pra rules apenas `cp`.
cat > "$VENDOR/tmjmenu-launcher.sh" << 'LAUNCHER'
#!/bin/sh
# TMJMenu launcher — popup search via Super key.
exec python3 -c "
import sys
sys.path.insert(0, '/opt/tmjmenu')
from tmjmenu.app import main
sys.exit(main())
" "$@"
LAUNCHER

cat > "$VENDOR/tmjdock-launcher.sh" << 'LAUNCHER'
#!/bin/sh
# TMJDock launcher — bottom-center dock daemon.
exec python3 -c "
import sys
sys.path.insert(0, '/opt/tmjmenu')
from tmjmenu.dock import main
sys.exit(main())
" "$@"
LAUNCHER

echo "✓ vendor/ populated."
ls -lah "$VENDOR/"
