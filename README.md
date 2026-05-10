# 🐧 TMJOs Linux Distribution

> **Clean • Minimal • Beautiful** — A customized Ubuntu-based Linux distribution designed for developers.

![TMJOs](https://img.shields.io/badge/version-1.1-blue)
![License](https://img.shields.io/badge/license-GPLv3-green)
![Ubuntu](https://img.shields.io/badge/based%20on-Ubuntu%2024.04%20LTS-orange)
![GNOME](https://img.shields.io/badge/desktop-GNOME-blue)

---

## ✨ O que é TMJOs?

TMJOs é uma distribuição Linux customizada baseada em **Ubuntu 24.04 LTS**, com foco em **minimalismo, beleza e produtividade** para desenvolvedores.

### 🎯 Características Principais

- **🎨 Interface Limpa**: GNOME desktop customizado, sem bloat
- **🍎 Dock estilo Mac**: Plank dock na barra inferior (tipo macOS)
- **💻 Pronto para Código**: VSCode, Git e Docker pré-instalados
- **📝 TMJPad**: editor de texto nativo com persistência total — fechou e reabriu, suas abas voltam exatamente como estavam
- **🐉 Identidade Própria**: branding completo (wallpapers, logo, dark mode, identidade do sistema em `/etc/os-release`)
- **⚡ Slim & Rápido**: ~3GB ISO, boot rápido
- **🔧 Desenvolvedor-Friendly**: Otimizado para devs
- **❤️ Open Source**: Totalmente gratuito e comunidade-driven

---

## 🚀 Quick Start

### Download & Install

```bash
# 1. Baixar ISO
wget https://github.com/tmjacometti/tmjos/releases/download/v1.1/tmjos-1.1-amd64.iso

# 2. Criar LiveUSB
sudo dd if=tmjos-1.1-amd64.iso of=/dev/sdX bs=4M status=progress && sync

# 3. Botar pela pen e instalar
# Seguir o installer padrão do Ubuntu
```

### Primeira Inicialização

```bash
# Atualizar sistema (primeira vez)
sudo apt update && sudo apt upgrade

# Verificar apps instalados
code --version     # VSCode
git --version      # Git
docker --version   # Docker
```

---

## 📸 Visual Preview

```
┌──────────────────────────────────────────────────────┐
│  Activities │ TMJOs ~    │     🕐 │ 🔊 🔋          │
├──────────────────────────────────────────────────────┤
│                                                      │
│                                                      │
│         [Wallpaper Clean - Minimalista]             │
│                                                      │
│                                                      │
│                                                      │
├──────────────────────────────────────────────────────┤
│    ⚙️    📁    💻    📝    🖥️                       │
│ Settings Files VSCode TMJPad Terminal              │
└──────────────────────────────────────────────────────┘
```

---

## 📦 O que vem instalado?

### Base System
- **OS**: Ubuntu 24.04 LTS (jammy)
- **Kernel**: Linux 6.8+
- **Init**: systemd
- **Package Manager**: APT

### Desktop Environment
- **DE**: GNOME 46+
- **Dock**: Plank (estilo Mac)
- **Theme**: Adwaita Dark (customizado)
- **Icons**: Adwaita (minimalista)

### Development Tools
- **VSCode** - Editor de código avançado (do repo oficial Microsoft)
- **Git + git-flow** - Controle de versão
- **Docker + docker-compose** - Containerização
- **build-essential** - GCC, make, libs de build
- **curl/wget** - Download tools
- **vim/nano** - Editors no terminal
- **Python 3 + GTK4 + libadwaita** - Stack pra apps GNOME

### Apps Próprios TMJOs
- **[TMJPad](apps/tmjpad/)** - Editor de texto sem frescura, persistência total das abas
  (fecha-abre, tudo volta), dark mode, atalhos padrão. Comando: `tmjpad`

### Network & Diagnostics
- **dnsutils** - `nslookup`, `dig`, `host`
- **net-tools** - `ifconfig`, `netstat`, `route`
- **traceroute** - `traceroute`
- **htop, neofetch** - System monitor + flex

### Utilities
- **Files** (Nautilus) - Gerenciador de arquivos
- **Terminal** - GNOME Terminal
- **GNOME Tweaks + dconf-editor** - Customizações
- **Settings** - Configurações do sistema

---

## 🛠️ Como Construir TMJOs do Zero

### Pré-requisitos

```bash
# Hardware
- Mínimo 30GB de espaço em disco
- 4GB RAM recomendado
- Ubuntu 24.04 LTS instalado

# Software
sudo add-apt-repository ppa:cubic-wizard/release
sudo apt update && sudo apt install cubic
```

### Build Process

```bash
# 1. Clone este repositório
git clone https://github.com/tmjacometti/tmjos.git
cd tmjos

# 2. Abrir Cubic e criar projeto novo
cubic
# Project Directory: ~/tmjos-build/project
# Output Directory:  ~/tmjos-build/output

# 3. Dentro do chroot do Cubic, rodar o script de customização
bash /caminho/para/scripts/tmjos_customize.sh

# 4. Gerar ISO no Cubic
# Botão: "Generate ISO"

# 5. Testar em VM antes de gravar pen drive
qemu-system-x86_64 -cdrom ~/tmjos-build/output/tmjos-*.iso -m 4G
```

📖 **Guia Detalhado**: Veja [docs/BUILD.md](docs/BUILD.md) e [docs/CHECKLIST.md](docs/CHECKLIST.md)

---

## 📚 Documentação

- **[docs/BUILD.md](docs/BUILD.md)** - Guia passo-a-passo de build
- **[docs/CHECKLIST.md](docs/CHECKLIST.md)** - Checklist de criação
- **[docs/DESIGN.md](docs/DESIGN.md)** - Referência visual & branding
- **[apps/tmjpad/README.md](apps/tmjpad/README.md)** - TMJPad (editor de texto)
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Como contribuir
- **[CHANGELOG.md](CHANGELOG.md)** - Histórico de versões

---

## 🤝 Como Contribuir

Adoramos contribuições! Seja reportando bugs, sugestões ou código:

### 1. **Fork & Clone**
```bash
git clone https://github.com/SEU_FORK/tmjos.git
cd tmjos
git checkout -b feature/sua-feature
```

### 2. **Faça suas mudanças**
```bash
# Edite arquivos, customizations, scripts, etc
# Commit com mensagens claras
git commit -m "feat: adiciona tema customizado"
```

### 3. **Push & Pull Request**
```bash
git push origin feature/sua-feature
# Abra um PR no GitHub com descrição detalhada
```

### Tipos de Contribuição Bem-Vindo

- 🐛 **Bug Reports** - Encontrou um problema?
- 💡 **Sugestões** - Ideias para melhorias
- 📝 **Documentação** - Melhorar guias & docs
- 🎨 **Design** - Temas, wallpapers, ícones
- 💻 **Código** - Customizações, scripts, ferramentas
- 🧪 **Testes** - Testar em diferentes hardwares
- 🌍 **Tradução** - Localizar para outros idiomas

---

## 📋 Roadmap

### ✅ v1.1 (Current — codename: insano)
- [x] Base GNOME limpa
- [x] Plank dock (tipo Mac) na base + autostart system-wide
- [x] Launcher "Todos os Apps" no Plank (estilo macOS Launchpad)
- [x] Ubuntu Dock desabilitado (sem dock duplicado)
- [x] VSCode, Git, Docker
- [x] **TMJPad** — editor de texto nativo com persistência total
- [x] Wallpaper oficial TMJOs (com dragão e janelas IDE)
- [x] Logo TMJOs PNG (3 variantes: Circular, Rounded, Square)
- [x] Dark mode default + dconf system-wide
- [x] Fonts: JetBrains Mono, Cantarell, Noto Color Emoji
- [x] **Plymouth boot splash com logo TMJOs** (breathing glow)
- [x] **GRUB rebrand** (`GRUB_DISTRIBUTOR=TMJOs`)
- [x] Identidade própria (`/etc/os-release`, `/etc/lsb-release`)
- [x] Welcome popups do Ubuntu installer suprimidos
- [x] ISO ~3GB
- [x] Documentação completa

### 🔄 v1.2 (Próxima)
- [ ] GRUB **visual theme** TMJOs (não só nome)
- [ ] Plymouth: progress bar animada além do breathing glow
- [ ] GDM (login screen) com wallpaper TMJOs
- [ ] Empacotamento `.deb` do TMJPad
- [ ] TMJPad: Find & Replace (Ctrl+F, Ctrl+H)
- [ ] TMJPad: ícone próprio
- [ ] Sons custom de boot/shutdown
- [ ] **APT repo próprio** (`packages.tmjos.dev`) — distribuir apps TMJOs via apt
- [ ] **TMJOs Software Center** (GTK4 GUI) — store com branding TMJOs sobre apt
- [ ] **TMJCode** v0.1 — VSCode customizado TMJOs (primeiro app via store)

### 🚀 v2.0 (Futuro)
- [ ] TMJCode (VSCode customizado com tema TMJOs)
- [ ] Repo APT oficial (`packages.tmjos.dev`)
- [ ] Website oficial
- [ ] Sistema de release automatizado (GitHub Actions)
- [ ] Multi-arch builds (arm64)
- [ ] Comunidade ativa

---

## 🐛 Bug Reports & Issues

Encontrou um bug? Abra uma [issue](https://github.com/tmjacometti/tmjos/issues)!

**Template básico:**
```markdown
**Descreva o bug:**
Uma descrição clara do problema.

**Como reproduzir:**
1. Fazer isso
2. Depois aquilo
3. Resultado esperado vs real

**Screenshots:**
Se aplicável, adicione prints

**Ambiente:**
- Hardware: [ex: Notebook Dell XPS]
- ISO version: [ex: v1.1]
- Testem em: [ex: VM/Hardware real]
```

---

## 💬 Comunidade & Discussões

- **GitHub Discussions**: [Vá para discussions](https://github.com/tmjacometti/tmjos/discussions)
- **Issues**: [Reportar bugs](https://github.com/tmjacometti/tmjos/issues)

---

## 📝 Licença

TMJOs é lançado sob **GPLv3** License. Veja [LICENSE](LICENSE) para detalhes.

```
TMJOs - Clean Linux Distribution
Copyright (C) 2026 TMJOs Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

---

## 🌟 Créditos & Agradecimentos

- **Ubuntu Team** - Base da distribuição
- **GNOME Project** - Desktop environment
- **Plank Developers** - Dock
- **Todos os contribuidores** - Que fazem isso acontecer! ❤️

---

## 📊 Stats & Analytics

![GitHub stars](https://img.shields.io/github/stars/tmjacometti/tmjos?style=social)
![GitHub forks](https://img.shields.io/github/forks/tmjacometti/tmjos?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/tmjacometti/tmjos?style=social)
![GitHub issues](https://img.shields.io/github/issues/tmjacometti/tmjos)
![GitHub pull requests](https://img.shields.io/github/issues-pr/tmjacometti/tmjos)

---

## 🚀 Let's Build Something Amazing Together!

**TMJOs: Clean Linux for Developers** 🐧✨

```
┌────────────────────────────────────────┐
│  Give us a star if you like TMJOs! ⭐  │
└────────────────────────────────────────┘
```

---

*Last updated: 2026 | Made with ❤️ by TMJOs Community*
