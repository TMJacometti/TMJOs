# Contribuindo com TMJOs

Valeu pelo interesse!

TMJOs e uma **distro Linux focada em desenvolvimento** baseada em Ubuntu 26.04 + XFCE, com apps nativos proprietarios (TMJPad, TMJMenu, TMJStore). Foco: produtividade dev + identidade visual neon.

---

## Como Contribuir

### Reportar Bugs

1. Procure se ja existe uma [issue](https://github.com/TMJacometti/TMJOs/issues) similar
2. Se nao houver, abra uma nova usando o template de **Bug Report**
3. Descreva como reproduzir, o que esperava e o que aconteceu
4. Inclua: versao da ISO ou do app, hardware relevante, logs

### Sugerir Features

1. Abra uma issue usando o template de **Feature Request**
2. Explique o caso de uso — por que isso ajudaria?
3. Antes de implementar mudancas grandes, **discuta primeiro**. Evita retrabalho.

### Enviar Codigo

1. **Fork** do repositorio
2. Crie uma branch: `git checkout -b feature/sua-feature` ou `fix/seu-fix`
3. Faca suas mudancas seguindo as convencoes abaixo
4. Teste localmente
5. Commit com mensagem semantica (veja abaixo)
6. **Push** e abra um **Pull Request**

---

## Convencoes

### Mensagens de Commit (Conventional Commits)

```
feat:     nova feature
fix:      correcao de bug
docs:     mudancas so em documentacao
refactor: refatoracao sem mudar comportamento
perf:     melhoria de performance
test:     testes
chore:    tarefas de manutencao (deps, build, etc)
```

Exemplos:
- `feat(tmjpad): add syntax highlighting`
- `fix(tmjdock): posicionamento no monitor interno`
- `feat(distro): add .NET 10 SDK to ISO`
- `chore(ci): update build-iso workflow`

### Estrutura de Pastas

```
TMJOs/
├── apps/              # Source dos apps nativos (Rust + GTK4)
│   ├── tmjpad/        # Editor de texto
│   ├── tmjmenu/       # Launcher + dock
│   └── tmjstore/      # Software center
├── distro/            # Build da ISO
│   ├── build.sh       # Script principal (live-build)
│   ├── packages.list  # Pacotes para instalar
│   ├── remove.list    # Bloat para remover
│   ├── hooks/         # Scripts executados durante o build
│   └── theme/         # Tema XFCE + terminal
├── packages/          # Debian packaging (reprepro, GPG keys)
├── tools/             # Vendor scripts para cada pacote
├── assets/            # Logos, wallpapers
└── .github/
    ├── workflows/     # CI (build-deb.yml, build-iso.yml)
    └── ISSUE_TEMPLATE/
```

### Estilo de Codigo

- **Rust**: `cargo fmt` + `cargo clippy`. `rustc 1.75+`.
- **Shell**: `set -euo pipefail` no topo, validar com `bash -n`.
- Comentarios em PT-BR informal.

### Branding visual (nao mexer sem combinar)

- Paleta: cyan `#00d4ff`, magenta `#ff2d95`, navy `#0a0e2a`, dark `#050714`, light `#e6e6e6`
- Fontes: JetBrains Mono (mono), Noto Sans (UI)
- Logo: dragao + gear, em `assets/logos/`

---

## Build Local

### Apps (Rust + GTK4):

```bash
sudo apt install -y cargo rustc pkg-config libgtk-4-dev libadwaita-1-dev
cd apps/tmjpad   # ou tmjmenu, tmjstore
cargo run --release
```

### ISO (precisa de Ubuntu host):

```bash
sudo apt install -y live-build debootstrap squashfs-tools xorriso grub-efi-amd64-bin
chmod +x distro/build.sh distro/hooks/*.sh
sudo distro/build.sh
```

### Build .deb local:

```bash
tools/vendor-tmjpad.sh
cd packages/sources/tmjpad
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../tmjpad_*.deb
```

---

## Duvidas?

- [Issues](https://github.com/TMJacometti/TMJOs/issues)

Toda contribuicao e bem-vinda — desde reportar typo ate enviar feature grande.
