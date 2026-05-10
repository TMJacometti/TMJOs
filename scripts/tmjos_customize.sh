#!/bin/bash

###############################################
# TMJOs - Script de Customização Automática
#
# Use dentro do Cubic, depois de entrar no chroot.
# Pode rodar fora do Cubic também (pra testes locais)
# desde que com sudo.
###############################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detecta se já é root (caso típico do chroot do Cubic).
# Fora do chroot, usa sudo. Isso evita erros como "sudo: command not found"
# em chroots minimalistas.
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   TMJOs - Customização Automática         ║${NC}"
echo -e "${BLUE}║   Clean Linux Distribution                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

# ===========================================
# FASE 1: ATUALIZAÇÃO DO SISTEMA
# ===========================================

echo -e "${YELLOW}[1/6] Atualizando sistema...${NC}"
$SUDO apt update
$SUDO apt upgrade -y

# ===========================================
# FASE 2: REMOVER APPS DESNECESSÁRIOS
# ===========================================

echo -e "${YELLOW}[2/6] Removendo apps desnecessários (slim)...${NC}"

APPS_TO_REMOVE=(
    "ubuntu-report"
    "apport"
    "popularity-contest"
    "thunderbird"
    "libreoffice-calc"
    "libreoffice-impress"
    "libreoffice-writer"
    "libreoffice-draw"
    "libreoffice-core"
    "libreoffice-common"
    "gnome-todo"
    "gnome-maps"
    "gnome-music"
    "gnome-videos"
    "totem"
    "rhythmbox"
    "shotwell"
    "remmina"
    "transmission-gtk"
)

for app in "${APPS_TO_REMOVE[@]}"; do
    echo -e "  Removendo: ${YELLOW}$app${NC}"
    $SUDO apt remove -y "$app" 2>/dev/null || true
done

echo -e "  ${YELLOW}Limpando arquivos órfãos...${NC}"
$SUDO apt autoremove -y
$SUDO apt autoclean -y
$SUDO apt clean

# ===========================================
# FASE 3: ADICIONAR REPOS EXTERNOS
# ===========================================

echo -e "${YELLOW}[3/6] Adicionando repositórios externos...${NC}"

# Dependências para gerenciar repos
$SUDO apt install -y wget gpg apt-transport-https software-properties-common ca-certificates

# --- VSCode (Microsoft) ---
echo -e "  Adicionando repo: ${GREEN}Microsoft VSCode${NC}"
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | $SUDO tee /usr/share/keyrings/microsoft.gpg > /dev/null
echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null

$SUDO apt update

# ===========================================
# FASE 4: INSTALAR APPS ESSENCIAIS
# ===========================================

echo -e "${YELLOW}[4/6] Instalando apps essenciais...${NC}"

# VSCode (do repo oficial Microsoft)
echo -e "  Instalando: ${GREEN}VSCode${NC}"
$SUDO apt install -y code

# Git + git-flow
echo -e "  Instalando: ${GREEN}Git + git-flow${NC}"
$SUDO apt install -y git git-flow

# Docker (versão Ubuntu — simples; não inclui buildx/compose v2 modernos)
echo -e "  Instalando: ${GREEN}Docker${NC}"
$SUDO apt install -y docker.io docker-compose

# Plank (dock estilo Mac)
echo -e "  Instalando: ${GREEN}Plank (Dock)${NC}"
$SUDO apt install -y plank

# Customização GNOME
echo -e "  Instalando: ${GREEN}GNOME Tweaks${NC}"
$SUDO apt install -y gnome-tweaks dconf-editor

# Extensões GNOME
echo -e "  Instalando: ${GREEN}Extensões GNOME${NC}"
$SUDO apt install -y gnome-shell-extensions gnome-shell-extension-manager

# Ferramentas utilitárias
echo -e "  Instalando: ${GREEN}Ferramentas utilitárias${NC}"
$SUDO apt install -y curl wget htop neofetch vim nano build-essential

# ===========================================
# FASE 5: CONFIGURAR PLANK (DOCK)
# ===========================================

echo -e "${YELLOW}[5/6] Configurando Plank...${NC}"

# Configuração Plank é por-usuário (~/.config). Em distros LiveCD essa
# config precisa ir no /etc/skel pra ser herdada pelos usuários novos.
SKEL_PLANK_DIR="/etc/skel/.config/plank/dock1"
$SUDO mkdir -p "$SKEL_PLANK_DIR"
$SUDO mkdir -p "$SKEL_PLANK_DIR/launchers"

$SUDO tee "$SKEL_PLANK_DIR/settings" > /dev/null << 'EOF'
[dock1]
alignment='center'
auto-pinch=false
current-workspace-only=false
dock-items=['gnome-control-center.dockitem', 'org.gnome.Nautilus.dockitem', 'code.dockitem', 'org.gnome.Terminal.dockitem']
hide-delay=0
hide-mode='window-dodge'
hide-on-focus=false
icon-size=48
items-alignment='center'
lock-items=false
monitor=0
offset=0
pinned-only=false
position='bottom'
pressure-reveal=false
show-dock-item=true
theme='Transparent'
unhide-delay=0
use-custom-font=false
EOF

echo -e "  ${GREEN}✓${NC} Plank configurado em /etc/skel (herdado por novos usuários)"

# ===========================================
# FASE 6: VERIFICAÇÃO FINAL
# ===========================================

echo -e "${YELLOW}[6/6] Verificando instalações...${NC}"

echo -e "\n${BLUE}═══ VERIFICAÇÃO DE PACOTES ═══${NC}\n"

check_cmd() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &> /dev/null; then
        local version
        version=$("$cmd" --version 2>&1 | head -n1)
        echo -e "  ${GREEN}✓${NC} $name: $version"
    else
        echo -e "  ${RED}✗${NC} $name: NÃO INSTALADO"
    fi
}

check_cmd "VSCode" "code"
check_cmd "Git" "git"
check_cmd "Docker" "docker"
check_cmd "Plank" "plank"
check_cmd "GNOME Tweaks" "gnome-tweaks"

# Limpeza final
echo -e "\n${YELLOW}Limpeza final...${NC}"
$SUDO apt clean
$SUDO apt autoclean -y
$SUDO rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
$SUDO rm -rf /var/lib/apt/lists/* 2>/dev/null || true

# ===========================================
# FINAL
# ===========================================

echo -e "\n${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      ✓ TMJOs Customização Completa!       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Próximos passos:${NC}"
echo -e "  1. Sair deste terminal e voltar ao Cubic"
echo -e "  2. No Cubic, clique em 'Generate ISO'"
echo -e "  3. Aguarde a geração (~20-40 min)"
echo -e "  4. Teste em VM antes de gravar em pen drive\n"

echo -e "${GREEN}TMJOs pronto pra gerar a ISO!${NC}\n"
