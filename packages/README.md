# TMJOs APT repo source

Este diretório contém os **sources** dos pacotes `.deb` do TMJOs.
Cada subpasta em `sources/` vira um `.deb` no APT repo público.

## 📂 Estrutura

```
packages/
├── conf/              # reprepro config (trixie suite)
├── keys/              # GPG public key (TMJOs archive keyring)
├── sources/           # source dir de cada pacote
│   ├── tmjos/         # meta-package
│   ├── tmjos-branding/
│   ├── tmjos-calamares-branding/
│   ├── tmjos-os-identity/
│   ├── tmjos-defaults/
│   ├── tmjos-hello/   # smoke test
│   ├── tmjmenu/       # TMJMenu + TMJDock
│   ├── tmjpad/
│   └── tmjstore/
└── README.md          # este arquivo
```

## 🚀 Build local (desenvolvimento)

```bash
# Build de um pacote específico
cd packages/sources/tmjos-branding
dpkg-buildpackage -us -uc -b
ls ../../*.deb
```

## 🤖 Build via CI

Push pra `main` que toca em `packages/sources/<pkg>/` dispara
`.github/workflows/build-deb.yml` que:

1. Builda o `.deb`
2. Assina com a GPG key TMJOs (secret `GPG_SIGNING_KEY`)
3. Atualiza repo via reprepro
4. Push pra branch `gh-pages` (= APT repo público)

## 📦 Como user instala/atualiza

ISO TMJOs v2.0+ já vem com o repo pré-configurado:

```bash
# /etc/apt/sources.list.d/tmjos.list
deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] \
  https://packages.tmjos.com.br trixie main apps extras
```

Daí o user roda:

```bash
sudo apt update
sudo apt upgrade tmjos       # atualiza todo o core
sudo apt install tmjpad      # instala app individual
```

## 🚧 Status atual

**v2.0 alpha** — migração Ubuntu (noble) → Debian (trixie) em andamento.
Repo APT publica apenas suite `trixie`. v1.x (noble) está congelado.
