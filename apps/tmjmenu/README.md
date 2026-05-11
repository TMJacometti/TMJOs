# TMJMenu

Menu de aplicações proprietário do TMJOs. Substitui o Activities Overview do GNOME por uma interface popup compacta com search, apps pinados e recentes — estilo Win11 Start mas com identidade TMJOs (paleta neon).

## Stack

- Python 3.12+
- GTK4 + libadwaita (via PyGObject)
- Lê `/usr/share/applications/*.desktop` (XDG)
- Persistência em `~/.config/tmjmenu/`

## Run

```bash
tmjmenu          # abre o menu
tmjmenu --toggle # toggle (abre se fechado, fecha se aberto) — usado pelo Super key
```

## Empacotamento

Distribuído como `tmjmenu.deb` no APT repo TMJOs. Source em
`packages/sources/tmjmenu/`, build via `tools/vendor-tmjmenu.sh` + dpkg-buildpackage.
