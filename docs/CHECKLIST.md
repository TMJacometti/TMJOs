# ✅ TMJOS - Checklist de Criação

## 🎯 OBJETIVO FINAL
```
┌─────────────────────────────────────┐
│         TMJOs Linux Distro          │
├─────────────────────────────────────┤
│ Base: Ubuntu 24.04 LTS              │
│ Desktop: GNOME Clean                │
│ Dock: Tipo Mac (Plank)              │
│ Apps: VSCode, Git, Docker           │
│ Tamanho: ~2-3GB (slim)              │
│ Output: ISO Bootável                │
└─────────────────────────────────────┘
```

---

## 📋 CHECKLIST DE EXECUÇÃO

### ✅ ANTES DE COMEÇAR

- [ ] Ubuntu 24.04 LTS instalado no notebook
- [ ] Mínimo 30GB de espaço em disco livre
- [ ] Conexão internet estável
- [ ] Pen drive 8GB+ (para LiveUSB)
- [ ] Backup de dados importantes

### ✅ FASE 1: INSTALAR CUBIC

```bash
# [1] Adicionar PPA do Cubic
sudo add-apt-repository ppa:cubic-wizard/release

# [2] Atualizar repositórios
sudo apt update

# [3] Instalar Cubic
sudo apt install cubic

# [4] Verificar instalação
cubic --version
```

- [ ] Cubic instalado com sucesso
- [ ] Terminal mostra versão do Cubic

### ✅ FASE 2: CRIAR PROJETO NO CUBIC

**Executar:**
```bash
cubic
```

**No Cubic GUI - Preenchimento de Formulário:**

| Campo | Valor |
|-------|-------|
| **Project Name** | `TMJOs` |
| **Project Version** | `1.0` |
| **Base ISO** | `Ubuntu 24.04 LTS 64-bit` |
| **Output Directory** | `~/tmjos-build/output` |
| **Project Directory** | `~/tmjos-build/project` |

- [ ] Projeto criado no Cubic
- [ ] Cubic entrou no terminal de chroot (aviso: você está em chroot)
- [ ] Pasta de trabalho criada

### ✅ FASE 3: EXECUTAR SCRIPT DE CUSTOMIZAÇÃO

**COPIE O SCRIPT `tmjos_customize.sh` para:**
```bash
# Dentro do terminal do Cubic (chroot)
nano ~/customize.sh
# Cole o conteúdo do script
# Salve: CTRL+O → ENTER → CTRL+X
```

**OU Execute direto:**
```bash
# Se o arquivo está no seu home
bash ~/tmjos_customize.sh
```

- [ ] Script executado sem erros
- [ ] VSCode instalado ✓
- [ ] Git instalado ✓
- [ ] Docker instalado ✓
- [ ] Plank instalado ✓
- [ ] Apps desnecessários removidos ✓
- [ ] Limpeza de cache feita ✓

### ✅ FASE 4: CUSTOMIZAÇÕES MANUAIS (DENTRO DO CHROOT)

#### 4.1 Configurar GNOME
```bash
# Abrir GNOME Tweaks para customizar
gnome-tweaks

# Ou via dconf (configuração avançada)
dconf-editor
```

**Ajustes recomendados:**
- [ ] Tema: `Adwaita-dark` (ou preferência)
- [ ] Ícones: `Adwaita` (padrão clean)
- [ ] Wallpaper: `Padrão GNOME` (limpo)
- [ ] Dock visível na barra inferior
- [ ] Animações ativadas (smooth)
- [ ] Hot corners desativados

#### 4.2 Configurar Plank (Dock)
```bash
# Iniciar Plank
plank &

# Clique DIREITO no Dock → Preferências
# Configure:
```

**Configurações Plank:**
- [ ] Position: `Bottom` (inferior)
- [ ] Icon Size: `48px` (médio)
- [ ] Hide Mode: `Window Dodge` (some ao focar janelas)
- [ ] Theme: `Transparent` (fundo transparente)
- [ ] Alignment: `Center`

#### 4.3 Customizar Apps no Dock
```bash
# Ver arquivos .dockitem disponíveis
ls /usr/share/applications/ | grep -E "(code|nautilus|gnome-control)"

# Adicionar à configuração do Plank (opcional)
# Editar: ~/.config/plank/dock1/settings
```

**Apps recomendados no Dock:**
- [ ] GNOME Control Center (configurações)
- [ ] Files (Nautilus - gerenciador)
- [ ] VSCode
- [ ] Terminal (opcional)

#### 4.4 Configurar Terminal (opcional mas recomendado)
```bash
# Deixar terminal mais limpo
gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false

# Tema escuro automático
gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-style true
```

- [ ] Customizações concluídas
- [ ] Interface limpa e clean ✓
- [ ] Dock funcionando como esperado ✓

### ✅ FASE 5: VERIFICAÇÃO FINAL NO CHROOT

**Sair do editor nano (se ainda estiver):**
```bash
exit  # (se necessário)
```

**Rodar testes finais:**
```bash
# Verificar espaço
df -h /

# Listar pacotes instalados (extras)
dpkg -l | grep -E "(code|docker|git|plank)"

# Teste rápido de cada app
code --version
git --version
docker --version
plank --version

# Limpeza final
sudo apt clean
sudo apt autoclean
sudo apt autoremove -y
```

- [ ] VSCode → responde com versão
- [ ] Git → responde com versão
- [ ] Docker → responde com versão
- [ ] Plank → responde com versão
- [ ] Sem erros de dependência
- [ ] Tamanho estimado: ~2-3GB

### ✅ FASE 6: GERAR ISO NO CUBIC

**No terminal do Cubic (ou GUI):**
1. Clique botão: **`Generate ISO`**
2. Espere processamento (20-40 minutos, depende do PC)
3. Progresso será exibido em tempo real

- [ ] ISO iniciada com sucesso
- [ ] Progresso > 50%
- [ ] Progresso > 90%
- [ ] **ISO gerada em:** `~/tmjos-build/output/tmjos-1.0-amd64.iso`

**Verificar tamanho:**
```bash
# No seu terminal normal (fora do Cubic)
ls -lh ~/tmjos-build/output/tmjos-1.0-amd64.iso

# Esperado: ~2.5-3.0 GB
```

- [ ] Arquivo ISO existe
- [ ] Tamanho entre 2-3GB
- [ ] Sem corrupção (hash check opcional)

### ✅ FASE 7: CRIAR LIVUSB

**Identificar pen drive:**
```bash
# Listar dispositivos
lsblk

# Ou com mais detalhes
sudo fdisk -l | grep "Disk /dev/sd"

# Esperado algo como: /dev/sdb (NÃO /dev/sda!)
```

- [ ] Pen drive identificado (ex: `/dev/sdb`)
- [ ] Pen drive de 8GB+ confirmado
- [ ] Pen drive desmontado

**Gravar ISO na pen:**
```bash
# ⚠️ CUIDADO: Substitua 'sdX' pela sua pen (lsblk confirma)
# ⚠️ AVISO: Isso APAGA o conteúdo da pen!

# Desmontar se montado
sudo umount /dev/sdX*

# Gravar com dd
sudo dd if=~/tmjos-build/output/tmjos-1.0-amd64.iso of=/dev/sdX bs=4M status=progress

# Sincronizar (esperar finalizar!)
sudo sync

# Ejetar seguramente (Linux)
sudo eject /dev/sdX

# Ou (macOS - se usar Mac)
diskutil eject /dev/diskX
```

- [ ] DD iniciado com `status=progress`
- [ ] Progresso mostra 100%
- [ ] Sem mensagem de erro
- [ ] Sync concluído
- [ ] Pen ejetada com segurança

### ✅ FASE 8: TESTAR LIVUSB

**Opção A: Em máquina virtual (RECOMENDADO - seguro)**
```bash
# Instalar QEMU se não tiver
sudo apt install qemu-system-x86

# Testar ISO antes de booting real
qemu-system-x86_64 -cdrom ~/tmjos-build/output/tmjos-1.0-amd64.iso \
  -m 4G \
  -smp 4 \
  -accel kvm \
  -monitor stdio
```

- [ ] VM inicia
- [ ] GRUB (boot menu) aparece
- [ ] Ubuntu carrega
- [ ] GNOME desktop aparece
- [ ] Dock (Plank) visível na base
- [ ] Sem travamento

**Opção B: Booting real na pen (CUIDADOSO)**
1. Rebootar notebook
2. Entrar em BIOS/UEFI (geralmente `F2`, `F12`, `DEL`)
3. Selecionar boot por USB
4. Aguardar carregar

- [ ] Boot pela pen drive funciona
- [ ] GRUB carrega
- [ ] Desktop TMJOs aparece corretamente
- [ ] Todos apps funcionam

### ✅ FASE 9: TESTES DE INTERFACE

**Teste cada elemento:**

```
┌─────────────────────────────────────┐
│ Teste de Interface TMJOs            │
├─────────────────────────────────────┤
│ [ ] Wallpaper carrega               │
│ [ ] GNOME top bar visível           │
│ [ ] Dock (Plank) na base            │
│ [ ] Ícones dos apps visíveis        │
│ [ ] Click no Dock abre apps         │
│ [ ] VSCode funciona                 │
│ [ ] Terminal funciona               │
│ [ ] Configurações GNOME abrem       │
│ [ ] WiFi conecta                    │
│ [ ] Shutdown funciona               │
└─────────────────────────────────────┘
```

- [ ] Visual clean e minimalista ✓
- [ ] Sem elementos desnecessários ✓
- [ ] Dock tipo Mac presente ✓
- [ ] Responsividade OK ✓
- [ ] Apps principais funcionam ✓

---

## 🚀 PÓS-GERAÇÃO

### Para Compartilhar TMJOs

- [ ] ISO testada e funcional
- [ ] Criar README.md com instruções
- [ ] Documentar customizações especiais
- [ ] Considerar criar repositório GitHub
- [ ] Versionar releases

### Próximos Passos

- [ ] **TMJCode**: VSCode customizado com TMJOs branding
- [ ] **Documentação oficial** do TMJOs
- [ ] **Suporte a contribuições** da comunidade
- [ ] **Atualizações periódicas** do kernel/apps

---

## 📞 TROUBLESHOOTING RÁPIDO

| Problema | Solução |
|----------|---------|
| Cubic não abre | `sudo cubic` (precisa root) |
| "sem espaço em disco" | Limpar `/tmp`: `sudo rm -rf /tmp/*` |
| Dock não aparece | `plank --replace &` |
| VSCode lento | Desabilitar extensões desnecessárias |
| ISO > 3GB | Remover mais apps com script |
| Boot USB não funciona | Tentar `CTRL+ALT+DEL` ou resetar BIOS |

---

## 🎯 STATUS FINAL

```
✅ TMJOS v1.0 - PRONTO PARA USAR!

Estatísticas:
├─ ISO Size: 2.5-3.0 GB
├─ Apps Removidos: ~15
├─ Apps Inclusos: VSCode, Git, Docker + essenciais
├─ Desktop: GNOME Limpo
├─ Dock: Plank (tipo Mac)
├─ Boot Time: ~15-20 seg
└─ Experiência: CLEAN & BEAUTIFUL 🎨
```

---

**Parabéns! TMJOs está pronto para o mundo! 🚀🐧**
