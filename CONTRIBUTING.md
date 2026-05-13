# Contribuindo com TMJOs Suite

Valeu pelo interesse! 🐉

TMJOs é uma **suite de apps neon proprietários** pra Linux Debian-based. Foco: hardcore dev productivity + identidade visual forte. Cada app é independente — mantemos o escopo enxuto.

---

## Como Contribuir

### 🐛 Reportar Bugs

1. Procure se já existe uma [issue](https://github.com/TMJacometti/TMJOs/issues) similar
2. Se não houver, abra uma nova usando o template de **Bug Report**
3. Descreva como reproduzir, o que esperava e o que aconteceu
4. Inclua sua distro + versão do app + logs relevantes

### ✨ Sugerir Features

1. Abra uma issue usando o template de **Feature Request**
2. Explique o caso de uso — por que isso ajudaria os usuários TMJOs?
3. Antes de implementar mudanças grandes, **discuta primeiro**. Evita retrabalho.

### 💻 Enviar Código

1. **Fork** do repositório
2. Crie uma branch: `git checkout -b feature/sua-feature` ou `fix/seu-fix`
3. Faça suas mudanças seguindo as convenções abaixo
4. Teste localmente
5. Commit com mensagem semântica (veja abaixo)
6. **Push** e abra um **Pull Request**

---

## Convenções

### Mensagens de Commit (Conventional Commits)

```
feat:     nova feature
fix:      correção de bug
docs:     mudanças só em documentação
style:    formatação, sem mudança de código
refactor: refatoração sem mudar comportamento
perf:     melhoria de performance
test:     testes
chore:    tarefas de manutenção (deps, build, etc)
```

Exemplos:
- `feat(tmjpad): add syntax highlighting`
- `fix(tmjdock): posicionamento no monitor interno`
- `chore(deps): bump gtk4-rs to 0.11`

### Estrutura de Pastas

```
TMJOs/
├── apps/             # source dos apps proprietários (Rust + Python)
│   ├── tmjpad/       # editor Rust
│   ├── tmjmenu/      # launcher + dock
│   └── tmjstore/     # software center
├── packages/         # debian packaging
│   ├── conf/         # reprepro config
│   ├── keys/         # GPG public key
│   └── sources/      # debian/* de cada pacote
├── tools/            # vendor scripts pra cada pacote
├── assets/           # logos, wallpapers (branding visual)
└── .github/          # CI workflows, templates
```

### Estilo de Código

- **Rust**: `cargo fmt` + `cargo clippy`. `rustc 1.75+`.
- **Python**: PEP 8, type hints quando possível, GTK4 + PyGObject.
- **Shell**: `set -euo pipefail` no topo, validar com `bash -n`.
- **Markdown**: linhas curtas (~80 chars), use code fences com linguagem.
- Comentários em PT-BR informal.

### Branding visual (não mexer sem combinar)

- Paleta: cyan `#00d4ff`, magenta `#ff2d95`, navy `#0a0e2a`, dark `#050714`, light `#e6e6e6`
- Fontes: JetBrains Mono (mono), Cantarell (UI fallback)
- Logo: dragão + gear, em [assets/logos/](assets/logos/)

---

## Build Local

### TMJPad (Rust):

```bash
sudo apt install -y cargo rustc pkg-config libgtk-4-dev libadwaita-1-dev
cd apps/tmjpad
cargo run --release
```

### TMJMenu/TMJStore (Python):

```bash
sudo apt install -y python3 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
cd apps/tmjmenu   # ou tmjstore
python3 -m tmjmenu
```

### Build .deb local:

```bash
tools/vendor-tmjpad.sh   # popula vendor/
cd packages/sources/tmjpad
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../tmjpad_*.deb
```

---

## Dúvidas?

- 💬 [Discussions](https://github.com/TMJacometti/TMJOs/discussions)
- 🐛 [Issues](https://github.com/TMJacometti/TMJOs/issues)

Toda contribuição é bem-vinda — desde reportar typo até enviar feature grande. 🚀
