Pré-requisitos verificáveis (roda os 3 primeiros pra confirmar ambiente):


# Confere que tá em Debian 13 trixie
cat /etc/os-release | grep -E 'NAME|VERSION'

# Versão do live-build (Debian deve ter upstream moderna, tipo 1:20230502)
dpkg-query -W -f='${Version}\n' live-build 2>/dev/null || echo "instala via apt"

# Espaço em disco (precisa 30GB+ livres em $HOME)
df -h ~
Setup do build (instala deps + clona repo):


# 1. Deps de build
sudo apt update && sudo apt install -y \
    live-build debootstrap xorriso squashfs-tools \
    debian-archive-keyring syslinux-utils isolinux \
    git tmux curl

# 2. SSH key — se já tinha em ~/.ssh, testa
ssh -T git@github.com   # esperado: "Hi TMJacometti!"

# 3. Clone via SSH (ou HTTPS se não configurou SSH)
mkdir -p ~/Projetos/GitHub && cd ~/Projetos/GitHub
git clone git@github.com:TMJacometti/TMJOs.git
cd TMJOs

# 4. Confere que pegou o último commit (a01d3d7)
git log --oneline -3
Build:


sudo ./tools/tmjos-build.sh

# Acompanha (socket compartilhado, sem precisar de sudo)
tmux -S /tmp/tmux-tmjos.sock attach -t tmjos-build
Saída esperada (Debian host = setup limpo):

Pre-flight passa (live-build, tmux, etc detectados)
lb config gera config Debian sem nenhum sed corretivo precisar agir (no-op)
"✓ Sem vazamentos ativos"
Hook 0100 instala GNOME minimal sem travas
Hook 0500 instala tmjos + code do APT repo
lb_binary_grub-efi empacota EFI corretamente (agora suportado em live-build upstream)
ISO sai em ~/tmjos-debian-build/live-image-amd64.hybrid.iso
