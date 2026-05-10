#!/bin/bash

###############################################
# TMJOs - Script de Customização v1.3+
#
# Roda dentro do chroot do Cubic (recomendado) ou em uma VM
# Ubuntu 24.04 limpa pra testes (NÃO no host de trabalho — remove apps).
#
# Faz, em ordem:
#   1. update + slim (remove bloat)
#   2. adiciona repo VSCode (Microsoft) — pra Recommends do tmjos
#      meta-package puxar 'code'
#   3. adiciona repo TMJOs (assinado) em packages.tmjos.dev
#      via tmjacometti.github.io/TMJOs
#   4. apt install tmjos — meta puxa todos os 6 core tmjos-* +
#      tmjpad + Recommends (VSCode, Docker, Git, fonts, etc.)
#   5. cleanup + verificação
#
# A diferença vs v1.2 customize.sh: o que era ~250 linhas de
# cp/sed/dconf agora é uma única linha 'apt install tmjos'. Os
# postinst hooks de cada tmjos-* package fazem o trabalho (dconf
# update, plymouth alternatives, gtk-update-icon-cache, etc.).
#
# Killer feature: depois disso, sistemas instalados recebem updates
# do core via 'sudo apt upgrade tmjos' — não precisa rebuildar ISO.
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

# TODO(v1.3.x): trocar pra https://packages.tmjos.com.br quando
# DNS propagar + Let's Encrypt provisionar HTTPS no custom domain.
TMJOS_REPO_URL="https://tmjacometti.github.io/TMJOs"

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   TMJOs - Customização v1.3 (apt-based)   ║${NC}"
echo -e "${BLUE}║   APT repo: tmjacometti.github.io/TMJOs   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

# ===========================================
# FASE 1 — ATUALIZAR
# ===========================================

echo -e "${YELLOW}[1/5] Atualizando sistema...${NC}"
$SUDO apt update
$SUDO apt upgrade -y

# ===========================================
# FASE 2 — SLIM AGGRESSIVE (remover bloat)
#
# tmjos meta-package só ADICIONA pacotes via Recommends. Os apps
# que TMJOs não quer (LibreOffice, gnome-* desnecessários, snap,
# tracker3, etc.) precisam sair antes do install.
# ===========================================

echo -e "${YELLOW}[2/5] Slim aggressive (removendo bloat)...${NC}"

APPS_TO_REMOVE=(
    # Telemetria
    "ubuntu-report"
    "apport"
    "popularity-contest"
    # Office suite
    "libreoffice-calc"
    "libreoffice-impress"
    "libreoffice-writer"
    "libreoffice-draw"
    "libreoffice-core"
    "libreoffice-common"
    # Apps GNOME desnecessários
    "gnome-todo"
    "gnome-maps"
    "gnome-music"
    "gnome-videos"
    "gnome-calendar"
    "gnome-contacts"
    "gnome-characters"
    "gnome-system-monitor"
    "yelp"
    "file-roller"
    # Mídia (TMJOs não é multimedia distro)
    "totem"
    "rhythmbox"
    "shotwell"
    "remmina"
    "transmission-gtk"
    # Slim Aggressive (RAM idle ~700MB, ISO ~2GB)
    "gnome-software"          # ~200MB RAM, TMJOs Software Center substitui
    "snapd"                    # ~200MB RAM, ~100MB disco
    "evolution-data-server"   # ~150MB RAM cache email
    "update-notifier"         # popup chato
    "thunderbird"              # ~350MB RAM
)

for app in "${APPS_TO_REMOVE[@]}"; do
    echo -e "  Removendo: ${YELLOW}$app${NC}"
    $SUDO apt remove -y "$app" 2>/dev/null || true
done

$SUDO apt autoremove -y
$SUDO apt autoclean -y
$SUDO apt clean

# ===========================================
# FASE 3 — REPO VSCODE (Microsoft)
#
# tmjos Recommends inclui 'code'. Precisa do repo Microsoft pra
# essa dep resolver. Sem isso, apt install tmjos puxa todos os
# Recommends EXCETO code.
# ===========================================

echo -e "${YELLOW}[3/5] Adicionando repo Microsoft VSCode...${NC}"

$SUDO apt install -y \
    wget gpg apt-transport-https software-properties-common ca-certificates curl

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | $SUDO tee /usr/share/keyrings/microsoft.gpg > /dev/null
echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null

# ===========================================
# FASE 4 — REPO TMJOS (packages.tmjos.dev)
# ===========================================

echo -e "${YELLOW}[4/5] Adicionando repo TMJOs...${NC}"

$SUDO mkdir -p /usr/share/keyrings
$SUDO curl -fsSL "$TMJOS_REPO_URL/keys/tmjos-archive-keyring.gpg" \
    -o /usr/share/keyrings/tmjos-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] $TMJOS_REPO_URL noble main" \
    | $SUDO tee /etc/apt/sources.list.d/tmjos.list > /dev/null

$SUDO apt update

# ===========================================
# FASE 5 — INSTALL TMJOS METAPACKAGE
#
# Puxa todos os componentes TMJOs e Recommends:
#   tmjos-branding, tmjos-os-identity, tmjos-dock, tmjos-defaults,
#   tmjos-shell-tweaks, tmjpad
#   + Recommends: code, git, docker.io, gnome-tweaks, fonts, etc.
# ===========================================

echo -e "${YELLOW}[5/5] Instalando TMJOs metapackage...${NC}"
$SUDO apt install -y tmjos

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
check_pkg "tmjos-dock"        "tmjos-dock"
check_pkg "tmjos-defaults"    "tmjos-defaults"
check_pkg "tmjos-shell-tweaks" "tmjos-shell-tweaks"
check_pkg "TMJPad"            "tmjpad"
echo ""
check_pkg "VSCode"            "code"
check_pkg "Git"               "git"
check_pkg "Docker"            "docker.io"
check_pkg "Plank"             "plank"
check_pkg "GNOME Tweaks"      "gnome-tweaks"
check_pkg "JetBrains Mono"    "fonts-jetbrains-mono"
check_pkg "Python GI"         "python3-gi"
check_pkg "GTK4"              "gir1.2-gtk-4.0"
check_pkg "Adwaita"           "gir1.2-adw-1"
check_pkg "spice-vdagent"     "spice-vdagent"
check_pkg "zram-config"       "zram-config"

echo -e "\n${BLUE}═══ IDENTIDADE TMJOS ═══${NC}\n"
if grep -q '^NAME="TMJOs"' /etc/os-release 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} /etc/os-release: $(grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2)"
else
    echo -e "  ${RED}✗${NC} /etc/os-release: ainda Ubuntu"
fi
if grep -q '^DISTRIB_CODENAME=noble' /etc/lsb-release 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} /etc/lsb-release: noble (compat scripts/PPAs)"
else
    echo -e "  ${RED}✗${NC} /etc/lsb-release: codename diferente — PPAs vão quebrar"
fi

echo -e "\n${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      ✓ TMJOs v1.3 customização completa!  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Próximos passos:${NC}"
echo -e "  1. Volte ao Cubic GUI"
echo -e "  2. Clique Next nas telas seguintes"
echo -e "  3. Generate ISO (xz pra release final, lz4 pra teste)"
echo -e "  4. Teste em VM com qemu-system-x86_64 -m 4G -accel kvm\n"

echo -e "${YELLOW}Killer feature v1.3:${NC} usuários instalados rodam"
echo -e "  ${GREEN}sudo apt upgrade tmjos${NC} pra atualizar todo o core"
echo -e "  sem precisar regenerar ISO. Welcome to v1.3 🐉\n"
