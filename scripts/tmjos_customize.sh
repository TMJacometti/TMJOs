#!/bin/bash

###############################################
# TMJOs - Script de Customização Completo
#
# Roda dentro do chroot do Cubic (recomendado) ou em uma VM
# Ubuntu 24.04 limpa pra testes (NÃO no host de trabalho — remove apps).
#
# Faz, em ordem:
#   1. update + slim (remove bloat)
#   2. adiciona repo VSCode (Microsoft)
#   3. instala apps (VSCode, Docker, Plank, ferramentas, deps GTK4)
#   4. clona repo TMJOs pra pegar assets
#   5. branding: wallpapers, logo, /etc/os-release, dconf defaults
#   6. plank autostart system-wide
#   7. TMJPad em /opt/tmjpad + wrapper
#   8. limpeza final
#
# Bug do v1.0: este script não fazia 4-7 — ISO saiu como Ubuntu vanilla
# com os apps instalados. Corrigido em v1.1.
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

TMJOS_REPO="https://github.com/TMJacometti/TMJOs"
TMJOS_SRC="/tmp/tmjos-source"
TMJOS_BRANCH="main"

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   TMJOs - Customização Completa v1.1      ║${NC}"
echo -e "${BLUE}║   Apps + Branding + TMJPad                ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

# ===========================================
# FASE 1 — ATUALIZAR
# ===========================================

echo -e "${YELLOW}[1/8] Atualizando sistema...${NC}"
$SUDO apt update
$SUDO apt upgrade -y

# ===========================================
# FASE 2 — SLIM (remover apps inúteis)
# ===========================================

echo -e "${YELLOW}[2/8] Removendo apps desnecessários (slim)...${NC}"

APPS_TO_REMOVE=(
    "ubuntu-report"
    "apport"
    "popularity-contest"
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

$SUDO apt autoremove -y
$SUDO apt autoclean -y
$SUDO apt clean

# ===========================================
# FASE 3 — REPO VSCODE (Microsoft)
# ===========================================

echo -e "${YELLOW}[3/8] Adicionando repo VSCode + deps básicas...${NC}"

$SUDO apt install -y \
    wget gpg apt-transport-https software-properties-common ca-certificates git

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | $SUDO tee /usr/share/keyrings/microsoft.gpg > /dev/null
echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null

$SUDO apt update

# ===========================================
# FASE 4 — APPS
# ===========================================

echo -e "${YELLOW}[4/8] Instalando apps...${NC}"

# Editor + dev
$SUDO apt install -y code git git-flow docker.io docker-compose

# Dock + customização GNOME
$SUDO apt install -y plank gnome-tweaks dconf-editor \
    gnome-shell-extensions gnome-shell-extension-manager

# CLI essenciais
$SUDO apt install -y curl wget htop neofetch vim nano build-essential \
    dnsutils net-tools traceroute

# Python + GTK4 + Adwaita (necessário pro TMJPad)
$SUDO apt install -y python3 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1

# ===========================================
# FASE 5 — Clonar repo TMJOs (pra pegar assets)
# ===========================================

echo -e "${YELLOW}[5/8] Clonando repo TMJOs pra pegar assets...${NC}"

rm -rf "$TMJOS_SRC"
git clone --depth 1 --branch "$TMJOS_BRANCH" "$TMJOS_REPO" "$TMJOS_SRC"

# ===========================================
# FASE 6 — BRANDING
# ===========================================

echo -e "${YELLOW}[6/8] Aplicando branding TMJOs...${NC}"

# 6a) Wallpaper
echo -e "  ${GREEN}→${NC} Wallpaper"
$SUDO mkdir -p /usr/share/backgrounds/tmjos
$SUDO cp "$TMJOS_SRC"/assets/wallpapers/tmjos_wallpaper.png /usr/share/backgrounds/tmjos/

# 6b) Logo — 3 variantes do Nano Banana (Circular, Rounded, Square).
# Rounded = app icon principal (estilo macOS/iOS).
# Circular e Square ficam disponíveis pra outros usos (avatar, banner).
echo -e "  ${GREEN}→${NC} Logos (3 variantes)"
$SUDO mkdir -p \
    /usr/share/icons/hicolor/512x512/apps \
    /usr/share/icons/tmjos \
    /usr/share/pixmaps

# App icon principal: usa o Rounded (combina com tema GNOME app icons)
$SUDO cp "$TMJOS_SRC"/assets/logos/TMJOs_Logo_Rounded.png \
    /usr/share/icons/hicolor/512x512/apps/tmjos.png
$SUDO cp "$TMJOS_SRC"/assets/logos/TMJOs_Logo_Rounded.png \
    /usr/share/pixmaps/tmjos.png

# Variantes adicionais em /usr/share/icons/tmjos/ pra apps que queiram
# escolher (about dialog redondo, banner, etc)
$SUDO cp "$TMJOS_SRC"/assets/logos/TMJOs_Logo_Circular.png /usr/share/icons/tmjos/
$SUDO cp "$TMJOS_SRC"/assets/logos/TMJOs_Logo_Rounded.png  /usr/share/icons/tmjos/
$SUDO cp "$TMJOS_SRC"/assets/logos/TMJOs_Logo_Square.png   /usr/share/icons/tmjos/

# Refresh icon cache (silencia warnings se hicolor não tiver index)
$SUDO gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

# 6c) /etc/os-release  e  /etc/lsb-release  (identidade do sistema)
echo -e "  ${GREEN}→${NC} /etc/os-release identidade TMJOs"
$SUDO tee /etc/os-release > /dev/null << 'EOF'
PRETTY_NAME="TMJOs 1.0"
NAME="TMJOs"
VERSION_ID="1.0"
VERSION="1.0 (insano)"
VERSION_CODENAME=insano
ID=tmjos
ID_LIKE="ubuntu debian"
HOME_URL="https://github.com/TMJacometti/TMJOs"
SUPPORT_URL="https://github.com/TMJacometti/TMJOs/issues"
BUG_REPORT_URL="https://github.com/TMJacometti/TMJOs/issues"
UBUNTU_CODENAME=noble
LOGO=tmjos
EOF

$SUDO tee /etc/lsb-release > /dev/null << 'EOF'
DISTRIB_ID=TMJOs
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=insano
DISTRIB_DESCRIPTION="TMJOs 1.0"
EOF

# 6d) /etc/issue + /etc/issue.net  (texto exibido no login TTY)
$SUDO tee /etc/issue > /dev/null << 'EOF'
TMJOs 1.0 \n \l

EOF
$SUDO cp /etc/issue /etc/issue.net

# 6e) dconf defaults system-wide: dark mode, wallpaper, color scheme
echo -e "  ${GREEN}→${NC} dconf defaults (dark + wallpaper)"
$SUDO mkdir -p /etc/dconf/profile /etc/dconf/db/local.d

$SUDO tee /etc/dconf/profile/user > /dev/null << 'EOF'
user-db:user
system-db:local
EOF

$SUDO tee /etc/dconf/db/local.d/00-tmjos-defaults > /dev/null << 'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/tmjos/tmjos_wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/tmjos/tmjos_wallpaper.png'
picture-options='zoom'
primary-color='#0a0e2a'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/tmjos/tmjos_wallpaper.png'
picture-options='zoom'

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Adwaita-dark'
icon-theme='Adwaita'
font-name='Cantarell 11'
monospace-font-name='JetBrains Mono 11'
clock-show-date=true
clock-show-seconds=false
clock-show-weekday=false

[org/gnome/shell]
favorite-apps=['code.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'tmjpad.desktop', 'gnome-control-center.desktop']
# Desabilita Ubuntu Dock (barra vertical lateral) e ícones do desktop —
# TMJOs usa Plank na base, sem ícones flutuando no desktop. Sem essas
# duas linhas, fica dois docks competindo + ícones de Home/Trash visíveis.
disabled-extensions=['ubuntu-dock@ubuntu.com', 'ubuntu-appindicators@ubuntu.com', 'ding@rastersoft.com']
EOF

$SUDO dconf update

# 6f) Plank autostart system-wide (todo usuário ganha o dock no login)
echo -e "  ${GREEN}→${NC} Plank autostart (/etc/xdg/autostart)"
$SUDO tee /etc/xdg/autostart/plank.desktop > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Name=Plank
Comment=Stupidly simple dock
Exec=plank
Icon=plank
Categories=GNOME;GTK;Utility;
StartupNotify=false
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
EOF

# 6g) Plank user-level skel (pra users criados na instalação)
echo -e "  ${GREEN}→${NC} Plank config em /etc/skel"
SKEL_PLANK_DIR="/etc/skel/.config/plank/dock1"
$SUDO mkdir -p "$SKEL_PLANK_DIR/launchers"
$SUDO tee "$SKEL_PLANK_DIR/settings" > /dev/null << 'EOF'
[dock1]
alignment='center'
auto-pinch=false
current-workspace-only=false
dock-items=['gnome-control-center.dockitem', 'org.gnome.Nautilus.dockitem', 'code.dockitem', 'tmjpad.dockitem', 'org.gnome.Terminal.dockitem']
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

# 6h) First-run setup: copia config do Plank pro user atual se ainda não tem.
# Isso resolve o caso do live-CD (user 'ubuntu' já existe, /etc/skel não foi
# aplicado) e também usuários antigos que tinham a distro sem essa config.
echo -e "  ${GREEN}→${NC} TMJOs first-run autostart (Plank config no live-CD)"
$SUDO tee /usr/local/bin/tmjos-first-run > /dev/null << 'EOF'
#!/bin/sh
# Copia config do Plank do /etc/skel pro user atual se ainda não existe.
# Roda no autostart phase=Initialization, antes do Plank ser iniciado.
if [ ! -d "$HOME/.config/plank" ] && [ -d /etc/skel/.config/plank ]; then
    mkdir -p "$HOME/.config"
    cp -r /etc/skel/.config/plank "$HOME/.config/"
fi
exit 0
EOF
$SUDO chmod +x /usr/local/bin/tmjos-first-run

$SUDO tee /etc/xdg/autostart/tmjos-first-run.desktop > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Name=TMJOs First-Run Setup
Comment=Copia configs default pra usuário atual se ainda não tem
Exec=/usr/local/bin/tmjos-first-run
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Initialization
EOF

# 6i) Suprimir popups de welcome / installer no live-CD
#
# O Ubuntu 24.04 dispara via autostart o ubuntu-desktop-provision
# (Flutter UI do novo installer). Em ISOs feitas com Cubic, o snap do
# installer fica num estado meio-quebrado — depende de hooks do casper
# que não correspondem ao squashfs regenerado. Resultado: popup
# "Something went wrong" toda vez que o desktop carrega.
#
# Solução: marcar Hidden=true nos autostarts dos welcome wizards.
# Isso esconde o popup mas mantém os pacotes instalados, então o
# ícone "Install TMJOS" no desktop (que vem via casper, não via
# autostart) continua funcional.
echo -e "  ${GREEN}→${NC} Suprimindo welcome popups (installer + initial-setup)"
WELCOME_AUTOSTARTS=(
    "/etc/xdg/autostart/ubuntu-desktop-installer.desktop"
    "/etc/xdg/autostart/ubuntu-desktop-bootstrap.desktop"
    "/etc/xdg/autostart/ubuntu-desktop-provision.desktop"
    "/etc/xdg/autostart/ubuntu-bootstrap.desktop"
    "/etc/xdg/autostart/gnome-initial-setup-first-login.desktop"
    "/etc/xdg/autostart/gnome-initial-setup-copy-worker.desktop"
    "/etc/xdg/autostart/snap-store-ubuntu-software.desktop"
)

for f in "${WELCOME_AUTOSTARTS[@]}"; do
    if [ -f "$f" ]; then
        if ! grep -q "^Hidden=true" "$f"; then
            echo "Hidden=true" | $SUDO tee -a "$f" > /dev/null
            echo -e "    ${GREEN}suppressed${NC}: $(basename "$f")"
        fi
    fi
done

# Também olha por entries com nomes inesperados que matchem padrões typical
$SUDO find /etc/xdg/autostart/ -maxdepth 1 -type f -name '*.desktop' 2>/dev/null | while read -r f; do
    name=$(basename "$f")
    case "$name" in
        *bootstrap*|*provision*|*installer*welcome*|*welcome*installer*)
            if ! grep -q "^Hidden=true" "$f"; then
                echo "Hidden=true" | $SUDO tee -a "$f" > /dev/null
                echo -e "    ${GREEN}suppressed${NC}: $name (pattern match)"
            fi
            ;;
    esac
done

# 6j) Boot identity: GRUB menu + Plymouth splash sem "Ubuntu"
echo -e "  ${GREEN}→${NC} Boot identity (GRUB distributor + Plymouth tema)"

# GRUB — força o distributor explicitamente. Mesmo que /etc/lsb-release já
# diga TMJOs, alguns hooks do GRUB amostram do default config primeiro.
if [ -f /etc/default/grub ]; then
    if grep -q '^GRUB_DISTRIBUTOR=' /etc/default/grub; then
        $SUDO sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="TMJOs"|' /etc/default/grub
    else
        echo 'GRUB_DISTRIBUTOR="TMJOs"' | $SUDO tee -a /etc/default/grub > /dev/null
    fi
    # update-grub regenera /boot/grub/grub.cfg com as entries renomeadas.
    # Em chroot do Cubic, /proc e /sys estão montados pelo Cubic, então
    # roda sem problema. No fallback, instala-no-target funciona.
    $SUDO update-grub 2>/dev/null \
        && echo -e "    ${GREEN}grub.cfg regenerated${NC}" \
        || echo -e "    ${YELLOW}(update-grub falhou no chroot, vai rodar no install)${NC}"
fi

# Plymouth — troca pro tema 'spinner' (neutro, sem branding Ubuntu).
# Pra v1.1 a ideia é fazer um tema TMJOs custom com logo + animação.
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    if plymouth-set-default-theme --list 2>/dev/null | grep -qx 'spinner'; then
        $SUDO plymouth-set-default-theme -R spinner 2>/dev/null \
            && echo -e "    ${GREEN}plymouth: spinner (neutro)${NC}" \
            || echo -e "    ${YELLOW}(plymouth -R falhou no chroot, vai aplicar no install)${NC}"
    else
        echo -e "    ${YELLOW}(plymouth: tema 'spinner' não disponível)${NC}"
    fi
fi

# ===========================================
# FASE 7 — TMJPAD (editor proprietário)
# ===========================================

echo -e "${YELLOW}[7/8] Instalando TMJPad...${NC}"

# Código vai pra /opt/tmjpad/ (read-only system-wide)
$SUDO rm -rf /opt/tmjpad
$SUDO mkdir -p /opt/tmjpad
$SUDO cp -r "$TMJOS_SRC"/apps/tmjpad/tmjpad /opt/tmjpad/
$SUDO chmod -R a+rX /opt/tmjpad

# Wrapper executável em /usr/local/bin/tmjpad
$SUDO tee /usr/local/bin/tmjpad > /dev/null << 'EOF'
#!/bin/sh
# TMJPad launcher - injeta /opt/tmjpad no path do Python
exec python3 -c "
import sys
sys.path.insert(0, '/opt/tmjpad')
from tmjpad.app import main
sys.exit(main())
" "$@"
EOF
$SUDO chmod +x /usr/local/bin/tmjpad

# Desktop entry
$SUDO cp "$TMJOS_SRC"/apps/tmjpad/data/tmjpad.desktop /usr/share/applications/

echo -e "  ${GREEN}✓${NC} TMJPad instalado em /opt/tmjpad/, comando: tmjpad"

# ===========================================
# FASE 8 — VERIFICAÇÃO + LIMPEZA
# ===========================================

echo -e "${YELLOW}[8/8] Verificação + limpeza final...${NC}"
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

check_pkg "VSCode" "code"
check_pkg "Git" "git"
check_pkg "Docker" "docker.io"
check_pkg "Plank" "plank"
check_pkg "GNOME Tweaks" "gnome-tweaks"
check_pkg "Python GI" "python3-gi"
check_pkg "GTK4 typelib" "gir1.2-gtk-4.0"
check_pkg "Adwaita typelib" "gir1.2-adw-1"

echo -e "\n${BLUE}═══ VERIFICAÇÃO DE BRANDING ═══${NC}\n"

check_file() {
    local name="$1"
    local path="$2"
    if [ -e "$path" ]; then
        echo -e "  ${GREEN}✓${NC} $name: $path"
    else
        echo -e "  ${RED}✗${NC} $name: AUSENTE em $path"
    fi
}

check_file "Wallpaper TMJOs" "/usr/share/backgrounds/tmjos/tmjos_wallpaper.png"
check_file "Logo PNG (icon theme)" "/usr/share/icons/hicolor/512x512/apps/tmjos.png"
check_file "Logo PNG (pixmaps)" "/usr/share/pixmaps/tmjos.png"
check_file "Logo Rounded variant" "/usr/share/icons/tmjos/TMJOs_Logo_Rounded.png"
check_file "Logo Circular variant" "/usr/share/icons/tmjos/TMJOs_Logo_Circular.png"
check_file "Logo Square variant" "/usr/share/icons/tmjos/TMJOs_Logo_Square.png"
check_file "/etc/os-release TMJOs" "/etc/os-release"
check_file "Plank autostart" "/etc/xdg/autostart/plank.desktop"
check_file "dconf defaults" "/etc/dconf/db/local.d/00-tmjos-defaults"
check_file "TMJPad code" "/opt/tmjpad/tmjpad/app.py"
check_file "TMJPad wrapper" "/usr/local/bin/tmjpad"
check_file "TMJPad .desktop" "/usr/share/applications/tmjpad.desktop"

# Confirma que /etc/os-release foi sobrescrito
if grep -q '^NAME="TMJOs"' /etc/os-release; then
    echo -e "  ${GREEN}✓${NC} /etc/os-release identidade: TMJOs"
else
    echo -e "  ${RED}✗${NC} /etc/os-release identidade: ainda Ubuntu (algo deu errado)"
fi

# Limpeza
echo -e "\n${YELLOW}Limpando temp + caches...${NC}"
$SUDO rm -rf "$TMJOS_SRC"
$SUDO apt clean
$SUDO apt autoclean -y
$SUDO rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
$SUDO rm -rf /var/lib/apt/lists/* 2>/dev/null || true

echo -e "\n${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      ✓ TMJOs v1.0 customização completa!  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Próximos passos:${NC}"
echo -e "  1. Volte ao Cubic GUI"
echo -e "  2. Clique Next nas telas seguintes (Kernels, Compression)"
echo -e "  3. Generate ISO (~20-40 min com xz)"
echo -e "  4. Teste em VM com qemu-system-x86_64 -m 4G -smp 4 ...\n"

echo -e "${GREEN}TMJOs pronto pra gerar a ISO!${NC}\n"
