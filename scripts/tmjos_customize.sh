#!/bin/bash

###############################################
# TMJOs v2.0 — Script de Customização (Debian 13 trixie)
#
# Diferente do v1.x (Ubuntu noble + Cubic), este script foi escrito
# pra rodar em chroot Debian 13 montado por:
#   - live-build hooks (CI pipeline)
#   - debootstrap+chroot manual (dev local)
#   - container Docker debian:trixie (testes)
#
# Faz, em ordem:
#   1. apt update + upgrade
#   2. SLIM AGGRESSIVE — remove bloat GNOME default do Debian
#      (LibreOffice, games, gnome-music/maps/weather, etc).
#      MANTÉM Evolution (Exchange compat).
#   3. adiciona repo Microsoft VSCode
#   4. adiciona repo TMJOs trixie em packages.tmjos.com.br
#   5. apt install tmjos — meta puxa todos componentes TMJOs
#   6. configura Calamares (instalador Debian) com branding TMJOs
#   7. OPTIMIZE — mascara serviços pesados (tracker, packagekit,
#      plymouth-quit-wait) + instala zram-tools/preload.
#      Target: idle ~700MB-1GB RAM, OS roda em 2GB total.
###############################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

TMJOS_REPO_URL="https://packages.tmjos.com.br"

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   TMJOs - Customização v2.0 (Debian-based)║${NC}"
echo -e "${BLUE}║   APT repo: packages.tmjos.com.br trixie  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

# ===========================================
# FASE 1 — UPDATE
# ===========================================

echo -e "${YELLOW}[1/7] Atualizando sistema...${NC}"
$SUDO apt update
$SUDO apt upgrade -y

# Pacotes essenciais pra adicionar repos extras
$SUDO apt install -y \
    wget gpg apt-transport-https software-properties-common \
    ca-certificates curl git

# ===========================================
# FASE 2 — SLIM AGGRESSIVE
# ===========================================

echo -e "${YELLOW}[2/7] Slim aggressive — removendo bloat...${NC}"

# Lista de pacotes a remover. Tudo via "|| true" pra não falhar se
# algum pacote não estiver instalado (depende do task selecionado).
# IMPORTANT: Evolution NÃO está aqui — user usa Exchange.
BLOAT_PACKAGES=(
    # LibreOffice suite (~400MB)
    'libreoffice*'

    # GNOME Help (yelp, ~100MB — apps modernos usam Web Help)
    yelp
    yelp-xsl

    # Apps GNOME não essenciais
    gnome-music
    gnome-todo
    gnome-maps
    gnome-weather
    gnome-contacts
    gnome-photos
    gnome-boxes

    # Games (~200MB)
    aisleriot
    gnome-mahjongg
    gnome-mines
    gnome-sudoku
    gnome-2048
    gnome-chess
    gnome-klotski
    gnome-nibbles
    gnome-robots
    gnome-tetravex
    five-or-more
    four-in-a-row
    hitori
    iagno
    lightsoff
    quadrapassel
    swell-foop
    tali

    # Media (substituídos por VLC/web em uso real)
    totem
    totem-common
    totem-plugins
    rhythmbox
    rhythmbox-data
    cheese
    cheese-common

    # Network
    transmission-gtk
    transmission-common
)

for pkg in "${BLOAT_PACKAGES[@]}"; do
    $SUDO apt remove --purge -y "$pkg" 2>/dev/null || true
done

$SUDO apt autoremove --purge -y

# ===========================================
# FASE 3 — VSCODE REPO
# ===========================================

echo -e "${YELLOW}[3/7] Adicionando repo Microsoft VSCode...${NC}"

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | $SUDO tee /usr/share/keyrings/microsoft.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null

# ===========================================
# FASE 4 — TMJOS APT REPO (trixie)
# ===========================================

echo -e "${YELLOW}[4/7] Adicionando repo TMJOs (trixie)...${NC}"

$SUDO mkdir -p /usr/share/keyrings
$SUDO curl -fsSL "$TMJOS_REPO_URL/keys/tmjos-archive-keyring.gpg" \
    -o /usr/share/keyrings/tmjos-archive-keyring.gpg

# Usa codename `trixie` (não noble como em v1.x)
# Components main + apps + extras (granularidade v2.0)
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] $TMJOS_REPO_URL trixie main apps" \
    | $SUDO tee /etc/apt/sources.list.d/tmjos.list > /dev/null

$SUDO apt update

# ===========================================
# FASE 5 — INSTALL TMJOS METAPACKAGE
# ===========================================

echo -e "${YELLOW}[5/7] Instalando TMJOs metapackage + apps...${NC}"

# Em Debian, o meta tmjos puxa via Depends:
#   - tmjos-branding, tmjos-defaults, tmjos-os-identity
#   - tmjmenu (TMJMenu + TMJDock)
#   - tmjpad
# E via Recommends:
#   - tmjstore, code, git, docker, calamares, evolution,
#     zram-tools, preload, etc.
$SUDO apt install -y tmjos

# ===========================================
# FASE 6 — CALAMARES BRANDING
# ===========================================

echo -e "${YELLOW}[6/7] Configurando Calamares + branding TMJOs...${NC}"

if $SUDO apt install -y calamares calamares-settings-debian tmjos-calamares-branding; then
    # Pacote instala em /usr/share/calamares/branding/tmjos/ (Debian-idiomatic).
    if [ -d /usr/share/calamares/branding/tmjos ] && [ -f /etc/calamares/settings.conf ]; then
        if grep -qE '^[[:space:]]*branding:' /etc/calamares/settings.conf; then
            $SUDO sed -i 's/^[[:space:]]*branding:.*/branding: tmjos/' /etc/calamares/settings.conf
        else
            echo "branding: tmjos" | $SUDO tee -a /etc/calamares/settings.conf > /dev/null
        fi
    fi
else
    echo -e "${YELLOW}Aviso: tmjos-calamares-branding indisponível; mantendo branding Debian.${NC}"
    $SUDO apt install -y calamares calamares-settings-debian || true
fi

# ===========================================
# FASE 7 — OPTIMIZE (mask services + zram + preload)
# ===========================================

echo -e "${YELLOW}[7/7] Otimizando pra rodar em 2GB RAM...${NC}"

# Mascara serviços pesados que ficam consumindo RAM/CPU idle.
# `|| true` porque alguns podem não existir (ex: tracker em sistemas
# sem GNOME Files).
MASK_SERVICES=(
    # Tracker 3 — indexer GNOME (CPU/IO/RAM killer no idle)
    tracker-miner-fs-3.service
    tracker-miner-rss-3.service
    tracker-extract-3.service
    tracker-writeback-3.service

    # PackageKit — TMJStore usa apt direto, não precisa do daemon
    packagekit.service
    packagekit-offline-update.service

    # Auto-upgrade — manter apt-daily.timer (só CHECK) mas mascarar
    # o upgrade automático. User atualiza via TMJStore ou apt manual.
    apt-daily-upgrade.service
    apt-daily-upgrade.timer

    # Plymouth quit wait — bloqueia boot 1-2s esperando animação
    plymouth-quit-wait.service
)

for svc in "${MASK_SERVICES[@]}"; do
    $SUDO systemctl mask "$svc" 2>/dev/null || true
done

# zram-tools: cria swap comprimido em RAM (3-4x compressão).
# Crítico pra sistemas 2GB — em vez de hit no disco SSD, comprime
# memória inativa em si.
# preload: pre-carrega apps usados frequentemente.
$SUDO apt install -y zram-tools preload || true

# ===========================================
# CLEANUP
# ===========================================

echo -e "${YELLOW}Limpeza final...${NC}"
$SUDO apt clean
$SUDO apt autoclean -y
$SUDO rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
$SUDO rm -rf /var/lib/apt/lists/* 2>/dev/null || true

# ===========================================
# VERIFICAÇÃO
# ===========================================

echo -e "\n${BLUE}═══ VERIFICAÇÃO DE PACOTES ═══${NC}\n"

check_pkg() {
    local name="$1"
    local pkg="$2"
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "^install ok installed$"; then
        local version
        version=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)
        echo -e "  ${GREEN}✓${NC} $name: $version"
    else
        echo -e "  ${RED}✗${NC} $name: NÃO INSTALADO"
    fi
}

check_pkg "TMJOs meta"        "tmjos"
check_pkg "tmjos-branding"    "tmjos-branding"
check_pkg "tmjos-os-identity" "tmjos-os-identity"
check_pkg "tmjos-defaults"    "tmjos-defaults"
check_pkg "tmjmenu"           "tmjmenu"
check_pkg "tmjpad"            "tmjpad"
check_pkg "tmjstore"          "tmjstore"
echo ""
check_pkg "Calamares"         "calamares"
check_pkg "VSCode"            "code"
check_pkg "Git"               "git"
check_pkg "Evolution"         "evolution"
check_pkg "zram-tools"        "zram-tools"
check_pkg "preload"           "preload"

echo -e "\n${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ✓ TMJOs v2.0 alpha customização completa!║${NC}"
echo -e "${BLUE}║  Debian-based · Slim · Sem Canonical      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"
