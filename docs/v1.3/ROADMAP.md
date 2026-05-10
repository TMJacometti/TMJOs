# TMJOs v1.3 — Roadmap detalhado

> **Codename:** _a definir_
> **Tema:** Sistema de updates próprio + apps store

v1.3 é a virada arquitetural — sai de "ISO custom estática" pra
"distro com pipeline de updates contínuo". Cada componente do core
vira `.deb` versionado distribuído via APT repo público hospedado
em GitHub Pages.

---

## 🎯 Objetivos da v1.3

1. **Pacote do core como `.deb` versionado** — usuários instalados
   recebem fixes via `sudo apt upgrade tmjos` sem reinstalar ISO.
2. **APT repo público** em `packages.tmjos.dev` (ou fallback
   `tmjacometti.github.io/tmjos-packages`).
3. **TMJOs Software Center** — GUI GTK4 sobre apt, branding TMJOs.
4. **TMJPad re-empacotado** como `.deb` (primeiro app real no repo).
5. **Polish residual:** GRUB visual theme, GDM customizado, sons.

> **TMJCode foi movido pra v1.4** junto com TMJNotes — ambos são
> apps novos que dependem da store estar madura.

---

## 🗺️ Fases (ordem de implementação)

### Fase 1 — Setup do APT repo (FUNDAÇÃO)

Sem esse, nada do resto roda.

- [ ] Estrutura de diretórios em `packages/` (este branch)
- [ ] GPG key TMJOs gerada localmente
  - Public key commitada em `packages/keys/tmjos-archive-keyring.asc`
  - Private key em variável secreta GitHub Actions (`GPG_SIGNING_KEY`)
- [ ] Reprepro ou aptly config em `packages/conf/distributions`
  - Distribution: `noble`
  - Components: `main`
  - Architectures: `amd64 source`
- [ ] GitHub Action `.github/workflows/build-deb.yml`
  - Trigger: push em `main` que tocar em `packages/sources/`
  - Build .deb pra cada `packages/sources/<pkg>/`
  - Sign + reprepro include
  - Push pra branch `gh-pages` que vira o repo público
- [ ] GitHub Pages habilitado pra branch `gh-pages`
  - URL final: `https://tmjacometti.github.io/TMJOs/`
- [ ] (Opcional, futuro) Apontar `packages.tmjos.dev` CNAME
- [ ] Customize.sh adiciona repo em
  `/etc/apt/sources.list.d/tmjos.list` na ISO
- [ ] Customize.sh copia public key pra
  `/usr/share/keyrings/tmjos-archive-keyring.gpg`

**Validation:** subir um `tmjos-hello_0.1_all.deb` dummy, fazer
`apt update + apt install tmjos-hello` em VM TMJOs nova.

### Fase 2 — Empacotar o core do TMJOs como .deb

Refatora `scripts/tmjos_customize.sh` em pacotes versionados.
Cada um com `debian/` dir (control, postinst, postrm, etc).

- [ ] **`tmjos-branding`** (= versão do release, ex 1.3.0)
  - `/usr/share/backgrounds/tmjos/tmjos_wallpaper.png`
  - `/usr/share/backgrounds/tmjos/tmjos_wallpaper_4k.png`
  - `/usr/share/icons/tmjos/TMJOs_Logo_*.png`
  - `/usr/share/icons/hicolor/512x512/apps/tmjos.png`
  - `/usr/share/pixmaps/tmjos.png`
  - `/usr/share/plymouth/themes/tmjos/*`
  - **postinst**: `update-alternatives --set default.plymouth ...`
    + `update-initramfs -u` + `gtk-update-icon-cache`
- [ ] **`tmjos-os-identity`**
  - `/etc/os-release`, `/etc/lsb-release`, `/etc/issue`,
    `/etc/issue.net`
  - Marcar `os-release` e `lsb-release` como `conffile`
  - **postinst**: nada (arquivos já em lugar)
- [ ] **`tmjos-dock`**
  - `/etc/skel/.config/plank/dock1/*`
  - `/etc/xdg/autostart/plank.desktop`
  - `/etc/xdg/autostart/tmjos-first-run.desktop`
  - `/etc/xdg/autostart/tmjos-dock-sync.desktop`
  - `/usr/local/bin/tmjos-first-run`
  - `/usr/local/bin/tmjos-show-apps`
  - `/usr/local/bin/tmjos-dock-sync`
  - `/usr/share/applications/tmjos-show-apps.desktop`
  - **Depends:** `plank, xdotool`
- [ ] **`tmjos-defaults`** (dconf)
  - `/etc/dconf/db/local.d/00-tmjos-defaults`
  - `/etc/dconf/profile/user`
  - **postinst:** `dconf update`
- [ ] **`tmjos-shell-tweaks`** (CSS hack do Activities)
  - Patch em `/usr/share/gnome-shell/theme/Yaru*/gnome-shell.css`
  - **Cuidado:** pacote tem que ter conflito declarado com
    `gnome-shell-common` se ele sobrescrever, ou usar override
  - Alternativa segura: instalar tema TMJOs próprio em
    `/usr/share/gnome-shell/theme/TMJOs/` e setar via dconf
- [ ] **`tmjpad`** (versão própria 0.1.x)
  - `/opt/tmjpad/*`
  - `/usr/local/bin/tmjpad`
  - `/usr/share/applications/tmjpad.desktop`
  - `/usr/share/icons/hicolor/256x256/apps/tmjpad.png`
  - **Depends:** `python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1`
  - **postinst:** `gtk-update-icon-cache`
- [ ] **`tmjos`** (meta-package)
  - Sem files. Só `Depends:` em todos os tmjos-* + apps base
  - Versão sincroniza com o release (1.3.0, 1.3.1, 1.4.0)

**Validation:**

```bash
# Em VM TMJOs v1.2.0 instalada (ainda sem o repo)
sudo apt update
sudo apt install --reinstall tmjos
# ↑ instala metapackage, que puxa tmjos-branding-1.3, etc
# Depois disso, /etc/os-release deve dizer 1.3, plymouth muda, etc
```

### Fase 3 — TMJOs Software Center

GUI GTK4 sobre apt, listando apps com tag `tmjos-app`.

- [ ] App em `apps/tmjos-store/` (similar estrutura do TMJPad)
- [ ] Lista apps via `apt-cache search '^tmj'` filtrado
- [ ] Botões Install/Update/Remove via PolicyKit (pkexec apt)
- [ ] Visual: dark theme, paleta TMJOs neon
- [ ] **Depends:** `python3-gi, gir1.2-gtk-4.0, packagekit`
- [ ] Empacotado como `tmjos-store.deb` no APT repo

### Fase 4 — Polish residual

- [ ] GRUB visual theme TMJOs (background + cores neon)
- [ ] GDM (login screen) com wallpaper TMJOs
- [ ] Sons custom de boot/shutdown
- [ ] ARM64 build

---

## 🚦 Release flow v1.3

```
1. Trabalho em branch  feature/<task>
2. PR pra main
3. Merge → GitHub Action builda .deb afetados
4. APT repo atualizado em gh-pages
5. Quando todas as features completam → tag v1.3.0
6. Gera ISO v1.3.0 com Cubic
7. GitHub Release com ISO + changelog
```

---

## 📦 Estrutura de diretórios pretendida

```
TMJOs/
├── packages/                   ← NEW: source do APT repo
│   ├── conf/
│   │   └── distributions       ← reprepro config
│   ├── keys/
│   │   └── tmjos-archive-keyring.asc  ← GPG public key
│   ├── sources/                ← uma subpasta por pacote
│   │   ├── tmjos-branding/
│   │   │   ├── debian/
│   │   │   │   ├── control
│   │   │   │   ├── changelog
│   │   │   │   ├── postinst
│   │   │   │   └── rules
│   │   │   └── files/
│   │   ├── tmjos-os-identity/
│   │   ├── tmjos-dock/
│   │   ├── tmjos-defaults/
│   │   ├── tmjos-shell-tweaks/
│   │   ├── tmjpad/
│   │   ├── tmjos-store/
│   │   ├── tmjcode/
│   │   └── tmjos/              ← meta-package
│   └── README.md
└── .github/workflows/
    └── build-deb.yml           ← CI/CD
```

---

## 🐛 Issues conhecidas a resolver no caminho

- **TMJPad icon não aparece (v1.2.0)** — primeiro caso de teste do
  sistema de updates: empacotar `tmjpad_0.1.1` com fix de icon-cache
  e verificar `apt upgrade tmjpad` em VM v1.2.0 instalada.
- **Activities button CSS hack** — pode não pegar em GNOME 46. Vai
  virar `tmjos-shell-tweaks` package (Fase 2) com tema custom.

---

## 🎓 Recursos

- Reprepro tutorial: https://wiki.debian.org/HowToSetupADebianRepository
- aptly (alternativa moderna): https://www.aptly.info/
- GitHub Pages como APT repo: tem vários blogposts
- Debian packaging guide: https://www.debian.org/doc/manuals/maint-guide/

---

**Próximo passo concreto:** começar pela Fase 1.1 — gerar GPG key TMJOs
e commitar a public key em `packages/keys/`.
