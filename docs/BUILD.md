# 🐧 TMJOS - Guia de Criação Completo

## 📋 Visão Geral
- **Nome**: TMJOs
- **Base**: Ubuntu 24.04 LTS
- **Desktop**: GNOME
- **Estilo**: Clean, Minimalista, Tipo ElementaryOS com Dock estilo Mac
- **Apps**: VSCode, Git, Docker (base slim)
- **Saída**: ISO LiveUSB (~2-3GB)

---

## 🛠️ **FASE 1: PREPARAÇÃO DO AMBIENTE**

### Passo 1.1: Instalar Cubic (ferramenta de customização)
```bash
# Adicionar repositório
sudo add-apt-repository ppa:cubic-wizard/release
sudo apt update

# Instalar Cubic
sudo apt install cubic

# Dar permissão de execução
sudo usermod -aG sudo $USER
```

### Passo 1.2: Preparar espaço em disco
```bash
# Verificar espaço livre (precisa de mínimo 30GB)
df -h

# Criar pasta de trabalho
mkdir -p ~/tmjos-build
cd ~/tmjos-build
```

---

## 🎨 **FASE 2: BUILD DO TMJOS COM CUBIC**

### Passo 2.1: Abrir Cubic e criar projeto
```bash
# Abrir interface gráfica do Cubic
cubic
```

**No Cubic:**
1. Selecione "Create a new custom distribution"
2. Choose Ubuntu 24.04 LTS ISO (baixe se não tiver)
3. Defina pasta de saída: `~/tmjos-build/output`
4. Nome: `TMJOs`
5. Versão: `1.0`

### Passo 2.2: Entrar no chroot (ambiente customizado)
Cubic vai abrir um terminal dentro do Ubuntu base. Agora você customiza:

---

## 📦 **FASE 3: REMOVER E INSTALAR PACOTES**

### Passo 3.1: Remover apps desnecessários (slim)
```bash
# Remover apps padrão pesados
sudo apt remove -y \
  ubuntu-report \
  apport \
  popularity-contest \
  thunderbird \
  firefox \
  libreoffice* \
  games-* \
  gnome-todo \
  gnome-maps \
  gnome-music

# Limpeza
sudo apt autoremove -y
sudo apt autoclean -y
```

### Passo 3.2: Instalar apps essenciais
```bash
# VSCode
sudo apt install -y code

# Git
sudo apt install -y git

# Docker
sudo apt install -y docker.io docker-compose

# Dependências para Dock/Dock-like
sudo apt install -y plank gnome-tweaks

# Ferramentas úteis
sudo apt install -y curl wget htop neofetch
```

### Passo 3.3: Instalar tema limpo e ícones
```bash
# Tema minimalista
sudo apt install -y adwaita-icon-theme gnome-shell-extension-*

# Ou instalar de repositórios (opcional)
# Tema Yaru (padrão Ubuntu clean)
# Já vem por padrão, mas pode customizar depois
```

---

## 🎯 **FASE 4: CUSTOMIZAÇÕES DE INTERFACE**

### Passo 4.1: Configurar GNOME (dentro do Cubic)
```bash
# Instalar ferramentas de customização
sudo apt install -y gnome-shell-extensions gnome-tweaks dconf-editor

# Extensões úteis
sudo apt install -y gnome-shell-extension-dash-to-dock
```

### Passo 4.2: Configurar Plank (Dock tipo Mac)
```bash
# Instalar Plank
sudo apt install -y plank

# Criar arquivo de configuração padrão
mkdir -p ~/.config/plank/dock1
cat > ~/.config/plank/dock1/settings << 'EOF'
[dock1]
# Posição: bottom, left, right, top
position='bottom'
# Tamanho dos ícones
icon-size=48
# Ocultar automaticamente
hide-mode='window-dodge'
# Tema escuro
theme='Transparent'
EOF
```

### Passo 4.3: Customizar Wallpaper e GRUB
```bash
# Wallpaper clean (você pode adicionar depois)
# Por enquanto deixar padrão GNOME (clean mesmo)

# Customizar GRUB (bootloader)
# Editar /etc/default/grub (opcional, para depois)
```

---

## ✅ **FASE 5: FINALIZANDO NO CUBIC**

### Passo 5.1: Dentro do Cubic, rodar último check
```bash
# Verificar se tudo está instalado
code --version
git --version
docker --version
plank --version

# Limpar cache final
sudo apt clean
sudo apt autoclean -y
```

### Passo 5.2: Sair do chroot e gerar ISO
No Cubic:
1. Clique em "Generate ISO"
2. Esperar processar (~20-30 min)
3. ISO será salva em `~/tmjos-build/output/tmjos-1.0-amd64.iso`

---

## 💾 **FASE 6: CRIAR LIVUSB E TESTAR**

### Passo 6.1: Criar LiveUSB
```bash
# Listar pen drives
lsblk

# Desmontar (se montado)
sudo umount /dev/sdX*

# Gravar ISO (substitua sdX pela sua pen)
sudo dd if=~/tmjos-build/output/tmjos-1.0-amd64.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

### Passo 6.2: Testar
1. Rebootar com LiveUSB
2. Verificar:
   - ✅ Boot correto
   - ✅ Dock tipo Mac funcionando
   - ✅ GNOME responsivo
   - ✅ VSCode, Git, Docker disponíveis
   - ✅ Interface limpa e minimalista

---

## 🔧 **TROUBLESHOOTING**

| Problema | Solução |
|----------|---------|
| Cubic não inicia | `sudo cubic` (precisa de root) |
| Sem espaço em disco | Limpar `/tmp`, aumentar partição |
| Docker não funciona | `sudo usermod -aG docker $user` |
| Plank não aparece | `plank --replace &` |
| ISO muito grande | Remover mais apps desnecessários |

---

## 📝 **PRÓXIMOS PASSOS**

- [ ] Customizar tema GNOME (cores, fontes)
- [ ] Adicionar atalhos de teclado personalizados
- [ ] Criar TMJCode (VSCode customizado)
- [ ] Documentação de instalação
- [ ] Repositório Git do projeto

---

## 🚀 **COMMANDS RÁPIDOS**

```bash
# Abrir Cubic
cubic

# Entrar novamente em projeto existente
cubic --project ~/tmjos-build

# Testar ISO em VM (QEMU)
qemu-system-x86_64 -cdrom ~/tmjos-build/output/tmjos-1.0-amd64.iso -m 2G

# Verificar tamanho da ISO
ls -lh ~/tmjos-build/output/tmjos-1.0-amd64.iso
```

---

## 📚 **Recursos**
- [Cubic Docs](https://cubic.frama.io/)
- [Ubuntu Customization Guide](https://wiki.ubuntu.com/)
- [GNOME Extensions](https://extensions.gnome.org/)
- [Plank Documentation](https://wiki.archlinux.org/title/Plank)

---

**Boa sorte com o TMJOs! 🎉**
