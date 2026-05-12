# 🐉 TMJOs Linux Distribution

> **OS DA TMJSistemas · OS MELHORES · OS INSANOS**
>
> Distribuição Linux baseada em **Debian 13 trixie** pra devs hardcore — slim, dark, neon, com stack proprietária de apps GTK4 nativos.

> ⚠️ **Status: v2.0 alpha** — em uso pessoal do dev. Launch oficial vai sair quando v2.0 estabilizar. Estável o suficiente pra usar, mas sem promessa de polish ou suporte público enquanto alpha.
>
> ℹ️ **Histórico**: v1.x era baseado em Ubuntu 24.04 (noble) — foi preview interno, nunca released publicamente. v2.0+ é rebase em Debian 13 (trixie) sem Canonical, sem snap, sem ubiquity.

![Version](https://img.shields.io/badge/version-2.0--alpha-cyan)
![License](https://img.shields.io/badge/license-GPLv3-green)
![Base](https://img.shields.io/badge/based%20on-Debian%2013%20trixie-red)
![APT](https://img.shields.io/badge/APT%20repo-packages.tmjos.com.br-blueviolet)

---

## ✨ O que é TMJOs?

TMJOs é uma distribuição Linux com **identidade visual neon TMJOs** (cyan/magenta), **stack proprietária de apps GTK4 nativos**, e **APT repo oficial** pra updates contínuos sem regen de ISO.

Codename: **insano**.

### 🎯 Características

- **🐉 Identidade própria**: branding completo (wallpaper TMJOs, Plymouth, logo dragão+gear, dark mode, paleta neon)
- **📦 APT repo oficial**: [packages.tmjos.com.br](https://packages.tmjos.com.br) com Let's Encrypt. `sudo apt upgrade tmjos` atualiza todo o core sem ISO nova
- **🏪 TMJStore**: software center proprietário descobre apps TMJOs via AppStream, instala via apt+pkexec, com visual neon
- **🚀 TMJMenu + TMJDock**: launcher GTK4 nativo. Popup search (Super+Space) + dock bottom-center estilo Win11 Start com botão TMJOs gradient cyan/magenta. Auto-hide adaptativo, Super+Shift+H toggle pinned
- **📝 TMJPad**: editor de texto com **persistência total** de sessão — fechou e reabriu, todas abas voltam (incluindo não salvas)
- **🧰 Calamares installer**: instalador gráfico Debian-native (sem ubiquity, sem WebKit2 baggage)
- **💻 Pré-instalado pra devs**: VSCode, Docker, Git, GNOME Tweaks, JetBrains Mono
- **🆓 Zero Canonical**: sem snapd, sem unattended-upgrades, sem telemetria Ubuntu

---

## 🚀 Quick Start

### Adicionar TMJOs APT repo num Debian 13 (trixie) existente

```bash
# 1. Adiciona o repo TMJOs
curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/tmjos-archive-keyring.gpg > /dev/null

echo 'deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br trixie main apps' \
  | sudo tee /etc/apt/sources.list.d/tmjos.list > /dev/null

# 2. Update + install
sudo apt update
sudo apt install -y tmjos
```

Reboot pra Plymouth + GDM pegarem. Pronto.

### Instalar ISO oficial

Baixa do [latest release](https://github.com/TMJacometti/TMJOs/releases/latest) — `tmjos-X.Y.Z-amd64.iso` (hospedada no Cloudflare R2).

```bash
# Criar LiveUSB
sudo dd if=tmjos-*.iso of=/dev/sdX bs=4M status=progress && sync

# Boot pela USB → sessão live → clicar no installer (Calamares)
```

### Updates contínuos (sem re-instalar)

```bash
sudo apt update && sudo apt upgrade tmjos
```

Killer feature do TMJOs: atualiza TODO o core (branding, identity, defaults, TMJMenu, TMJDock, TMJPad, TMJStore) via apt. Sem regen de ISO.

---

## 📦 O que vem instalado

### Core TMJOs (meta `tmjos`)

| Pacote | Função |
|---|---|
| `tmjos-branding` | Wallpapers, logos, Plymouth boot splash |
| `tmjos-os-identity` | `/etc/os-release`, `/etc/lsb-release` (dpkg-divert) |
| `tmjos-defaults` | dconf overrides (dark mode, fonts, slim runtime mask) |
| `tmjmenu` | TMJMenu popup + TMJDock |
| `tmjpad` | Editor de texto com session persistence |
| `tmjstore` *(Recommends)* | Software center proprietário TMJOs |

### Stack de dev (Recommends)

- VSCode (do repo oficial Microsoft), Git, git-flow, Docker + compose
- GNOME Tweaks, dconf-editor
- Python 3 + GTK4 + libadwaita
- Calamares (installer gráfico)
- Fontes: JetBrains Mono, Cantarell
- CLI: curl, wget, htop, neofetch, vim

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
# Software (host Debian 12+ ou derivada):
sudo apt install -y live-build debootstrap xorriso \
    debian-archive-keyring squashfs-tools
```

### Build process

```bash
# 1. Clone
git clone https://github.com/TMJacometti/TMJOs.git
cd TMJOs

# 2. Prepara build dir + roda lb config (mirrors Debian)
mkdir -p ~/tmjos-debian-build
cd ~/tmjos-debian-build
sudo lb config \
    --distribution trixie \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --mirror-bootstrap http://deb.debian.org/debian/ \
    --mirror-chroot http://deb.debian.org/debian/ \
    --mirror-binary http://deb.debian.org/debian/ \
    --parent-mirror-bootstrap http://deb.debian.org/debian/ \
    --apt-recommends true

# 3. Popula config/ com archives/hooks/package-lists TMJOs
sudo /caminho/pra/TMJOs/tools/tmjos-live-build-setup.sh

# 4. Build
sudo lb build 2>&1 | tee build.log

# ISO sai em ~/tmjos-debian-build/*.iso (~30-60min)
```

Detalhes em [`docs/BUILD.md`](docs/BUILD.md).

---

## 📚 Documentação

- **[CHANGELOG.md](CHANGELOG.md)** — Histórico + backlog detalhado
- **[docs/BUILD.md](docs/BUILD.md)** — Guia de build via live-build
- **[docs/CHECKLIST.md](docs/CHECKLIST.md)** — Checklist de release
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

- **MAJOR** (1.x → 2.x): rebase de distro base, mudança de stack significativa
- **MINOR** (2.0 → 2.1): mudança UX/feature substancial **do core da distro** (não apps)
- **PATCH** (2.0.0 → 2.0.1): bug fixes, point releases

**Apps TMJOs** (TMJPad, TMJMenu, TMJStore, TMJCode, TMJNotes, TMJMoney, TMJCriptoBot, TMJRestApi) têm versionamento **independente**. Lançam como `.deb` no APT repo a qualquer momento — não exigem bump da distro.

---

## 📋 Roadmap

### 🚧 v2.0 alpha (atual) — Migração pra Debian 13

- [x] Rebase de Ubuntu 24.04 → **Debian 13 trixie**
- [x] APT repo suite `trixie` no [packages.tmjos.com.br](https://packages.tmjos.com.br)
- [x] Script de customização `tmjos_customize.sh` para chroot Debian
- [x] Setup pra `live-build` (substitui Cubic Ubuntu-only)
- [ ] Primeira ISO alpha gerada + testada em virt-manager
- [ ] Calamares branding básico (tmjos-calamares-branding package)

### 🔜 v2.0 stable

- [ ] **Calamares branding completo**: slideshow QML, partition assets, logo full
- [ ] **TMJDock Wayland-native** via gtk4-layer-shell (sem X11 force)
- [ ] **APT components**: separar `main` / `apps` / `extras` (granularidade)
- [ ] **ISO size target**: 2-3GB

### 🌟 Apps independentes (durante v2.0.x, sem bump da distro)

- [ ] **TMJNotes** — sticky notes GTK4 com persistência total
- [ ] **TMJMoney** — controle financeiro pessoal
- [ ] **TMJRestApi** — REST client tipo Postman, GTK4
- [ ] **TMJCriptoBot** — bot de trading cripto (educacional)
- [ ] **TMJCode** — VSCode customizado com tema/extensões TMJOs
- [ ] **TMJStore v0.2**: DEP-11 no APT repo + update check daemon + search + filtro categoria
- [ ] **TMJStore v0.3**: reviews + botão Donate por dev

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

- **Debian Project** — base da distribuição
- **GNOME Project** — desktop environment
- **Calamares** — installer
- **TMJSistemas** — branding, design, dev
- **Contribuidores** — ❤️

---

*TMJOs v2.0 alpha · Debian 13 trixie · Made with 🐉 by TMJSistemas*
