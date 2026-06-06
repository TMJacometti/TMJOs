# Changelog

Mudancas relevantes do TMJOs. Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

## [Unreleased]

### Distro
- Build da ISO TMJOs 26.04 via GitHub Actions (live-build)
- XFCE minimal (sem painel — tmjDock substitui)
- Pre-instalado: Git, VSCode, Python 3.12, Node.js LTS, .NET 10 SDK
- Pre-instalado: TMJPad, TMJMenu, TMJStore
- Branding completo (boot, login, os-release — zero Ubuntu visivel)
- Tema neon TMJOs no desktop, terminal e LightDM

### TMJPad
- Fix: `save_to_disk` agora usa atomic write (tmp + rename)
- Fix: `find_next` nao trava mais na mesma match
- README atualizado para Rust 2.0.0

---

## [0.1.0] — 2026-06-06

### Adicionado
- Estrutura inicial do projeto TMJOs como distro Linux
- TMJPad 2.0.0 — editor de texto em Rust + GTK4 + libadwaita
  - Multi-tab com reordenacao
  - Session persistence atomica (~/.config/tmjpad/)
  - Auto-save debounced 500ms
  - Find & Replace inline (Ctrl+F / Ctrl+H)
  - Dark theme neon TMJOs
- TMJMenu — launcher popup (Super+Space) + TMJDock (dock bottom)
- TMJStore — software center com visual neon
- APT repo em packages.tmjos.com.br (suite stable, GPG signed)
- CI: build-deb.yml (builda .deb + publica APT repo via gh-pages)
- CI: build-iso.yml (gera ISO via live-build + publica como Release)
- Assets: logos (circular, rounded, square), wallpapers (1080p, 4K)

---

[Unreleased]: https://github.com/TMJacometti/TMJOs/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/TMJacometti/TMJOs/releases/tag/v0.1.0
