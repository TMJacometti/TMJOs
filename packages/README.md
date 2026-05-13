# TMJOs APT repo source

Sources dos pacotes `.deb` do TMJOs Suite — apps neon que instalam via apt em qualquer Linux Debian-based.

## 📂 Estrutura

```
packages/
├── conf/              # reprepro config (suite stable)
├── keys/              # GPG public key (TMJOs archive keyring)
├── sources/           # source dir de cada pacote
│   ├── tmjpad/        # editor Rust
│   ├── tmjmenu/       # launcher + dock (Python, migra pra Rust)
│   └── tmjstore/      # software center (Python, migra pra Rust)
└── README.md          # este arquivo
```

## 🚀 Build local (desenvolvimento)

```bash
# Vendor upstream files
cd <repo-root>
tools/vendor-tmjpad.sh   # ou vendor-tmjmenu.sh, vendor-tmjstore.sh

# Build do pacote
cd packages/sources/tmjpad
dpkg-buildpackage -us -uc -b
ls ../../*.deb
```

## 🤖 Build via CI

Push pra `main` ou qualquer `feature/**` que toque em `apps/**` ou `packages/**` dispara
`.github/workflows/build-deb.yml`:

1. Vendor (`tools/vendor-*.sh`)
2. `dpkg-buildpackage` em cada `packages/sources/*/`
3. `reprepro includedeb stable` pra cada `.deb`
4. Deploy pra branch `gh-pages` (= APT repo público em `packages.tmjos.com.br`)

## 📦 Como user instala

```bash
curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/tmjos-archive-keyring.gpg > /dev/null

echo 'deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br stable main' \
  | sudo tee /etc/apt/sources.list.d/tmjos.list > /dev/null

sudo apt update
sudo apt install tmjpad tmjmenu tmjstore
```

Funciona em qualquer Linux Debian-based: Ubuntu, Debian, Mint, Pop!_OS, Kali, Tails, Parrot, elementaryOS, Zorin OS, etc.
