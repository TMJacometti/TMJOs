# Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
e o projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Backlog v1.4] — apps proprietários novos + tweaks pendentes

- **Activities button hide** (movido de v1.3): decisão é **fazer sem
  JavaScript** (user preferiu evitar até extensions GJS sandboxed).
  Opções a explorar em ordem de preferência:
  1. **CSS positioning off-screen** via dpkg-divert:
     ```css
     #panelLeft .panel-button:first-child {
         position: absolute;
         left: -99999px;
     }
     ```
     Não depende de class names que mudam entre GNOME versions —
     só posiciona o primeiro filho do panel esquerdo fora da tela.
  2. **Tema GNOME Shell TMJOs** dedicado em `/usr/share/gnome-shell/
     theme/TMJOs/` que `@import "../Yaru-dark/gnome-shell.css"`
     no início e sobrescreve o que precisa. Setado via dconf
     system-db `name="TMJOs"`. Mais robusto que dpkg-divert pra
     manter customizações de longo prazo.
  3. **Selectors CSS novos pra GNOME 46+** (último recurso — frágil
     entre releases).


Versão centrada em apps. Depende da v1.3 ter shipado APT repo +
TMJOs Software Center, porque ambos os apps abaixo são distribuídos
via apt e listados na store.

- **TMJCode** (VSCode customizado com tema/extensões TMJOs):
  - Wrapper sobre VSCode upstream que injeta `--extensions-dir`
    custom em `~/.tmjcode/extensions/`
  - Tema dark TMJOs (paleta cyan/magenta neon)
  - Extensões default pré-instaladas: prettier, eslint, tema TMJOs
  - Comando: `tmjcode`
  - Empacotado como `tmjcode.deb` no APT repo

- **TMJNotes** (sticky notes nativas, estilo Microsoft Sticky Notes):
  - GTK4 + libadwaita (mesma stack do TMJPad)
  - Notas pequenas flutuantes na tela, várias simultaneamente
  - Cores customizáveis por nota (paleta TMJOs neon)
  - **Persistência total** igual TMJPad: fechou e reabriu, todas as
    notas voltam exatamente como estavam (posição, tamanho, cor, texto,
    cursor)
  - Atalho global pra criar nova nota (Super+N? Super+Shift+N?)
  - Always-on-top opcional por nota
  - Markdown leve no texto (negrito, itálico, listas)
  - Comando: `tmjnotes` ou `tmjsticky`
  - Empacotado como `tmjnotes.deb` no APT repo

## [1.2.x] — patches via apt (depende do APT repo da v1.3)

- **TMJPad usa o logo geral do TMJOs em vez do ícone próprio**
  (livro azul). PNG foi copiado pra
  `/usr/share/icons/hicolor/256x256/apps/tmjpad.png` mas GTK icon
  cache não pegou ou conflitou. Será o **primeiro caso de teste do
  sistema de updates v1.3**: empacota `tmjpad_0.1.1_all.deb` com o
  fix do cache e users instalados rodam `apt upgrade tmjpad`.

## [Backlog v1.3.x] — patches via apt

- `tmjos-os-identity 1.3.0-3`: trocar `dpkg-divert --rename` por
  `--no-rename` em postinst/postrm. dpkg loga warning sobre
  rename de Essential package — funciona OK mas é boa prática
  evitar. Patch via apt upgrade quando alguém abrir.

- **Activities button visível no GNOME 46:** v1.3 mantém
  `tmjos-shell-tweaks 1.3.0-1` com CSS hack via dpkg-divert. O
  selector `.panel-button.activities-button` deixou de matchar
  em GNOME 46, então o hack é no-op mas continua instalado
  sem dano. O Activities button aparece no top-left. Decisão:
  resolver em v1.4 — escolher entre extension GNOME Shell própria
  (4 linhas de GJS sandboxed) ou pesquisar novos selectors do
  panel pra cada major GNOME release.

## [Backlog v1.3] — em planejamento

(Slim Aggressive foi promovido pra v1.2 — todos os cortes, disable de
tracker3 e adição de zram/preload já entram na release pública.)

### Boot & visuais

- GRUB theme com visual TMJOs (v1.2 só renomeia distributor para "TMJOs")
- Plymouth: progress bar animada além do breathing glow do logo
- GDM (login screen) com wallpaper e logo TMJOs
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

### Sistema de updates do core do TMJOs (CRÍTICO)

Hoje as customizações TMJOs (branding, dconf, plymouth, plank skel,
os-release, scripts) são aplicadas **só durante o build da ISO** via
customize.sh. Sistemas já instalados ficam congelados — não recebem
fixes nem features novas sem reinstalar tudo. v1.3 tem que mudar isso.

**Estratégia: empacotar o core em .deb instaláveis/atualizáveis via apt.**

Refatorar customize.sh em pacotes:

  - `tmjos-branding_X.deb`
      /usr/share/backgrounds/tmjos/*
      /usr/share/icons/tmjos/*
      /usr/share/icons/hicolor/*/apps/tmjos.png
      /usr/share/plymouth/themes/tmjos/*
      postinst: dconf update + gtk-update-icon-cache + update-initramfs -u

  - `tmjos-os-identity_X.deb`
      /etc/os-release, /etc/lsb-release, /etc/issue, /etc/issue.net
      conffile: marcado como "config-file" (apt não sobrescreve sem
      perguntar)

  - `tmjos-dock_X.deb`
      /etc/skel/.config/plank/dock1/*
      /etc/xdg/autostart/plank.desktop
      /etc/xdg/autostart/tmjos-first-run.desktop
      /usr/local/bin/tmjos-first-run
      /usr/local/bin/tmjos-show-apps
      /usr/share/applications/tmjos-show-apps.desktop

  - `tmjos-defaults_X.deb`
      /etc/dconf/db/local.d/00-tmjos-defaults
      /etc/dconf/profile/user
      postinst: dconf update

  - `tmjos-meta_X.deb` — meta-pacote que puxa TODOS os tmjos-*
      Depends: tmjos-branding (= X), tmjos-os-identity (= X),
               tmjos-dock (= X), tmjos-defaults (= X),
               tmjpad, plank, gnome-tweaks, ...

Fluxo de update do user instalado:

```
sudo apt update          # ← lê packages.tmjos.dev
sudo apt upgrade tmjos   # ← puxa nova versão de todo o core
```

Componentes adicionais:

- **GitHub Action `release.yml`** dispara em `git tag v1.X` e
  builda todos os `.deb`, assina com GPG key, sobe pra branch
  `gh-pages` que vira o APT repo público.
- **Postinst hooks bem feitos** que aplicam delta sem reboot quando
  possível (dconf update, gtk-update-icon-cache, fc-cache, etc.).
  Quando precisa de reboot (Plymouth, GRUB, initramfs), avisa.
- **Notificação de update** (sutil, no top bar quando tem release nova).
  Pode ser via update-notifier custom ou TMJOs Software Center.
- **`/etc/tmjos-release`** — arquivo simples com a versão atual,
  separado de `/etc/os-release` que é mais identidade que versão.

Refatoração dolorosa mas paga **muito** dividendo: cada fix vira
`apt upgrade` em vez de re-formatação. Releases mais frequentes
viram viáveis (v1.2.1, v1.2.2 patches sem ISO nova).

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
- **Activities button escondido** via CSS injection no Yaru shell theme
  (mais robusto que extension de terceiros — sem deps externas).
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
- **Release notes URL** rebranded para o CHANGELOG do TMJOs.
- **Esquema "branding visual + compat scripts" pra identidade do sistema:**
  - `/etc/os-release` → TMJOs 1.2 (insano), visível no GNOME About e
    ferramentas modernas que leem esse arquivo.
  - `/etc/lsb-release` → 100% Ubuntu noble. Crítico pra `add-apt-repository`,
    scripts de install (NodeJS, Docker, k8s) que usam `$(lsb_release -cs)`.
    Sem isso, todo PPA install retorna 404 ("suite insano not found").
  - Trade-off: `lsb_release -a` no terminal mostra "Ubuntu 24.04 LTS" em
    vez de TMJOs. Decisão consciente — compat de scripts > vaidade do
    terminal output. GNOME About mostra TMJOs corretamente.

### Slim Aggressive — RAM idle ~700MB, ISO ~2GB (target: notebooks 4GB)

- **Removido:** gnome-software, snapd, evolution-data-server,
  update-notifier, thunderbird, gnome-calendar, gnome-contacts,
  gnome-characters, yelp, file-roller, gnome-system-monitor.
- **Disabled (via tmjos-first-run):** tracker3 indexação
  (extract/miner-fs/miner-rss/writeback/xdg-portal masked).
- **Adicionado:** zram-config (RAM compactada como swap virtual,
  ~30% RAM efetiva extra), preload (pré-carrega apps em RAM ociosa).

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
  - **Ícone próprio** (`apps/tmjpad/assets/logo/tmjpad.png`) instalado
    em `/usr/share/icons/hicolor/256x256/apps/tmjpad.png` — estilo
    macOS app icon com livro + letras T M J coloridas

### Dock unificada — pin Activities ↔ Plank

- **`tmjos-dock-sync` daemon** (`/usr/local/bin/tmjos-dock-sync`):
  monitora `gsettings get org.gnome.shell favorite-apps` e replica as
  mudanças em `~/.config/plank/dock1/settings`. Quando o usuário pina
  um app pelo Activities Overview (right-click → Pin to Dash), o
  launcher aparece automaticamente na Plank. Cria os `.dockitem`
  faltantes em `launchers/` no caminho.
- **Sticky:** `tmjos-show-apps.dockitem` permanece SEMPRE no início.
- **Unidirecional** (Activities → Plank) por design. A direção contrária
  não faz sentido prático — pin no Plank é via right-click "Keep in Dock".
- Autostart entry em `/etc/xdg/autostart/tmjos-dock-sync.desktop`.
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
  (Thunderbird foi removido em v1.2 — usuário usa webmail ou outro cliente)

### Suprimido (cosmético)
- Welcome popups do Ubuntu installer / gnome-initial-setup que abrem
  no login do live-CD com erro "Something went wrong" (depend de hooks
  do casper que não combinam com squashfs regenerado por Cubic). Os
  pacotes ficam instalados — o ícone "Install TMJOs" no desktop continua
  funcional, só os autostart popups são marcados `Hidden=true`.

[Backlog v1.3]: https://github.com/TMJacometti/TMJOs/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/TMJacometti/TMJOs/releases/tag/v1.2.0
