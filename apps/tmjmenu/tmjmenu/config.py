"""Persistência de configuração do TMJMenu/TMJDock.

Apps pinados ficam em ~/.config/tmjmenu/pinned.json — lista de
desktop_ids (ex: ["code.desktop", "tmjpad.desktop"]).

API estável:
  load_pinned() -> list[str]
  save_pinned(items: list[str]) -> None
  add_pinned(desktop_id: str) -> bool      # True se adicionou
  remove_pinned(desktop_id: str) -> bool   # True se removeu
  is_pinned(desktop_id: str) -> bool
"""

from __future__ import annotations

import json
import os
from pathlib import Path

CONFIG_DIR = Path(
    os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
) / "tmjmenu"
PINNED_FILE = CONFIG_DIR / "pinned.json"

# Default first-run set — VSCode, Terminal, Files, TMJPad.
DEFAULT_PINNED: list[str] = [
    "code.desktop",
    "org.gnome.Terminal.desktop",
    "org.gnome.Nautilus.desktop",
    "tmjpad.desktop",
]


def load_pinned() -> list[str]:
    """Lê pinned.json. Fallback pra DEFAULT_PINNED se file não existe
    ou é inválido. Não cria o arquivo no read (só no save)."""
    if PINNED_FILE.is_file():
        try:
            data = json.loads(PINNED_FILE.read_text(encoding="utf-8"))
            if isinstance(data, list) and all(isinstance(x, str) for x in data):
                return data
        except (json.JSONDecodeError, OSError):
            pass
    return list(DEFAULT_PINNED)


def save_pinned(items: list[str]) -> None:
    """Atomic write de pinned.json — tmp + rename pra não corromper
    se o processo morrer no meio."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp = PINNED_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(items, indent=2), encoding="utf-8")
    tmp.replace(PINNED_FILE)


def add_pinned(desktop_id: str) -> bool:
    items = load_pinned()
    if desktop_id in items:
        return False
    items.append(desktop_id)
    save_pinned(items)
    return True


def remove_pinned(desktop_id: str) -> bool:
    items = load_pinned()
    if desktop_id not in items:
        return False
    items.remove(desktop_id)
    save_pinned(items)
    return True


def is_pinned(desktop_id: str) -> bool:
    return desktop_id in load_pinned()
