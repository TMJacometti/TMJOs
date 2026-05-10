# TMJOs APT repo source

Este diretório contém os **sources** dos pacotes `.deb` do TMJOs.
Cada subpasta em `sources/` vira um `.deb` no APT repo público.

> **Pra entender a arquitetura completa**, leia
> [`docs/v1.3/ROADMAP.md`](../docs/v1.3/ROADMAP.md).

## 📂 Estrutura

```
packages/
├── conf/              # reprepro/aptly config
├── keys/              # GPG public key (TMJOs archive keyring)
├── sources/           # source dir de cada pacote
│   ├── tmjos-branding/
│   ├── tmjos-os-identity/
│   ├── tmjos-dock/
│   ├── tmjos-defaults/
│   ├── tmjos-shell-tweaks/
│   ├── tmjpad/
│   ├── tmjos-store/
│   ├── tmjcode/
│   └── tmjos/         # meta-package
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

ISO TMJOs v1.3+ já vem com o repo pré-configurado:

```bash
# /etc/apt/sources.list.d/tmjos.list
deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] \
  https://tmjacometti.github.io/TMJOs/ noble main
```

Daí o user roda:

```bash
sudo apt update
sudo apt upgrade tmjos       # atualiza todo o core
sudo apt install tmjcode     # instala app individual
```

## 🚧 Status atual

**v1.3 em desenvolvimento.** Esta estrutura ainda está sendo populada.
Acompanhe progresso em [`docs/v1.3/ROADMAP.md`](../docs/v1.3/ROADMAP.md).
