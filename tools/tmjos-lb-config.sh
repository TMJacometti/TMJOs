#!/bin/bash
# tmjos-lb-config.sh
#
# Roda `lb config` com flags Debian explícitas pra host Debian 13 (trixie).
# Em Debian, live-build é a versão upstream moderna (1:20230502+) que
# entende --mode debian corretamente e gera config sem vazamentos.
#
# Histórico: versões anteriores tinham sed corretivo agressivo pra
# compensar o fork antigo de live-build no Ubuntu (3.0~a57-1ubuntu54)
# que vazava defaults Ubuntu (LB_MODE=ubuntu, casper, ubuntu-keyring,
# mirrors security.ubuntu.com etc). Em Debian host esses leaks não
# acontecem — mantemos só um safety net mínimo.

set -euo pipefail

if [ -z "${BUILD_DIR:-}" ]; then
    echo "ERROR: BUILD_DIR não setado. Chama via tmjos-build.sh." >&2
    exit 1
fi

cd "$BUILD_DIR"

echo "→ lb config (Debian 13 trixie, modo Debian explícito)"

lb config \
    --mode debian \
    --system live \
    --distribution trixie \
    --parent-distribution trixie \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --iso-application "TMJOs" \
    --iso-publisher "TMJSistemas" \
    --iso-volume "TMJOS-$(date +%Y%m%d)" \
    --memtest none \
    --bootloader grub-efi \
    --archive-areas "main contrib non-free non-free-firmware" \
    --parent-archive-areas "main contrib non-free non-free-firmware" \
    --mirror-bootstrap "http://deb.debian.org/debian/" \
    --mirror-chroot "http://deb.debian.org/debian/" \
    --mirror-chroot-security "http://security.debian.org/debian-security/" \
    --mirror-binary "http://deb.debian.org/debian/" \
    --mirror-binary-security "http://security.debian.org/debian-security/" \
    --parent-mirror-bootstrap "http://deb.debian.org/debian/" \
    --parent-mirror-chroot "http://deb.debian.org/debian/" \
    --parent-mirror-chroot-security "http://security.debian.org/debian-security/" \
    --parent-mirror-binary "http://deb.debian.org/debian/" \
    --parent-mirror-binary-security "http://security.debian.org/debian-security/" \
    --security false \
    --volatile false \
    --backports false \
    --apt apt \
    --apt-recommends true \
    --apt-secure true \
    --cache true \
    --cache-packages true \
    --cache-stages "bootstrap" \
    --keyring-packages "debian-archive-keyring" \
    --linux-packages "linux-image" \
    --initramfs live-boot \
    --initsystem systemd \
    --bootappend-live "boot=live components quiet splash locales=pt_BR.UTF-8 keyboard-layouts=br" \
    --debian-installer false \
    --firmware-binary true \
    --firmware-chroot true

# ─────────────────────────────────────────────────────────────────
# Safety net — em Debian host estes seds viram no-op (config já vem
# correto). Mantidos pra defesa caso o script seja rodado em outro
# host por engano (ex: Ubuntu) ou versão de live-build futura mude
# defaults.
# ─────────────────────────────────────────────────────────────────
sed -i 's/^LB_MODE="ubuntu"$/LB_MODE="debian"/' "$BUILD_DIR/config/common" 2>/dev/null || true
sed -i 's/^LB_INITRAMFS="casper"$/LB_INITRAMFS="live-boot"/' "$BUILD_DIR/config/common" 2>/dev/null || true
sed -i 's/^LB_KEYRING_PACKAGES="ubuntu-keyring"$/LB_KEYRING_PACKAGES="debian-archive-keyring"/' "$BUILD_DIR/config/chroot" 2>/dev/null || true
sed -i 's/^LB_HDD_LABEL="UBUNTU"$/LB_HDD_LABEL="TMJOS"/' "$BUILD_DIR/config/binary" 2>/dev/null || true
sed -i 's/boot=casper/boot=live/g' "$BUILD_DIR/config/binary" 2>/dev/null || true

# Verificação anti-vazamento — falha se sobrou ubuntu/casper ATIVO.
echo "→ verificando vazamentos Ubuntu"
LEAKS=$(grep -rEHn '"(ubuntu|casper|UBUNTU)"' "$BUILD_DIR/config" 2>/dev/null \
        | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' \
        | grep -v 'LB_MODE=' \
        | grep -v 'LB_PARENT_MODE=' \
        || true)
if [ -n "$LEAKS" ]; then
    echo "✗ VAZAMENTOS ativos detectados:"
    echo "$LEAKS"
    exit 1
fi
echo "✓ Sem vazamentos ativos"