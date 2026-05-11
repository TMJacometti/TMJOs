"""TMJMenu — janela popup GTK4 com search + grid de apps + recentes.

Layout (Win11 Start style):

    ┌──────────────────────────────────┐
    │ 🔍 Search apps...                │  ← GtkSearchEntry
    ├──────────────────────────────────┤
    │ PINADOS                          │
    │  □□  □□  □□  □□  □□  □□          │  ← FlowBox 6 colunas
    │  □□  □□  □□  □□  □□  □□          │
    ├──────────────────────────────────┤
    │ RECENTES                         │
    │  □ VSCode  □ TMJPad  □ Settings  │
    └──────────────────────────────────┘

Iteração 1 (esta): search + lista filtrada. Pinados/recentes vêm
depois.
"""

from __future__ import annotations

import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk  # noqa: E402

from . import config
from .launcher import launch
from .search import AppEntry, discover_apps, search


APP_ID = "br.com.tmjsistemas.tmjmenu"
WINDOW_WIDTH = 600
WINDOW_HEIGHT = 500


class TMJMenuWindow(Gtk.ApplicationWindow):
    """Janela popup do TMJMenu."""

    def __init__(self, app: Adw.Application) -> None:
        super().__init__(application=app)
        self.set_title("TMJMenu")
        self.set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT)
        self.set_resizable(False)
        self.set_decorated(False)
        self.add_css_class("tmjmenu-window")

        self._apps: list[AppEntry] = discover_apps()

        # Esc fecha a janela.
        # Capture phase pra interceptar ANTES do GtkSearchEntry (que
        # consome Esc por default pra limpar o texto).
        controller = Gtk.EventControllerKey.new()
        controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        controller.connect("key-pressed", self._on_key_pressed)
        self.add_controller(controller)

        # Layout root
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        root.set_margin_top(12)
        root.set_margin_bottom(12)
        root.set_margin_start(12)
        root.set_margin_end(12)
        self.set_child(root)

        # Search bar
        self._search_entry = Gtk.SearchEntry()
        self._search_entry.set_placeholder_text("Buscar aplicações…")
        self._search_entry.connect("search-changed", self._on_search_changed)
        self._search_entry.connect("activate", self._on_search_activate)
        root.append(self._search_entry)

        # Lista de resultados (ScrolledWindow + ListBox)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        root.append(scrolled)

        self._listbox = Gtk.ListBox()
        self._listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._listbox.connect("row-activated", self._on_row_activated)
        scrolled.set_child(self._listbox)

        # Populate inicial (todos os apps)
        self._populate("")

        # Foco no search entry pra digitar direto
        self._search_entry.grab_focus()

    def _populate(self, query: str) -> None:
        """Refaz a list box baseado na query atual."""
        # Limpa rows antigas
        child = self._listbox.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self._listbox.remove(child)
            child = next_child

        for app in search(self._apps, query):
            self._listbox.append(self._build_row(app))

        # Pré-seleciona o primeiro pra Enter funcionar
        first = self._listbox.get_row_at_index(0)
        if first is not None:
            self._listbox.select_row(first)

    def _build_row(self, app: AppEntry) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        row._tmj_app = app  # type: ignore[attr-defined]

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_margin_top(6)
        box.set_margin_bottom(6)
        box.set_margin_start(8)
        box.set_margin_end(8)
        row.set_child(box)

        icon = Gtk.Image()
        icon.set_pixel_size(32)
        if app.icon:
            icon.set_from_icon_name(app.icon)
        else:
            icon.set_from_icon_name("application-x-executable")
        box.append(icon)

        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        text_box.set_hexpand(True)
        box.append(text_box)

        name_label = Gtk.Label(label=app.name, xalign=0)
        name_label.add_css_class("heading")
        text_box.append(name_label)

        if app.comment:
            comment_label = Gtk.Label(label=app.comment, xalign=0)
            comment_label.add_css_class("dim-label")
            comment_label.add_css_class("caption")
            comment_label.set_ellipsize(3)  # PANGO_ELLIPSIZE_END = 3
            text_box.append(comment_label)

        # Pin indicator + right-click pra toggle pin
        if config.is_pinned(app.desktop_id):
            pin_icon = Gtk.Image.new_from_icon_name("starred-symbolic")
            pin_icon.set_tooltip_text("Fixado na dock")
            pin_icon.add_css_class("accent")
            box.append(pin_icon)

        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)  # right click
        gesture.connect(
            "released",
            lambda *_args, a=app: self._toggle_pin(a),
        )
        row.add_controller(gesture)

        return row

    def _toggle_pin(self, app: AppEntry) -> None:
        """Right-click numa row: pinar se não tá, despinar se já tá."""
        if config.is_pinned(app.desktop_id):
            config.remove_pinned(app.desktop_id)
        else:
            config.add_pinned(app.desktop_id)
        # Re-popula pra refletir o pin badge atualizado
        self._populate(self._search_entry.get_text())

    # ── Event handlers ────────────────────────────────────────────────

    def _on_search_changed(self, entry: Gtk.SearchEntry) -> None:
        self._populate(entry.get_text())

    def _on_search_activate(self, entry: Gtk.SearchEntry) -> None:
        """Enter no search bar lança o primeiro resultado."""
        row = self._listbox.get_selected_row() or self._listbox.get_row_at_index(0)
        if row is not None:
            self._launch_row(row)

    def _on_row_activated(self, _listbox: Gtk.ListBox, row: Gtk.ListBoxRow) -> None:
        self._launch_row(row)

    def _launch_row(self, row: Gtk.ListBoxRow) -> None:
        app = getattr(row, "_tmj_app", None)
        if app is None:
            return
        if launch(app):
            self.close()

    def _on_key_pressed(
        self,
        _controller: Gtk.EventControllerKey,
        keyval: int,
        _keycode: int,
        _state,
    ) -> bool:
        # Escape fecha
        if keyval == 0xFF1B:  # GDK_KEY_Escape
            self.close()
            return True
        return False


class TMJMenuApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id=APP_ID,
            flags=0,
        )

    def do_activate(self) -> None:
        window = self.props.active_window
        if window is None:
            window = TMJMenuWindow(self)
        window.present()


def main() -> int:
    app = TMJMenuApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
