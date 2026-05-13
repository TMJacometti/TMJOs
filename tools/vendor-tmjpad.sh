#!/bin/sh
# Vendor TMJPad upstream files into the .deb package source tree.
# Run this before `dpkg-buildpackage` for the tmjpad package, both
# locally and in CI.
#
# Why: Debian sources should be self-contained — they shouldn't reach
# outside their own directory at build time. So we copy the relevant
# files from apps/tmjpad/ into packages/sources/tmjpad/vendor/ before
# building.
#
# TMJPad é Rust + gtk4-rs desde v2.0.0. Vendora:
#   - src/ + Cargo.toml + Cargo.lock
#   - deps Rust via `cargo vendor` em vendor/rust-deps/ (build offline)
#   - data/ (desktop, appdata, icon)

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/apps/tmjpad"
PKG="$REPO_ROOT/packages/sources/tmjpad"
VENDOR="$PKG/vendor"

[ -f "$SRC/Cargo.toml" ] || {
    echo "ERROR: $SRC/Cargo.toml not found. Run from the repo root." >&2
    exit 1
}

command -v cargo >/dev/null 2>&1 || {
    echo "ERROR: cargo não instalado. Roda: sudo apt install -y cargo rustc" >&2
    exit 1
}

echo "Vendoring TMJPad → packages/sources/tmjpad/vendor/"
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
# Cria também .cargo/config.toml apontando pra vendor dir.
echo "→ cargo vendor (deps offline)..."
mkdir -p "$VENDOR/.cargo"
cargo vendor --manifest-path "$SRC/Cargo.toml" "$VENDOR/rust-deps" \
    > "$VENDOR/.cargo/config.toml"

# 4. Assets — desktop entry, appdata, icon
mkdir -p "$VENDOR/data"
cp "$SRC/data/tmjpad.desktop"                       "$VENDOR/data/tmjpad.desktop"
cp "$SRC/data/br.com.tmjsistemas.tmjpad.appdata.xml" "$VENDOR/data/tmjpad.appdata.xml"
cp "$SRC/assets/logo/tmjpad.png"                    "$VENDOR/data/tmjpad.png"

echo "✓ vendor/ populated."
du -sh "$VENDOR/rust-deps" "$VENDOR/src"
