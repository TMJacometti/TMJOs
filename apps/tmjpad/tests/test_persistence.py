"""Tests for tmjpad.persistence — pure Python, no GTK."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

# Make tmjpad package importable when running pytest from this dir
sys.path.insert(0, str(Path(__file__).parent.parent))

from tmjpad.persistence import (
    Session,
    TabState,
    new_tab_state,
    next_untitled_title,
    read_buffer,
    remove_buffer,
    write_buffer,
)


@pytest.fixture
def tmp_buffers(tmp_path: Path) -> Path:
    base = tmp_path / "buffers"
    base.mkdir()
    return base


@pytest.fixture
def tmp_session(tmp_path: Path) -> Path:
    return tmp_path / "session.json"


# ---- TabState ----

def test_new_tab_state_has_unique_id():
    a = new_tab_state()
    b = new_tab_state()
    assert a.id != b.id


def test_buffer_path_uses_id(tmp_buffers: Path):
    state = TabState(id="abc", title="x", path=None)
    assert state.buffer_path(tmp_buffers).name == "abc.txt"


# ---- buffer write/read ----

def test_write_then_read_buffer(tmp_buffers: Path):
    state = new_tab_state()
    write_buffer(state, "hello\nworld", base=tmp_buffers)
    assert read_buffer(state, base=tmp_buffers) == "hello\nworld"


def test_read_buffer_missing_returns_empty(tmp_buffers: Path):
    state = new_tab_state()
    assert read_buffer(state, base=tmp_buffers) == ""


def test_remove_buffer_deletes_file(tmp_buffers: Path):
    state = new_tab_state()
    write_buffer(state, "x", base=tmp_buffers)
    assert state.buffer_path(tmp_buffers).exists()
    remove_buffer(state, base=tmp_buffers)
    assert not state.buffer_path(tmp_buffers).exists()


def test_write_buffer_is_atomic(tmp_buffers: Path):
    """No .tmp file left behind after successful write."""
    state = new_tab_state()
    write_buffer(state, "data", base=tmp_buffers)
    leftover_tmps = list(tmp_buffers.glob("*.tmp"))
    assert leftover_tmps == []


def test_write_buffer_unicode(tmp_buffers: Path):
    state = new_tab_state()
    content = "olá 🐉 → λ"
    write_buffer(state, content, base=tmp_buffers)
    assert read_buffer(state, base=tmp_buffers) == content


# ---- Session save/load ----

def test_save_load_roundtrip(tmp_session: Path):
    s = Session(
        tabs=[
            TabState(id="1", title="a.md", path="/tmp/a.md", cursor_offset=10),
            TabState(id="2", title="Untitled-1", path=None, cursor_offset=0),
        ],
        active_index=1,
        window_width=1280,
        window_height=720,
    )
    s.save(session_file=tmp_session)
    loaded = Session.load(session_file=tmp_session)
    assert len(loaded.tabs) == 2
    assert loaded.tabs[0].title == "a.md"
    assert loaded.tabs[0].path == "/tmp/a.md"
    assert loaded.tabs[0].cursor_offset == 10
    assert loaded.tabs[1].path is None
    assert loaded.active_index == 1
    assert loaded.window_width == 1280
    assert loaded.window_height == 720


def test_load_missing_returns_empty(tmp_session: Path):
    assert not tmp_session.exists()
    loaded = Session.load(session_file=tmp_session)
    assert loaded.tabs == []
    assert loaded.active_index == 0


def test_load_corrupt_json_renames_to_bak(tmp_session: Path):
    tmp_session.write_text("not json {{{")
    loaded = Session.load(session_file=tmp_session)
    assert loaded.tabs == []
    assert tmp_session.with_suffix(".json.bak").exists()
    assert not tmp_session.exists()


def test_load_invalid_schema_renames_to_bak(tmp_session: Path):
    """Tabs with missing required fields are caught and don't crash."""
    tmp_session.write_text(json.dumps({"tabs": [{"foo": "bar"}]}))
    loaded = Session.load(session_file=tmp_session)
    assert loaded.tabs == []
    assert tmp_session.with_suffix(".json.bak").exists()


def test_save_creates_parent_dir(tmp_path: Path):
    deep = tmp_path / "a" / "b" / "c" / "session.json"
    Session(tabs=[]).save(session_file=deep)
    assert deep.exists()


# ---- next_untitled_title ----

def test_next_untitled_with_empty_set():
    assert next_untitled_title(set()) == "Untitled-1"


def test_next_untitled_skips_existing():
    assert next_untitled_title({"Untitled-1", "Untitled-2"}) == "Untitled-3"


def test_next_untitled_skips_gaps():
    # Note: function returns first available, doesn't fill gaps
    assert next_untitled_title({"Untitled-1", "Untitled-3"}) == "Untitled-2"


def test_next_untitled_ignores_unrelated_titles():
    assert next_untitled_title({"foo.md", "bar.txt"}) == "Untitled-1"
