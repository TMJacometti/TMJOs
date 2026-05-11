"""Widgets compartilhados entre tmjmenu (popup) e tmjdock.

Context menu pra Pin/Unpin reusável em ambos.
"""

from __future__ import annotations

from typing import Callable

from gi.repository import Gio, Gtk

from . import config
from .search import AppEntry


def show_pin_context_menu(
    parent: Gtk.Widget,
    app: AppEntry,
    on_change: Callable[[], None],
) -> None:
    """Mostra PopoverMenu ancorado ao `parent` com a opção Pin/Unpin
    apropriada pro estado atual do `app`. Quando o user clica na
    opção, chama `on_change()` pro caller refletir a mudança (re-build
    da lista, atualizar badge, etc).
    """
    is_pinned = config.is_pinned(app.desktop_id)
    label = "Desafixar da Dock" if is_pinned else "Fixar na Dock"

    menu_model = Gio.Menu()
    menu_model.append(label, "ctx.toggle-pin")

    action = Gio.SimpleAction.new("toggle-pin", None)

    def _on_activate(_action, _param):
        if config.is_pinned(app.desktop_id):
            config.remove_pinned(app.desktop_id)
        else:
            config.add_pinned(app.desktop_id)
        on_change()

    action.connect("activate", _on_activate)

    action_group = Gio.SimpleActionGroup()
    action_group.add_action(action)
    parent.insert_action_group("ctx", action_group)

    popover = Gtk.PopoverMenu.new_from_model(menu_model)
    popover.set_parent(parent)
    popover.set_has_arrow(True)
    popover.popup()
