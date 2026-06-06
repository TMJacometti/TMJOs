#!/bin/sh
# Vendor TMJStore upstream files into the .deb package source tree.
# Run this before `dpkg-buildpackage` for the tmjstore package, both
# locally and in CI.
#
# TMJStore é Rust + gtk4-rs + libadwaita desde v2.0.0. Vendora:
#   - src/ + Cargo.toml + Cargo.lock
#   - deps Rust via `cargo vendor` em vendor/rust-deps/ (build offline)
#   - data/ (desktop, appdata, icon)

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/apps/tmjstore"
PKG="$REPO_ROOT/packages/sources/tmjstore"
VENDOR="$PKG/vendor"

[ -f "$SRC/Cargo.toml" ] || {
    echo "ERROR: $SRC/Cargo.toml not found. Run from the repo root." >&2
    exit 1
}

command -v cargo >/dev/null 2>&1 || {
    echo "ERROR: cargo não instalado. Roda: sudo apt install -y cargo rustc" >&2
    exit 1
}

echo "Vendoring TMJStore → packages/sources/tmjstore/vendor/"
rm -rf "$VENDOR"
mkdir -p "$VENDOR"

# 1. Source Rust + Cargo manifest
cp -r "$SRC/src"        "$VENDOR/src"
cp    "$SRC/Cargo.toml" "$VENDOR/Cargo.toml"

# 2. Gera Cargo.lock se ainda não existe (e vendora deps)
cd "$SRC"
if [ ! -f Cargo.lock ]; then
    echo "→ cargo generate-lockfile (fresh Cargo.lock)..."
    cargo generate-lockfile
fi
cp Cargo.lock "$VENDOR/Cargo.lock"

# 3. cargo vendor — baixa todas as crates pra rust-deps/ pra build offline.
echo "→ cargo vendor (deps offline)..."
mkdir -p "$VENDOR/.cargo"
cargo vendor --manifest-path "$SRC/Cargo.toml" "$VENDOR/rust-deps" \
    > "$VENDOR/.cargo/config.toml"

# 4. Assets — desktop entry, appdata, icon
mkdir -p "$VENDOR/data"
cp "$SRC/data/tmjstore.desktop"                          "$VENDOR/data/tmjstore.desktop"
cp "$SRC/data/br.com.tmjsistemas.tmjstore.appdata.xml"   "$VENDOR/data/tmjstore.appdata.xml"
cp "$SRC/assets/logo/tmjstore.png"                       "$VENDOR/data/tmjstore.png"

echo "✓ vendor/ populated."
du -sh "$VENDOR/rust-deps" "$VENDOR/src"
