# TMJStore

Software Center proprietário do TMJOs. Descobre apps TMJOs via AppStream metadata, instala via APT.

## Diferenças vs gnome-software / snap-store / etc

- **Só apps TMJOs**: filtra origem `tmjos` no APT repo. Não polui com Spotify, Telegram, GIMP, etc.
- **Visual TMJOs neon**: paleta cyan/magenta, JetBrains Mono, dark.
- **Zero capitalismo**: sem "Editor's choice", sem patrocinados, sem recomendações de tracking.
- **Fonte única**: APT repo `packages.tmjos.com.br`.

## Stack

- Python 3.12+
- GTK4 + libadwaita
- libappstream-glib (parsing AppStream metadata)
- subprocess (apt install / apt remove / apt upgrade via pkexec)

## UX

```
┌─────────────────────────────────────────────┐
│  TMJStore                          [_] [□] [×]│
├─────────────────────────────────────────────┤
│  [ Apps ]  [ Instalados ]  [ Updates (2) ]  │
├─────────────────────────────────────────────┤
│  ┌────┐  TMJPad                             │
│  │📒│  Editor sem frescura com persistência │
│  └────┘                          [ Install ]│
│                                             │
│  ┌────┐  TMJMenu                            │
│  │🐉│  Menu + dock proprietário             │
│  └────┘                       [ Installed ✓]│
└─────────────────────────────────────────────┘
```

## Run

```bash
tmjstore
```
