# 🐉 TMJOs Suite

> **OS DA TMJSistemas · OS MELHORES · OS INSANOS**
>
> Suite de apps neon proprietários para devs hardcore. Cyan, magenta, dragão e gear. Instala em qualquer Linux Debian-based via APT.

![License](https://img.shields.io/badge/license-GPLv3-green)
![APT](https://img.shields.io/badge/APT%20repo-packages.tmjos.com.br-blueviolet)
![Stack](https://img.shields.io/badge/stack-GTK4%20%2B%20Rust%2FPython-orange)

---

## ✨ O que é

TMJOs é um **ecossistema de apps proprietários** com identidade visual neon — cyan/magenta/dark navy, logo dragão+gear, fontes JetBrains Mono. Apps GTK4 + libadwaita, escritos em **Rust** (novos) e **Python** (em migração).

Funciona em **qualquer Linux Debian-based** (Ubuntu, Debian, Mint, Pop!_OS, Kali, Tails, Parrot, elementaryOS, Zorin, etc) via APT repo oficial.

---

## 🚀 Instalação

```bash
# 1. Adiciona o repo TMJOs
curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/tmjos-archive-keyring.gpg > /dev/null

echo 'deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br stable main' \
  | sudo tee /etc/apt/sources.list.d/tmjos.list > /dev/null

# 2. Update
sudo apt update

# 3. Instala os apps que quiser
sudo apt install tmjpad    # Editor de texto
sudo apt install tmjmenu   # Launcher + dock
sudo apt install tmjstore  # Software center
```

---

## 📦 Apps

### 📝 TMJPad
Editor de texto com **persistência total de sessão**. Fechou e reabriu? Todas abas voltam (incluindo as não salvas). Auto-save debounced, find/replace, dark theme neon. **Rust + GTK4** (v2.0+).

```bash
sudo apt install tmjpad
tmjpad
```

### 🚀 TMJMenu + TMJDock
Launcher proprietário GTK4 nativo. **Super+Space** abre popup search. Dock bottom-center estilo Win11 Start com botão TMJOs gradient cyan/magenta. Auto-hide adaptativo (detecta VM vs hardware real), Super+Shift+H toggle pinned. Suporta gtk4-layer-shell pra Wayland nativo.

```bash
sudo apt install tmjmenu
tmjdock &   # roda em background
```

### 🏪 TMJStore
Software center proprietário que descobre apps TMJOs via AppStream + instala via apt+pkexec. Visual neon próprio (sem capitalismo corporativo). 3 abas: Apps disponíveis, Instalados, Updates pendentes.

```bash
sudo apt install tmjstore
tmjstore
```

---

## 🎨 Identidade visual

- **Paleta neon**: cyan #00d4ff, magenta #ff2d95, navy #0a0e2a
- **Logo**: dragão + gear (TMJOs.png em [assets/logos/](assets/logos/))
- **Fontes**: JetBrains Mono (mono), Cantarell (UI)
- **Tema**: dark obrigatório, contraste forte, sem floofy
- **Slogan**: "OS MELHORES · OS INSANOS"

Stack visual coesa entre todos apps — paleta + fonts + padrões UI (sidebar com border cyan, hover magenta glow, etc).

---

## 🛠️ Stack técnica

| App | Linguagem | Status |
|---|---|---|
| TMJPad | **Rust** + gtk4-rs | v2.0+ |
| TMJMenu/TMJDock | Python + PyGObject | migra pra Rust em v3.0 |
| TMJStore | Python + PyGObject | migra pra Rust em v3.0 |
| Apps novos (TMJCode, TMJNotes, TMJMoney, TMJRestApi, TMJCriptoBot) | Rust desde nascimento | backlog |

Migração gradual pra Rust = mais performance, single binaries, identidade técnica hardcore.

---

## 🤝 Como Contribuir

```bash
git clone https://github.com/TMJacometti/TMJOs.git
cd TMJOs
git checkout -b feature/sua-feature
# ...code...
git commit -m "feat: sua mudança"
git push origin feature/sua-feature
# Abre PR
```

Cada app tem seu próprio README em [apps/<nome>/](apps/). Pacotes .deb são gerados via CI a cada push.

---

## 📋 Backlog

- [ ] **TMJPad polish** — fix bugs do primeiro build Rust
- [ ] **TMJDock posicionamento** — sempre no monitor interno (eDP/LVDS/DSI)
- [ ] **TMJStore v0.2** — DEP-11 no APT repo + update check daemon + search/filtros
- [ ] **TMJCode** — VSCode-style editor customizado (Rust + gtk4-rs)
- [ ] **TMJNotes** — sticky notes GTK4 com persistência (Rust)
- [ ] **TMJMoney** — controle financeiro pessoal (Rust)
- [ ] **TMJRestApi** — REST client tipo Postman (Rust)
- [ ] **TMJCriptoBot** — bot de trading cripto educacional (Rust)
- [ ] **AppImage** releases pra alcance qualquer Linux x86_64
- [ ] **Flatpak** no Flathub pra distribuição universal

---

## 📝 Licença

GPLv3. Ver [LICENSE](LICENSE).

```
TMJOs Suite — OS DA TMJSistemas · OS MELHORES · OS INSANOS
Copyright (C) 2026 TMJOs Contributors
```

---

## 🐛 Bug Reports

[Abre issue no GitHub](https://github.com/TMJacometti/TMJOs/issues).

---

*Made with 🐉 by TMJSistemas*
