# TMJPad

> **Editor de texto sem frescura. Múltiplas abas. Zero perda de dados.**

TMJPad é o editor de texto nativo do TMJOs. Foco no que importa:

- **Múltiplas abas** com Ctrl+N / Ctrl+W / Ctrl+Tab
- **Persistência total**: ao fechar a janela, salva o estado de TODAS as abas
  (incluindo as não-salvas). Ao reabrir, tudo volta exatamente como estava.
- **Auto-save de buffer** a cada modificação (debounce 500ms) — se travar,
  perder energia, kill -9, nada se perde
- **Dark theme único**, fonte mono, paleta TMJOs (cyan/magenta sobre navy)
- **Find & Replace** (Ctrl+F / Ctrl+H)
- Sem plugins, extensões, syntax highlighting, multi-cursor, macros, light
  theme. **Sem frescura.**

## Stack

- Rust 1.75+ (edition 2021)
- GTK 4.12 + libadwaita 1.5 (gtk4-rs)
- Serde + serde_json (persistência)
- Zero runtime dependencies além de GTK

## Build

```bash
cd apps/tmjpad
cargo build --release
```

O binário fica em `target/release/tmjpad`.

## Instalar (dev)

```bash
cargo run
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
| `Ctrl+F` | Find (busca incremental, Enter avança, Shift+Enter volta, Esc fecha) |
| `Ctrl+H` | Find & Replace (botões Replace e Replace All) |

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

## Licença

GPLv3 — junto com o TMJOs.
