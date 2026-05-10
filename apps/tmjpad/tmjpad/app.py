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

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.append(header)
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

    def _on_tab_switched(self, _nb, _page, _index) -> None:
        self.update_status_bar()
        self.save_session()

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
