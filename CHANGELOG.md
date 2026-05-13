# Changelog

Mudanças relevantes do TMJOs Suite. Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

Cada app tem versionamento independente — não há "versão do TMJOs". Apps são publicados no APT repo TMJOs (suite `stable`) conforme novas releases saem.

---

## [Unreleased]

- Apps novos no backlog: **TMJCode** (editor VSCode-style, Rust), **TMJNotes** (sticky notes, Rust), **TMJMoney** (controle financeiro, Rust), **TMJRestApi** (REST client tipo Postman, Rust), **TMJCriptoBot** (bot trading cripto educacional, Rust)
- **AppImage** releases pra alcance cross-distro x86_64 sem APT
- **Flatpak** no Flathub pra distribuição universal Linux
- Migração progressiva dos apps Python (tmjmenu, tmjstore) pra Rust

---

## TMJPad

Editor de texto com persistência total de sessão. Multi-tab, auto-save, find/replace, dark theme neon. GTK4 + libadwaita.

### [2.0.0] — 2026-05-13

- **Reescrita completa em Rust** + gtk4-rs + libadwaita (era Python + PyGObject).
- Single binary em `/usr/bin/tmjpad` (~3-5MB, sem deps Python no runtime).
- Startup time ~5x mais rápido (~100ms vs ~500ms Python).
- Memory footprint -60% (~15MB vs ~40MB).
- Paridade total com versão 0.1.2 Python:
  - Multi-tab com reordenação
  - Session persistence atômica em `~/.config/tmjpad/`
  - Auto-save debounced 500ms
  - Find & Replace inline (Ctrl+F / Ctrl+H, case-insensitive, wrap)
  - Dark theme TMJOs neon + JetBrains Mono
  - Cursor restoration entre sessões
- Architecture: amd64 (era `all`/Python). Build via cargo no CI.

### [0.1.2] — Python, era pré-Rust

- Multi-tab + session persistence + find/replace + auto-save (~838 linhas Python).
- Substituída por 2.0.0 Rust (history preservada no git).

---

## TMJMenu / TMJDock

Launcher popup search (Super+Space) + dock GTK4 nativo. Visual TMJOs em qualquer GNOME (substitui dash-to-dock + Activities Overview pra quem quer). Python + PyGObject (migra pra Rust em v3.0).

### [1.3.4-16] — 2026-05-13

- **Fix**: TMJDock agora ancora no monitor INTERNO do laptop (eDP/LVDS/DSI), independente do que esteja marcado como primary. Em multi-monitor (laptop + externo), dock sempre fica no painel do laptop.
- **Add `tmjmenu/monitors.py`**: helper module com `shell_monitor()` + `shell_geometry()`. Prioriza connector interno, fallback pra primary, fallback pra primeiro monitor. Env overrides `TMJOS_MONITOR_CONNECTOR` e `TMJOS_MONITOR_GEOMETRY` pra casos edge (kiosk, etc).
- **Wayland nativo** via gtk4-layer-shell quando disponível (Recommends). Mutter trata layer-shell direto. Fallback X11 hints pra Xorg/XWayland.
- Padding interno reduzido (12 → 6) — bar mais compacto.
- AUTO_HIDE_REVEAL_PX aumentado (8 → 64) — área de hover maior pra detectar mouse aproximando.
- Botão central renomeado: "Activities Overview" → "Todos os apps" (abre TMJMenu popup com lista completa).

### Versões anteriores

- 1.3.4-15: rebuild pra publicar no APT repo TMJOs.
- 1.3.4-14: fix de re-detecção de apps recém instalados na dock.
- 1.3.x série anterior: TMJMenu (popup search Super+Space) + TMJDock (botão TMJOs gradient cyan/magenta) GTK4 nativo.

---

## TMJStore

Software center proprietário que descobre apps TMJOs via AppStream + instala via apt+pkexec. Visual neon próprio. Python + PyGObject (migra pra Rust em v3.0).

### [0.1.0] — 2026-05-11

- Initial release. 3 abas: Apps disponíveis, Instalados, Updates pendentes.
- Discovery via AppStream metadata (`apt-cache show` + `appstreamcli`).
- Filtra apps com origin `packages.tmjos.com.br` (TMJOs apps only).
- Install / Remove / Upgrade via pkexec + apt.
- GTK4 + libadwaita nativo, paleta neon TMJOs.

---

## Suite (infraestrutura)

### [2026-05-13] — Foco: suite de apps

- TMJOs é uma **suite de apps proprietários** instaláveis via apt em qualquer Linux Debian-based (Ubuntu, Debian, Mint, Pop!_OS, Kali, Tails, Parrot, elementaryOS, Zorin, etc).
- APT repo `packages.tmjos.com.br` com suite única `stable` (agnóstica de codename de distro).
- Site/landing em `packages.tmjos.com.br`.
- Build CI em `.github/workflows/build-deb.yml`: vendor + dpkg-buildpackage + reprepro + deploy gh-pages com `force_orphan: true` (APT repo recriado do zero a cada deploy).

---

[Unreleased]: https://github.com/TMJacometti/TMJOs/compare/main...HEAD
