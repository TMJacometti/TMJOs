#!/bin/bash
# tools/patch-live-build.sh
#
# Patches /usr/lib/live/build/* pra remover referências Ubuntu legacy
# que quebram builds modernos (Ubuntu 26.04+ / plucky+). Idempotente.
#
# Live-build 3.0~a57-1ubuntu54 é fork antigo do Ubuntu CDImage team
# com defaults e hardcodes apontando pra pacotes Ubuntu 2011-2018 que
# foram removidos. Esses patches editam os scripts direto pra neutralizar.
#
# Backup do arquivo original fica em $arquivo.orig pra reversão manual.
#
# Usage: sudo ./tools/patch-live-build.sh

set -euo pipefail

LB_DIR="/usr/lib/live/build"

if [ ! -d "$LB_DIR" ]; then
    echo "ERROR: live-build não instalado ($LB_DIR não existe)" >&2
    echo "Roda: sudo apt install -y live-build" >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: precisa de sudo (edit em $LB_DIR)" >&2
    exit 1
fi

echo "━━━ Patching live-build pra Ubuntu plucky compat ━━━"
echo "  Target: $LB_DIR"
echo ""

PATCHED=0

# ─────────────────────────────────────────────────────────────────
# Patch 1: lb_binary_syslinux — remove gfxboot-theme-ubuntu hardcoded
# (linha ~103). Pacote foi removido do Ubuntu há ~10 anos.
# ─────────────────────────────────────────────────────────────────
F="$LB_DIR/lb_binary_syslinux"
if [ -f "$F" ]; then
    if grep -q '^\s*Check_package.*gfxboot-theme-ubuntu' "$F"; then
        [ -f "$F.tmjos-orig" ] || cp "$F" "$F.tmjos-orig"
        sed -i 's|^\(\s*\)\(Check_package.*gfxboot-theme-ubuntu.*\)$|\1# [TMJOs patch] \2|' "$F"
        echo "  ✓ Comentado: gfxboot-theme-ubuntu em lb_binary_syslinux"
        PATCHED=$((PATCHED+1))
    else
        echo "  • lb_binary_syslinux: já patcheado"
    fi
    # Mesma coisa pra Chroot ... tar xfz ... gfxboot-theme-ubuntu/bootlogo
    if grep -q 'Chroot.*gfxboot-theme-ubuntu' "$F"; then
        sed -i 's|^\(\s*\)\(Chroot.*gfxboot-theme-ubuntu.*\)$|\1# [TMJOs patch] \2|' "$F"
        echo "  ✓ Comentado: Chroot tar gfxboot-theme-ubuntu em lb_binary_syslinux"
        PATCHED=$((PATCHED+1))
    fi
    # E o tar xfz fora do Chroot
    if grep -q '^\s*tar xfz.*gfxboot-theme-ubuntu' "$F"; then
        sed -i 's|^\(\s*\)\(tar xfz.*gfxboot-theme-ubuntu.*\)$|\1# [TMJOs patch] \2|' "$F"
        echo "  ✓ Comentado: tar xfz gfxboot-theme-ubuntu em lb_binary_syslinux"
        PATCHED=$((PATCHED+1))
    fi
fi

# ─────────────────────────────────────────────────────────────────
# Patch 2: lb_chroot_live-packages — fallback pra live-config-systemd
# se LB_INITSYSTEM vazio (default na a57 era sysvinit).
# (Já passamos --initsystem systemd no lb config, esse é safety net.)
# ─────────────────────────────────────────────────────────────────
F="$LB_DIR/lb_chroot_live-packages"
if [ -f "$F" ]; then
    if grep -q 'live-config-sysvinit\|live-config-${LB_INITSYSTEM:-sysvinit}' "$F"; then
        [ -f "$F.tmjos-orig" ] || cp "$F" "$F.tmjos-orig"
        sed -i 's|live-config-sysvinit|live-config-systemd|g' "$F"
        sed -i 's|live-config-\${LB_INITSYSTEM:-sysvinit}|live-config-${LB_INITSYSTEM:-systemd}|g' "$F"
        echo "  ✓ Default live-config: sysvinit → systemd em lb_chroot_live-packages"
        PATCHED=$((PATCHED+1))
    else
        echo "  • lb_chroot_live-packages: já patcheado ou não necessário"
    fi
fi

# ─────────────────────────────────────────────────────────────────
# Patch 3: Popular /root/isolinux/ com isolinux.bin + *.c32
# Live-build a57 tem `cp /root/isolinux/isolinux.bin` hardcoded no
# lb_binary_syslinux. Em sistemas modernos, isolinux instala em
# /usr/lib/ISOLINUX/. Sem isso, build falha com:
#   cp: cannot stat '/root/isolinux/isolinux.bin': No such file or directory
# ─────────────────────────────────────────────────────────────────
if [ ! -f /root/isolinux/isolinux.bin ]; then
    if [ ! -f /usr/lib/ISOLINUX/isolinux.bin ]; then
        echo "  → Instalando isolinux + syslinux-common (precisa pros arquivos)..."
        apt-get install -y isolinux syslinux-common >/dev/null 2>&1 || true
    fi

    if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
        mkdir -p /root/isolinux
        cp /usr/lib/ISOLINUX/isolinux.bin /root/isolinux/
        cp /usr/lib/syslinux/modules/bios/*.c32 /root/isolinux/ 2>/dev/null || true
        echo "  ✓ Populado /root/isolinux/ (isolinux.bin + $(ls /root/isolinux/*.c32 2>/dev/null | wc -l) modules .c32)"
        PATCHED=$((PATCHED+1))
    else
        echo "  ⚠️  /usr/lib/ISOLINUX/isolinux.bin não existe após apt install — build pode falhar"
    fi
else
    echo "  • /root/isolinux/ já populado"
fi

echo ""
if [ "$PATCHED" -eq 0 ]; then
    echo "✓ Nenhum patch novo aplicado (live-build já tá ok ou totalmente patcheado)"
else
    echo "✓ $PATCHED patch(es) aplicado(s)"
    echo "  Backups: arquivo.tmjos-orig nos paths originais"
    echo "  Reverter manual: sudo cp <file>.tmjos-orig <file>"
fi
