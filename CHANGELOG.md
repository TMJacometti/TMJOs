# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Planejado (v1.1)
- Plymouth boot splash com logo TMJOs
- GRUB theme personalizado
- GDM (login screen) com wallpaper TMJOs
- **Regenerar wallpaper + logo:** v1.0 tem ambiguidade visual (parece
  "TM T JOs" por causa do T grande central separando "TM" e "JOs").
  Refazer com tipografia "TMJOs" contínua. Em geração no Nano Banana.
- **Validar fix do welcome popup:** v1.1 do customize.sh já suprime
  ubuntu-desktop-installer / -provision / -bootstrap autostarts via
  `Hidden=true`. Próximo build deve sair sem o popup. Manter no
  backlog até confirmar visualmente que sumiu.
- Ícone próprio do TMJPad
- Empacotamento `.deb` do TMJPad
- TMJPad: Find & Replace (Ctrl+F, Ctrl+H)

## [1.0.0] - 2026

### Adicionado — Sistema base
- Distribuição base Ubuntu 24.04 LTS
- Desktop GNOME 46+ limpo
- Plank dock estilo macOS — agora com **autostart system-wide** em `/etc/xdg/autostart/`
- VSCode (repo oficial Microsoft) pré-instalado
- Git + git-flow
- Docker (docker.io + docker-compose)
- GNOME Tweaks + dconf-editor
- Extensões GNOME (gnome-shell-extensions, gnome-shell-extension-manager)
- Ferramentas utilitárias: curl, wget, htop, neofetch, vim, nano, build-essential
- Ferramentas de rede: dnsutils (nslookup, dig, host), net-tools, traceroute
- Stack Python para apps GTK4: python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1

### Adicionado — Branding & Identidade Visual
- Wallpapers oficiais TMJOs (com dragão, slogan "OS MELHORES. OS INSANOS.")
- Logo TMJOs em SVG: `logo.svg`, `icon.svg`, `logo-monochrome.svg`
- Wallpapers instalados em `/usr/share/backgrounds/tmjos/`
- Logo instalado em `/usr/share/icons/hicolor/scalable/apps/tmjos.svg` e pixmaps
- `/etc/os-release` e `/etc/lsb-release` com identidade TMJOs (NAME=TMJOs, ID=tmjos, VERSION_CODENAME=insano)
- `/etc/issue` e `/etc/issue.net` com banner TMJOs no login TTY
- dconf system-wide defaults: dark mode, wallpaper TMJOs, JetBrains Mono no terminal,
  favorite-apps no shell incluindo TMJPad

### Adicionado — Apps Próprios TMJOs
- **TMJPad** v0.1: editor de texto sem frescura com persistência total das abas
  - Auto-save de buffer a cada 500ms (debounced) — zero perda de dados em crash
  - Restauração completa do estado ao reabrir (abas, conteúdo, cursor, ordem)
  - Atomic writes (tmp file + rename) pra todos os arquivos de estado
  - Dark theme único, paleta TMJOs (cyan/magenta sobre dark navy)
  - Atalhos: Ctrl+N/W/Tab/S/F, foco automático no text view ao abrir aba
  - Instalado em `/opt/tmjpad/` com wrapper em `/usr/local/bin/tmjpad`

### Adicionado — Documentação
- README, CONTRIBUTING, CHANGELOG, LICENSE
- Script automatizado de customização (`scripts/tmjos_customize.sh`)
- Guia de build (`docs/BUILD.md`)
- Checklist de criação (`docs/CHECKLIST.md`)
- Referência de design (`docs/DESIGN.md`)
- README do TMJPad (`apps/tmjpad/README.md`)
- Templates de issue (bug, feature, question) e PR
- Licença GPLv3

### Removido (slim)
- LibreOffice (suite completa)
- Apps GNOME pouco usados: Maps, Music, Videos, Todo
- Totem, Rhythmbox, Shotwell, Remmina, Transmission
- Telemetria: ubuntu-report, apport, popularity-contest

### Mantido (decisão de produto)
- Firefox: browser padrão de fato dos usuários Ubuntu
- Thunderbird: cliente de email útil para muitos casos de uso

[Unreleased]: https://github.com/tmjacometti/tmjos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tmjacometti/tmjos/releases/tag/v1.0.0
