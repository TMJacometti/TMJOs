"""TMJDock — dock proprietária do TMJOs.

Substitui o Plank. Layout estilo Windows Start (TMJOs à esquerda):

    ┌──────────────────────────────────────────────────────┐
    │ ⬢ TMJ  ⊞ ShowApps │ □ VSCode  □ Terminal  □ Files  │
    └──────────────────────────────────────────────────────┘
       ↑       ↑                ↑
       │       │                pinados (config.py — persistido em
       │       │                ~/.config/tmjmenu/pinned.json)
       │       Activities Overview (gdbus org.gnome.Shell)
       Botão TMJOs (abre TMJMenu popup)
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")

from gi.repository import Adw, Gdk, Gio, GLib, Gtk  # noqa: E402

from . import config
from .launcher import launch
from .search import AppEntry, discover_apps
from .widgets import show_pin_context_menu
from .x11 import hide_window_offscreen, make_dock, query_pointer_y, show_window_at


DOCK_APP_ID = "br.com.tmjsistemas.tmjdock"
ICON_SIZE = 48
DOCK_PADDING = 12         # padding interno (entre borda e ícones)
ITEM_SPACING = 6          # espaçamento entre ícones

# Auto-hide:
#   AUTO_HIDE_REVEAL_PX → quão perto do bottom edge ativa o show.
#   AUTO_HIDE_POLL_MS    → frequência do polling de pointer position.
AUTO_HIDE_REVEAL_PX = 4
AUTO_HIDE_POLL_MS = 250


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

.tmjdock-separator {
    background-color: rgba(255, 255, 255, 0.12);
    min-width: 1px;
}
"""


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

        # Discover apps disponíveis (pra resolver desktop_id → AppEntry)
        self._all_apps: dict[str, AppEntry] = {
            a.desktop_id: a for a in discover_apps()
        }

        # Container externo pra aplicar background com rounded corners
        self._bar = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL,
            spacing=ITEM_SPACING,
            halign=Gtk.Align.CENTER,
            valign=Gtk.Align.CENTER,
        )
        self._bar.add_css_class("tmjdock-bar")
        self._bar.set_margin_top(DOCK_PADDING)
        self._bar.set_margin_bottom(DOCK_PADDING)
        self._bar.set_margin_start(DOCK_PADDING)
        self._bar.set_margin_end(DOCK_PADDING)
        self.set_child(self._bar)

        self._build_bar()

        # Re-build dock se pinned.json mudar (pin/unpin do popup ou
        # editado manualmente).
        self._setup_pinned_watch()

        # Auto-hide state. Dock começa visível. Cache de geometria pra
        # evitar recalcular monitor a cada tick.
        self._hidden = False
        self._mouse_over_dock = False
        # User-force hidden: quando o user aperta Super+H, dock fica
        # forçada hidden — auto-hide tick respeita esse estado e mantém
        # hide até outro toggle. Bottom-edge hover não traz de volta.
        self._user_force_hidden = False
        self._cached_monitor_geom: tuple[int, int, int, int] | None = None
        self._cached_dock_size: tuple[int, int] | None = None

        # Track mouse hovering a dock (impede esconder enquanto user
        # tá usando — clicks, hover sobre botões).
        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", lambda *_a: self._set_mouse_over(True))
        motion.connect("leave", lambda *_a: self._set_mouse_over(False))
        self.add_controller(motion)

        # X11 hints depois que window mapped E allocation finalizada.
        # GTK4 emite "map" antes da allocation real estar pronta, então
        # passamos via idle_add (próximo tick do main loop, depois do
        # measure/allocate). Sem isso, centralização horizontal pega
        # uma width parcial e a dock fica deslocada à esquerda.
        self.connect("realize", lambda _w: GLib.idle_add(
            self._apply_x11_dock_hints))
        self.connect("map", lambda _w: GLib.idle_add(
            self._after_first_map))

    def _after_first_map(self) -> bool:
        """Após primeiro map, aplica X11 hints + inicia polling auto-hide.
        Também escuta `monitors-changed` pra re-aplicar quando a
        resolução da VM muda (Boxes/virtio-gpu dynamic resize)."""
        self._apply_x11_dock_hints()

        # Re-cache + re-position quando monitor geometry muda (resize
        # da janela Boxes, hotplug de monitor, mudança de resolução, etc).
        display = self.get_display()
        monitors = display.get_monitors()
        monitors.connect(
            "items-changed",
            lambda *_a: GLib.idle_add(self._apply_x11_dock_hints),
        )
        # Notify::geometry no monitor primário pega resize só do
        # próprio display sem hotplug.
        if monitors.get_n_items() > 0:
            primary = monitors.get_item(0)
            try:
                primary.connect(
                    "notify::geometry",
                    lambda *_a: GLib.idle_add(self._apply_x11_dock_hints),
                )
            except Exception:
                pass

        # Inicia polling do cursor pra auto-hide
        GLib.timeout_add(AUTO_HIDE_POLL_MS, self._auto_hide_tick)
        return False  # idle_add: rodar uma vez

    def _set_mouse_over(self, over: bool) -> None:
        self._mouse_over_dock = over

    # ── Build / rebuild da bar ────────────────────────────────────────

    def _build_bar(self) -> None:
        """Limpa e re-popula a bar. Chamado on init e on pinned.json change."""
        # Limpa filhos existentes
        child = self._bar.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self._bar.remove(child)
            child = next_child

        # 1. Botão TMJOs (esquerda, Windows Start style)
        self._bar.append(self._build_menu_button())

        # 2. Botão "Show all apps" (Activities Overview)
        self._bar.append(self._build_show_apps_button())

        # 3. Separador
        sep = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        sep.set_margin_start(4)
        sep.set_margin_end(4)
        sep.set_margin_top(8)
        sep.set_margin_bottom(8)
        sep.add_css_class("tmjdock-separator")
        self._bar.append(sep)

        # 4. Apps pinados (do config.json)
        for desktop_id in config.load_pinned():
            app = self._all_apps.get(desktop_id)
            if app is not None:
                self._bar.append(self._build_app_button(app))

    def _setup_pinned_watch(self) -> None:
        """Re-build dock quando ~/.config/tmjmenu/pinned.json mudar.
        Permite que pin/unpin do popup TMJMenu reflita na dock sem restart.
        """
        try:
            config.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
            gfile = Gio.File.new_for_path(str(config.PINNED_FILE))
            self._monitor = gfile.monitor_file(Gio.FileMonitorFlags.NONE, None)
            self._monitor.connect("changed", self._on_pinned_changed)
        except Exception:
            self._monitor = None

    def _on_pinned_changed(
        self, _monitor, _file, _other_file, event_type
    ) -> None:
        # Debounce: só rebuild em CHANGES_DONE_HINT pra evitar
        # rebuild parcial quando outro processo tá escrevendo.
        if event_type == Gio.FileMonitorEvent.CHANGES_DONE_HINT:
            self._build_bar()
            # idle_add: re-centralizar após allocation nova
            GLib.idle_add(self._apply_x11_dock_hints)

    # ── Botões ───────────────────────────────────────────────────────

    def _build_app_button(self, app: AppEntry) -> Gtk.Button:
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

        # Right-click → context menu com "Desafixar da Dock"
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)  # right
        gesture.connect(
            "released",
            lambda *_args, w=btn, a=app: show_pin_context_menu(
                w, a, self._on_pin_changed
            ),
        )
        btn.add_controller(gesture)

        return btn

    def _build_menu_button(self) -> Gtk.Button:
        btn = Gtk.Button()
        btn.set_has_frame(False)
        btn.add_css_class("tmjdock-menu-button")
        btn.set_tooltip_text("TMJMenu (Super+Space)")

        icon = Gtk.Image()
        icon.set_pixel_size(ICON_SIZE)
        _set_tmjos_icon(icon)
        btn.set_child(icon)

        btn.connect("clicked", self._on_menu_button_clicked)
        return btn

    def _build_show_apps_button(self) -> Gtk.Button:
        btn = Gtk.Button()
        btn.set_has_frame(False)
        btn.add_css_class("tmjdock-app-button")
        btn.set_tooltip_text("Mostrar todos os apps")

        icon = Gtk.Image()
        icon.set_pixel_size(ICON_SIZE)
        icon.set_from_icon_name("view-app-grid-symbolic")
        btn.set_child(icon)

        btn.connect("clicked", self._on_show_apps_clicked)
        return btn

    # ── Event handlers ───────────────────────────────────────────────

    def _on_menu_button_clicked(self, _btn: Gtk.Button) -> None:
        """Lança o TMJMenu (popup search). Dock continua aberta."""
        if shutil.which("tmjmenu"):
            argv = ["tmjmenu"]
        else:
            argv = [sys.executable, "-m", "tmjmenu.app"]
        try:
            GLib.spawn_async(
                argv,
                flags=(
                    GLib.SpawnFlags.SEARCH_PATH
                    | GLib.SpawnFlags.STDOUT_TO_DEV_NULL
                    | GLib.SpawnFlags.STDERR_TO_DEV_NULL
                ),
            )
        except GLib.Error:
            pass

    def _on_show_apps_clicked(self, _btn: Gtk.Button) -> None:
        """Abre o Activities Overview do GNOME Shell via D-Bus."""
        try:
            GLib.spawn_async(
                [
                    "gdbus", "call", "--session",
                    "--dest", "org.gnome.Shell",
                    "--object-path", "/org/gnome/Shell",
                    "--method", "org.gnome.Shell.ShowApplications",
                ],
                flags=(
                    GLib.SpawnFlags.SEARCH_PATH
                    | GLib.SpawnFlags.STDOUT_TO_DEV_NULL
                    | GLib.SpawnFlags.STDERR_TO_DEV_NULL
                ),
            )
        except GLib.Error:
            pass

    def _on_pin_changed(self) -> None:
        """Callback do context menu — re-build da bar com estado novo.

        O GFileMonitor de pinned.json também dispara, mas chamar
        aqui torna o feedback imediato (sem esperar o monitor).
        """
        self._build_bar()
        # idle_add: deixa o GTK refazer measure+allocate antes de
        # re-centralizar (senão dock_width fica do tamanho antigo).
        GLib.idle_add(self._apply_x11_dock_hints)

    # ── X11 dock hints ───────────────────────────────────────────────

    # ── Auto-hide ────────────────────────────────────────────────────

    def _auto_hide_tick(self) -> bool:
        """Polling tick: checa pointer position, esconde/mostra dock.

        Lógica:
        - Se user-force-hidden (Super+H toggled) → mantém hidden,
          ignora mouse.
        - Senão, se mouse está sobre a dock → mostra (não esconde
          enquanto user interage).
        - Senão, se mouse nos últimos AUTO_HIDE_REVEAL_PX do bottom
          edge → mostra.
        - Senão → esconde.

        Returns True pra GLib re-agendar o tick.
        """
        try:
            if self._cached_monitor_geom is None:
                return True

            # User pressed Super+H — força hide
            if self._user_force_hidden:
                if not self._hidden:
                    self._hide_dock()
                return True

            mouse_y = query_pointer_y()
            if mouse_y is None:
                # Xlib indisponível — desabilita auto-hide silenciosamente
                self._show_dock()
                return False

            mx, my, mw, mh = self._cached_monitor_geom
            screen_bottom = my + mh
            near_bottom = mouse_y >= screen_bottom - AUTO_HIDE_REVEAL_PX

            should_show = self._mouse_over_dock or near_bottom

            if should_show and self._hidden:
                self._show_dock()
            elif not should_show and not self._hidden:
                self._hide_dock()
        except Exception:
            pass
        return True

    def toggle_force_hidden(self) -> None:
        """Toggle do estado user-force-hidden — chamado por Super+H.

        Off → On:  dock some imediatamente, fica oculta até próximo toggle.
        On → Off:  retorna ao auto-hide normal (mostra se mouse near bottom).
        """
        self._user_force_hidden = not self._user_force_hidden
        if self._user_force_hidden:
            self._hide_dock()
        else:
            # Mostra imediatamente; próximo tick decide se mantém visível
            # baseado em mouse position
            self._show_dock()

    def _hide_dock(self) -> None:
        if self._cached_monitor_geom is None:
            return
        xid = self._get_xid()
        if xid is None:
            return
        _, my, _, mh = self._cached_monitor_geom
        hide_window_offscreen(xid, my + mh)
        self._hidden = True

    def _show_dock(self) -> None:
        if self._cached_monitor_geom is None or self._cached_dock_size is None:
            return
        xid = self._get_xid()
        if xid is None:
            return
        mx, my, mw, mh = self._cached_monitor_geom
        dw, dh = self._cached_dock_size
        win_x = mx + (mw - dw) // 2
        margin = 12
        win_y = my + mh - dh - margin
        show_window_at(xid, win_x, win_y, dw, dh)
        self._hidden = False

    def _get_xid(self) -> int | None:
        native = self.get_native()
        if native is None:
            return None
        surface = native.get_surface()
        if surface is None or not hasattr(surface, "get_xid"):
            return None
        xid = surface.get_xid()
        return xid or None

    def _apply_x11_dock_hints(self) -> bool:
        """Tenta transformar a window em dock X11. Silencioso em Wayland.

        Returns False (idle_add semântica: não repetir) — mas se a
        allocation ainda não tá pronta, returns True pra tentar
        novamente no próximo idle tick.
        """
        try:
            native = self.get_native()
            if native is None:
                return False
            surface = native.get_surface()
            if surface is None or not hasattr(surface, "get_xid"):
                return False
            xid = surface.get_xid()
            if not xid:
                return False

            display = self.get_display()
            monitors = display.get_monitors()
            if monitors.get_n_items() == 0:
                return False
            monitor = monitors.get_item(0)
            geometry = monitor.get_geometry()

            # GTK4: get_width()/get_height() retornam a allocation real
            # (depois de measure+allocate). Se ainda for 0, defer.
            dock_w = self.get_width()
            dock_h = self.get_height()
            if dock_w <= 0 or dock_h <= 0:
                # Pede pra GTK calcular o natural size do conteúdo
                _min_size, nat_size = self.get_preferred_size()
                dock_w = nat_size.width or 600
                dock_h = nat_size.height or 80

            make_dock(
                xid=xid,
                monitor_x=geometry.x,
                monitor_y=geometry.y,
                monitor_width=geometry.width,
                monitor_height=geometry.height,
                dock_width=dock_w,
                dock_height=dock_h,
            )
            # Cache pro auto-hide tick não recalcular toda vez
            self._cached_monitor_geom = (
                geometry.x, geometry.y, geometry.width, geometry.height,
            )
            self._cached_dock_size = (dock_w, dock_h)
        except Exception:
            pass
        return False  # idle_add: rodar uma vez só


class TMJDockApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id=DOCK_APP_ID,
            # HANDLES_COMMAND_LINE: secondary process (ex: `tmjdock
            # --toggle-hide`) passa cmdline pra primary via D-Bus em
            # vez de criar nova instance. Permite hotkey global trigger.
            flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE,
        )
        # Action toggle-hide: chamada via cmdline (`tmjdock --toggle-hide`)
        # ou via D-Bus (gapplication action ...).
        action = Gio.SimpleAction.new("toggle-hide", None)
        action.connect("activate", self._on_toggle_hide_action)
        self.add_action(action)

    def _on_toggle_hide_action(
        self, _action: Gio.SimpleAction, _param
    ) -> None:
        window = self.props.active_window
        if isinstance(window, TMJDockWindow):
            window.toggle_force_hidden()

    def do_command_line(self, cmdline: Gio.ApplicationCommandLine) -> int:
        args = cmdline.get_arguments()
        # args[0] é o nome do programa
        if "--toggle-hide" in args[1:]:
            # Se a primary instance ainda não tem window (cold start),
            # ativa pra criar window + force hidden.
            if self.props.active_window is None:
                self.activate()
            self.activate_action("toggle-hide", None)
        else:
            self.activate()
        return 0

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
