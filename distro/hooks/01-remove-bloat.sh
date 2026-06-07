#!/bin/bash
set -e

echo "[TMJOs] Removing bloat..."

# Kill snap completely
systemctl disable --now snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
apt-get purge -y snapd snap-confine 2>/dev/null || true
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd
cat > /etc/apt/preferences.d/no-snap.pref << 'EOF'
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# Purge packages from remove.list
SCRIPT_DIR="/tmp/tmjos-distro"
while IFS= read -r pkg; do
    pkg="${pkg%%#*}"
    pkg="$(echo "$pkg" | xargs)"
    [ -z "$pkg" ] && continue
    apt-get purge -y $pkg 2>/dev/null || true
done < "$SCRIPT_DIR/remove.list"

apt-get autoremove -y
apt-get clean

echo "[TMJOs] Bloat removed."
