# TMJStore

Software Center nativo do TMJOs. Descobre apps TMJOs via AppStream metadata, instala via APT.

## Diferenciais

- **So apps TMJOs**: filtra origem `tmjos` no APT repo
- **Visual TMJOs neon**: paleta cyan/magenta, JetBrains Mono, dark
- **Fonte unica**: APT repo `packages.tmjos.com.br`

## Stack

- Rust 1.75+ (edition 2021)
- GTK4 + libadwaita (gtk4-rs)
- AppStream metadata (discovery)
- APT via pkexec (install/remove/upgrade)

## UX

```
+---------------------------------------------+
|  TMJStore                          [_] [x]  |
+---------------------------------------------+
|  [ Apps ]  [ Instalados ]  [ Updates (2) ]  |
+---------------------------------------------+
|  TMJPad                                     |
|  Editor sem frescura com persistencia       |
|                                  [ Install ]|
|                                             |
|  TMJMenu                                    |
|  Menu + dock nativo                         |
|                               [ Installed ] |
+---------------------------------------------+
```

## Run

```bash
tmjstore
```

## Empacotamento

```bash
sudo apt install tmjstore
```

## Licenca

GPLv3 — junto com o TMJOs.
