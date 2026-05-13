#!/bin/bash
# tmjos-build.sh
#
# Master script TMJOs ISO build. Roda end-to-end:
#   1. Pre-flight checks (RAM, disco, tools, tracker, swap, Firefox)
#   2. lb clean --purge
#   3. lb config (modo Debian explícito)
#   4. Setup hooks/preferences
#   5. lb build em tmux
#
# Usage: sudo ./tmjos-build.sh
#
# Variáveis opcionais:
#   TMJOS_BUILD_DIR  — onde montar o build (default: ~$SUDO_USER/tmjos-debian-build)
#   TMJOS_SKIP_CLEAN — true pra pular lb clean (debug, default: false)

# Não usamos `set -e` no master pra controlar erro por etapa com
# mensagem clara. Sub-scripts mantêm `set -euo pipefail`.
set -uo pipefail

# ─────────────────────────────────────────────────────────────────
# 0. Resolução robusta de paths
# ─────────────────────────────────────────────────────────────────

# Resolve diretório real do script (segue symlinks, normaliza path).
# Importante quando rodado via sudo de outro dir, ou via symlink.
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Confirma que os sub-scripts existem antes de tentar usá-los
for sub in tmjos-lb-config.sh tmjos-hooks-setup.sh; do
    if [ ! -f "$SCRIPT_DIR/$sub" ]; then
        echo "✗ ERRO: $SCRIPT_DIR/$sub não existe." >&2
        echo "   Os 3 scripts precisam estar na MESMA pasta:" >&2
        echo "   - tmjos-build.sh" >&2
        echo "   - tmjos-lb-config.sh" >&2
        echo "   - tmjos-hooks-setup.sh" >&2
        exit 1
    fi
done

# Resolve $HOME do usuário real (não /root via sudo)
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    REAL_USER="$SUDO_USER"
else
    USER_HOME="$HOME"
    REAL_USER="$(whoami)"
fi

# BUILD_DIR é exportado pra sub-scripts (sourceados) verem
export BUILD_DIR="${TMJOS_BUILD_DIR:-$USER_HOME/tmjos-debian-build}"
SKIP_CLEAN="${TMJOS_SKIP_CLEAN:-false}"

# Função de erro fatal com mensagem clara
die() {
    echo "" >&2
    echo "✗ ERRO: $*" >&2
    echo "" >&2
    exit 1
}

# ─────────────────────────────────────────────────────────────────
# 1. Pre-flight checks
# ─────────────────────────────────────────────────────────────────

if [ "$(id -u)" -ne 0 ]; then
    die "Roda com sudo (lb build precisa de root)."
fi

echo "━━━ Pre-flight checks ━━━"
echo "Script dir:  $SCRIPT_DIR"
echo "Build dir:   $BUILD_DIR"
echo "Real user:   $REAL_USER"
echo ""

# Tools
for tool in lb tmux debootstrap isohybrid; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        if [ "$tool" = "isohybrid" ]; then
            echo "→ Instalando syslinux-utils (provê isohybrid)..."
            apt-get install -y syslinux-utils
        else
            die "\`$tool\` não instalado. Roda: sudo apt install live-build tmux debootstrap syslinux-utils"
        fi
    fi
done
echo "✓ live-build, tmux, debootstrap, syslinux-utils presentes"

# Workaround pro live-build a57 do Ubuntu (path /root/isolinux/ hardcoded)
# removido — em Debian host com live-build moderno, --bootloader grub-efi
# funciona nativo e não precisa de isolinux files no path antigo.

# Versão do live-build (informativo — sintaxe varia entre versões)
LB_VERSION=$(dpkg-query -W -f='${Version}' live-build 2>/dev/null || echo "desconhecida")
echo "  live-build versão: $LB_VERSION"

# RAM
TOTAL_RAM_GB=$(awk '/MemTotal/{printf "%d\n", $2/1024/1024}' /proc/meminfo)
AVAIL_RAM_MB=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
if [ "$TOTAL_RAM_GB" -lt 4 ]; then
    echo "⚠️  $TOTAL_RAM_GB GB de RAM total. Build pode ter problemas."
fi
echo "✓ RAM: $TOTAL_RAM_GB GB total, $AVAIL_RAM_MB MB disponível"

# Disco
mkdir -p "$BUILD_DIR" || die "Não consegui criar $BUILD_DIR"
DISK_AVAIL_GB=$(df -BG "$BUILD_DIR" | awk 'NR==2 {gsub("G",""); print $4}')
if [ "$DISK_AVAIL_GB" -lt 15 ]; then
    die "$DISK_AVAIL_GB GB livre em $BUILD_DIR. Precisa de 15GB+."
fi
echo "✓ Disco: $DISK_AVAIL_GB GB disponível em $BUILD_DIR"

# Tracker do host (matador de build em hosts GNOME)
if pgrep -x localsearch >/dev/null 2>&1 || \
   pgrep -x tracker-miner-fs-3 >/dev/null 2>&1; then
    echo "→ Matando tracker/localsearch do host..."
    sudo -u "$REAL_USER" -- killall localsearch tracker-extract \
        tracker-miner-fs-3 tracker-miner-rss-3 2>/dev/null || true
    sudo -u "$REAL_USER" -- systemctl --user mask \
        localsearch-3.service tracker-miner-fs-3.service \
        tracker-extract-3.service tracker-miner-rss-3.service 2>/dev/null || true
    echo "✓ Tracker mascarado"
fi
touch "$BUILD_DIR/.trackerignore"

# Firefox — mata direto (single-user mode)
if pgrep -x firefox >/dev/null 2>&1 || pgrep -x firefox-bin >/dev/null 2>&1; then
    FF_RAM_MB=$(ps -C firefox,firefox-bin -o rss= 2>/dev/null | \
                awk '{s+=$1} END {print int(s/1024)}')
    echo "→ Matando Firefox (~${FF_RAM_MB} MB)..."
    sudo -u "$REAL_USER" -- killall firefox firefox-bin 2>/dev/null || true
    sleep 2
    echo "✓ Firefox encerrado"
fi

# Limpa swap se >50% usado
SWAP_USED_PCT=$(free | awk '/^Swap:/ { if ($2>0) print int($3*100/$2); else print 0 }')
if [ "$SWAP_USED_PCT" -gt 50 ]; then
    echo "→ Limpando swap ($SWAP_USED_PCT% em uso)..."
    swapoff -a && swapon -a
fi

# Swap extra temporário se hardware apertado
TOTAL_SWAP_GB=$(awk '/SwapTotal/{printf "%d\n", $2/1024/1024}' /proc/meminfo)
SWAP_EXTRA="/swapfile-tmjos"
SWAP_EXTRA_CREATED=false

cleanup_swap_extra() {
    if [ "$SWAP_EXTRA_CREATED" = "true" ] && [ -f "$SWAP_EXTRA" ]; then
        echo ""
        echo "→ Abortado — removendo swap temporário ($SWAP_EXTRA)..."
        swapoff "$SWAP_EXTRA" 2>/dev/null || true
        rm -f "$SWAP_EXTRA"
        echo "✓ Swap temporário removido"
    fi
}
# IMPORTANT: NÃO usar EXIT — o lb build roda em background no tmux,
# e o master termina logo depois. Trap em EXIT mataria o swap antes do
# build pesado começar (root cause de várias travas anteriores).
# Cleanup só em Ctrl+C/kill explícito — user remove manual quando build
# terminar (mensagem final dá o comando).
trap cleanup_swap_extra INT TERM

if [ "$TOTAL_RAM_GB" -lt 16 ] || [ "$TOTAL_SWAP_GB" -lt 6 ]; then
    if [ ! -f "$SWAP_EXTRA" ]; then
        echo "→ RAM/swap apertados. Criando $SWAP_EXTRA (4GB temporário)..."
        dd if=/dev/zero of="$SWAP_EXTRA" bs=1M count=4096 \
            status=progress 2>&1 | tail -3
        chmod 600 "$SWAP_EXTRA"
        mkswap "$SWAP_EXTRA" >/dev/null
        swapon "$SWAP_EXTRA" || die "swapon $SWAP_EXTRA falhou"
        SWAP_EXTRA_CREATED=true
        echo "✓ Swap extra ativo"
    fi
fi

echo "✓ Sistema preparado pra build"
free -h
echo ""

# ─────────────────────────────────────────────────────────────────
# 2. lb clean --purge
# ─────────────────────────────────────────────────────────────────

if [ "$SKIP_CLEAN" != "true" ] && [ -d "$BUILD_DIR/config" ]; then
    echo "━━━ lb clean --purge ━━━"
    cd "$BUILD_DIR" || die "cd $BUILD_DIR falhou"
    lb clean --purge || true
    # Garantia: apaga config/ e .build/ pra forçar lb config fresh
    rm -rf "$BUILD_DIR/config"
    rm -rf "$BUILD_DIR/.build"
    echo "✓ Estado limpo"
    echo ""
fi

# ─────────────────────────────────────────────────────────────────
# 3. lb config (sourceia tmjos-lb-config.sh)
# ─────────────────────────────────────────────────────────────────

echo "━━━ lb config ━━━"
cd "$BUILD_DIR" || die "cd $BUILD_DIR falhou"

# Source com checagem explícita — se algo deu erro lá dentro, mostramos
if ! . "$SCRIPT_DIR/tmjos-lb-config.sh"; then
    die "tmjos-lb-config.sh falhou. Acima ↑ deve ter detalhes do erro."
fi

# Confirma que lb config gerou os arquivos esperados
for required in config/common config/chroot config/binary config/bootstrap; do
    [ -f "$BUILD_DIR/$required" ] || \
        die "lb config não gerou $required. Veja logs acima."
done
echo "✓ Config files gerados"
echo ""

# ─────────────────────────────────────────────────────────────────
# 4. Hooks + preferences (sourceia tmjos-hooks-setup.sh)
# ─────────────────────────────────────────────────────────────────

echo "━━━ Hooks + preferences ━━━"
if ! . "$SCRIPT_DIR/tmjos-hooks-setup.sh"; then
    die "tmjos-hooks-setup.sh falhou. Acima ↑ deve ter detalhes."
fi
echo ""

# ─────────────────────────────────────────────────────────────────
# 5. lb build em tmux
# ─────────────────────────────────────────────────────────────────

SESSION_NAME="tmjos-build"
# Socket compartilhado em /tmp + permissões pro user real: master roda
# como root via sudo, mas user normal precisa poder fazer `tmux attach`
# sem sudo. Sem socket custom, tmux usa /tmp/tmux-$UID/ que é por-user.
TMUX_SOCKET="/tmp/tmux-tmjos.sock"
TMUX="tmux -S $TMUX_SOCKET"

if $TMUX has-session -t "$SESSION_NAME" 2>/dev/null; then
    $TMUX kill-session -t "$SESSION_NAME"
fi

echo "━━━ lb build (em tmux: $SESSION_NAME) ━━━"
echo ""
echo "Build rodando em background tmux. Imune a Ctrl+Z, SSH drops, etc."
echo ""
echo "  Acompanhar:    tmux -S $TMUX_SOCKET attach -t $SESSION_NAME"
echo "  Desanexar:     Ctrl+B depois D"
echo "  Status:        tmux -S $TMUX_SOCKET ls"
echo ""
echo "  Log completo:  $BUILD_DIR/build.log"
echo "  ISO final:     $BUILD_DIR/live-image-amd64.hybrid.iso"
echo ""

# Roda lb build em tmux session detached, no socket compartilhado
$TMUX new-session -d -s "$SESSION_NAME" -c "$BUILD_DIR" \
    "lb build 2>&1 | tee build.log; \
     echo ''; \
     echo '━━━ BUILD TERMINADO ━━━'; \
     ls -lh *.iso 2>/dev/null || echo 'Nenhuma ISO gerada — checa build.log'; \
     echo ''; \
     echo 'Pressione Enter pra fechar esta sessão tmux.'; \
     read"

# Da acesso ao socket pro user real (sem isso ele precisa de sudo)
if [ -S "$TMUX_SOCKET" ]; then
    chown "$REAL_USER":"$REAL_USER" "$TMUX_SOCKET" 2>/dev/null || true
    chmod 600 "$TMUX_SOCKET" 2>/dev/null || true
fi

# Confirma que tmux iniciou
sleep 1
if ! $TMUX has-session -t "$SESSION_NAME" 2>/dev/null; then
    die "Sessão tmux não iniciou. Tenta rodar 'lb build' direto em $BUILD_DIR pra debug."
fi

echo "✓ Build iniciado em background"
echo ""
echo "Agora roda:"
echo "  tmux -S $TMUX_SOCKET attach -t $SESSION_NAME"
echo ""

if [ "$SWAP_EXTRA_CREATED" = "true" ]; then
    echo "━━━ ATENÇÃO: swap temporário ATIVO ━━━"
    echo ""
    echo "  $SWAP_EXTRA (4GB) foi adicionado e está dando suporte ao build."
    echo "  NÃO REMOVA enquanto o build estiver rodando — vai travar."
    echo ""
    echo "  Quando o build TERMINAR (sucesso ou falha), remova manualmente:"
    echo "    sudo swapoff $SWAP_EXTRA && sudo rm $SWAP_EXTRA"
    echo ""
fi