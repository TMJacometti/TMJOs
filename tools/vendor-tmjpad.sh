#!/bin/sh
# Vendor TMJPad upstream files into the .deb package source tree.
# Run this before `dpkg-buildpackage` for the tmjpad package, both
# locally and in CI.
#
# Why: Debian sources should be self-contained — they shouldn't reach
# outside their own directory at build time. So we copy the relevant
# files from apps/tmjpad/ into packages/sources/tmjpad/vendor/ before
# building.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/apps/tmjpad"
PKG="$REPO_ROOT/packages/sources/tmjpad"
VENDOR="$PKG/vendor"

[ -d "$SRC/tmjpad" ] || {
    echo "ERROR: $SRC/tmjpad not found. Run from the repo root." >&2
    exit 1
}

echo "Vendoring TMJPad → packages/sources/tmjpad/vendor/"
rm -rf "$VENDOR"
mkdir -p "$VENDOR"

# 1. Python module
cp -r "$SRC/tmjpad" "$VENDOR/tmjpad"

# 2. .desktop entry
cp "$SRC/data/tmjpad.desktop" "$VENDOR/tmjpad.desktop"

# 3. Icon
cp "$SRC/assets/logo/tmjpad.png" "$VENDOR/tmjpad.png"

# 4. Launcher wrapper script — generated here so it lives next to the
# vendored files and the Debian rules can just `cp` it.
cat > "$VENDOR/tmjpad-launcher.sh" << 'LAUNCHER'
#!/bin/sh
# TMJPad launcher — injects /opt/tmjpad in Python's path and runs main()
exec python3 -c "
import sys
sys.path.insert(0, '/opt/tmjpad')
from tmjpad.app import main
sys.exit(main())
" "$@"
LAUNCHER

echo "✓ vendor/ populated."
ls -lah "$VENDOR/"
