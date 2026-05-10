# TMJPad

> **Editor de texto sem frescura. Múltiplas abas. Zero perda de dados.**

TMJPad é o editor de texto nativo do TMJOs. Foco no que importa:

- ✅ **Múltiplas abas** com Ctrl+T / Ctrl+W / Ctrl+Tab
- ✅ **Persistência total**: ao fechar a janela, salva o estado de TODAS as abas
  (incluindo as não-salvas). Ao reabrir, tudo volta exatamente como estava.
- ✅ **Auto-save de buffer** a cada modificação (debounce 500ms) — se travar,
  perder energia, kill -9, nada se perde
- ✅ **Dark theme único**, fonte mono, paleta TMJOs (cyan/magenta sobre navy)
- ✅ **Find básico** (Ctrl+F)
- ❌ Sem plugins, extensões, syntax highlighting, multi-cursor, macros, light
  theme. **Sem frescura.**

## Stack

- Python 3.12+
- GTK 4 + libadwaita (PyGObject)
- Apenas dependências standard library + `gi` (PyGObject)

## Instalar (dev)

```bash
# Dentro do TMJOs/apps/tmjpad
python3 -m tmjpad
```

## Instalar (sistema)

```bash
make install
# Atalho aparece no menu de apps como "TMJPad"
```

## Atalhos

| Atalho | Ação |
|--------|------|
| `Ctrl+N` | Nova aba |
| `Ctrl+O` | Abrir arquivo |
| `Ctrl+S` | Salvar aba atual |
| `Ctrl+Shift+S` | Salvar como |
| `Ctrl+W` | Fechar aba atual |
| `Ctrl+Tab` | Próxima aba |
| `Ctrl+Shift+Tab` | Aba anterior |
| `Ctrl+F` | Find |

## Persistência — como funciona

```
~/.config/tmjpad/
├── session.json          # estado das abas (ordem, paths, cursor, ativa)
└── buffers/
    ├── <uuid>.txt        # conteúdo de cada aba (auto-save)
    └── <uuid>.txt
```

**Fonte de verdade ao restaurar:** os arquivos em `buffers/`. O `session.json`
descreve apenas como exibir (ordem, ativa, cursor). Se a sessão crashar mid-write,
os buffers preservam o conteúdo mais recente.

**Atomic writes:** todo write usa `tmp file + rename` pra evitar corrupção.

## Status

🚧 v0.1 — MVP em desenvolvimento. Parte do TMJOs v1.1.

## Licença

GPLv3 — junto com o TMJOs.
