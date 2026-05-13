# ✅ TMJOs — Checklist de Release (v2.0+ Debian)

## 🎯 OBJETIVO FINAL

```
┌─────────────────────────────────────┐
│         TMJOs Linux Distro          │
├─────────────────────────────────────┤
│ Base: Debian 13 (trixie)            │
│ Desktop: GNOME + TMJDock            │
│ Installer: Calamares                │
│ Apps: TMJOs stack + VSCode/Git      │
│ ISO target: ~3-4GB                  │
└─────────────────────────────────────┘
```

---

## 📋 CHECKLIST DE EXECUÇÃO

### ✅ ANTES DE COMEÇAR

- [ ] Host Debian/Ubuntu/derivada (testado em Ubuntu 24.04 e Debian 12)
- [ ] Mínimo 30GB livres em `$HOME`
- [ ] Conexão internet estável (ISO baixa ~2GB de pacotes)
- [ ] Pen drive 8GB+ pra LiveUSB
- [ ] Backup de dados importantes

### ✅ FASE 1 — DEPS DO HOST

```bash
sudo apt update
sudo apt install -y \
    live-build debootstrap xorriso \
    squashfs-tools debian-archive-keyring git
```

- [ ] `lb --version` mostra >= 1:20230502 (a57 ou superior funciona)
- [ ] `debootstrap --version` ok

### ✅ FASE 2 — `lb config`

```bash
mkdir -p ~/tmjos-debian-build
cd ~/tmjos-debian-build

sudo lb config \
    --distribution trixie \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --mirror-bootstrap http://deb.debian.org/debian/ \
    --mirror-chroot http://deb.debian.org/debian/ \
    --mirror-binary http://deb.debian.org/debian/ \
    --parent-mirror-bootstrap http://deb.debian.org/debian/ \
    --security false \
    --apt-recommends true
```

- [ ] `config/` dir criado
- [ ] `grep -r '^LB_.*archive.ubuntu' config/` retorna vazio
- [ ] `grep -r 'trixie/updates' config/` retorna vazio
- [ ] `grep -r 'deb.debian.org' config/` retorna entries

### ✅ FASE 3 — POPULA CONFIG TMJOS

**Opção A (recomendado): master script faz tudo (config + hooks + build)**

```bash
sudo ~/Projetos/GitHub/TMJOs/tools/tmjos-build.sh
```

**Opção B: stepwise (debug)**

```bash
sudo ~/Projetos/GitHub/TMJOs/tools/tmjos-lb-config.sh    # config Debian limpo
sudo ~/Projetos/GitHub/TMJOs/tools/tmjos-hooks-setup.sh  # popula hooks
```

- [ ] `config/hooks/0100-tmjos-debian-base.chroot_early` instala a base Debian main
- [ ] `config/package-lists/` não contém listas `.chroot` (evita trava em `lb_chroot_package-lists`)
- [ ] `config/hooks/normal/0500-tmjos-apt-install.hook.chroot` adiciona os repos TMJOs/Microsoft e instala `tmjos code`
- [ ] `config/hooks/normal/0700-tmjos-slim.hook.chroot` remove bloat e mascara serviços pesados
- [ ] `config/hooks/normal/0900-tmjos-setup.hook.chroot` é executável

### ✅ FASE 4 — BUILD

```bash
sudo lb build 2>&1 | tee build.log
```

- [ ] Bootstrap completa sem erro
- [ ] Chroot phase: apt install -y tmjos resolve
- [ ] Binary phase: squashfs gerado
- [ ] `*.hybrid.iso` aparece em `~/tmjos-debian-build/`
- [ ] ISO < 5GB (ideal: 3-4GB)

### ✅ FASE 5 — TESTE EM VM

**virt-manager (recomendado):**

```bash
virt-manager
# New VM → Local install media → live-image-amd64.hybrid.iso
# RAM 4G · CPUs 2 · Disco 30G
```

- [ ] VM boota via GRUB
- [ ] GNOME live session carrega
- [ ] Wallpaper TMJOs aparece
- [ ] Plymouth boot splash mostra branding TMJOs
- [ ] TMJMenu abre via Super+Space
- [ ] TMJDock visível no bottom
- [ ] TMJPad abre e persiste abas
- [ ] TMJStore lista pacotes TMJOs
- [ ] Sessão sem crashes / rendering ok

### ✅ FASE 6 — INSTALL (Calamares)

- [ ] Ícone "Install TMJOs" no desktop live
- [ ] Calamares abre sem WebKit error
- [ ] Particionamento manual funciona
- [ ] Usuário criado com sucesso
- [ ] Instalação completa sem erro
- [ ] Reboot pro sistema instalado funciona
- [ ] GDM mostra logo TMJOs
- [ ] Login → desktop TMJOs completo
- [ ] `apt update && apt upgrade tmjos` funciona no instalado

### ✅ FASE 7 — LIVEUSB FINAL

```bash
# Substituir sdX pela pen correta (lsblk pra conferir)
sudo umount /dev/sdX*
sudo dd if=~/tmjos-debian-build/live-image-amd64.hybrid.iso \
    of=/dev/sdX bs=4M status=progress conv=fsync
sync
sudo eject /dev/sdX
```

- [ ] DD termina sem erro
- [ ] Sync completo
- [ ] Pen ejetada
- [ ] Boot real em hardware funciona

### ✅ FASE 8 — RELEASE

- [ ] SHA256 da ISO computado: `sha256sum *.iso > tmjos.iso.sha256`
- [ ] Upload pro Cloudflare R2 (`tmjos-v2.0.0-alpha-amd64.iso`)
- [ ] Tag git (`v2.0.0-alpha`)
- [ ] CHANGELOG.md atualizado
- [ ] GitHub release publicado com link R2 + checksum

---

## 🔧 TROUBLESHOOTING

| Problema | Solução |
|---|---|
| `lb config` falha | Confira flags `--mirror-*` explícitos |
| Build trava em bootstrap | Mirror down? Tenta `http://ftp.br.debian.org/debian/` |
| Hook falha | Ver `build.log`, hook precisa ser `/bin/sh` portable |
| Pacote `tmjos` não resolve | APT repo trixie ainda não publicou? Conferir CI no GitHub Actions |
| ISO não boota | Confere se `--binary-images iso-hybrid` foi passado |
| GRUB ok mas live falha | Falta `live-boot` + `live-config` na package-list |

---

## 📞 STATUS FINAL ESPERADO

```
✅ TMJOs v2.0.0-alpha — PRONTO PARA TEST!

Estatísticas:
├─ ISO Size: 3-4 GB
├─ Base: Debian 13 (trixie)
├─ Desktop: GNOME + TMJMenu/TMJDock
├─ Installer: Calamares
├─ APT repo: packages.tmjos.com.br (trixie main apps extras)
├─ Boot Time: ~10-15 seg
└─ Experiência: NEON, DARK, INSANO 🐉
```
