# 🐉 TMJOs — Guia de Build (v2.0+ Debian 13)

## 📋 Visão Geral
- **Nome**: TMJOs
- **Base**: Debian 13 (trixie)
- **Desktop**: GNOME
- **Installer**: Calamares
- **Apps**: stack TMJOs (TMJMenu, TMJDock, TMJPad, TMJStore) + VSCode, Git, Docker
- **Ferramenta de build**: `live-build` (Debian official)
- **Saída**: ISO LiveUSB híbrida (~3-4GB target)

> Em v1.x usávamos Cubic + Ubuntu 24.04. Migramos pra Debian em v2.0 — Cubic só roda em base Ubuntu, então o flow de build mudou completamente.

---

## 🛠️ FASE 1 — PREPARAÇÃO DO HOST

### Passo 1.1: Instalar dependências

Host pode ser Debian 12+, Ubuntu 24.04+, ou qualquer derivada que tenha `live-build` (>= 1:20230502) nos repos.

```bash
sudo apt update
sudo apt install -y \
    live-build \
    debootstrap \
    xorriso \
    squashfs-tools \
    debian-archive-keyring \
    git
```

### Passo 1.2: Preparar espaço

```bash
# Mínimo 30GB livre no $HOME
df -h ~

# Cria o build dir (NÃO dentro do repo do TMJOs)
mkdir -p ~/tmjos-debian-build
cd ~/tmjos-debian-build
```

> Importante: `lb config` precisa de um diretório dedicado. Não roda dentro do clone do TMJOs — o repo tem só os *scripts* que populam o diretório de build.

---

## 🎨 FASE 2 — `lb config` (esqueleto live-build)

### Passo 2.1: Bootstrap config Debian

```bash
cd ~/tmjos-debian-build

sudo lb config \
    --distribution trixie \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --mirror-bootstrap http://deb.debian.org/debian/ \
    --mirror-chroot http://deb.debian.org/debian/ \
    --mirror-binary http://deb.debian.org/debian/ \
    --parent-mirror-bootstrap http://deb.debian.org/debian/ \
    --security false \
    --apt-recommends true \
    --debian-installer false
```

Isso cria `~/tmjos-debian-build/config/` com a estrutura base do live-build.

### Passo 2.2: Validar mirrors

```bash
# Deve mostrar os mirrors Debian ativos; valores ativos com archive.ubuntu
# ou trixie/updates não podem aparecer.
grep -r '^LB_.*deb.debian.org' config/
grep -r '^LB_.*archive.ubuntu\|trixie/updates' config/ || true
```

---

## 📦 FASE 3 — POPULAR CONFIG COM TMJOS

### Passo 3.1: Rodar o setup script do TMJOs

```bash
# Caminho pro clone do repo TMJOs (substitua pelo seu)
TMJOS_REPO=~/Projetos/GitHub/TMJOs

sudo "$TMJOS_REPO/tools/tmjos-live-build-setup.sh"
```

O script popula:

| Diretório | Conteúdo |
|---|---|
| `config/hooks/0100-tmjos-debian-base.chroot_early` | Instala a base Debian main sem usar package-list |
| `config/hooks/normal/0500-tmjos-apt-install.hook.chroot` | Adiciona repos TMJOs/Microsoft e instala `tmjos code` |
| `config/hooks/normal/` | Hooks pós-install (slim, icon-cache, desktop-database) |

### Passo 3.2: Conferir o que foi setado

```bash
ls -la config/package-lists/
ls -la config/hooks/
ls -la config/hooks/normal/

# Não deve ter lista .chroot: evitamos lb_chroot_package-lists.
find config/package-lists -type f
```

---

## 🏗️ FASE 4 — BUILD DA ISO

### Passo 4.1: `lb build`

```bash
cd ~/tmjos-debian-build
sudo lb build 2>&1 | tee build.log
```

Esperado: ~30-60min em hardware moderno (i5/16GB/SSD). Build phases:

1. **bootstrap** — debootstrap Debian trixie base (~5min)
2. **chroot** — entra no chroot, adiciona repos extras, instala packages (~15-30min)
3. **binary** — gera squashfs + ISO híbrida + EFI (~5-10min)

### Passo 4.2: Verificar ISO

```bash
ls -lh ~/tmjos-debian-build/*.iso

# Hash pra validação posterior
sha256sum ~/tmjos-debian-build/*.iso > tmjos.iso.sha256
```

---

## 🧪 FASE 5 — TESTAR EM VM

### Opção A — virt-manager (recomendado)

```bash
sudo apt install -y virt-manager libvirt-daemon-system qemu-kvm

virt-manager
# New VM → Local install media → aponta pra ~/tmjos-debian-build/live-image-amd64.hybrid.iso
# Memória: 4GB · CPUs: 2 · Disco: 30GB · Display: virtio-gpu (pra 3D)
```

### Opção B — QEMU CLI

```bash
qemu-system-x86_64 \
    -m 4G \
    -smp 4 \
    -accel kvm \
    -cdrom ~/tmjos-debian-build/live-image-amd64.hybrid.iso \
    -boot d
```

### Checklist de teste

- [ ] Boot via GRUB → live session carrega
- [ ] GDM aparece (sem login necessário em live)
- [ ] GNOME desktop com wallpaper TMJOs
- [ ] TMJMenu abre via Super+Space
- [ ] TMJDock visível no bottom (bottom-center)
- [ ] TMJPad abre e persiste sessão
- [ ] TMJStore lista os apps TMJOs
- [ ] Calamares (ícone "Install TMJOs" no desktop) abre
- [ ] Instalação completa sem erro

---

## 💾 FASE 6 — LIVEUSB (deploy final)

```bash
# Identificar pen drive (NÃO confundir com disco interno)
lsblk

# Gravar (substituir sdX)
sudo umount /dev/sdX*
sudo dd if=~/tmjos-debian-build/live-image-amd64.hybrid.iso \
    of=/dev/sdX bs=4M status=progress conv=fsync
sync
sudo eject /dev/sdX
```

---

## 🔧 TROUBLESHOOTING

| Problema | Solução |
|---|---|
| `lb config` puxa mirrors errados | Verificar host: `lb config` em host Ubuntu usa Ubuntu mirrors por default. Sempre passar `--mirror-*` explícito |
| `debian-archive-keyring missing` | `sudo apt install -y debian-archive-keyring` no host |
| Hook falha no chroot | Ver `build.log`; hooks rodam como root em ambiente chroot — usar `/bin/sh` portable |
| ISO não boota EFI | Conferir que xorriso gerou ISO híbrida (`iso-hybrid` no `lb config`) |
| Pacote `tmjos` não encontrado | APT repo TMJOs (trixie) precisa estar populado. Conferir [packages.tmjos.com.br/dists/trixie](https://packages.tmjos.com.br) |

---

## 📚 Recursos

- [live-build manual](https://live-team.pages.debian.net/live-manual/html/live-manual/index.en.html)
- [Debian trixie release notes](https://www.debian.org/releases/trixie/)
- [Calamares docs](https://calamares.io/docs/)
