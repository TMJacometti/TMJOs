"""Session and buffer persistence for TMJPad.

Each open tab has a buffer file at ~/.config/tmjpad/buffers/<uuid>.txt that
mirrors the current text. The session.json file holds tab list (order, paths,
cursor positions, active tab, window size).

Auto-save writes to buffer files on every modification (debounced). The
session.json is rewritten on tab open/close/save/reorder.

Goal: zero data loss even on hard crash. Source of truth on restart is the
buffer files; session.json describes how to display them.

This module is pure Python (no GTK) so it's easily unit-testable.
"""
from __future__ import annotations

import json
import os
import uuid
from dataclasses import asdict, dataclass, field
from pathlib import Path


def _config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "tmjpad"


CONFIG_DIR = _config_dir()
BUFFERS_DIR = CONFIG_DIR / "buffers"
SESSION_FILE = CONFIG_DIR / "session.json"


@dataclass
class TabState:
    """Persistent state of a single tab."""

    id: str
    title: str
    path: str | None  # filesystem path; None for untitled
    cursor_offset: int = 0

    def buffer_path(self, base: Path = BUFFERS_DIR) -> Path:
        return base / f"{self.id}.txt"


@dataclass
class Session:
    tabs: list[TabState] = field(default_factory=list)
    active_index: int = 0
    window_width: int = 1100
    window_height: int = 700

    @classmethod
    def load(cls, session_file: Path = SESSION_FILE) -> Session:
        """Read session.json. Returns empty Session if missing or corrupt.

        On corruption, the bad file is renamed to .json.bak so debug is possible.
        """
        if not session_file.exists():
            return cls()
        try:
            raw = json.loads(session_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            session_file.replace(session_file.with_suffix(".json.bak"))
            return cls()
        try:
            tabs = [TabState(**t) for t in raw.get("tabs", [])]
            return cls(
                tabs=tabs,
                active_index=raw.get("active_index", 0),
                window_width=raw.get("window_width", 1100),
                window_height=raw.get("window_height", 700),
            )
        except (TypeError, KeyError):
            session_file.replace(session_file.with_suffix(".json.bak"))
            return cls()

    def save(self, session_file: Path = SESSION_FILE) -> None:
        """Atomic write: tmp file + rename."""
        session_file.parent.mkdir(parents=True, exist_ok=True)
        BUFFERS_DIR.mkdir(parents=True, exist_ok=True)
        tmp = session_file.with_suffix(".json.tmp")
        payload = {
            "tabs": [asdict(t) for t in self.tabs],
            "active_index": self.active_index,
            "window_width": self.window_width,
            "window_height": self.window_height,
        }
        tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        tmp.replace(session_file)


def new_tab_state(title: str = "Untitled-1", path: str | None = None) -> TabState:
    return TabState(id=str(uuid.uuid4()), title=title, path=path)


def write_buffer(state: TabState, content: str, base: Path = BUFFERS_DIR) -> None:
    """Atomic write of buffer content."""
    base.mkdir(parents=True, exist_ok=True)
    buf = state.buffer_path(base)
    tmp = buf.with_suffix(".tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(buf)


def read_buffer(state: TabState, base: Path = BUFFERS_DIR) -> str:
    buf = state.buffer_path(base)
    if buf.exists():
        return buf.read_text(encoding="utf-8")
    return ""


def remove_buffer(state: TabState, base: Path = BUFFERS_DIR) -> None:
    buf = state.buffer_path(base)
    if buf.exists():
        buf.unlink()


def next_untitled_title(existing_titles: set[str]) -> str:
    """Generate next available 'Untitled-N' name not in existing_titles."""
    n = 1
    while f"Untitled-{n}" in existing_titles:
        n += 1
    return f"Untitled-{n}"
