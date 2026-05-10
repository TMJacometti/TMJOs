# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Backlog v1.3] — em planejamento

### Slim Plus — alvo: rodar em 4GB RAM (estilo elementaryOS)

Meta: ISO ~2.5GB, RAM idle ~900MB (de ~1.4GB hoje), sem perda visível
de UX pro usuário típico.

- **Remover:**
  - `gnome-software` (~200MB RAM) — TMJOs Software Center vai substituir
  - `snapd` + snaps default (~200MB RAM, ~100MB disco) — não usamos snap
  - `evolution-data-server` (~150MB) — cache de email/contatos
  - `gnome-calendar`, `gnome-contacts`, `gnome-characters`, `yelp`
  - `file-roller` (Nautilus tem archive plugin nativo)
  - `gnome-system-monitor` (htop substitui)
- **Disable (não remove, só desativa serviços):**
  - `tracker3` extract/miner — indexação de arquivos pesa ~300MB RAM e
    queima disco. `systemctl --user mask tracker-extract-3.service
    tracker-miner-fs-3.service`
  - `update-notifier` autostart — quem quer update roda apt
- **Adicionar:**
  - `zram-config` — comprime RAM em swap virtual, ganha ~30% RAM
    efetiva grátis em sistemas low-mem
  - `preload` — daemon que pré-carrega apps mais usados em RAM ociosa

### Boot & visuais

- GRUB theme com visual TMJOs (v1.2 só renomeia distributor para "TMJOs")
- Plymouth: progress bar animada além do breathing glow do logo
- GDM (login screen) com wallpaper e logo TMJOs
- Ícone próprio do TMJPad (atualmente usa o logo geral do TMJOs)
- Empacotamento `.deb` do TMJPad (atualmente roda via wrapper em /usr/local/bin)
- Sounds de boot/shutdown customizados
- ARM64 build

### Loja própria de apps TMJOs

- **APT repo próprio** (`packages.tmjos.dev` ou `tmjacometti.github.io/tmjos-packages`):
  hospedado em GitHub Pages, GPG key pra assinatura, GitHub Action que
  empacota cada app em `.deb` a cada push. Usuário roda `apt install
  tmjpad` / `tmjcode` / `tmj*` e `apt upgrade` cuida das atualizações.
  ISO já vem com o repo pré-configurado em `/etc/apt/sources.list.d/tmjos.list`.
- **TMJOs Software Center** (GTK4 GUI): wrapper visual sobre o APT repo
  acima — lista apps TMJOs, busca, instala/atualiza com 1 click. Branding
  TMJOs completo. Depende do APT repo estar de pé primeiro.
- **Apps proprietários previstos** (atualmente em ideação, não implementados):
  - **TMJCode** — VSCode customizado com tema/extensões TMJOs
  - **TMJPad** já lançado em v1.2, será reembalado como `.deb` no repo

## [1.2.0] - 2026-05-10

Primeira release pública. **TMJOs 1.2 (codename: insano).**

### Nota sobre versionamento

Pulamos v1.0.x e v1.1.x públicas. As primeiras builds internas
(numeradas 1.0 e 1.1 durante o desenvolvimento) eram smoke tests:
- v1.0 saía sem branding, Plymouth custom, com Ubuntu Dock duplicado
  e popups de instalador.
- v1.1 chegou a mostrar Plymouth TMJOs sob KVM e branding visual,
  mas ainda tinha Activities button visível, Plank com 6 ícones em
  vez de 4, sem Find/Replace no TMJPad e sem watermark TMJSistemas.

v1.2.0 é o primeiro build com TUDO polido e Find/Replace funcional.

### Novidades em v1.2 (não estavam em v1.0/v1.1)

- **TMJPad ganhou Find & Replace** — Ctrl+F (busca), Ctrl+H (busca +
  replace), Esc fecha, Enter/Shift+Enter navega entre matches, Replace
  All com undo único.
- **Plymouth watermark "TMJSistemas"** em vermelho sangue com glow no
  centro do splash.
- **Plymouth layout reorganizado** — logo TMJOs pequeno (80x80) +
  "Loading..." no rodapé, em vez do logo grande no centro.
- **Activities button escondido** via Just Perfection extension.
- **Plank trim:** 4 launchers default (Todos os Apps + VSCode + TMJPad
  + Terminal) em vez dos 6 anteriores.
- **"Todos os Apps" sticky:** o launcher é re-injetado no dock se o
  usuário tentar remover.
- **Welcome popup do Ubuntu installer:** suprimido via Hidden=true.
- **Wallpaper upscaled:** 1920x1080 (e variante 4K em
  tmjos_wallpaper_4k.png) com Lanczos.
- **VM/host integration:** spice-vdagent + qemu-guest-agent permitem
  clipboard QEMU↔Host, drag-drop, dynamic resize.
- **Fonts:** fonts-jetbrains-mono explicitamente instalado (referenciado
  no dconf default monospace).

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
  - **Find & Replace:** Ctrl+F (busca), Ctrl+H (busca + replace), Esc fecha,
    Enter/Shift+Enter navega entre matches, Replace All com undo único
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

[Backlog v1.3]: https://github.com/TMJacometti/TMJOs/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/TMJacometti/TMJOs/releases/tag/v1.2.0
