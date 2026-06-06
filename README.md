# TMJOs

> **OS DA TMJSistemas · OS MELHORES · OS INSANOS**
>
> Distro Linux minimalista para devs. Ubuntu 26.04 + XFCE, sem bloat, 2GB RAM. Tema neon, apps proprietários, tudo pré-instalado.

![License](https://img.shields.io/badge/license-GPLv3-green)
![Base](https://img.shields.io/badge/base-Ubuntu%2026.04-orange)
![DE](https://img.shields.io/badge/DE-XFCE-blue)
![APT](https://img.shields.io/badge/APT%20repo-packages.tmjos.com.br-blueviolet)

---

## O que é

TMJOs é uma **distro Linux focada em desenvolvimento**, baseada em Ubuntu 26.04 com XFCE. Sem snap, sem bloat, sem frescura. Sobe com 2GB de RAM e já vem com tudo que um dev precisa.

**Pré-instalado de fábrica:**

| Ferramenta | Versão |
|---|---|
| Git | latest |
| VSCode | latest |
| TMJPad | Editor de texto nativo TMJOs (Rust) |
| Python | 3.12 |
| Node.js | LTS |
| .NET SDK | 10 |

**Apps nativos TMJOs:**

| App | O que faz |
|---|---|
| **TMJPad** | Editor de texto com persistência total de sessão — fechou, reabriu, tudo volta |
| **TMJMenu** | Launcher popup (Super+Space) + TMJDock (dock bottom, substitui painel XFCE) |
| **TMJStore** | Software center TMJOs com visual neon |

---

## Download

Baixe a ISO na aba [Releases](https://github.com/TMJacometti/TMJOs/releases). Grave num USB com [balenaEtcher](https://etcher.balena.io/) ou `dd` e instale.

**Requisitos mínimos:**
- CPU: amd64 (x86_64)
- RAM: 2 GB
- Disco: 20 GB

---

## Instalar apps TMJOs em outra distro

Os apps TMJOs funcionam em qualquer Linux Debian-based via APT:

```bash
# Adiciona o repo
curl -fsSL https://packages.tmjos.com.br/keys/tmjos-archive-keyring.gpg \
  | sudo tee /usr/share/keyrings/tmjos-archive-keyring.gpg > /dev/null

echo 'deb [signed-by=/usr/share/keyrings/tmjos-archive-keyring.gpg] https://packages.tmjos.com.br stable main' \
  | sudo tee /etc/apt/sources.list.d/tmjos.list > /dev/null

sudo apt update

# Instala
sudo apt install tmjpad    # Editor de texto
sudo apt install tmjmenu   # Launcher + dock
sudo apt install tmjstore  # Software center
```

---

## Identidade visual

- **Paleta neon**: cyan `#00d4ff`, magenta `#ff2d95`, navy `#0a0e2a`
- **Logo**: dragao + gear
- **Fontes**: JetBrains Mono (mono), Noto Sans (UI)
- **Tema**: dark obrigatorio, contraste forte
- **Boot, login, desktop**: tudo TMJOs, zero branding Ubuntu

---

## Stack

| Componente | Tech |
|---|---|
| Base | Ubuntu 26.04 Server (minimal, sem snap) |
| Desktop | XFCE (sem painel — tmjDock substitui) |
| TMJPad | Rust + GTK4 + libadwaita |
| TMJMenu/TMJDock | Rust + GTK4 + libadwaita |
| TMJStore | Rust + GTK4 + libadwaita |
| Build da ISO | live-build via GitHub Actions |
| Pacotes .deb | dpkg-buildpackage + reprepro, assinados GPG |

---

## Estrutura do repo

```
TMJOs/
├── apps/
│   ├── tmjpad/        # Editor de texto (Rust)
│   ├── tmjmenu/       # Launcher + dock (Rust)
│   └── tmjstore/      # Software center (Rust)
├── distro/
│   ├── build.sh       # Script de build da ISO
│   ├── packages.list  # O que instalar
│   ├── remove.list    # O que remover
│   ├── hooks/         # Scripts executados durante o build
│   └── theme/         # Tema XFCE + terminal
├── packages/          # Configs do APT repo (reprepro, GPG keys)
├── assets/            # Logos, wallpapers
└── .github/workflows/
    ├── build-deb.yml  # CI: builda .deb e publica no APT repo
    └── build-iso.yml  # CI: gera ISO e publica como Release
```

---

## Como contribuir

```bash
git clone https://github.com/TMJacometti/TMJOs.git
cd TMJOs
git checkout -b feature/sua-feature
# ...code...
git commit -m "feat: sua mudanca"
git push origin feature/sua-feature
# Abre PR
```

Cada app tem seu proprio README em `apps/<nome>/`.

---

## Licenca

GPLv3. Ver [LICENSE](LICENSE).

---

*Made with dragao by TMJSistemas*
