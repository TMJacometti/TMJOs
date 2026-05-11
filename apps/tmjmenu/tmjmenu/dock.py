"""TMJDock — dock proprietária do TMJOs.

Substitui o Plank. Layout estilo macOS/Win11:

    ┌────────────────────────────────────────────────────────┐
    │ □ VSCode  □ Terminal  □ TMJPad   ⬢ TMJ   □ Files  □ … │  ← centered
    └────────────────────────────────────────────────────────┘
                          ↑
                  botão TMJOs (abre TMJMenu popup)

Iteração 1 (esta):
- Window GTK4 always-visible bottom-centered
- HBox com apps pinados + botão TMJOs no meio
- Click em app pinado → launch
- Click no botão TMJOs → abre TMJMenu popup

Iteração 2:
- X11 hints (_NET_WM_WINDOW_TYPE_DOCK + STRUT_PARTIAL) → reserva espaço
- Auto-hide com hover (mouse near bottom edge → show)
"""

from __future__ import annotations

import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")

from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402

from .launcher import launch
from .search import AppEntry, discover_apps


DOCK_APP_ID = "br.com.tmjsistemas.tmjdock"
ICON_SIZE = 48
DOCK_HEIGHT = 64
DOCK_PADDING = 8


# Defaults pinned apps — mesma lista do Plank atual no tmjos-dock.
# User pode customizar em ~/.config/tmjmenu/pinned.json (iter 2+).
DEFAULT_PINNED = [
    "code.desktop",
    "org.gnome.Terminal.desktop",
    "tmjpad.desktop",
    "org.gnome.Nautilus.desktop",
    "gnome-control-center.desktop",
]


class TMJDockWindow(Gtk.ApplicationWindow):
    """Dock principal do TMJOs."""

    def __init__(self, app: Adw.Application) -> None:
        super().__init__(application=app)
        self.set_title("TMJDock")
        self.set_decorated(False)
        self.set_resizable(False)
        self.add_css_class("tmjdock-window")

        # Window properties pra parecer dock
        # (X11 hints reais vêm em iteração 2 com python-xlib)
        self.set_default_size(800, DOCK_HEIGHT)

        # Posicionar bottom-center
        # GTK4 não tem set_position() — vamos depender do WM por enquanto.
        # X11 hints corrigem isso na próxima iter.

        # Discover apps disponíveis (pra resolver desktop_id → AppEntry)
        all_apps = {a.desktop_id: a for a in discover_apps()}

        # Build dock content
        content = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL,
            spacing=DOCK_PADDING,
            halign=Gtk.Align.CENTER,
            valign=Gtk.Align.CENTER,
        )
        content.set_margin_start(DOCK_PADDING)
        content.set_margin_end(DOCK_PADDING)
        self.set_child(content)

        # Pinned apps — primeira metade
        pinned = [all_apps[d] for d in DEFAULT_PINNED if d in all_apps]
        half = len(pinned) // 2
        for app in pinned[:half]:
            content.append(self._build_app_button(app))

        # Botão TMJOs no centro
        content.append(self._build_menu_button())

        # Pinned apps — segunda metade
        for app in pinned[half:]:
            content.append(self._build_app_button(app))

    def _build_app_button(self, app: AppEntry) -> Gtk.Button:
        """Botão grande de app pinado na dock."""
        btn = Gtk.Button()
        btn.set_has_frame(False)
        btn.set_tooltip_text(app.name)

        icon = Gtk.Image()
        icon.set_pixel_size(ICON_SIZE)
        if app.icon:
            icon.set_from_icon_name(app.icon)
        else:
            icon.set_from_icon_name("application-x-executable")
        btn.set_child(icon)

        btn.connect("clicked", lambda _b, a=app: launch(a))
        return btn

    def _build_menu_button(self) -> Gtk.Button:
        """Botão TMJOs central — abre o TMJMenu popup."""
        btn = Gtk.Button()
        btn.set_has_frame(False)
        btn.set_tooltip_text("TMJMenu (Super)")
        btn.add_css_class("tmjdock-menu-button")

        icon = Gtk.Image()
        icon.set_pixel_size(ICON_SIZE)
        # Usa o logo TMJOs do tmjos-branding (já instalado no sistema)
        icon.set_from_icon_name("tmjos")
        btn.set_child(icon)

        btn.connect("clicked", self._on_menu_button_clicked)
        return btn

    def _on_menu_button_clicked(self, _btn: Gtk.Button) -> None:
        """Lança `tmjmenu` (popup search). Dock continua aberta."""
        try:
            GLib.spawn_async(
                ["tmjmenu"],
                flags=(
                    GLib.SpawnFlags.SEARCH_PATH
                    | GLib.SpawnFlags.STDOUT_TO_DEV_NULL
                    | GLib.SpawnFlags.STDERR_TO_DEV_NULL
                ),
            )
        except GLib.Error:
            pass


class TMJDockApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id=DOCK_APP_ID,
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS,
        )

    def do_activate(self) -> None:
        window = self.props.active_window
        if window is None:
            window = TMJDockWindow(self)
        window.present()


def main() -> int:
    app = TMJDockApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
