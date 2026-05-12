"""Spawn de apps a partir de uma AppEntry — usa GLib pra detach correto."""

from __future__ import annotations

import re
import shlex

from gi.repository import GLib

from .search import AppEntry


# Field codes XDG (https://specifications.freedesktop.org/desktop-entry-spec/)
# %f %F %u %U são pra arquivos passados pelo file manager — pra lançar do
# menu sem arquivo, strip estes.
_FIELD_CODES = re.compile(r"%[fFuUdDnNickvm]")


def _strip_field_codes(exec_cmd: str) -> str:
    """Remove %f/%U etc. do Exec= antes de spawnar."""
    return _FIELD_CODES.sub("", exec_cmd).strip()


def launch(app: AppEntry) -> bool:
    """Lança o app em background, detached do tmjmenu.

    Retorna True se conseguiu spawn (não significa que o app não vai
    crashar logo em seguida — só significa que o exec rolou).
    """
    cmd = _strip_field_codes(app.exec_cmd)
    if not cmd:
        return False

    try:
        argv = shlex.split(cmd)
    except ValueError:
        return False

    try:
        GLib.spawn_async(
            argv,
            flags=(
                GLib.SpawnFlags.SEARCH_PATH
                | GLib.SpawnFlags.STDOUT_TO_DEV_NULL
                | GLib.SpawnFlags.STDERR_TO_DEV_NULL
            ),
        )
        return True
    except GLib.Error:
        return False
