#!/bin/sh
# Vendor TMJMenu+TMJDock upstream files into the .deb package source.
# Rust + gtk4-rs desde v2.0.0.
#
# Vendora:
#   - src/ + Cargo.toml + Cargo.lock
#   - deps Rust via `cargo vendor` em vendor/rust-deps/ (build offline)
#   - data/ (desktops, appdata, first-run hook)
#   - assets/logo/tmjmenu.png

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/apps/tmjmenu"
PKG="$REPO_ROOT/packages/sources/tmjmenu"
VENDOR="$PKG/vendor"

[ -f "$SRC/Cargo.toml" ] || {
    echo "ERROR: $SRC/Cargo.toml not found. Run from the repo root." >&2
    exit 1
}

command -v cargo >/dev/null 2>&1 || {
    echo "ERROR: cargo não instalado. Roda: sudo apt install -y cargo rustc" >&2
    exit 1
}

echo "Vendoring TMJMenu → packages/sources/tmjmenu/vendor/"
rm -rf "$VENDOR"
mkdir -p "$VENDOR"

# 1. Source Rust + Cargo manifest
cp -r "$SRC/src"        "$VENDOR/src"
cp    "$SRC/Cargo.toml" "$VENDOR/Cargo.toml"

# 2. Gera Cargo.lock se ainda não existe
cd "$SRC"
if [ ! -f Cargo.lock ]; then
    echo "→ cargo generate-lockfile..."
    cargo generate-lockfile
fi
cp Cargo.lock "$VENDOR/Cargo.lock"

# 3. cargo vendor — deps offline
echo "→ cargo vendor (deps offline)..."
mkdir -p "$VENDOR/.cargo"
cargo vendor --manifest-path "$SRC/Cargo.toml" "$VENDOR/rust-deps" \
    > "$VENDOR/.cargo/config.toml"

# 4. Assets — desktops, appdata, first-run hook, icon
mkdir -p "$VENDOR/data"
cp "$SRC/data/tmjmenu.desktop"                          "$VENDOR/data/"
cp "$SRC/data/tmjdock.desktop"                          "$VENDOR/data/"
cp "$SRC/data/tmjmenu-first-run"                        "$VENDOR/data/"
cp "$SRC/data/tmjmenu-first-run.desktop"                "$VENDOR/data/"
cp "$SRC/data/br.com.tmjsistemas.tmjmenu.appdata.xml"   "$VENDOR/data/"
cp "$SRC/assets/logo/tmjmenu.png"                       "$VENDOR/data/tmjmenu.png"

echo "✓ vendor/ populated."
du -sh "$VENDOR/rust-deps" "$VENDOR/src"
