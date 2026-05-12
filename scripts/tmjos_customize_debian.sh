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
#   1. apt update (Debian já é slim — não precisa remover bloat)
#   2. instala stack dev: VSCode (Microsoft repo), Git, Docker,
#      Python+GTK4, fonts, etc.
#   3. adiciona repo TMJOs trixie em packages.tmjos.com.br
#   4. apt install tmjos — meta puxa todos componentes TMJOs
#   5. configura Calamares (instalador Debian) com branding TMJOs
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

echo -e "${YELLOW}[1/5] Atualizando sistema...${NC}"
$SUDO apt update
$SUDO apt upgrade -y

# Pacotes essenciais pra adicionar repos extras
$SUDO apt install -y \
    wget gpg apt-transport-https software-properties-common \
    ca-certificates curl git

# ===========================================
# FASE 2 — VSCODE REPO
# ===========================================

echo -e "${YELLOW}[2/5] Adicionando repo Microsoft VSCode...${NC}"

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | $SUDO tee /usr/share/keyrings/microsoft.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null

# ===========================================
# FASE 3 — TMJOS APT REPO (trixie)
# ===========================================

echo -e "${YELLOW}[3/5] Adicionando repo TMJOs (trixie)...${NC}"

$SUDO mkdir -p /usr/share/keyrings
$SUDO curl -fsSL "$TMJOS_REPO_URL/keys/tmjos-archive-keyring.gpg" \
    -o /usr/share/keyrings/tmjos-archive-keyring.gpg

# Usa codename `trixie` (não noble como em v1.x)
# Components main + apps + extras (granularidade v2.0)
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] $TMJOS_REPO_URL trixie main apps" \
    | $SUDO tee /etc/apt/sources.list.d/tmjos.list > /dev/null

$SUDO apt update

# ===========================================
# FASE 4 — INSTALL TMJOS METAPACKAGE
# ===========================================

echo -e "${YELLOW}[4/5] Instalando TMJOs metapackage + apps...${NC}"

# Em Debian, o meta tmjos puxa via Depends:
#   - tmjos-branding, tmjos-defaults, tmjos-os-identity
#   - tmjmenu (TMJMenu + TMJDock)
#   - tmjpad
# E via Recommends:
#   - tmjstore (software center)
#   - code, git, docker.io, etc
$SUDO apt install -y tmjos

# Pacotes Ubuntu-specific que NÃO vão pra Debian:
#   - tmjos-installer (era ubiquity divert — em Debian usamos
#     Calamares com tmjos-calamares-branding)
#   - tmjos-shell-tweaks (Yaru-specific — Debian não precisa)
#   - tmjos-dock (Plank legacy — irrelevante)

# ===========================================
# FASE 5 — CALAMARES BRANDING (v2.0 alpha: básico)
# ===========================================

echo -e "${YELLOW}[5/5] Configurando Calamares (placeholder v2.0 alpha)...${NC}"

# TODO em v2.0 stable: tmjos-calamares-branding package que provê:
#   /etc/calamares/branding/tmjos/branding.desc
#   /etc/calamares/branding/tmjos/show.qml (slideshow QML)
#   /etc/calamares/branding/tmjos/*.png (assets)
#
# Por ora, garante calamares instalado. Branding default Debian.
$SUDO apt install -y calamares calamares-settings-debian || true

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

echo -e "\n${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ✓ TMJOs v2.0 alpha customização completa!║${NC}"
echo -e "${BLUE}║  Debian-based · Sem Canonical · Sem snap  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"
