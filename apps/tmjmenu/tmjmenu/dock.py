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
import subprocess
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
#   AUTO_HIDE_REVEAL_PX  → quão perto do bottom edge ativa o show.
#   AUTO_HIDE_POLL_MS    → frequência do polling de pointer position.
#   AUTO_HIDE_HIDE_DELAY_MS → debounce antes de esconder (evita
#                              flicker quando user move o mouse).
AUTO_HIDE_REVEAL_PX = 8
AUTO_HIDE_POLL_MS = 400  # slower polling pra menos overhead em VMs
AUTO_HIDE_HIDE_DELAY_MS = 600


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

/* Dock pinned (Super+Shift+H) -- border cyan mais intenso e glow */
.tmjdock-bar.pinned {
    border: 1px solid rgba(0, 212, 255, 0.6);
    box-shadow: 0 6px 24px rgba(0, 0, 0, 0.4),
                0 0 12px rgba(0, 212, 255, 0.25);
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


def _running_in_vm() -> bool:
    """Detecta se TMJOs roda em VM via `systemd-detect-virt`.

    Em VM (Boxes/qemu/kvm/virtio-gpu sem aceleração GPU real), o
    strut churn do auto-hide cascateia Mutter re-layouts caros.
    Desativar auto-hide default em VM elimina o gargalo sem perder
    funcionalidade no hardware real onde renderiza com GPU.

    Returns True se detect-virt retorna algo diferente de "none".
    Falha (binário não existe) → assume hardware real (False).
    """
    try:
        result = subprocess.run(
            ["systemd-detect-virt"],
            capture_output=True, text=True, timeout=2,
        )
        # detect-virt retorna 0 + tipo se VM, 1 + "none" se metal
        virt = result.stdout.strip()
        return virt != "" and virt != "none"
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return False


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
        # Auto-hide condicional: off em VM (strut churn cascateia Mutter
        # re-layouts caros em virt). Hardware real → auto-hide funciona.
        # Em VM, Super+Shift+H é no-op (não reativa, evita confusão).
        self._auto_hide_enabled = not _running_in_vm()
        self._pinned = not self._auto_hide_enabled
        # Counter de popovers abertos (context menu pin/unpin). Enquanto > 0
        # a dock NÃO esconde mesmo se mouse sair (senão menu some no meio
        # da interação).
        self._popovers_open = 0
        # Debounce de hide: ID do timeout pendente. _schedule_hide agenda;
        # _cancel_hide cancela se o user trouxe o mouse de volta.
        self._pending_hide_id: int = 0
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
        """Após primeiro map, aplica X11 hints + inicia polling auto-hide
        (apenas se _auto_hide_enabled). Em VM, polling fica desligado por
        default — dock vira always-visible sem strut churn.
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

        # Inicia polling do cursor pra auto-hide — só em hardware real.
        # Em VM, _auto_hide_enabled é False (set no __init__ via
        # _running_in_vm()) e _pinned começa True, deixando dock
        # sempre visível. Zero polling, zero strut churn.
        if self._auto_hide_enabled:
            GLib.timeout_add(AUTO_HIDE_POLL_MS, self._auto_hide_tick)
        return False  # idle_add: rodar uma vez

    def _set_mouse_over(self, over: bool) -> None:
        self._mouse_over_dock = over

    # ── Build / rebuild da bar ────────────────────────────────────────

    def _build_bar(self) -> None:
        """Limpa e re-popula a bar. Chamado on init e on pinned.json change.

        Re-discovery dos apps pra pegar apps instalados depois do __init__
        do tmjdock (ex: user instalou TMJStore via apt, pinou via popup
        TMJMenu — sem o re-discovery, a dock skipava silenciosamente
        porque _all_apps não tinha o desktop_id novo).
        """
        self._all_apps = {a.desktop_id: a for a in discover_apps()}
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

        # Right-click → context menu com "Desfixar da Dock"
        gesture = Gtk.GestureClick.new()
        gesture.set_button(3)  # right
        gesture.connect(
            "released",
            lambda *_args, w=btn, a=app: show_pin_context_menu(
                w, a,
                on_change=self._on_pin_changed,
                on_popover_state=self._on_popover_state,
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
        """Abre o Activities Overview do GNOME Shell.

        Em GNOME 46+, org.gnome.Shell.ShowApplications via D-Bus
        retorna AccessDenied pra apps unprivileged. Então simulamos
        o keypress da tecla Super (que é o overlay-key default —
        nossa config só bind Super+Space e Super+Shift+H, Super
        sozinha continua abrindo Activities).
        """
        try:
            GLib.spawn_async(
                ["xdotool", "key", "Super_L"],
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
        - Se PINNED (Super+Shift+H toggled) → mantém visível, auto-hide off.
        - Senão, se popover aberto OU mouse sobre a dock OU mouse near
          bottom edge → mostra (cancela hide pendente).
        - Senão → agenda hide com debounce (não esconde instantâneo
          pra evitar flicker e perder cliques).

        Returns True pra GLib re-agendar o tick.
        """
        try:
            if self._cached_monitor_geom is None:
                return True

            # Pinned (Super+Shift+H) — dock sempre visível, auto-hide off.
            # Pausa o polling completamente (return False) — sem motivo
            # pra continuar fazendo X11 round-trips se a dock tá fixa.
            # toggle_pinned() reinicia o tick quando user desativa.
            if self._pinned:
                self._cancel_hide()
                if self._hidden:
                    self._show_dock()
                return False  # PAUSA polling

            mouse_y = query_pointer_y()
            if mouse_y is None:
                # Xlib indisponível — desabilita auto-hide silenciosamente
                self._show_dock()
                return False

            _mx, my, _mw, mh = self._cached_monitor_geom
            screen_bottom = my + mh
            near_bottom = mouse_y >= screen_bottom - AUTO_HIDE_REVEAL_PX

            should_show = (
                self._popovers_open > 0
                or self._mouse_over_dock
                or near_bottom
            )

            if should_show:
                self._cancel_hide()
                if self._hidden:
                    self._show_dock()
            else:
                # Não esconde imediato — agenda com debounce. Se o
                # user trouxer o mouse de volta no intervalo, _cancel_hide
                # impede o hide.
                if not self._hidden:
                    self._schedule_hide()
        except Exception:
            pass
        return True

    def _schedule_hide(self) -> None:
        """Agenda hide com debounce (AUTO_HIDE_HIDE_DELAY_MS)."""
        if self._pending_hide_id:
            return  # já agendado
        self._pending_hide_id = GLib.timeout_add(
            AUTO_HIDE_HIDE_DELAY_MS, self._do_delayed_hide
        )

    def _cancel_hide(self) -> None:
        """Cancela hide pendente (mouse voltou, popover abriu, etc)."""
        if self._pending_hide_id:
            GLib.source_remove(self._pending_hide_id)
            self._pending_hide_id = 0

    def _do_delayed_hide(self) -> bool:
        """Callback do debounce — esconde de verdade depois do delay."""
        self._pending_hide_id = 0
        # Re-checa estado: se algo mudou no intervalo (pinned, popover
        # abriu, mouse voltou), não esconde.
        if self._pinned:
            return False
        if self._popovers_open == 0 and not self._mouse_over_dock:
            if not self._hidden:
                self._hide_dock()
        return False  # timeout: rodar uma vez

    def _on_popover_state(self, is_open: bool) -> None:
        """Track context menus pra evitar esconder dock enquanto
        user interage com pin/unpin menu."""
        if is_open:
            self._popovers_open += 1
            self._cancel_hide()
        else:
            self._popovers_open = max(0, self._popovers_open - 1)

    def toggle_pinned(self) -> None:
        """Toggle do modo pinned — chamado por Super+Shift+H.

        Em hardware real:
            Off → On:  auto-hide desligado, dock fixa + badge glow.
            On → Off:  retorna ao auto-hide normal.

        Em VM (auto-hide hardcoded off):
            No-op com notification informando.
        """
        if not self._auto_hide_enabled:
            # Em VM, auto-hide cascateia Mutter relayout caro. Toggle
            # silenciosamente seria confuso — informa o user.
            self._notify(
                "TMJDock",
                "Auto-hide indisponível em VM (use hardware real)",
                "dialog-information-symbolic",
            )
            return

        self._pinned = not self._pinned
        self._update_pinned_visual()

        if self._pinned:
            self._show_dock()
            self._notify("TMJDock", "Dock fixa", "view-pin-symbolic")
        else:
            GLib.timeout_add(AUTO_HIDE_POLL_MS, self._auto_hide_tick)
            self._notify("TMJDock", "Auto-hide ativo",
                         "view-restore-symbolic")

    def _update_pinned_visual(self) -> None:
        """Adiciona/remove class CSS .pinned na bar (glow cyan)."""
        if self._pinned:
            self._bar.add_css_class("pinned")
        else:
            self._bar.remove_css_class("pinned")

    def _notify(self, summary: str, body: str, icon: str = "tmjos") -> None:
        """Envia notification breve via `notify-send`.

        Timeout 1500ms — feedback rápido, não fica poluindo o
        notification tray.
        """
        try:
            GLib.spawn_async(
                ["notify-send",
                 "--app-name=TMJDock",
                 "--expire-time=1500",
                 "--icon=" + icon,
                 summary, body],
                flags=(
                    GLib.SpawnFlags.SEARCH_PATH
                    | GLib.SpawnFlags.STDOUT_TO_DEV_NULL
                    | GLib.SpawnFlags.STDERR_TO_DEV_NULL
                ),
            )
        except GLib.Error:
            pass

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
            if display is None:
                return False
            monitors = display.get_monitors()
            if monitors is None or monitors.get_n_items() == 0:
                return False
            monitor = monitors.get_item(0)
            if monitor is None:
                # Pode acontecer durante resize/hotplug — monitor lista
                # virou inconsistente entre n_items() e get_item(0).
                return False
            geometry = monitor.get_geometry()
            if geometry is None:
                return False

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
            window.toggle_pinned()

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
