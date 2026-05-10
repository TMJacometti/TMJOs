# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Backlog v1.2] — em planejamento

- GRUB theme com visual TMJOs (v1.1 só renomeia distributor para "TMJOs")
- Plymouth: progress bar animada além do breathing glow do logo
- GDM (login screen) com wallpaper e logo TMJOs
- Ícone próprio do TMJPad (atualmente usa o logo geral do TMJOs)
- Empacotamento `.deb` do TMJPad (atualmente roda via wrapper em /usr/local/bin)
- TMJPad: Find & Replace (Ctrl+F, Ctrl+H)
- Sounds de boot/shutdown customizados
- ARM64 build

## [1.1.0] - 2026-05-10

Primeira release pública. **TMJOs 1.1 (codename: insano).**

### Nota sobre versionamento

Pulamos v1.0.x pública. As primeiras builds internas (numeradas 1.0
durante o desenvolvimento) eram smoke tests — saíram sem branding,
sem Plymouth custom, com Ubuntu Dock duplicado e popups de instalador.
v1.1.0 é o primeiro build com TUDO funcional e documentado.

### Adicionado — Sistema base
- Distribuição base Ubuntu 24.04 LTS Desktop (kernel 6.8 GA)
- Desktop GNOME 46+ limpo, dark mode default
- VSCode (repo oficial Microsoft) pré-instalado
- Git + git-flow
- Docker (docker.io + docker-compose)
- GNOME Tweaks + dconf-editor
- Extensões GNOME (gnome-shell-extensions, gnome-shell-extension-manager)
- Ferramentas utilitárias: curl, wget, htop, neofetch, vim, nano, build-essential
- Ferramentas de rede: dnsutils (nslookup, dig, host), net-tools, traceroute
- Stack Python para apps GTK4: python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1
- Fontes: JetBrains Mono, Cantarell, Noto Color Emoji

### Adicionado — Dock (Plank, estilo macOS)
- Plank pinnado na base, tema transparent, ícones 48px
- Autostart system-wide via `/etc/xdg/autostart/plank.desktop`
- Ubuntu Dock (sidebar vertical) e ícones flutuantes do desktop desabilitados
  via dconf — apenas o Plank na base
- 4 itens default: **Todos os Apps** + VSCode + TMJPad + Terminal
- Launcher "Todos os Apps" abre o GNOME Apps Overview via `org.gnome.Shell.Eval`
- "Todos os Apps" é re-injetado no dock no login se removido (entrada
  obrigatória — ponto único de descoberta de apps no dock)
- First-run autostart copia config de Plank do `/etc/skel/` pro user atual
  (resolve live-CD onde user 'ubuntu' já existe sem skel)

### Adicionado — Branding & Identidade Visual
- Wallpaper oficial TMJOs (dragão + engrenagem hexagonal + janelas IDE
  flutuantes + tipografia "TMJOs" central) instalado em
  `/usr/share/backgrounds/tmjos/tmjos_wallpaper.png`
- Logo TMJOs em 3 variantes (Circular, Rounded, Square) em
  `/usr/share/icons/tmjos/`; Rounded como app icon default em
  `/usr/share/icons/hicolor/512x512/apps/tmjos.png`
- `/etc/os-release` e `/etc/lsb-release` com identidade TMJOs
  (NAME=TMJOs, ID=tmjos, VERSION_CODENAME=insano)
- `/etc/issue` e `/etc/issue.net` com banner TMJOs no login TTY
- dconf system-wide defaults: dark mode (`color-scheme=prefer-dark`),
  wallpaper TMJOs, fonte mono JetBrains Mono, favorite-apps incluindo TMJPad

### Adicionado — Boot Identity
- GRUB renomeado: `GRUB_DISTRIBUTOR="TMJOs"` em `/etc/default/grub`,
  entrada do menu mostra "TMJOs" no lugar de "Ubuntu"
- Plymouth tema custom **TMJOs** instalado em `/usr/share/plymouth/themes/tmjos/`:
  fundo dark navy, logo central, breathing-glow opacity animation (0.92↔1.0)
- Tema setado como default via `update-alternatives` + initramfs regenerado

### Adicionado — Apps Próprios TMJOs
- **TMJPad** v0.1: editor de texto sem frescura com persistência total das abas
  - Auto-save de buffer a cada 500ms (debounced) — zero perda de dados em crash
  - Restauração completa do estado ao reabrir (abas, conteúdo, cursor, ordem)
  - Atomic writes (tmp file + rename) pra todos os arquivos de estado
  - Dark theme único, paleta TMJOs, fonte JetBrains Mono
  - Atalhos: Ctrl+N/W/Tab/S, foco automático no text view ao abrir aba
  - Instalado em `/opt/tmjpad/` com wrapper em `/usr/local/bin/tmjpad`
  - Entry no menu de apps (`/usr/share/applications/tmjpad.desktop`)

### Adicionado — Documentação
- README, CONTRIBUTING, CHANGELOG, LICENSE (GPLv3)
- Script automatizado de customização (`scripts/tmjos_customize.sh`)
- Guia de build (`docs/BUILD.md`)
- Checklist de criação (`docs/CHECKLIST.md`)
- Referência de design (`docs/DESIGN.md`)
- README do TMJPad (`apps/tmjpad/README.md`)
- Templates de issue (bug, feature, question) e PR

### Removido (slim)
- LibreOffice (suite completa)
- Apps GNOME pouco usados: Maps, Music, Videos, Todo
- Totem, Rhythmbox, Shotwell, Remmina, Transmission
- Telemetria: ubuntu-report, apport, popularity-contest

### Mantido (decisão de produto)
- Firefox: browser padrão de fato dos usuários Ubuntu
- Thunderbird: cliente de email útil para muitos casos de uso

### Suprimido (cosmético)
- Welcome popups do Ubuntu installer / gnome-initial-setup que abrem
  no login do live-CD com erro "Something went wrong" (depend de hooks
  do casper que não combinam com squashfs regenerado por Cubic). Os
  pacotes ficam instalados — o ícone "Install TMJOs" no desktop continua
  funcional, só os autostart popups são marcados `Hidden=true`.

[Backlog v1.2]: https://github.com/TMJacometti/TMJOs/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/TMJacometti/TMJOs/releases/tag/v1.1.0
