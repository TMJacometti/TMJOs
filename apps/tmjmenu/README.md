# TMJMenu

Menu de aplicacoes e dock nativos do TMJOs. Substitui o painel XFCE na distro.

## Stack

- Rust 1.75+ (edition 2021)
- GTK4 + libadwaita (gtk4-rs)
- Le `/usr/share/applications/*.desktop` (XDG)
- Persistencia em `~/.config/tmjmenu/`

## Componentes

- **TMJMenu** (`tmjmenu`) — popup search-launcher (Super+Space)
- **TMJDock** (`tmjdock`) — dock bottom, sempre visivel, substitui o painel XFCE

## Run

```bash
tmjmenu          # abre o popup search
tmjdock          # roda a dock (daemon)
```

## Autostart

`tmjdock` e configurado pra autostart via `data/tmjdock.desktop` (instalado em `/etc/xdg/autostart/`).

## Empacotamento

Distribuido como `tmjmenu.deb` via APT repo TMJOs (`packages.tmjos.com.br`).

```bash
sudo apt install tmjmenu
```

## Licenca

GPLv3 — junto com o TMJOs.
