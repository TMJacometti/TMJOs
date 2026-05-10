"""TMJPad — GTK4 + libadwaita UI."""
from __future__ import annotations

import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402

from . import __version__
from .persistence import (
    CONFIG_DIR,
    Session,
    TabState,
    new_tab_state,
    next_untitled_title,
    read_buffer,
    remove_buffer,
    write_buffer,
)

AUTOSAVE_DEBOUNCE_MS = 500


def _focus_view_once(view: Gtk.TextView) -> bool:
    """idle_add callback that focuses a text view exactly once.

    GLib.idle_add interprets a truthy return as 'call me again'. grab_focus()
    returns True on success, which would cause an infinite loop and saturate
    the display server. We explicitly return False to mark the source done.
    """
    view.grab_focus()
    return False

DARK_CSS = b"""
window { background-color: #0a0e2a; }

.tmjpad-textview, .tmjpad-textview text {
    background-color: #0a0e2a;
    color: #e6e6e6;
    font-family: 'JetBrains Mono', 'Cascadia Code', 'Fira Code', monospace;
    font-size: 13pt;
    caret-color: #00d4ff;
}
.tmjpad-textview text selection {
    background-color: alpha(#9d4edd, 0.5);
    color: #ffffff;
}

.tmjpad-status {
    background-color: #050714;
    color: #00d4ff;
    padding: 4px 12px;
    font-family: monospace;
    font-size: 10pt;
    border-top: 1px solid #1a1e3a;
}

notebook header {
    background-color: #050714;
    border-bottom: 1px solid #1a1e3a;
}
notebook tab {
    background-color: #0a0e2a;
    color: #888;
    padding: 4px 12px;
    border-radius: 0;
    border-right: 1px solid #1a1e3a;
}
notebook tab:checked {
    background-color: #1a1e3a;
    color: #00d4ff;
}
notebook tab button {
    min-width: 16px;
    min-height: 16px;
    padding: 2px;
}

headerbar {
    background-color: #050714;
    color: #e6e6e6;
    border-bottom: 1px solid #1a1e3a;
}

.tmjpad-find-bar {
    background-color: #050714;
    border-bottom: 1px solid #1a1e3a;
}
.tmjpad-find-bar entry {
    background-color: #0a0e2a;
    color: #e6e6e6;
    border: 1px solid #1a1e3a;
    border-radius: 4px;
    padding: 4px 8px;
}
.tmjpad-find-bar entry:focus {
    border-color: #00d4ff;
    box-shadow: 0 0 0 1px #00d4ff;
}
.tmjpad-find-bar entry.error {
    border-color: #ff2d95;
    color: #ff2d95;
}
.tmjpad-find-bar button {
    background-color: #1a1e3a;
    color: #00d4ff;
    border-radius: 4px;
}
.tmjpad-find-bar button:hover {
    background-color: #252a4d;
}
"""


class _Tab:
    """A single editor tab: text buffer + scrolled view + state."""

    def __init__(self, state: TabState, window: TMJPadWindow):
        self.state = state
        self.window = window
        self._autosave_source = 0

        self.buffer = Gtk.TextBuffer()
        self._load_initial_content()

        self.text_view = Gtk.TextView(
            buffer=self.buffer,
            wrap_mode=Gtk.WrapMode.NONE,
            monospace=True,
            top_margin=8,
            bottom_margin=8,
            left_margin=12,
            right_margin=12,
        )
        self.text_view.add_css_class("tmjpad-textview")

        self.scroller = Gtk.ScrolledWindow(
            hexpand=True,
            vexpand=True,
            child=self.text_view,
        )

        # Restore cursor (after content loaded so offsets are valid)
        if 0 <= state.cursor_offset <= self.buffer.get_char_count():
            it = self.buffer.get_iter_at_offset(state.cursor_offset)
            self.buffer.place_cursor(it)

        self.dirty = False
        self.title_label: Gtk.Label | None = None  # set when added to notebook

        # Wire up after initial load to avoid marking as dirty
        self.buffer.connect("changed", self._on_buffer_changed)
        self.buffer.connect("notify::cursor-position", self._on_cursor_moved)

    def _load_initial_content(self) -> None:
        """Buffer file is the source of truth. Fall back to file path on first open."""
        content = read_buffer(self.state)
        if not content and self.state.path and Path(self.state.path).exists():
            try:
                content = Path(self.state.path).read_text(encoding="utf-8")
            except OSError:
                content = ""
        self.buffer.set_text(content)

    def get_text(self) -> str:
        start, end = self.buffer.get_bounds()
        return self.buffer.get_text(start, end, False)

    def _on_buffer_changed(self, _buf: Gtk.TextBuffer) -> None:
        self.dirty = True
        self.window.update_tab_label(self)
        self._schedule_autosave()

    def _on_cursor_moved(self, _buf, _pspec) -> None:
        self.window.update_status_bar()

    def _schedule_autosave(self) -> None:
        if self._autosave_source:
            GLib.source_remove(self._autosave_source)
        self._autosave_source = GLib.timeout_add(
            AUTOSAVE_DEBOUNCE_MS, self._do_autosave
        )

    def _do_autosave(self) -> bool:
        self._autosave_source = 0
        write_buffer(self.state, self.get_text())
        self.state.cursor_offset = self.buffer.props.cursor_position
        self.window.save_session()
        return False  # one-shot

    def save_to_disk(self) -> bool:
        """Write content to self.state.path. Returns True on success."""
        if not self.state.path:
            return False
        try:
            Path(self.state.path).write_text(self.get_text(), encoding="utf-8")
        except OSError as e:
            print(f"tmjpad: save failed: {e}", file=sys.stderr)
            return False
        self.dirty = False
        self.window.update_tab_label(self)
        return True

    def cleanup_for_close(self) -> None:
        """Cancel pending autosave and write final buffer snapshot."""
        if self._autosave_source:
            GLib.source_remove(self._autosave_source)
            self._autosave_source = 0
        write_buffer(self.state, self.get_text())
        self.state.cursor_offset = self.buffer.props.cursor_position


class _FindReplaceBar(Gtk.Box):
    """Inline find/replace bar above the notebook.

    Hidden by default. Opened by Ctrl+F (find only) or Ctrl+H (with replace).
    Esc closes. Search uses Gtk.TextBuffer.forward/backward search with the
    case-sensitive flag off by default.
    """

    def __init__(self, window: TMJPadWindow):
        super().__init__(
            orientation=Gtk.Orientation.HORIZONTAL,
            spacing=6,
            margin_top=4,
            margin_bottom=4,
            margin_start=8,
            margin_end=8,
        )
        self.window = window
        self.add_css_class("tmjpad-find-bar")
        self.set_visible(False)

        self.find_entry = Gtk.Entry(
            placeholder_text="Find",
            hexpand=True,
        )
        self.replace_entry = Gtk.Entry(
            placeholder_text="Replace with",
            hexpand=True,
        )

        self.prev_btn = Gtk.Button.new_from_icon_name("go-up-symbolic")
        self.prev_btn.set_tooltip_text("Previous (Shift+Enter)")
        self.next_btn = Gtk.Button.new_from_icon_name("go-down-symbolic")
        self.next_btn.set_tooltip_text("Next (Enter)")
        self.replace_btn = Gtk.Button(label="Replace")
        self.replace_all_btn = Gtk.Button(label="Replace All")
        self.close_btn = Gtk.Button.new_from_icon_name("window-close-symbolic")
        self.close_btn.set_tooltip_text("Close (Esc)")

        # Layout
        self.append(self.find_entry)
        self.append(self.prev_btn)
        self.append(self.next_btn)
        self.append(self.replace_entry)
        self.append(self.replace_btn)
        self.append(self.replace_all_btn)
        self.append(self.close_btn)

        # Signals
        self.find_entry.connect("activate", lambda _e: self.find_next())
        self.replace_entry.connect("activate", lambda _e: self.replace_one())
        self.next_btn.connect("clicked", lambda _b: self.find_next())
        self.prev_btn.connect("clicked", lambda _b: self.find_prev())
        self.replace_btn.connect("clicked", lambda _b: self.replace_one())
        self.replace_all_btn.connect("clicked", lambda _b: self.replace_all())
        self.close_btn.connect("clicked", lambda _b: self.close())

        # Esc fecha quando o foco está no bar
        for entry in (self.find_entry, self.replace_entry):
            kc = Gtk.EventControllerKey()
            kc.connect("key-pressed", self._on_key_pressed)
            entry.add_controller(kc)

    def _on_key_pressed(self, _ctrl, keyval, _keycode, _state) -> bool:
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False

    def open(self, replace: bool) -> None:
        """Open the bar. If replace=True, show replace entry + buttons."""
        self.replace_entry.set_visible(replace)
        self.replace_btn.set_visible(replace)
        self.replace_all_btn.set_visible(replace)
        self.set_visible(True)

        # Pre-fill find with current selection if there's one
        tab = self.window._active_tab()
        if tab is not None:
            buf = tab.buffer
            if buf.get_has_selection():
                start, end = buf.get_selection_bounds()
                self.find_entry.set_text(buf.get_text(start, end, False))

        self.find_entry.grab_focus()
        self.find_entry.select_region(0, -1)

    def close(self) -> None:
        self.set_visible(False)
        # Devolve foco pro text view da aba ativa
        tab = self.window._active_tab()
        if tab is not None:
            GLib.idle_add(_focus_view_once, tab.text_view)

    # ---- search ops ----

    def _current_buffer(self) -> Gtk.TextBuffer | None:
        tab = self.window._active_tab()
        return tab.buffer if tab is not None else None

    def _search(self, forward: bool) -> bool:
        """Find from cursor. Wraps around at the end."""
        buf = self._current_buffer()
        if buf is None:
            return False
        needle = self.find_entry.get_text()
        if not needle:
            return False

        flags = Gtk.TextSearchFlags.CASE_INSENSITIVE | Gtk.TextSearchFlags.VISIBLE_ONLY
        cursor_iter = buf.get_iter_at_mark(buf.get_insert())

        if forward:
            match = cursor_iter.forward_search(needle, flags, None)
            if match is None:
                # Wrap: search from start
                match = buf.get_start_iter().forward_search(needle, flags, None)
        else:
            match = cursor_iter.backward_search(needle, flags, None)
            if match is None:
                # Wrap: search from end
                match = buf.get_end_iter().backward_search(needle, flags, None)

        if match is None:
            return False
        start, end = match
        buf.select_range(start, end)
        # Scroll viewport pra match ficar visível
        tab = self.window._active_tab()
        if tab is not None:
            tab.text_view.scroll_to_iter(start, 0.1, False, 0.0, 0.5)
        return True

    def find_next(self) -> None:
        if not self._search(forward=True):
            self._flash_no_match()

    def find_prev(self) -> None:
        if not self._search(forward=False):
            self._flash_no_match()

    def _flash_no_match(self) -> None:
        """Visual cue when nothing's found — error CSS class on the entry."""
        self.find_entry.add_css_class("error")
        GLib.timeout_add(400, lambda: (self.find_entry.remove_css_class("error"), False)[1])

    def replace_one(self) -> None:
        """If selection matches the find term, replace it. Then find next."""
        buf = self._current_buffer()
        if buf is None or not buf.get_has_selection():
            # Sem seleção — só faz find
            self.find_next()
            return
        needle = self.find_entry.get_text()
        if not needle:
            return
        start, end = buf.get_selection_bounds()
        selected = buf.get_text(start, end, False)
        if selected.lower() == needle.lower():
            buf.delete(start, end)
            buf.insert_at_cursor(self.replace_entry.get_text())
        # Avança pro próximo match
        self.find_next()

    def replace_all(self) -> None:
        buf = self._current_buffer()
        if buf is None:
            return
        needle = self.find_entry.get_text()
        replacement = self.replace_entry.get_text()
        if not needle:
            return

        flags = Gtk.TextSearchFlags.CASE_INSENSITIVE | Gtk.TextSearchFlags.VISIBLE_ONLY
        count = 0

        # Begin user action pra agrupar tudo num único undo
        buf.begin_user_action()
        try:
            it = buf.get_start_iter()
            while True:
                match = it.forward_search(needle, flags, None)
                if match is None:
                    break
                start, end = match
                buf.delete(start, end)
                buf.insert(start, replacement)
                # `start` agora aponta pro fim do replacement; continue dali
                it = start
                count += 1
        finally:
            buf.end_user_action()


class TMJPadWindow(Adw.ApplicationWindow):
    def __init__(self, application: Adw.Application, session: Session):
        super().__init__(application=application)
        self.session = session
        self.tabs: list[_Tab] = []
        self._suppress_session_save = False

        self.set_title("TMJPad")
        self.set_default_size(session.window_width, session.window_height)

        self._build_ui()
        self._wire_actions(application)
        self._restore_tabs()
        self.connect("close-request", self._on_close_request)

    def _build_ui(self) -> None:
        header = Adw.HeaderBar()

        new_btn = Gtk.Button.new_from_icon_name("document-new-symbolic")
        new_btn.set_tooltip_text("New tab (Ctrl+N)")
        new_btn.connect("clicked", lambda _b: self.new_tab())

        open_btn = Gtk.Button.new_from_icon_name("document-open-symbolic")
        open_btn.set_tooltip_text("Open file (Ctrl+O)")
        open_btn.connect("clicked", lambda _b: self.open_file_dialog())

        save_btn = Gtk.Button.new_from_icon_name("document-save-symbolic")
        save_btn.set_tooltip_text("Save (Ctrl+S)")
        save_btn.connect("clicked", lambda _b: self.save_active_tab())

        header.pack_start(new_btn)
        header.pack_start(open_btn)
        header.pack_start(save_btn)

        self.notebook = Gtk.Notebook(scrollable=True, show_border=False)
        self.notebook.connect("switch-page", self._on_tab_switched)
        self.notebook.connect("page-reordered", self._on_tab_reordered)

        self.status_label = Gtk.Label(xalign=0, label="Ln 1, Col 1  │  UTF-8")
        self.status_label.add_css_class("tmjpad-status")

        # Find/Replace bar (inicia escondida, aparece com Ctrl+F ou Ctrl+H)
        self.find_bar = _FindReplaceBar(self)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.append(header)
        box.append(self.find_bar)
        box.append(self.notebook)
        box.append(self.status_label)
        self.set_content(box)

    def _wire_actions(self, app: Adw.Application) -> None:
        actions = [
            ("new-tab", "<Ctrl>n", lambda *_: self.new_tab()),
            ("open-file", "<Ctrl>o", lambda *_: self.open_file_dialog()),
            ("save-tab", "<Ctrl>s", lambda *_: self.save_active_tab()),
            ("save-tab-as", "<Ctrl><Shift>s", lambda *_: self.save_as_active_tab()),
            ("close-tab", "<Ctrl>w", lambda *_: self.close_active_tab()),
            ("next-tab", "<Ctrl>Tab", lambda *_: self.cycle_tab(1)),
            ("prev-tab", "<Ctrl><Shift>Tab", lambda *_: self.cycle_tab(-1)),
            ("find", "<Ctrl>f", lambda *_: self.find_bar.open(replace=False)),
            ("find-replace", "<Ctrl>h", lambda *_: self.find_bar.open(replace=True)),
        ]
        for name, accel, callback in actions:
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", callback)
            self.add_action(action)
            app.set_accels_for_action(f"win.{name}", [accel])

    # ---- tab management ----

    def _restore_tabs(self) -> None:
        self._suppress_session_save = True
        try:
            if not self.session.tabs:
                self._add_tab(new_tab_state(title="Untitled-1"))
            else:
                for state in self.session.tabs:
                    self._add_tab(state)
            target = max(0, min(self.session.active_index, len(self.tabs) - 1))
            self.notebook.set_current_page(target)
        finally:
            self._suppress_session_save = False
        # Focus the active tab's text view at startup
        if 0 <= target < len(self.tabs):
            GLib.idle_add(_focus_view_once, self.tabs[target].text_view)

    def _add_tab(self, state: TabState) -> _Tab:
        tab = _Tab(state, self)
        self.tabs.append(tab)

        title_label = Gtk.Label(label=self._format_title(tab))
        close_btn = Gtk.Button.new_from_icon_name("window-close-symbolic")
        close_btn.set_has_frame(False)
        close_btn.connect("clicked", lambda _b, t=tab: self.close_tab(t))

        label_box = Gtk.Box(spacing=6, orientation=Gtk.Orientation.HORIZONTAL)
        label_box.append(title_label)
        label_box.append(close_btn)
        tab.title_label = title_label

        self.notebook.append_page(tab.scroller, label_box)
        self.notebook.set_tab_reorderable(tab.scroller, True)
        return tab

    def _format_title(self, tab: _Tab) -> str:
        return ("● " if tab.dirty else "") + tab.state.title

    def update_tab_label(self, tab: _Tab) -> None:
        if tab.title_label is not None:
            tab.title_label.set_label(self._format_title(tab))

    def update_status_bar(self) -> None:
        tab = self._active_tab()
        if tab is None:
            self.status_label.set_label("")
            return
        offset = tab.buffer.props.cursor_position
        it = tab.buffer.get_iter_at_offset(offset)
        line = it.get_line() + 1
        col = it.get_line_offset() + 1
        path = tab.state.path or "(unsaved)"
        self.status_label.set_label(f"Ln {line}, Col {col}  │  UTF-8  │  {path}")

    def _active_tab(self) -> _Tab | None:
        idx = self.notebook.get_current_page()
        if 0 <= idx < len(self.tabs):
            return self.tabs[idx]
        return None

    def _on_tab_switched(self, _nb, _page, index) -> None:
        self.update_status_bar()
        self.save_session()
        # Quando tu muda de aba (Ctrl+Tab), foca direto pro text view
        if 0 <= index < len(self.tabs):
            GLib.idle_add(_focus_view_once, self.tabs[index].text_view)

    def _on_tab_reordered(self, _nb, page_widget, new_index) -> None:
        # reorder self.tabs to match notebook order
        for i, t in enumerate(self.tabs):
            if t.scroller is page_widget:
                old_index = i
                break
        else:
            return
        moved = self.tabs.pop(old_index)
        self.tabs.insert(new_index, moved)
        self.save_session()

    # ---- file/tab actions ----

    def new_tab(self, path: str | None = None) -> _Tab:
        if path:
            state = new_tab_state(title=Path(path).name, path=path)
        else:
            existing = {t.state.title for t in self.tabs}
            state = new_tab_state(title=next_untitled_title(existing))
        tab = self._add_tab(state)
        self.notebook.set_current_page(self.notebook.get_n_pages() - 1)
        self.save_session()
        # Foca o text view depois do widget realizar (precisa estar mapeado).
        # idle_add garante que rode no próximo iddle do main loop.
        GLib.idle_add(_focus_view_once, tab.text_view)
        return tab

    def open_file_dialog(self) -> None:
        dialog = Gtk.FileDialog(title="Open File")
        dialog.open(self, None, self._on_open_response)

    def _on_open_response(self, dialog, result) -> None:
        try:
            file = dialog.open_finish(result)
        except GLib.Error:
            return  # user cancelled
        if file is None:
            return
        self.new_tab(path=file.get_path())

    def save_active_tab(self) -> None:
        tab = self._active_tab()
        if tab is None:
            return
        if tab.state.path:
            tab.save_to_disk()
            self.save_session()
        else:
            self._save_as(tab)

    def save_as_active_tab(self) -> None:
        tab = self._active_tab()
        if tab is not None:
            self._save_as(tab)

    def _save_as(self, tab: _Tab) -> None:
        dialog = Gtk.FileDialog(title="Save As")
        dialog.save(self, None, lambda d, r: self._on_save_as_response(d, r, tab))

    def _on_save_as_response(self, dialog, result, tab: _Tab) -> None:
        try:
            file = dialog.save_finish(result)
        except GLib.Error:
            return
        if file is None:
            return
        path = file.get_path()
        tab.state.path = path
        tab.state.title = Path(path).name
        tab.save_to_disk()
        self.update_tab_label(tab)
        self.save_session()

    def close_active_tab(self) -> None:
        tab = self._active_tab()
        if tab is not None:
            self.close_tab(tab)

    def close_tab(self, tab: _Tab) -> None:
        idx = self.tabs.index(tab)
        tab.cleanup_for_close()
        remove_buffer(tab.state)
        self.notebook.remove_page(idx)
        self.tabs.remove(tab)
        if not self.tabs:
            # always keep at least one tab
            self.new_tab()
        else:
            self.save_session()

    def cycle_tab(self, direction: int) -> None:
        n = self.notebook.get_n_pages()
        if n == 0:
            return
        cur = self.notebook.get_current_page()
        self.notebook.set_current_page((cur + direction) % n)

    # ---- session persistence ----

    def save_session(self) -> None:
        if self._suppress_session_save:
            return
        self.session.tabs = [t.state for t in self.tabs]
        self.session.active_index = self.notebook.get_current_page()
        # default size — actual window size at save-time
        w, h = self.get_default_size()
        self.session.window_width = w
        self.session.window_height = h
        self.session.save()

    def _on_close_request(self, _w) -> bool:
        for tab in self.tabs:
            tab.cleanup_for_close()
        self.save_session()
        return False  # allow close


class TMJPadApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id="dev.tmjos.TMJPad",
            flags=Gio.ApplicationFlags.HANDLES_OPEN,
        )
        self.window: TMJPadWindow | None = None

    def do_startup(self) -> None:  # type: ignore[override]
        Adw.Application.do_startup(self)
        self._install_css()
        # Force dark color scheme
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.FORCE_DARK)

    def _install_css(self) -> None:
        provider = Gtk.CssProvider()
        provider.load_from_data(DARK_CSS)
        display = Gdk.Display.get_default()
        if display is not None:
            Gtk.StyleContext.add_provider_for_display(
                display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def do_activate(self) -> None:  # type: ignore[override]
        if self.window is None:
            CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            session = Session.load()
            self.window = TMJPadWindow(self, session)
        self.window.present()

    def do_open(self, files, n_files, hint) -> None:  # type: ignore[override]
        self.activate()
        if self.window is None:
            return
        for f in files:
            self.window.new_tab(path=f.get_path())


def main() -> int:
    app = TMJPadApp()
    return app.run(sys.argv)
