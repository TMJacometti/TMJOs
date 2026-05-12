# 🐉 TMJOs Linux Distribution

> **OS DA TMJSistemas · OS MELHORES · OS INSANOS**
>
> Distribuição Linux baseada em Ubuntu 24.04 LTS pra devs hardcore — slim, dark, neon, com stack proprietária de apps.

> ⚠️ **Status: Preview interno (v1.x)** — em uso pessoal do dev. Launch oficial vai sair com **v2.0** (rebase em Debian 13 trixie, ~Q3 2026). Estável o suficiente pra usar, mas sem promessa de polish ou suporte público enquanto v1.x.

![Version](https://img.shields.io/badge/version-1.3.4-cyan)
![License](https://img.shields.io/badge/license-GPLv3-green)
![Base](https://img.shields.io/badge/based%20on-Ubuntu%2024.04%20LTS-orange)
![APT](https://img.shields.io/badge/APT%20repo-packages.tmjos.com.br-blueviolet)

---

## ✨ O que é TMJOs?

TMJOs é uma distribuição Linux com **identidade visual neon TMJOs** (cyan/magenta), **stack proprietária de apps GTK4 nativos**, e **APT repo oficial** pra updates contínuos sem regen de ISO.

Codename: **insano**.

### 🎯 Características

- **🐉 Identidade própria**: branding completo (wallpaper TMJOs, Plymouth, logo dragão+gear, dark mode, paleta neon)
- **📦 APT repo oficial**: [packages.tmjos.com.br](https://packages.tmjos.com.br) com Let's Encrypt. `sudo apt upgrade tmjos` atualiza todo o core sem ISO nova
- **🏪 TMJStore**: software center proprietário descobre apps TMJOs via AppStream, instala via apt+pkexec, com visual neon (sem capitalismo Ubuntu)
- **🚀 TMJMenu + TMJDock**: launcher GTK4 nativo. Popup search (Super+Space) + dock bottom-center estilo Win11 Start com botão TMJOs gradient cyan/magenta. Auto-hide adaptativo, Super+Shift+H toggle pinned
- **📝 TMJPad**: editor de texto com **persistência total** de sessão — fechou e reabriu, todas abas voltam (incluindo não salvas)
- **⚡ Slim Aggressive**: RAM idle ~700MB. Remove snapd, evolution, thunderbird, gnome-software, telemetria. Mascarado plymouth-quit-wait + unattended-upgrades pra zero travas
- **💻 Pré-instalado pra devs**: VSCode, Docker, Git, Plank, GNOME Tweaks, JetBrains Mono
- **🔧 X11 forçado**: sessão GDM em X11 (Wayland fica pra v2.0 com TMJDock layer-shell)

---

## 🚀 Quick Start

### Instalar TMJOs em sistema Ubuntu 24.04 existente

```bash
# 1. Adiciona o repo TMJOs
curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/tmjos-archive-keyring.gpg > /dev/null

echo 'deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br/ noble main' \
  | sudo tee /etc/apt/sources.list.d/tmjos.list > /dev/null

# 2. Update + install
sudo apt update
sudo apt install -y tmjos
```

Reboot pra Plymouth + sessão X11 pegarem. Pronto.

### Instalar ISO oficial

Baixa do [latest release](https://github.com/TMJacometti/TMJOs/releases/latest) — `tmjos-X.Y.Z-amd64.iso` (hospedada no Cloudflare R2).

```bash
# Criar LiveUSB
sudo dd if=tmjos-*.iso of=/dev/sdX bs=4M status=progress && sync

# Boot pela USB, sessão live carrega, clicar no installer (Ubiquity)
```

### Updates contínuos (sem re-instalar)

```bash
sudo apt update && sudo apt upgrade tmjos
```

Killer feature da v1.3: atualiza TODO o core (branding, dock, identity, shell tweaks, installer, TMJPad, TMJMenu) via apt. Sem regen de ISO.

---

## 📦 O que vem instalado

### Core TMJOs (meta `tmjos`)

| Pacote | Função |
|---|---|
| `tmjos-branding` | Wallpapers, logos, Plymouth boot splash |
| `tmjos-os-identity` | `/etc/os-release`, `/etc/lsb-release` (dpkg-divert) |
| `tmjos-defaults` | dconf overrides (dark mode, fonts, X11 force, slim runtime mask) |
| `tmjos-shell-tweaks` | Activities button escondido via GJS extension |
| `tmjos-installer` | ubiquity sem WebKit2 slideshow + imagem "Installation complete" TMJOs |
| `tmjos-dock` | Plank config legacy + scripts (mantido como fallback) |
| `tmjmenu` | TMJMenu popup + TMJDock |
| `tmjpad` | Editor de texto com session persistence |
| `tmjstore` *(Recommends)* | Software center proprietário TMJOs |

### Stack de dev (Recommends)

- VSCode (do repo oficial Microsoft), Git, git-flow, Docker + compose
- GNOME Tweaks, dconf-editor, gnome-shell-extensions
- Python 3 + GTK4 + libadwaita
- spice-vdagent + qemu-guest-agent (VM integration)
- zram-config + preload (RAM efficiency)
- Fontes: JetBrains Mono, Cantarell, Noto Color Emoji
- CLI: curl, htop, neofetch, vim, dnsutils, net-tools, traceroute

---

## 📸 Layout visual

```
┌────────────────────────────────────────────────────────┐
│ TMJOs ▼                            🕐 🔊 🔋 (top bar) │
├────────────────────────────────────────────────────────┤
│                                                        │
│         [Wallpaper TMJOs — dragão + gear neon]        │
│                                                        │
│                                                        │
│           ┌──────────────────────────────┐             │
│           │ ⬢TMJ  ⊞  │ VSC Term Files Pad│  ← TMJDock │
│           └──────────────────────────────┘             │
└────────────────────────────────────────────────────────┘
```

- **Super+Space** abre o **TMJMenu** (popup search)
- **Super+Shift+H** fixa/desafixa dock (badge cyan glow quando fixed)
- Click no **botão TMJOs** central → abre TMJMenu
- Click no **botão Show apps** (⊞) → Activities Overview do GNOME (apps grid completo)

---

## 🛠️ Build da ISO do zero

### Pré-requisitos

```bash
# Hardware: 30GB disco, 4GB RAM
# Software:
sudo add-apt-repository ppa:cubic-wizard/release
sudo apt update && sudo apt install -y cubic
```

### Build process

```bash
# 1. Clone
git clone https://github.com/TMJacometti/TMJOs.git
cd TMJOs

# 2. Cubic — novo projeto
cubic
# Project dir: ~/tmjos-build/projects
# Source ISO: ubuntu-24.04.*-desktop-amd64.iso

# 3. Na page Terminal (chroot) do Cubic, baixa o customize.sh
wget -O /tmp/customize.sh https://raw.githubusercontent.com/TMJacometti/TMJOs/main/scripts/tmjos_customize.sh
bash /tmp/customize.sh

# 4. Cubic Next > Next > Generate ISO

# 5. Testar em VM (recomendado: virt-manager com virtio-gpu-gl pra 3D)
virt-manager
```

O `tmjos_customize.sh` faz 6 fases:
1. apt update + upgrade
2. Slim aggressive (remove ~25 pacotes desnecessários)
3. Adiciona repo VSCode (Microsoft)
4. Adiciona repo TMJOs (`packages.tmjos.com.br`)
5. `apt install tmjos` (puxa todos os componentes + Recommends)
6. Upgrade final (pacotes recém-instalados)

---

## 📚 Documentação

- **[CHANGELOG.md](CHANGELOG.md)** — Histórico + backlog detalhado
- **[apps/tmjpad/README.md](apps/tmjpad/README.md)** — TMJPad
- **[apps/tmjmenu/README.md](apps/tmjmenu/README.md)** — TMJMenu/TMJDock
- **[apps/tmjstore/README.md](apps/tmjstore/README.md)** — TMJStore
- **[packages/README.md](packages/README.md)** — APT repo + .deb sources

---

## 🤝 Como Contribuir

```bash
git clone https://github.com/SEU_FORK/TMJOs.git
cd TMJOs
git checkout -b feature/sua-feature
# ...code...
git commit -m "feat: sua mudança"
git push origin feature/sua-feature
# Abre PR
```

### Política de versionamento

- **MAJOR** (1.x → 2.x): rebase de Ubuntu base, mudança de stack significativa
- **MINOR** (1.3 → 1.4): mudança UX/feature substancial **do core da distro** (não apps)
- **PATCH** (1.3.0 → 1.3.4): bug fixes, point releases

**Apps TMJOs** (TMJPad, TMJMenu, TMJStore, TMJCode, TMJNotes) têm versionamento **independente**. Lançam como `.deb` no APT repo a qualquer momento — não exigem bump da distro.

---

## 📋 Roadmap

### ✅ v1.3 — APT repo + apps proprietários

- [x] **APT repo oficial** `packages.tmjos.com.br` (Let's Encrypt, GH Pages, GH Actions CI)
- [x] **9 pacotes Debian assinados** (GPG)
- [x] **Killer feature**: `sudo apt upgrade tmjos` atualiza core sem ISO nova
- [x] **Custom domain** com cert auto-renewed
- [x] **TMJMenu + TMJDock**: launcher proprietário GTK4 nativo (Super+Space, auto-hide, pin/unpin, context menu, Super+Shift+H)
- [x] **TMJStore**: software center com 3 abas + AppStream + detail view + cache + busy feedback verde + toast
- [x] **TMJPad** repackaged como `.deb` (com session persistence)
- [x] **Plymouth boot splash** + watermark TMJSistemas
- [x] **Slim Aggressive**: RAM idle ~700MB, mascarado plymouth-quit-wait + unattended-upgrades + packagekit
- [x] **Ubiquity branding**: imagem "Installation complete" TMJOs (dpkg-divert)
- [x] **VM detection**: auto-hide adaptativo via systemd-detect-virt

### 🔜 Apps independentes (durante v1.3.x, sem bump da distro)

- [ ] **TMJCode** — VSCode customizado com tema/extensões TMJOs
- [ ] **TMJNotes** — sticky notes GTK4 com persistência total
- [ ] **TMJStore v0.2**: DEP-11 no APT repo + update check daemon + search + filtro categoria
- [ ] **TMJStore v0.3**: reviews + botão Donate por dev

### 🚀 v2.0 "Insano 2" (futuro)

- [ ] Rebase em **Ubuntu 26.04 LTS** (suporte até 2031)
- [ ] **Wayland-native** com TMJDock via gtk4-layer-shell (sem X11 force)
- [ ] **APT repo components**: `noble main apps extras` + `noble-dev` testing suite
- [ ] **Reduzir ISO** (atual 6GB → target 2-3GB via single-squashfs no 26.04)
- [ ] **TMJOs slideshow** próprio no installer (substitui Ubuntu marketing)
- [ ] GRUB visual theme TMJOs (não só nome)
- [ ] GDM login screen com wallpaper TMJOs

---

## 🐛 Bug Reports

Abra [issue no GitHub](https://github.com/TMJacometti/TMJOs/issues).

---

## 📝 Licença

GPLv3. Ver [LICENSE](LICENSE).

```
TMJOs - OS DA TMJSistemas · OS MELHORES · OS INSANOS
Copyright (C) 2026 TMJOs Contributors
```

---

## 🌟 Créditos

- **Ubuntu Team** — base da distribuição
- **GNOME Project** — desktop environment
- **TMJSistemas** — branding, design, dev
- **Contribuidores** — ❤️

---

*Last updated: 2026-05-11 · TMJOs v1.3.4 · Made with 🐉 by TMJSistemas*
