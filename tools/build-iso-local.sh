#!/bin/bash
# tools/build-iso-local.sh
#
# Builda a ISO TMJOs LOCALMENTE — mesma coisa que o GitHub Actions
# faz, mas sem upload pra Cloudflare R2. Saída em /tmp/tmjos-build/.
#
# Útil pra iterar em mudanças do `distro/` config sem esperar push →
# CI buildar → Cloudflare upload → download (~30-40min round-trip).
#
# Usage:
#   sudo ./tools/build-iso-local.sh              # builda
#   sudo ./tools/build-iso-local.sh --qemu       # builda + boota em QEMU após
#   sudo ./tools/build-iso-local.sh --virt-manager  # builda + abre virt-manager
#
# Pré-requisitos: Ubuntu/Debian host. Live-build instalado automaticamente
# se não tiver. Precisa ~10GB livres em /tmp. Build leva 20-40min.

set -uo pipefail

# ─────────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────────
OPEN_AFTER=""
for arg in "$@"; do
    case "$arg" in
        --qemu) OPEN_AFTER="qemu" ;;
        --virt-manager) OPEN_AFTER="virt-manager" ;;
        --help|-h)
            sed -n '/^# Usage/,/^# Pré-/p' "$0" | sed 's/^# //;s/^#//'
            exit 0
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────
# Resolve paths
# ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$(whoami)"
fi

die() {
    echo "" >&2
    echo "✗ ERRO: $*" >&2
    exit 1
}

# ─────────────────────────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || die "Roda com sudo (lb build precisa de root)."

[ -f "$REPO_ROOT/distro/build.sh" ] || die "distro/build.sh não encontrado em $REPO_ROOT"

echo "━━━ Pre-flight checks ━━━"

# Disco
DISK_FREE_GB=$(df -BG --output=avail /tmp | tail -1 | tr -d ' G')
if [ "$DISK_FREE_GB" -lt 10 ]; then
    die "/tmp tem $DISK_FREE_GB GB livres — precisa de 10GB+ pro build."
fi
echo "✓ Disco em /tmp: ${DISK_FREE_GB}GB livres"

# Deps de build
MISSING=""
for cmd in lb debootstrap xorriso mksquashfs; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING="$MISSING $cmd"
done

if [ -n "$MISSING" ]; then
    echo "→ Instalando deps faltantes:$MISSING"
    apt-get update -qq
    apt-get install -y \
        live-build debootstrap squashfs-tools xorriso \
        grub-efi-amd64-bin grub-pc-bin \
        mtools dosfstools \
        syslinux-utils isolinux syslinux-common
fi
echo "✓ Build deps presentes"

# Debootstrap precisa conhecer plucky (Ubuntu 26.04)
if [ ! -f /usr/share/debootstrap/scripts/plucky ]; then
    echo "→ Criando symlink debootstrap pra plucky (Ubuntu 26.04)..."
    ln -sf gutsy /usr/share/debootstrap/scripts/plucky
fi
echo "✓ debootstrap conhece plucky"

# Cargo (apps Rust dependem) — usado pelos pacotes durante install
if ! command -v cargo >/dev/null 2>&1; then
    echo "→ Instalando cargo + rustc (apps TMJOs são Rust)..."
    apt-get install -y cargo rustc pkg-config \
        libgtk-4-dev libadwaita-1-dev
fi
echo "✓ Cargo presente"

echo ""

# ─────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────
echo "━━━ Buildando ISO (20-40min) ━━━"
echo "  Logs em: /tmp/tmjos-build/build.log"
echo ""

chmod +x "$REPO_ROOT/distro/build.sh" "$REPO_ROOT/distro"/hooks/*.sh
"$REPO_ROOT/distro/build.sh"

# ─────────────────────────────────────────────────────────────────
# Resultado
# ─────────────────────────────────────────────────────────────────
ISO_FILE=$(find /tmp/tmjos-build -maxdepth 1 -name '*.iso' | head -1)
if [ -z "$ISO_FILE" ]; then
    die "Build terminou mas ISO não foi gerada. Confere /tmp/tmjos-build/build.log."
fi

ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)

# Permissão pro user real (pra dar pra rodar QEMU sem sudo + acessar pelo navegador, etc)
chown "$REAL_USER":"$REAL_USER" "$ISO_FILE"
chmod 644 "$ISO_FILE"

echo ""
echo "━━━ ✓ ISO PRONTA ━━━"
echo ""
echo "  Arquivo: $ISO_FILE"
echo "  Tamanho: $ISO_SIZE"
echo ""
echo "━━━ Como testar ━━━"
echo ""
echo "QEMU rápido (KVM acelerado):"
echo "  qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \\"
echo "      -bios /usr/share/OVMF/OVMF_CODE_4M.fd \\"
echo "      -cdrom $ISO_FILE \\"
echo "      -boot d -display gtk"
echo ""
echo "virt-manager:"
echo "  virt-manager → New VM → Local install media → $ISO_FILE"
echo "  RAM: 4GB · CPUs: 2 · Disco: 30GB · Firmware: UEFI x86_64"
echo ""

# Cleanup automático opcional do build dir intermediário (não a ISO)
# pra não acumular ~7GB de chroot/squashfs entre builds.
read -r -p "Limpar chroot intermediário (~7GB) e manter só a ISO? [y/N]: " CLEAN_INTERMEDIATE < /dev/tty || CLEAN_INTERMEDIATE="n"
if [ "${CLEAN_INTERMEDIATE,,}" = "y" ]; then
    cd /tmp/tmjos-build
    sudo lb clean --purge 2>/dev/null || true
    rm -rf chroot config binary auto cache
    echo "✓ Intermediário limpo. ISO preservada: $ISO_FILE"
fi

# ─────────────────────────────────────────────────────────────────
# Open after (opcional)
# ─────────────────────────────────────────────────────────────────
case "$OPEN_AFTER" in
    qemu)
        echo ""
        echo "━━━ Iniciando QEMU ━━━"
        if [ -f /usr/share/OVMF/OVMF_CODE_4M.fd ]; then
            BIOS_ARGS="-bios /usr/share/OVMF/OVMF_CODE_4M.fd"
        else
            echo "→ Instalando OVMF (UEFI firmware pra VM)..."
            apt-get install -y ovmf
            BIOS_ARGS="-bios /usr/share/OVMF/OVMF_CODE_4M.fd"
        fi
        # Roda como user real (não root) pra acelerar via KVM
        sudo -u "$REAL_USER" qemu-system-x86_64 \
            -enable-kvm -m 4G -smp 4 \
            $BIOS_ARGS \
            -cdrom "$ISO_FILE" \
            -boot d -display gtk &
        ;;
    virt-manager)
        if ! command -v virt-manager >/dev/null 2>&1; then
            echo "→ Instalando virt-manager + KVM..."
            apt-get install -y virt-manager libvirt-daemon-system qemu-kvm ovmf
            usermod -aG libvirt "$REAL_USER" 2>/dev/null || true
        fi
        sudo -u "$REAL_USER" virt-manager &
        echo "→ virt-manager aberto. ISO em: $ISO_FILE"
        ;;
esac
