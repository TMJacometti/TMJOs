"""Install/remove/upgrade de apps via pkexec + apt.

pkexec eleva privilégio com prompt gráfico (PolicyKit). User digita
senha uma vez, comando roda como root.

Não usa apt-get diretamente — usa wrapper que chama pkexec sob o capô.
Em case de erro (user cancelou prompt, dep faltando), retorna error
string pra UI mostrar.
"""

from __future__ import annotations

import shlex
from typing import Callable

from gi.repository import GLib


def _spawn_apt(action: str, pkg_name: str,
               on_done: Callable[[bool, str], None]) -> None:
    """Spawn pkexec + apt-get <action> <pkg>. Calls on_done(success, msg).

    Roda async via GLib.spawn_async + child_watch.
    """
    if action not in ("install", "remove", "upgrade"):
        on_done(False, f"Ação inválida: {action}")
        return

    # apt-get com flags pra non-interactive — mas pkexec abre prompt gráfico
    # pra senha.
    argv = [
        "pkexec",
        "apt-get",
        "-y",
        "-q",
        "--no-install-recommends" if action == "install" else "--",
        action,
        pkg_name,
    ]
    # filtrar "--" placeholder
    argv = [a for a in argv if a != "--"]

    try:
        pid, _, _, _ = GLib.spawn_async(
            argv,
            flags=(
                GLib.SpawnFlags.SEARCH_PATH
                | GLib.SpawnFlags.DO_NOT_REAP_CHILD
            ),
        )
        GLib.child_watch_add(
            GLib.PRIORITY_DEFAULT, pid,
            lambda _pid, status, *_: on_done(
                status == 0,
                "OK" if status == 0 else f"apt-get retornou {status}",
            ),
        )
    except GLib.Error as e:
        on_done(False, f"Falha ao spawn: {e}")


def install(pkg: str, on_done: Callable[[bool, str], None]) -> None:
    _spawn_apt("install", pkg, on_done)


def remove(pkg: str, on_done: Callable[[bool, str], None]) -> None:
    _spawn_apt("remove", pkg, on_done)


def upgrade(pkg: str, on_done: Callable[[bool, str], None]) -> None:
    _spawn_apt("install", pkg, on_done)  # apt install = upgrade se já instalado
