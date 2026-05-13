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

import os
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")

try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell as LayerShell
except (ImportError, ValueError):
    LayerShell = None

try:
    from Xlib import display as _xlib_display  # noqa: F401
    _XLIB_OK = True
except ImportError:
    _XLIB_OK = False

from gi.repository import Adw, Gdk, GLib, Gtk  # noqa: E402

from . import config
from .launcher import launch
from .monitors import shell_geometry, shell_monitor
from .search import AppEntry, discover_apps, search
from .widgets import show_pin_context_menu
from .x11 import focus_popup, make_popup


APP_ID = "br.com.tmjsistemas.tmjmenu"
WINDOW_WIDTH = 600
WINDOW_HEIGHT = 500
MENU_MARGIN = 8


class TMJMenuWindow(Gtk.ApplicationWindow):
    """Janela popup do TMJMenu."""

    def __init__(self, app: Adw.Application) -> None:
        super().__init__(application=app)
        self.set_title("TMJMenu")
        self.set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT)
        self.set_resizable(False)
        self.set_decorated(False)
        self.add_css_class("tmjmenu-window")
        self._layer_shell_enabled = self._setup_layer_shell()

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

        if not self._layer_shell_enabled:
            # OR + position têm que rolar ANTES do XMapWindow — realize
            # fires entre XCreateWindow e XMapWindow, então é a hook certa.
            # Mudar override_redirect depois do map é no-op até o próximo
            # unmap/remap, e o Mutter já teria decidido placement.
            self.connect("realize", lambda _w: self._position_x11_fallback())
            # OR windows não recebem foco do WM — grab manual no map
            # pra search entry capturar teclas.
            self.connect("map", lambda _w: self._focus_x11_fallback())

    def _setup_layer_shell(self) -> bool:
        """Ancora o menu perto da dock em compositors wlroots-based.

        wlr-layer-shell-unstable-v1 só é implementado por Hyprland/Sway/
        wayfire/river/labwc/niri. Mutter (GNOME) e KWin (Plasma) não
        suportam — `is_supported()` retorna False e caímos no X11
        fallback (override_redirect via XWayland, ver _select_backend).
        """
        if LayerShell is None or not _running_on_wayland():
            return False
        if hasattr(LayerShell, "is_supported") and not LayerShell.is_supported():
            return False

        LayerShell.init_for_window(self)
        LayerShell.set_namespace(self, "tmjmenu")
        LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
        monitor = shell_monitor()
        if monitor is not None:
            LayerShell.set_monitor(self, monitor)
        LayerShell.set_anchor(self, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_margin(self, LayerShell.Edge.BOTTOM, 64)
        return True

    def _position_x11_fallback(self) -> bool:
        debug = bool(os.environ.get("TMJMENU_DEBUG"))
        if not _XLIB_OK:
            if debug:
                print("[tmjmenu] _XLIB_OK=False — Xlib não disponível",
                      file=sys.stderr)
            return False
        native = self.get_native()
        if native is None:
            if debug:
                print("[tmjmenu] get_native() is None", file=sys.stderr)
            return False
        surface = native.get_surface()
        if surface is None or not hasattr(surface, "get_xid"):
            if debug:
                print(
                    f"[tmjmenu] surface={surface} sem get_xid (backend"
                    " Wayland nativo?)",
                    file=sys.stderr,
                )
            return False
        xid = surface.get_xid()
        if not xid:
            if debug:
                print("[tmjmenu] xid=0", file=sys.stderr)
            return False

        geometry = shell_geometry()
        if geometry is None:
            if debug:
                print("[tmjmenu] shell_geometry() is None", file=sys.stderr)
            return False
        gx, gy, gw, gh = (
            geometry.x, geometry.y, geometry.width, geometry.height
        )
        x = gx + (gw - WINDOW_WIDTH) // 2
        y = gy + gh - WINDOW_HEIGHT - 64
        final_y = max(gy + MENU_MARGIN, y)
        ok = make_popup(
            xid,
            x=x,
            y=final_y,
            width=WINDOW_WIDTH,
            height=WINDOW_HEIGHT,
        )
        if debug:
            print(
                f"[tmjmenu] make_popup xid={xid} monitor=({gx},{gy} "
                f"{gw}x{gh}) → ({x},{final_y} "
                f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}) ok={ok}",
                file=sys.stderr,
            )
        return False

    def _focus_x11_fallback(self) -> None:
        if not _XLIB_OK:
            return
        native = self.get_native()
        if native is None:
            return
        surface = native.get_surface()
        if surface is None or not hasattr(surface, "get_xid"):
            return
        xid = surface.get_xid()
        if xid:
            focus_popup(xid)

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
            "pressed",
            lambda *_args, w=row, a=app: show_pin_context_menu(
                w, a, self._on_pin_changed
            ),
        )
        row.add_controller(gesture)

        return row

    def _on_pin_changed(self) -> None:
        """Callback do context menu — re-popula pra atualizar estrelas."""
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


def _running_on_wayland() -> bool:
    display = Gdk.Display.get_default()
    if display is None:
        return False
    return "Wayland" in display.__gtype__.name


_WLROOTS_DESKTOPS = ("hyprland", "sway", "wayfire", "river", "labwc", "niri")


def _select_backend() -> None:
    """Em compositors Wayland que não suportam wlr-layer-shell
    (Mutter/GNOME, KWin/KDE), força XWayland. O cliente roda sob XWayland,
    `get_xid()` fica disponível, e o fallback override_redirect ancora o
    popup no monitor certo. Wlroots-based stays Wayland nativo.

    Chamado em main() antes de criar Adw.Application — GTK4 lê
    GDK_BACKEND quando o primeiro Gdk.Display abre.
    """
    if "GDK_BACKEND" in os.environ:
        return
    if os.environ.get("XDG_SESSION_TYPE") != "wayland":
        return
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()
    if not any(name in desktop for name in _WLROOTS_DESKTOPS):
        os.environ["GDK_BACKEND"] = "x11"


def main() -> int:
    _select_backend()
    app = TMJMenuApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
