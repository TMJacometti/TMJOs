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
- Auto-size pelo conteúdo (não width fixo)
- CSS: rounded corners + shadow + dark background

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
from .x11 import make_dock


DOCK_APP_ID = "br.com.tmjsistemas.tmjdock"
ICON_SIZE = 48
DOCK_PADDING = 12         # padding interno (entre borda e ícones)
ITEM_SPACING = 6          # espaçamento entre ícones


# CSS — visual macOS/Win11 dock: dark bg semi-transparente,
# rounded corners 18px, drop shadow. TMJOs accent no botão central.
DOCK_CSS = b"""
.tmjdock-window {
    background: transparent;
}

.tmjdock-bar {
    background-color: rgba(10, 14, 42, 0.85);
    border-radius: 18px;
    padding: 8px;
    border: 1px solid rgba(0, 212, 255, 0.15);
    box-shadow: 0 6px 24px rgba(0, 0, 0, 0.4);
}

.tmjdock-app-button {
    background: transparent;
    border-radius: 12px;
    padding: 6px;
    transition: background 150ms ease;
}

.tmjdock-app-button:hover {
    background-color: rgba(255, 255, 255, 0.08);
}

.tmjdock-app-button:active {
    background-color: rgba(0, 212, 255, 0.2);
}

.tmjdock-menu-button {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.25), rgba(255, 0, 170, 0.25));
    border-radius: 14px;
    padding: 6px;
    border: 1px solid rgba(0, 212, 255, 0.4);
}

.tmjdock-menu-button:hover {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.45), rgba(255, 0, 170, 0.45));
    border: 1px solid rgba(0, 212, 255, 0.7);
}
"""


# Defaults pinned apps — mesma lista do Plank atual no tmjos-dock.
# User pode customizar em ~/.config/tmjmenu/pinned.json (iter futura).
DEFAULT_PINNED = [
    "code.desktop",
    "org.gnome.Terminal.desktop",
    "tmjpad.desktop",
    "org.gnome.Nautilus.desktop",
    "gnome-control-center.desktop",
]


def _set_tmjos_icon(image: Gtk.Image) -> None:
    """Tenta o icon 'tmjos' do theme (tmjos-branding instalado), fallback
    pro asset embedded no módulo (dev local / sistemas sem tmjos-branding).
    """
    display = Gdk.Display.get_default()
    if display is not None:
        theme = Gtk.IconTheme.get_for_display(display)
        if theme.has_icon("tmjos"):
            image.set_from_icon_name("tmjos")
            return
    # Fallback: PNG embedded no package Python
    asset = Path(__file__).parent / "assets" / "tmjos.png"
    if asset.is_file():
        image.set_from_file(str(asset))
    else:
        image.set_from_icon_name("applications-other")


def _install_css() -> None:
    """Instala o CSS provider global (uma vez)."""
    provider = Gtk.CssProvider()
    provider.load_from_data(DOCK_CSS, len(DOCK_CSS))
    display = Gdk.Display.get_default()
    if display is not None:
        Gtk.StyleContext.add_provider_for_display(
            display,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )


class TMJDockWindow(Gtk.ApplicationWindow):
    """Dock principal do TMJOs."""

    def __init__(self, app: Adw.Application) -> None:
        super().__init__(application=app)
        self.set_title("TMJDock")
        self.set_decorated(False)
        self.set_resizable(False)
        self.add_css_class("tmjdock-window")

        # Sem default-size — auto-size pelo conteúdo
        # (GTK calcula width baseado nos children).

        # Discover apps disponíveis (pra resolver desktop_id → AppEntry)
        all_apps = {a.desktop_id: a for a in discover_apps()}

        # Container externo pra aplicar background com rounded corners
        # (window root é transparente, este box é "a dock" visualmente)
        bar = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL,
            spacing=ITEM_SPACING,
            halign=Gtk.Align.CENTER,
            valign=Gtk.Align.CENTER,
        )
        bar.add_css_class("tmjdock-bar")
        bar.set_margin_top(DOCK_PADDING)
        bar.set_margin_bottom(DOCK_PADDING)
        bar.set_margin_start(DOCK_PADDING)
        bar.set_margin_end(DOCK_PADDING)
        self.set_child(bar)

        # Pinned apps — primeira metade
        pinned = [all_apps[d] for d in DEFAULT_PINNED if d in all_apps]
        half = len(pinned) // 2
        for app in pinned[:half]:
            bar.append(self._build_app_button(app))

        # Botão TMJOs no centro
        bar.append(self._build_menu_button())

        # Pinned apps — segunda metade
        for app in pinned[half:]:
            bar.append(self._build_app_button(app))

        # Após a window estar mapped, aplica X11 hints pra virar dock
        # real (type=DOCK, strut bottom, position bottom-center).
        self.connect("realize", self._on_realize)
        self.connect("map", self._on_map)

    def _on_realize(self, _w: Gtk.Window) -> None:
        # Realize garante que get_native().get_surface() já existe.
        # Mas X11 hints precisam ser setados ANTES do mapeamento real,
        # então em alguns casos esse é o momento certo. Tentamos aqui;
        # se não funcionar, _on_map é o segundo cinto de segurança.
        self._apply_x11_dock_hints()

    def _on_map(self, _w: Gtk.Window) -> None:
        # Pós-map: hints podem precisar reapply. Inofensivo se já aplicou.
        self._apply_x11_dock_hints()

    def _apply_x11_dock_hints(self) -> None:
        """Tenta transformar a window em dock X11. Silencioso em Wayland."""
        try:
            native = self.get_native()
            if native is None:
                return
            surface = native.get_surface()
            if surface is None:
                return
            # Em X11, surface tem get_xid(). Em Wayland, não tem.
            if not hasattr(surface, "get_xid"):
                return
            xid = surface.get_xid()
            if not xid:
                return

            # Detecta primary monitor via GDK
            display = self.get_display()
            monitors = display.get_monitors()
            if monitors.get_n_items() == 0:
                return
            # GDK 4 não tem get_primary direto; primeiro é geralmente primary
            monitor = monitors.get_item(0)
            geometry = monitor.get_geometry()

            # Width "ideal" da dock: tamanho natural do conteúdo.
            # GTK4 não dá natural-size facilmente antes de allocate.
            # Usa default 600 que cobre 5 apps + botão + margens.
            allocation = self.get_allocation()
            dock_w = allocation.width or 600
            dock_h = allocation.height or 80

            make_dock(
                xid=xid,
                monitor_x=geometry.x,
                monitor_y=geometry.y,
                monitor_width=geometry.width,
                monitor_height=geometry.height,
                dock_width=dock_w,
                dock_height=dock_h,
            )
        except Exception:
            pass

    def _build_app_button(self, app: AppEntry) -> Gtk.Button:
        """Botão grande de app pinado na dock."""
        btn = Gtk.Button()
        btn.set_has_frame(False)
        btn.add_css_class("tmjdock-app-button")
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
        btn.add_css_class("tmjdock-menu-button")
        btn.set_tooltip_text("TMJMenu (Super)")

        icon = Gtk.Image()
        icon.set_pixel_size(ICON_SIZE)
        _set_tmjos_icon(icon)
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
        _install_css()
        window = self.props.active_window
        if window is None:
            window = TMJDockWindow(self)
        window.present()


def main() -> int:
    app = TMJDockApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
