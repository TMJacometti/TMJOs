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
echo -e "${BLUE}║   TMJOs - Customização Completa v1.2      ║${NC}"
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
    # Telemetria / opcional
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
    # Apps GNOME que ninguém usa em distro pra dev
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
    # SLIM PLUS — corte agressivo pra rodar em 4GB RAM
    "gnome-software"          # ~200MB RAM, TMJOs Software Center substitui
    "snapd"                    # ~200MB RAM, ~100MB disco — não usamos snap
    "evolution-data-server"   # ~150MB RAM cache email
    "update-notifier"         # popup chato, quem quer roda apt
    "thunderbird"              # ~350MB RAM, dev usa webmail/clients alternativos
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

# Dock + customização GNOME (just-perfection NÃO existe no Ubuntu 24.04
# apt; usamos CSS hack no Yaru shell theme pra esconder Activities button)
$SUDO apt install -y plank gnome-tweaks dconf-editor \
    gnome-shell-extensions gnome-shell-extension-manager

# CLI essenciais
$SUDO apt install -y curl wget htop neofetch vim nano build-essential \
    dnsutils net-tools traceroute

# Python + GTK4 + Adwaita (necessário pro TMJPad)
$SUDO apt install -y python3 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1

# Fontes — JetBrains Mono é referenciada no dconf default; sem ela o
# GNOME cai pra fallback feio. Cantarell já vem mas garantimos.
$SUDO apt install -y fonts-jetbrains-mono fonts-cantarell fonts-noto-color-emoji

# VM/hypervisor integration — spice-vdagent dá clipboard, drag-drop e
# resize automático com host quando rodando em QEMU/KVM/GNOME Boxes/
# virt-manager. qemu-guest-agent permite host enviar comandos ao guest.
# Inofensivos em hardware real (services não iniciam sem host suportar).
$SUDO apt install -y spice-vdagent qemu-guest-agent

# SLIM PLUS — RAM efetiva extra em sistemas low-mem
# zram-config: comprime RAM ociosa em "swap" virtual (ganha ~30% RAM efetiva)
# preload:     daemon que pré-carrega apps mais usados em RAM ociosa
$SUDO apt install -y zram-config preload

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

# 6c) /etc/os-release e /etc/lsb-release — esquema "branding + compat":
#
#   /etc/os-release  → identidade TMJOs (codename "insano"). Visível no
#                      GNOME "About this computer" e ferramentas modernas.
#                      Mantém UBUNTU_CODENAME=noble pra ferramentas que
#                      sabem buscar essa key específica.
#   /etc/lsb-release → 100% Ubuntu vanilla (DISTRIB_CODENAME=noble).
#                      Crítico pra:
#                        - add-apt-repository ppa:foo/bar (usa lsb_release -cs)
#                        - scripts de install (NodeJS NodeSource, Docker
#                          install.sh, k8s, etc.) que fazem
#                          $(lsb_release -cs) e esperam um codename Ubuntu
#                          válido.
#                      Sem isso, todo PPA install retorna 404.
echo -e "  ${GREEN}→${NC} /etc/os-release identidade TMJOs (visual)"
$SUDO tee /etc/os-release > /dev/null << 'EOF'
PRETTY_NAME="TMJOs 1.2"
NAME="TMJOs"
VERSION_ID="1.2"
VERSION="1.2 (insano)"
VERSION_CODENAME=insano
ID=tmjos
ID_LIKE="ubuntu debian"
HOME_URL="https://github.com/TMJacometti/TMJOs"
SUPPORT_URL="https://github.com/TMJacometti/TMJOs/issues"
BUG_REPORT_URL="https://github.com/TMJacometti/TMJOs/issues"
UBUNTU_CODENAME=noble
LOGO=tmjos
EOF

echo -e "  ${GREEN}→${NC} /etc/lsb-release Ubuntu noble (compat scripts/PPAs)"
$SUDO tee /etc/lsb-release > /dev/null << 'EOF'
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=24.04
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Ubuntu 24.04 LTS"
EOF

# 6d) /etc/issue + /etc/issue.net  (texto exibido no login TTY)
$SUDO tee /etc/issue > /dev/null << 'EOF'
TMJOs 1.2 \n \l

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
# Desabilita Ubuntu Dock (barra vertical lateral) e ícones do desktop.
disabled-extensions=['ubuntu-dock@ubuntu.com', 'ubuntu-appindicators@ubuntu.com', 'ding@rastersoft.com']
EOF

$SUDO dconf update

# 6e.2) CSS hack: esconde GNOME Activities button no top bar
# (substitui o que faríamos via just-perfection extension, que não existe
# no apt do Ubuntu 24.04). Editamos o Yaru shell theme — tema default
# do Ubuntu 24.04. Compatível com Yaru-dark também.
echo -e "  ${GREEN}→${NC} CSS hack: hide Activities button"
for css in /usr/share/gnome-shell/theme/Yaru/gnome-shell.css \
           /usr/share/gnome-shell/theme/Yaru-dark/gnome-shell.css \
           /usr/share/gnome-shell/gnome-shell.css; do
    if [ -f "$css" ]; then
        if ! grep -q "TMJOs hide activities" "$css"; then
            $SUDO tee -a "$css" > /dev/null << 'EOF'

/* TMJOs hide activities — esconde Activities button do top bar */
#panel .panel-button.activities-button,
#panel .panel-button:first-child {
    visibility: hidden;
    width: 0;
    min-width: 0;
    padding: 0;
    margin: 0;
    border: 0;
}
EOF
            echo "    patched $css"
        fi
    fi
done

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
# IMPORTANTE: dock-items na settings só lista nomes de .dockitem files —
# os arquivos .dockitem PRECISAM existir em launchers/. Sem eles, Plank
# ignora a entry silenciosamente e o dock fica vazio.
echo -e "  ${GREEN}→${NC} Plank config em /etc/skel + .dockitem files"
SKEL_PLANK_DIR="/etc/skel/.config/plank/dock1"
$SUDO mkdir -p "$SKEL_PLANK_DIR/launchers"

# Cria os 4 .dockitem que apontam pros .desktop instalados
$SUDO tee "$SKEL_PLANK_DIR/launchers/tmjos-show-apps.dockitem" > /dev/null << 'DOCK'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/tmjos-show-apps.desktop
DOCK
$SUDO tee "$SKEL_PLANK_DIR/launchers/code.dockitem" > /dev/null << 'DOCK'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/code.desktop
DOCK
$SUDO tee "$SKEL_PLANK_DIR/launchers/tmjpad.dockitem" > /dev/null << 'DOCK'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/tmjpad.desktop
DOCK
$SUDO tee "$SKEL_PLANK_DIR/launchers/org.gnome.Terminal.dockitem" > /dev/null << 'DOCK'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/org.gnome.Terminal.desktop
DOCK

$SUDO tee "$SKEL_PLANK_DIR/settings" > /dev/null << 'EOF'
[dock1]
alignment='center'
auto-pinch=false
current-workspace-only=false
dock-items=['tmjos-show-apps.dockitem', 'code.dockitem', 'tmjpad.dockitem', 'org.gnome.Terminal.dockitem']
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

# 6g.1) Launcher "Todos os Apps" — botão estilo macOS Launchpad que abre
# o GNOME Activities Apps view. Sem isso, o Plank vira só uma row de
# pinneds e o usuário não tem ponto de entrada pro app drawer no dock.
echo -e "  ${GREEN}→${NC} Launcher 'Todos os Apps' (Plank → GNOME Apps view)"

# Wrapper script: abre o overview de apps via gdbus (GNOME Shell)
$SUDO tee /usr/local/bin/tmjos-show-apps > /dev/null << 'EOF'
#!/bin/sh
# Abre a Apps View do GNOME Shell (mesma tela do Activities → Apps grid).
# Usa Eval do GNOME Shell — disponível por default no Ubuntu desktop.
gdbus call --session \
    --dest org.gnome.Shell \
    --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Eval \
    "Main.overview.dash.showAppsButton.checked = true; Main.overview.show();" \
    >/dev/null 2>&1 || true
EOF
$SUDO chmod +x /usr/local/bin/tmjos-show-apps

# .desktop entry — o Plank usa o ID do .desktop como nome do .dockitem
$SUDO tee /usr/share/applications/tmjos-show-apps.desktop > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Name=Todos os Apps
GenericName=All Applications
Comment=Abre a lista de todos os apps instalados
Exec=/usr/local/bin/tmjos-show-apps
Icon=view-app-grid-symbolic
Terminal=false
Categories=Utility;
Keywords=apps;launcher;launchpad;overview;
EOF

# 6h) First-run setup: copia config do Plank pro user atual se ainda não tem.
# Isso resolve o caso do live-CD (user 'ubuntu' já existe, /etc/skel não foi
# aplicado) e também usuários antigos que tinham a distro sem essa config.
echo -e "  ${GREEN}→${NC} TMJOs first-run autostart (Plank config no live-CD)"
$SUDO tee /usr/local/bin/tmjos-first-run > /dev/null << 'EOF'
#!/bin/sh
# TMJOs first-run / every-login setup. Roda no autostart phase=Initialization.

PLANK_DIR="$HOME/.config/plank/dock1"
PLANK_SETTINGS="$PLANK_DIR/settings"

# 1) First-time copy do Plank config do /etc/skel (+ launchers/.dockitem)
if [ ! -d "$HOME/.config/plank" ] && [ -d /etc/skel/.config/plank ]; then
    mkdir -p "$HOME/.config"
    cp -r /etc/skel/.config/plank "$HOME/.config/"
fi

# 2) Re-injetar 'tmjos-show-apps.dockitem' como primeiro item se faltar
if [ -f "$PLANK_SETTINGS" ]; then
    if ! grep -q "tmjos-show-apps.dockitem" "$PLANK_SETTINGS"; then
        sed -i "s|^dock-items=\[|dock-items=['tmjos-show-apps.dockitem', |" \
            "$PLANK_SETTINGS"
    fi
fi

# 2b) Garante que TODOS os .dockitem necessários existem em launchers/.
# Se algum estiver faltando (config inconsistente entre versões), copia
# do /etc/skel pra evitar Plank vazio.
LAUNCHERS_DIR="$PLANK_DIR/launchers"
if [ -d "$LAUNCHERS_DIR" ] && [ -d /etc/skel/.config/plank/dock1/launchers ]; then
    for src in /etc/skel/.config/plank/dock1/launchers/*.dockitem; do
        [ -f "$src" ] || continue
        dest="$LAUNCHERS_DIR/$(basename "$src")"
        [ ! -f "$dest" ] && cp "$src" "$dest"
    done
fi

# 3) SLIM PLUS — Disable tracker3 (indexação de arquivos pesa ~300MB RAM
# e queima disco em background). Mascarar via systemctl --user faz só
# pro usuário atual, sem afetar root ou multi-user.
systemctl --user mask \
    tracker-extract-3.service \
    tracker-miner-fs-3.service \
    tracker-miner-rss-3.service \
    tracker-writeback-3.service \
    tracker-xdg-portal-3.service \
    >/dev/null 2>&1 || true
systemctl --user stop \
    tracker-extract-3.service \
    tracker-miner-fs-3.service \
    tracker-miner-rss-3.service \
    >/dev/null 2>&1 || true

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

# 6i.2) Release notes URL — Ubuntu hardcoda
# http://www.ubuntu.com/getubuntu/releasenotes?os=ubuntu&ver=24.04.4&lang=${LANG}
# em vários arquivos (boot menus, GRUB cfg, casper, .disk/release_notes_url).
# Substitui por URL pública do CHANGELOG/Release do TMJOs.
echo -e "  ${GREEN}→${NC} Release notes URL → CHANGELOG TMJOs"
TMJOS_RELEASE_URL="https://github.com/TMJacometti/TMJOs/blob/main/CHANGELOG.md"

# Procura em /etc, /usr/share, /usr/lib, /cdrom, /isolinux, /boot
# por strings tipo 'ubuntu.com/getubuntu/releasenotes' e troca pela URL TMJOs.
# IMPORTANTE: grep retornar 0 matches sai com exit 1, e combinado com
# set -o pipefail mata o script. Por isso `|| true` em cada chamada.
SEARCH_DIRS=(/etc /usr/share /usr/lib /cdrom /isolinux /boot)
for d in "${SEARCH_DIRS[@]}"; do
    [ -d "$d" ] || continue
    files=$($SUDO grep -rlI "ubuntu.com/getubuntu/releasenotes" "$d" 2>/dev/null || true)
    [ -z "$files" ] && continue
    while IFS= read -r f; do
        if $SUDO sed -i \
            "s|http[s]\?://www\.ubuntu\.com/getubuntu/releasenotes[^\"' )]*|$TMJOS_RELEASE_URL|g" \
            "$f" 2>/dev/null; then
            echo "    rewrote $f"
        fi
    done <<< "$files"
done

# .disk/release_notes_url (texto puro com URL) — algumas vezes o Cubic
# regenera, mas se existir no chroot, atualizamos.
for f in /cdrom/.disk/release_notes_url /.disk/release_notes_url; do
    if [ -f "$f" ]; then
        echo "$TMJOS_RELEASE_URL" | $SUDO tee "$f" > /dev/null
        echo "    rewrote $f"
    fi
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

# Plymouth — instala tema TMJOs custom (logo + breathing animation).
# Precisa fazer 3 coisas separadamente porque `plymouth-set-default-theme -R`
# falha silenciosamente no chroot do Cubic (a flag -R chama
# update-initramfs que precisa de /proc, /sys mounts).
echo -e "  ${GREEN}→${NC} Plymouth tema TMJOs (logo no boot splash)"
$SUDO mkdir -p /usr/share/plymouth/themes/tmjos
$SUDO cp -r "$TMJOS_SRC"/assets/plymouth/tmjos/. /usr/share/plymouth/themes/tmjos/

# 1) Set the theme via update-alternatives — funciona em chroot
$SUDO update-alternatives --install \
    /usr/share/plymouth/themes/default.plymouth default.plymouth \
    /usr/share/plymouth/themes/tmjos/tmjos.plymouth 200 2>/dev/null || true
$SUDO update-alternatives --set default.plymouth \
    /usr/share/plymouth/themes/tmjos/tmjos.plymouth 2>/dev/null || true

# Verifica que o symlink ficou apontando certo
if [ -L /etc/alternatives/default.plymouth ]; then
    target=$($SUDO readlink /etc/alternatives/default.plymouth)
    echo -e "    default.plymouth → $target"
fi

# 2) Garantir que arquivos do tema têm permissão correta
$SUDO chmod -R a+rX /usr/share/plymouth/themes/tmjos

# 3) Regenerate initramfs verbosely. Cubic mounts /proc /sys /dev no chroot.
echo -e "    regenerating initramfs (verbose)..."
$SUDO update-initramfs -u -k all 2>&1 | sed 's/^/    [initramfs] /' || true

# 4) Sanity check: o tema tmjos chegou no initrd?
echo -e "    verifying initramfs contains tmjos theme..."
INITRD_PATH=$(find /boot -maxdepth 1 -name 'initrd.img-*' -print -quit 2>/dev/null)
if [ -n "$INITRD_PATH" ] && command -v lsinitramfs >/dev/null 2>&1; then
    if $SUDO lsinitramfs "$INITRD_PATH" 2>/dev/null | grep -q "plymouth/themes/tmjos"; then
        echo -e "    ${GREEN}✓ tmjos theme found in $(basename "$INITRD_PATH")${NC}"
    else
        echo -e "    ${RED}✗ tmjos theme NOT in initrd — Plymouth will fall back to Ubuntu!${NC}"
        echo -e "    ${YELLOW}contents of $INITRD_PATH (plymouth section):${NC}"
        $SUDO lsinitramfs "$INITRD_PATH" 2>/dev/null | grep -i plymouth | sed 's/^/      /' || echo "      (no plymouth files)"
    fi
fi

# update-grub já foi rodado na seção GRUB acima (linha ~373), não duplicar.

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
check_file "Plymouth theme dir" "/usr/share/plymouth/themes/tmjos/tmjos.plymouth"
check_file "Plymouth logo" "/usr/share/plymouth/themes/tmjos/logo.png"
check_file "/etc/os-release TMJOs" "/etc/os-release"
check_file "Plank autostart" "/etc/xdg/autostart/plank.desktop"
check_file "dconf defaults" "/etc/dconf/db/local.d/00-tmjos-defaults"
check_file "TMJPad code" "/opt/tmjpad/tmjpad/app.py"
check_file "TMJPad wrapper" "/usr/local/bin/tmjpad"
check_file "TMJPad .desktop" "/usr/share/applications/tmjpad.desktop"

# Confirma identidade TMJOs em os-release
if grep -q '^NAME="TMJOs"' /etc/os-release; then
    echo -e "  ${GREEN}✓${NC} /etc/os-release identidade: TMJOs (visual)"
else
    echo -e "  ${RED}✗${NC} /etc/os-release identidade: ainda Ubuntu (algo deu errado)"
fi
# Confirma que lsb-release ficou Ubuntu (compat scripts)
if grep -q '^DISTRIB_CODENAME=noble' /etc/lsb-release; then
    echo -e "  ${GREEN}✓${NC} /etc/lsb-release codename: noble (compat scripts/PPAs)"
else
    echo -e "  ${RED}✗${NC} /etc/lsb-release codename: NÃO é noble — PPAs vão quebrar"
fi

# Limpeza
echo -e "\n${YELLOW}Limpando temp + caches...${NC}"
$SUDO rm -rf "$TMJOS_SRC"
$SUDO apt clean
$SUDO apt autoclean -y
$SUDO rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
$SUDO rm -rf /var/lib/apt/lists/* 2>/dev/null || true

echo -e "\n${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      ✓ TMJOs v1.2 customização completa!  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Próximos passos:${NC}"
echo -e "  1. Volte ao Cubic GUI"
echo -e "  2. Clique Next nas telas seguintes (Kernels, Compression)"
echo -e "  3. Generate ISO (~20-40 min com xz)"
echo -e "  4. Teste em VM com qemu-system-x86_64 -m 4G -smp 4 ...\n"

echo -e "${GREEN}TMJOs pronto pra gerar a ISO!${NC}\n"
