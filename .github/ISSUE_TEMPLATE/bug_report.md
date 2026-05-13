---
name: 🐛 Bug Report
about: Reportar um bug ou comportamento inesperado
title: "[BUG] "
labels: bug
assignees: ''
---

## Descrição do Bug

Descrição clara e concisa do problema.

## Como Reproduzir

1. ...
2. ...
3. ...

## Comportamento Esperado

O que deveria acontecer.

## Comportamento Real

O que realmente aconteceu.

## Screenshots / Logs

Se aplicável, anexe screenshots ou cole logs:

```
journalctl -xe | tail -50
```

## Ambiente

- **App afetado**: <!-- ex: tmjpad, tmjmenu, tmjstore -->
- **Versão do app**: <!-- saída de `apt show tmjpad | grep Version` -->
- **Distro + versão**: <!-- ex: Ubuntu 24.04, Debian trixie, Linux Mint 22 -->
- **Sessão**: <!-- X11 ou Wayland — saída de `echo $XDG_SESSION_TYPE` -->
- **Hardware**: <!-- opcional, ex: Dell XPS 13 i7 16GB -->

## Checklist

- [ ] Consegui reproduzir o bug consistentemente
- [ ] Procurei por issues similares já abertas
- [ ] Estou na versão mais recente (`apt update && apt upgrade <app>`)
