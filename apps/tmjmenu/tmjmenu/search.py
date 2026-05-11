"""Discovery e search de aplicações via XDG .desktop entries.

Lê todas as `.desktop` files dos diretórios padrão XDG e fornece busca
fuzzy por nome, comando e keywords. Idêntico em estrutura ao que o
GNOME Shell / Activities faz.
"""

from __future__ import annotations

import configparser
import os
from dataclasses import dataclass
from pathlib import Path


# Diretórios XDG padrão (ordem = prioridade — user override > sistema).
APPLICATIONS_DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
]


@dataclass(frozen=True)
class AppEntry:
    """Representa um app instalado, parseado de uma .desktop entry."""

    desktop_id: str          # ex: "code.desktop" (chave de unicidade)
    name: str                # "Visual Studio Code"
    comment: str             # "Code Editing. Redefined."
    exec_cmd: str            # "/usr/bin/code %F"
    icon: str                # "code" (nome no theme) OU path absoluto
    categories: tuple[str, ...]
    keywords: tuple[str, ...]
    no_display: bool         # apps com NoDisplay=true não aparecem no menu


def _parse_desktop(path: Path) -> AppEntry | None:
    """Parse a single .desktop file. Returns None se inválido/oculto."""
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        cfg.read(path, encoding="utf-8")
    except (UnicodeDecodeError, configparser.Error):
        return None

    if "Desktop Entry" not in cfg:
        return None
    entry = cfg["Desktop Entry"]

    # Filtros básicos — desktop spec
    if entry.get("Type", "").strip() != "Application":
        return None
    if entry.get("Hidden", "false").strip().lower() == "true":
        return None

    name = entry.get("Name", "").strip()
    exec_cmd = entry.get("Exec", "").strip()
    if not name or not exec_cmd:
        return None

    return AppEntry(
        desktop_id=path.name,
        name=name,
        comment=entry.get("Comment", "").strip(),
        exec_cmd=exec_cmd,
        icon=entry.get("Icon", "").strip(),
        categories=tuple(c for c in entry.get("Categories", "").split(";") if c),
        keywords=tuple(k for k in entry.get("Keywords", "").split(";") if k),
        no_display=entry.get("NoDisplay", "false").strip().lower() == "true",
    )


def discover_apps() -> list[AppEntry]:
    """Lista todos os apps instalados (não-ocultos), dedup por desktop_id.

    User overrides em ~/.local/share/applications/ ganham de /usr/share/.
    """
    seen: dict[str, AppEntry] = {}
    for d in APPLICATIONS_DIRS:
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.desktop")):
            if p.name in seen:
                # User-local já foi parseado (vimos antes na ordem) — skip
                continue
            entry = _parse_desktop(p)
            if entry is None or entry.no_display:
                continue
            seen[p.name] = entry
    return list(seen.values())


def fuzzy_match(query: str, app: AppEntry) -> int:
    """Retorna score >=0 se app casa com query, ou -1 se não.

    Maior = melhor match. Regras simples:
    - Match no início do nome:       100
    - Substring no nome (case-i):     50
    - Substring no comment:           20
    - Substring em keywords:          15
    - Substring no exec:              10
    """
    if not query:
        return 0  # vazio = todos passam, ordem original

    q = query.casefold().strip()
    name = app.name.casefold()
    comment = app.comment.casefold()
    exec_cmd = app.exec_cmd.casefold()

    if name.startswith(q):
        return 100
    if q in name:
        return 50
    if q in comment:
        return 20
    if any(q in k.casefold() for k in app.keywords):
        return 15
    if q in exec_cmd:
        return 10
    return -1


def search(apps: list[AppEntry], query: str) -> list[AppEntry]:
    """Filtra + ordena apps por relevância pra query.

    Query vazia → todos os apps em ordem alfabética por nome.
    """
    if not query.strip():
        return sorted(apps, key=lambda a: a.name.casefold())

    scored = []
    for app in apps:
        s = fuzzy_match(query, app)
        if s >= 0:
            scored.append((s, app.name.casefold(), app))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [a for _, _, a in scored]
