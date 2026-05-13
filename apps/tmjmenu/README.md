# TMJMenu

Menu de aplicações proprietário do TMJOs. Fornece uma interface popup compacta com search, apps pinados e recentes — estilo Start/Menu moderno, mas com identidade TMJOs.

## Stack

- Python 3.12+
- GTK4 + libadwaita (via PyGObject)
- gtk4-layer-shell para o dock no Wayland/Hyprland
- Lê `/usr/share/applications/*.desktop` (XDG)
- Persistência em `~/.config/tmjmenu/`

## Componentes

- **TMJMenu** (`tmjmenu`) — popup search-launcher, abre via Super key
- **TMJDock** (`tmjdock`) — barra sempre visível embaixo, substitui o Plank

No Wayland/Hyprland, o `tmjdock` usa `gtk4-layer-shell` para ficar ancorado
no rodape. Sem layer-shell, ele cai no fallback X11 usado em desenvolvimento.

## Run

```bash
tmjmenu          # abre o popup search
tmjdock          # roda a dock (daemon)
```

## Autostart

`tmjdock` é configurado pra autostart via `data/tmjdock.desktop` (instalado em `~/.config/autostart/`). Quando empacotado como `.apk`, vai em `/etc/xdg/autostart/`.

## Empacotamento

Distribuído como `tmjmenu.apk` no repo APK TMJOs. APKBUILD em
`packages/tmjmenu/`.
