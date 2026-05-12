"""TMJStore — main window GTK4.

Layout (Adwaita ViewSwitcher):

┌─────────────────────────────────────────────┐
│  TMJStore        [Apps] [Installed] [Upd]  │  ← Adw.ViewSwitcher
├─────────────────────────────────────────────┤
│  ┌──────────────────────────────────────┐   │
│  │ 📒  TMJPad                           │   │
│  │     Editor sem frescura...           │   │
│  │                          [ Install ] │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ 🐉  TMJMenu                          │   │
│  │     Menu + dock proprietário         │   │
│  │                       [ Installed ✓] │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘

Iteração 0.1.0: 3 views, refresh manual, ações via pkexec+apt.
Futuro: libappstream-glib + screenshots + release notes detalhada.
"""

from __future__ import annotations

import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk  # noqa: E402

from . import installer
from .detail import build_detail_page
from .discover import TMJApp, discover_tmj_apps


APP_ID = "br.com.tmjsistemas.tmjstore"
WINDOW_WIDTH = 720
WINDOW_HEIGHT = 600


STORE_CSS = b"""
.tmjstore-app-row {
    background-color: rgba(20, 24, 60, 0.6);
    border-radius: 12px;
    border: 1px solid rgba(0, 212, 255, 0.12);
    padding: 12px;
    margin: 6px 0;
}

.tmjstore-app-row:hover {
    background-color: rgba(20, 24, 60, 0.85);
    border: 1px solid rgba(0, 212, 255, 0.3);
}

.tmjstore-install-btn {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.3),
                                         rgba(255, 0, 170, 0.3));
    border: 1px solid rgba(0, 212, 255, 0.5);
    border-radius: 8px;
    padding: 6px 16px;
    font-weight: bold;
}

.tmjstore-install-btn:hover {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.5),
                                         rgba(255, 0, 170, 0.5));
}

/* Botao durante operacao apt -- verde "in progress" */
.tmjstore-busy-btn {
    background: linear-gradient(135deg, rgba(50, 200, 80, 0.4),
                                         rgba(0, 212, 100, 0.4));
    border: 1px solid rgba(50, 200, 80, 0.7);
    border-radius: 8px;
    padding: 6px 16px;
    color: #d0ffd0;
    font-weight: bold;
}

.tmjstore-installed-tag {
    color: #00d4ff;
    font-weight: bold;
}

.tmjstore-chip {
    background-color: rgba(0, 212, 255, 0.15);
    border: 1px solid rgba(0, 212, 255, 0.3);
    border-radius: 999px;
    padding: 2px 10px;
    font-size: 0.85em;
}

.tmjstore-release {
    background-color: rgba(20, 24, 60, 0.4);
    border-left: 3px solid rgba(0, 212, 255, 0.5);
    border-radius: 6px;
    padding: 8px 12px;
}
"""


def _install_css() -> None:
    from gi.repository import Gdk
    provider = Gtk.CssProvider()
    provider.load_from_data(STORE_CSS, len(STORE_CSS))
    display = Gdk.Display.get_default()
    if display is not None:
        Gtk.StyleContext.add_provider_for_display(
            display, provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )


def set_app_icon(image: Gtk.Image, pkg_name: str, size: int = 64) -> None:
    """Seta o icon de um app — tiers em ordem:
    1. Theme icon (hicolor — só funciona se app instalado)
    2. /usr/share/pixmaps/<pkg>.png (idem)
    3. Cache local ~/.cache/tmjstore/icons/<pkg>.png (sobrevive uninstall)
    4. Embedded asset (só pra tmjstore — dev mode)
    5. application-x-executable (genérico)
    """
    from pathlib import Path
    from gi.repository import Gdk
    from .discover import cached_icon_path

    image.set_pixel_size(size)

    display = Gdk.Display.get_default()
    if display is not None:
        theme = Gtk.IconTheme.get_for_display(display)
        if theme.has_icon(pkg_name):
            image.set_from_icon_name(pkg_name)
            return

    pixmap = Path(f"/usr/share/pixmaps/{pkg_name}.png")
    if pixmap.is_file():
        image.set_from_file(str(pixmap))
        return

    # Tier 3: cache local — sobrevive uninstall
    cached = cached_icon_path(pkg_name)
    if cached is not None:
        image.set_from_file(str(cached))
        return

    # Dev mode: embedded asset (só pra apps próprios — tmjstore)
    if pkg_name == "tmjstore":
        embedded = Path(__file__).parent / "assets" / "tmjstore.png"
        if embedded.is_file():
            image.set_from_file(str(embedded))
            return

    image.set_from_icon_name("application-x-executable")


class TMJStoreWindow(Adw.ApplicationWindow):
    def __init__(self, app: Adw.Application) -> None:
        super().__init__(application=app)
        self.set_title("TMJStore")
        self.set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT)

        # ToastOverlay envolve tudo — toasts aparecem flutuando.
        self._toast_overlay = Adw.ToastOverlay()
        self.set_content(self._toast_overlay)

        # NavigationView pra push/pop entre lista e detalhe
        self._nav = Adw.NavigationView()
        self._toast_overlay.set_child(self._nav)

        # Página principal (lista com 3 tabs)
        self._main_page = self._build_main_page()
        self._nav.add(self._main_page)

        # Set de ações em curso (evita double-click + permite track)
        self._busy_pkgs: set[str] = set()
        # Mapeia pkg → ação em curso (pra mostrar label correta no botão)
        self._busy_action_map: dict[str, str] = {}

        # Populate inicial
        self._refresh()

    def _toast(self, message: str, timeout: int = 3) -> None:
        """Mostra Adw.Toast flutuante."""
        toast = Adw.Toast.new(message)
        toast.set_timeout(timeout)
        self._toast_overlay.add_toast(toast)

    def _build_main_page(self) -> Adw.NavigationPage:
        """Constrói a página principal com 3 tabs."""
        toolbar = Adw.ToolbarView()

        header = Adw.HeaderBar()

        refresh_btn = Gtk.Button.new_from_icon_name("view-refresh-symbolic")
        refresh_btn.set_tooltip_text("Atualizar lista")
        refresh_btn.connect("clicked", lambda _b: self._refresh())
        header.pack_end(refresh_btn)

        toolbar.add_top_bar(header)

        self._stack = Adw.ViewStack()

        self._apps_view, self._apps_box = self._build_list_view()
        self._installed_view, self._installed_box = self._build_list_view()
        self._updates_view, self._updates_box = self._build_list_view()

        self._stack.add_titled_with_icon(
            self._apps_view, "apps", "Apps", "view-grid-symbolic")
        self._stack.add_titled_with_icon(
            self._installed_view, "installed", "Instalados",
            "object-select-symbolic")
        self._updates_view_page = self._stack.add_titled_with_icon(
            self._updates_view, "updates", "Updates",
            "software-update-available-symbolic")

        switcher = Adw.ViewSwitcher()
        switcher.set_stack(self._stack)
        switcher.set_policy(Adw.ViewSwitcherPolicy.WIDE)
        header.set_title_widget(switcher)

        toolbar.set_content(self._stack)
        return Adw.NavigationPage.new(toolbar, "TMJStore")

    def _build_list_view(self) -> tuple[Gtk.ScrolledWindow, Gtk.Box]:
        """Cria ScrolledWindow + Box interno. Retorna tupla (scrolled,
        container) — scrolled vai pro Adw.ViewStack, container é onde
        popular cards. GTK4 envolve a Box num Viewport interno, então
        manter referência direta evita ter que navegar scrolled.get_child()."""
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_vexpand(True)

        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        container.set_margin_top(12)
        container.set_margin_bottom(12)
        container.set_margin_start(16)
        container.set_margin_end(16)
        scrolled.set_child(container)

        return scrolled, container

    def _refresh(self) -> None:
        """Re-discover apps + popula as 3 views."""
        apps = discover_tmj_apps()

        self._populate_box(self._apps_box, apps)
        self._populate_box(self._installed_box,
                           [a for a in apps if a.installed])
        updates = [a for a in apps if a.has_update]
        self._populate_box(self._updates_box, updates)

        # Badge do tab Updates
        if hasattr(self._updates_view_page, "set_badge_number"):
            self._updates_view_page.set_badge_number(len(updates))

    def _populate_box(self, container: Gtk.Box, apps: list[TMJApp]) -> None:
        """Limpa + re-popula a Box com cards dos apps."""
        # Clear children
        child = container.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            container.remove(child)
            child = next_child

        if not apps:
            empty = Gtk.Label(label="Nenhum app aqui.")
            empty.add_css_class("dim-label")
            empty.set_margin_top(40)
            container.append(empty)
            return

        for app in apps:
            container.append(self._build_app_row(app))

    def _build_app_row(self, app: TMJApp) -> Gtk.Widget:
        """Card clicável de app. Wrappa num Gtk.Button pra ficar
        clickable inteiro — click navega pra tela de detalhe."""
        btn = Gtk.Button()
        btn.add_css_class("tmjstore-app-row")
        btn.set_has_frame(False)
        btn.connect("clicked", lambda _b: self._open_detail(app))

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn.set_child(row)

        # Icon
        icon = Gtk.Image()
        set_app_icon(icon, app.icon_name, size=64)
        row.append(icon)

        # Text column
        text_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        text_col.set_hexpand(True)
        text_col.set_valign(Gtk.Align.CENTER)
        row.append(text_col)

        name_label = Gtk.Label(label=app.display_name, xalign=0)
        name_label.add_css_class("title-3")
        text_col.append(name_label)

        summary_label = Gtk.Label(label=app.summary, xalign=0)
        summary_label.add_css_class("dim-label")
        summary_label.set_wrap(True)
        text_col.append(summary_label)

        if app.installed and app.installed_version:
            ver_label = Gtk.Label(
                label=f"Instalado: {app.installed_version}", xalign=0)
            ver_label.add_css_class("caption")
            ver_label.add_css_class("tmjstore-installed-tag")
            text_col.append(ver_label)

        # Action button (não propaga click pra row pra evitar abrir
        # detail quando user clica "Install" direto da lista).
        action_btn = self._build_action_button(app)
        action_btn.set_valign(Gtk.Align.CENTER)
        row.append(action_btn)

        return btn

    def _open_detail(self, app: TMJApp) -> None:
        """Push de uma detail page na NavigationView."""
        detail = build_detail_page(
            app=app,
            on_install=lambda a: self._do_action("install", a),
            on_remove=lambda a: self._do_action("remove", a),
            on_upgrade=lambda a: self._do_action("upgrade", a),
        )
        page = Adw.NavigationPage.new(detail, app.display_name)
        self._nav.push(page)

    def _build_action_button(self, app: TMJApp) -> Gtk.Button:
        # Se app tem operação em curso, mostra botão "Aguarde..." verde
        if app.pkg_name in self._busy_pkgs:
            busy_label = {
                "install": "Instalando…",
                "remove": "Removendo…",
                "upgrade": "Atualizando…",
            }.get(self._busy_action_for(app.pkg_name), "Aguarde…")
            btn = Gtk.Button(label=busy_label)
            btn.add_css_class("tmjstore-busy-btn")
            btn.set_sensitive(False)
            return btn

        if app.has_update:
            btn = Gtk.Button(label="Atualizar")
            btn.add_css_class("tmjstore-install-btn")
            btn.connect("clicked", lambda _b: self._do_action(
                "upgrade", app))
        elif app.installed:
            btn = Gtk.Button(label="Remover")
            btn.connect("clicked", lambda _b: self._do_action(
                "remove", app))
        else:
            btn = Gtk.Button(label="Instalar")
            btn.add_css_class("tmjstore-install-btn")
            btn.connect("clicked", lambda _b: self._do_action(
                "install", app))
        return btn

    def _busy_action_for(self, pkg_name: str) -> str:
        """Retorna o tipo de ação em curso pro pkg, ou '' se nenhuma."""
        return self._busy_action_map.get(pkg_name, "")

    def _do_action(self, action: str, app: TMJApp) -> None:
        """Dispara apt action async + feedback via toast.

        Fluxo:
        1. Toast imediato "Instalando X..." (não bloqueia user).
        2. Adiciona app a _busy_pkgs (evita double-click).
        3. apt roda async via GLib.spawn + child_watch.
        4. on_done: toast OK/falha + pop detail (se aberto) + refresh
           lista.
        """
        if app.pkg_name in self._busy_pkgs:
            return  # já tem ação rodando — ignora double-click

        verb_pt = {
            "install": "Instalando",
            "remove": "Removendo",
            "upgrade": "Atualizando",
        }.get(action, action)
        verb_done_pt = {
            "install": "instalado",
            "remove": "removido",
            "upgrade": "atualizado",
        }.get(action, "OK")

        self._busy_pkgs.add(app.pkg_name)
        self._busy_action_map[app.pkg_name] = action
        self._toast(f"{verb_pt} {app.display_name}…")
        # Refresh imediato — botão troca pra "Instalando…" verde
        self._refresh()

        def on_done(success: bool, msg: str) -> None:
            self._busy_pkgs.discard(app.pkg_name)
            self._busy_action_map.pop(app.pkg_name, None)
            if success:
                self._toast(f"{app.display_name} {verb_done_pt} ✓")
            else:
                self._toast(f"Falha em {app.display_name}: {msg}", timeout=5)

            # Se detail page tá no topo, volta pra lista
            visible = self._nav.get_visible_page()
            if visible is not None and visible is not self._main_page:
                self._nav.pop()

            # Refresh lista com novo estado
            self._refresh()

        if action == "install":
            installer.install(app.pkg_name, on_done)
        elif action == "remove":
            installer.remove(app.pkg_name, on_done)
        elif action == "upgrade":
            installer.upgrade(app.pkg_name, on_done)


class TMJStoreApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(application_id=APP_ID, flags=0)

    def do_activate(self) -> None:
        _install_css()
        window = self.props.active_window
        if window is None:
            window = TMJStoreWindow(self)
        window.present()


def main() -> int:
    app = TMJStoreApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
