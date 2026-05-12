# Contribuindo com o TMJOs

Valeu pelo interesse em contribuir! 🐧

O TMJOs é uma distro Linux focada em **clean, minimalismo e produtividade pra devs**. Mantemos o escopo enxuto de propósito — nem toda feature legal cabe na distro.

---

## Como Contribuir

### 🐛 Reportar Bugs

1. Procure se já existe uma [issue](https://github.com/tmjacometti/tmjos/issues) similar
2. Se não houver, abra uma nova usando o template de **Bug Report**
3. Descreva como reproduzir, o que esperava e o que aconteceu
4. Inclua sua versão (`TMJOs v1.0`), hardware e logs relevantes

### ✨ Sugerir Features

1. Abra uma issue usando o template de **Feature Request**
2. Explique o caso de uso — por que isso ajudaria os usuários do TMJOs?
3. Antes de implementar mudanças grandes, **discuta primeiro**. Evita retrabalho.

### 💻 Enviar Código

1. **Fork** do repositório
2. Crie uma branch: `git checkout -b feature/sua-feature` ou `fix/seu-fix`
3. Faça suas mudanças seguindo as convenções abaixo
4. Teste localmente (preferencialmente em VM)
5. Commit com mensagem semântica (veja abaixo)
6. **Push** e abra um **Pull Request** usando o template

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
- `feat: adiciona wallpaper TMJOs blue`
- `fix: corrige hook de live-build`
- `docs: atualiza guia de build com nova versão do live-build`

### Estrutura de Pastas

```
tmjos/
├── docs/          # Documentação técnica
├── scripts/       # Scripts de build e customização
├── assets/        # Wallpapers, ícones, screenshots
├── .github/       # Templates de issue/PR, workflows
└── .local/        # (gitignored — não commitar)
```

### Estilo de Código

- **Shell scripts**: `set -euo pipefail` no topo, validar com `bash -n` e idealmente `shellcheck`
- **Markdown**: linhas curtas (~80 chars), use code fences com linguagem
- Comentários em inglês quando o público-alvo é amplo, em PT-BR quando é interno

---

## O Que Está no Escopo

✅ Fica no TMJOs:
- Customizações do GNOME que mantêm a interface limpa
- Apps essenciais pra dev (editor, git, container runtime)
- Scripts e docs do processo de build
- Temas, wallpapers e branding
- Otimizações de tamanho/performance da ISO

❌ **Fora** do escopo (geralmente):
- Aplicativos pesados (suite office, players, etc.)
- Customizações que duplicam funcionalidades do GNOME
- Mudanças que aumentam significativamente o tamanho da ISO

---

## Build Local

Pra testar suas mudanças no script de customização sem refazer toda ISO, dá pra rodar em uma VM Debian 13 (trixie) limpa OU em um container `debian:trixie`:

```bash
# Em uma VM/container Debian 13 (NÃO no seu host!)
sudo bash scripts/tmjos_customize.sh
```

⚠️ **Não rode esse script no seu host de trabalho** — ele adiciona repos extras e instala stack completa do TMJOs. Use VM ou container.

---

## Dúvidas?

- 💬 Discussions: https://github.com/tmjacometti/tmjos/discussions
- 🐛 Issues: https://github.com/tmjacometti/tmjos/issues

Toda contribuição é bem-vinda — desde reportar typo até enviar uma feature grande. 🚀
