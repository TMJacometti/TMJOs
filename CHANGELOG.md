# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Planejado
- Wallpaper oficial TMJOs
- Tema GNOME customizado
- GRUB theme com branding
- Boot splash screen

## [1.0.0] - 2026

### Adicionado
- Distribuição base Ubuntu 24.04 LTS
- Desktop GNOME 46+ limpo
- Plank dock estilo macOS pré-configurado em `/etc/skel`
- VSCode (repo oficial Microsoft) pré-instalado
- Git + git-flow
- Docker (docker.io + docker-compose)
- GNOME Tweaks + dconf-editor
- Extensões GNOME (gnome-shell-extensions)
- Ferramentas utilitárias: curl, wget, htop, neofetch, vim, nano, build-essential
- Script automatizado de customização (`scripts/tmjos_customize.sh`)
- Documentação completa de build (`docs/BUILD.md`)
- Checklist passo-a-passo de criação (`docs/CHECKLIST.md`)
- Referência de design e branding (`docs/DESIGN.md`)
- Templates de issue (bug, feature, question) e PR
- Licença GPLv3

### Removido (slim)
- LibreOffice (suite completa)
- Firefox / Thunderbird
- Apps GNOME pouco usados: Maps, Music, Videos, Todo
- Totem, Rhythmbox, Shotwell, Remmina, Transmission
- Telemetria: ubuntu-report, apport, popularity-contest

[Unreleased]: https://github.com/tmjacometti/tmjos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tmjacometti/tmjos/releases/tag/v1.0.0
