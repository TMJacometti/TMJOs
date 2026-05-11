# TMJMenu

Menu de aplicações proprietário do TMJOs. Substitui o Activities Overview do GNOME por uma interface popup compacta com search, apps pinados e recentes — estilo Win11 Start mas com identidade TMJOs (paleta neon).

## Stack

- Python 3.12+
- GTK4 + libadwaita (via PyGObject)
- Lê `/usr/share/applications/*.desktop` (XDG)
- Persistência em `~/.config/tmjmenu/`

## Componentes

- **TMJMenu** (`tmjmenu`) — popup search-launcher, abre via Super key
- **TMJDock** (`tmjdock`) — barra sempre visível embaixo, substitui o Plank

## Run

```bash
tmjmenu          # abre o popup search
tmjdock          # roda a dock (daemon)
```

## Autostart

`tmjdock` é configurado pra autostart via `data/tmjdock.desktop` (instalado em `~/.config/autostart/`). Quando empacotado como .deb, vai em `/etc/xdg/autostart/`.

## Empacotamento

Distribuído como `tmjmenu.deb` no APT repo TMJOs. Source em
`packages/sources/tmjmenu/`, build via `tools/vendor-tmjmenu.sh` + dpkg-buildpackage.
