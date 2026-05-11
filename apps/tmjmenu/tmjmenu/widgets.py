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
    on_popover_state: Callable[[bool], None] | None = None,
) -> None:
    """Mostra PopoverMenu ancorado ao `parent` com a opção Pin/Unpin
    apropriada pro estado atual do `app`.

    - `on_change()` é chamado quando user clica a action (refletir
      mudança na UI do caller).
    - `on_popover_state(open)` é chamado com True quando o popover
      aparece e False quando fecha. Usado pelo TMJDock pra evitar
      esconder a dock enquanto o context menu tá aberto.
    """
    is_pinned = config.is_pinned(app.desktop_id)
    label = "Desfixar da Dock" if is_pinned else "Fixar na Dock"

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

    if on_popover_state is not None:
        on_popover_state(True)
        popover.connect("closed", lambda *_a: on_popover_state(False))

    popover.popup()
