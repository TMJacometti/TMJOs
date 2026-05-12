"""Tela de detalhe de um app TMJOs.

Layout (Adw.NavigationPage com seu próprio header):

    ┌──────────────────────────────────────────────┐
    │ ← Voltar    TMJMenu                          │  ← HeaderBar (NavView)
    ├──────────────────────────────────────────────┤
    │   ┌─────┐                                    │
    │   │ 🐉  │  TMJMenu               [ Instalar ]│
    │   │     │  Menu + dock proprietário          │
    │   └─────┘  Instalado: 1.3.4-12               │
    │   Descrição                                  │
    │   ...                                        │
    │   Informações / Histórico de versões         │
    └──────────────────────────────────────────────┘
"""

from __future__ import annotations

from typing import Callable

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, Gtk  # noqa: E402

from .discover import TMJApp


def build_detail_page(
    app: TMJApp,
    on_install: Callable[[TMJApp], None],
    on_remove: Callable[[TMJApp], None],
    on_upgrade: Callable[[TMJApp], None],
) -> Adw.ToolbarView:
    """Cria um Adw.ToolbarView populado pra ser embarcado em
    Adw.NavigationPage. Inclui própria HeaderBar pra o back button
    do NavigationView aparecer + título do app.

    Adw.ToolbarView é "final" (sealed) em libadwaita, então usamos
    factory function ao invés de subclass.
    """
    toolbar = Adw.ToolbarView()

    # === HeaderBar (NavigationView injeta back button automaticamente) ===
    header = Adw.HeaderBar()
    title = Adw.WindowTitle.new(app.display_name, app.summary)
    header.set_title_widget(title)
    toolbar.add_top_bar(header)

    # === Conteúdo scroll ===
    scrolled = Gtk.ScrolledWindow()
    scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    scrolled.set_vexpand(True)
    toolbar.set_content(scrolled)

    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
    content.set_margin_top(20)
    content.set_margin_bottom(20)
    content.set_margin_start(24)
    content.set_margin_end(24)
    scrolled.set_child(content)

    # === Header app: icon + name + summary + action button ===
    header_app = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
    content.append(header_app)

    icon = Gtk.Image()
    # Tenta theme → pixmaps → embedded (mesma lógica do app.py)
    from .app import set_app_icon
    set_app_icon(icon, app.icon_name, size=96)
    header_app.append(icon)

    text_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    text_col.set_hexpand(True)
    text_col.set_valign(Gtk.Align.CENTER)
    header_app.append(text_col)

    name_label = Gtk.Label(label=app.display_name, xalign=0)
    name_label.add_css_class("title-1")
    text_col.append(name_label)

    summary_label = Gtk.Label(label=app.summary, xalign=0)
    summary_label.add_css_class("title-4")
    summary_label.add_css_class("dim-label")
    summary_label.set_wrap(True)
    text_col.append(summary_label)

    if app.installed and app.installed_version:
        ver_label = Gtk.Label(
            label=f"Instalado: {app.installed_version}", xalign=0)
        ver_label.add_css_class("caption")
        ver_label.add_css_class("tmjstore-installed-tag")
        text_col.append(ver_label)

    action_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    action_box.set_valign(Gtk.Align.CENTER)
    header_app.append(action_box)
    action_box.append(_build_action_button(app, on_install, on_remove,
                                           on_upgrade))

    # === Description ===
    if app.description:
        content.append(_section_header("Descrição"))
        desc_label = Gtk.Label(label=app.description, xalign=0)
        desc_label.set_wrap(True)
        desc_label.set_selectable(True)
        desc_label.set_max_width_chars(80)
        content.append(desc_label)

    # === Categories chip line ===
    if app.categories:
        cat_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        cat_box.set_halign(Gtk.Align.START)
        for cat in app.categories:
            chip = Gtk.Label(label=cat)
            chip.add_css_class("tmjstore-chip")
            cat_box.append(chip)
        content.append(cat_box)

    # === Info table ===
    content.append(_section_header("Informações"))
    info_grid = Gtk.Grid(column_spacing=18, row_spacing=6)
    info_grid.set_hexpand(True)
    content.append(info_grid)

    rows = [
        ("Versão atual:", app.candidate_version or "—"),
        ("Pacote:", app.pkg_name),
    ]
    if app.developer:
        rows.append(("Desenvolvedor:", app.developer))
    if app.license:
        rows.append(("Licença:", app.license))
    if app.homepage:
        rows.append(("Homepage:", app.homepage))
    if app.bugtracker:
        rows.append(("Bug tracker:", app.bugtracker))

    for i, (key, value) in enumerate(rows):
        k = Gtk.Label(label=key, xalign=0)
        k.add_css_class("dim-label")
        info_grid.attach(k, 0, i, 1, 1)

        if value.startswith("http"):
            link = Gtk.LinkButton.new_with_label(value, value)
            link.set_halign(Gtk.Align.START)
            info_grid.attach(link, 1, i, 1, 1)
        else:
            v = Gtk.Label(label=value, xalign=0)
            v.set_selectable(True)
            info_grid.attach(v, 1, i, 1, 1)

    # === Release history ===
    if app.releases:
        content.append(_section_header("Histórico de versões"))
        for r in app.releases:
            rel_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            rel_box.add_css_class("tmjstore-release")
            rel_box.set_margin_bottom(8)
            content.append(rel_box)

            hdr = Gtk.Label(
                label=f"{r.version} · {r.date}" if r.date else r.version,
                xalign=0,
            )
            hdr.add_css_class("heading")
            rel_box.append(hdr)

            if r.description:
                body = Gtk.Label(label=r.description, xalign=0)
                body.add_css_class("dim-label")
                body.set_wrap(True)
                body.set_selectable(True)
                rel_box.append(body)

    return toolbar


def _section_header(text: str) -> Gtk.Label:
    label = Gtk.Label(label=text, xalign=0)
    label.add_css_class("title-3")
    label.set_margin_top(8)
    return label


def _build_action_button(
    app: TMJApp,
    on_install: Callable[[TMJApp], None],
    on_remove: Callable[[TMJApp], None],
    on_upgrade: Callable[[TMJApp], None],
) -> Gtk.Button:
    if app.has_update:
        btn = Gtk.Button(label="Atualizar")
        btn.add_css_class("tmjstore-install-btn")
        btn.connect("clicked", lambda _b: on_upgrade(app))
    elif app.installed:
        btn = Gtk.Button(label="Remover")
        btn.connect("clicked", lambda _b: on_remove(app))
    else:
        btn = Gtk.Button(label="Instalar")
        btn.add_css_class("tmjstore-install-btn")
        btn.connect("clicked", lambda _b: on_install(app))
    return btn
