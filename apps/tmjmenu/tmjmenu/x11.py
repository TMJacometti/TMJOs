"""X11 helpers pra TMJDock — set window type, struts, position.

Roda apenas no backend X11 (GDK_BACKEND=x11). Em Wayland, esses
hints não fazem nada — o port pra layer-shell vem em v2.0.

Imports do Xlib são guardados try/except: o módulo é importável
mesmo sem python-xlib instalado (silencioso no-op). Isso permite
o tmjmenu (popup) rodar em sistemas mínimos sem a dep.
"""

from __future__ import annotations

from typing import Optional

try:
    from Xlib import X, display
    from Xlib.Xatom import ATOM, CARDINAL
    _XLIB_OK = True
except ImportError:
    _XLIB_OK = False


def make_dock(xid: int, monitor_x: int, monitor_y: int,
              monitor_width: int, monitor_height: int,
              dock_width: int, dock_height: int) -> bool:
    """Transforma a window em dock real no X11.

    Aplica:
    - _NET_WM_WINDOW_TYPE = _NET_WM_WINDOW_TYPE_DOCK
      → WM trata como panel: sempre no top, sem decorations, sem
        Alt+Tab, sticky em todos os workspaces.
    - _NET_WM_STRUT_PARTIAL (12 valores)
      → reserva espaço bottom: janelas maximizadas respeitam.
    - XMoveWindow pra bottom-center do monitor especificado.

    Retorna True se aplicou; False se Xlib indisponível ou erro.
    """
    if not _XLIB_OK:
        return False

    try:
        d = display.Display()
        win = d.create_resource_object("window", xid)

        # === _NET_WM_WINDOW_TYPE = _NET_WM_WINDOW_TYPE_DOCK ===
        atom_type = d.intern_atom("_NET_WM_WINDOW_TYPE")
        atom_dock = d.intern_atom("_NET_WM_WINDOW_TYPE_DOCK")
        win.change_property(atom_type, ATOM, 32, [atom_dock])

        # === Position: bottom-centered do monitor especificado ===
        win_x = monitor_x + (monitor_width - dock_width) // 2
        # 12px de margin do bottom edge (visual "floating")
        margin = 12
        win_y = monitor_y + monitor_height - dock_height - margin
        win.configure(x=win_x, y=win_y, width=dock_width, height=dock_height)

        # === _NET_WM_STRUT_PARTIAL ===
        # 12 cardinals: left, right, top, bottom,
        # left_start_y, left_end_y, right_start_y, right_end_y,
        # top_start_x, top_end_x, bottom_start_x, bottom_end_x.
        # Pra bottom-only dock: só bottom > 0, e bottom_start_x/end_x
        # delimitam a faixa horizontal que reserva espaço.
        strut_bottom = dock_height + margin
        bottom_start_x = win_x
        bottom_end_x = win_x + dock_width - 1
        atom_strut = d.intern_atom("_NET_WM_STRUT_PARTIAL")
        win.change_property(
            atom_strut, CARDINAL, 32,
            [0, 0, 0, strut_bottom, 0, 0, 0, 0, 0, 0,
             bottom_start_x, bottom_end_x],
        )

        # Também _NET_WM_STRUT (versão antiga, 4 valores) pra WMs
        # que não entendem PARTIAL (raro mas safe).
        atom_strut_old = d.intern_atom("_NET_WM_STRUT")
        win.change_property(atom_strut_old, CARDINAL, 32,
                            [0, 0, 0, strut_bottom])

        # Sticky em todos os workspaces (0xFFFFFFFF = NET_WM_DESKTOP all)
        atom_desktop = d.intern_atom("_NET_WM_DESKTOP")
        win.change_property(atom_desktop, CARDINAL, 32, [0xFFFFFFFF])

        d.sync()
        d.close()
        return True
    except Exception:
        return False


def get_primary_monitor_geometry() -> Optional[tuple[int, int, int, int]]:
    """Retorna (x, y, width, height) do monitor primário X11.

    Em vez de usar Xrandr direto (complicado em python-xlib), preferimos
    GDK que já faz multi-monitor: get_monitors() retorna lista em
    ordem de primary first. Esse helper é mantido aqui pra futuro,
    mas dock.py usa GDK pra detectar monitor.
    """
    return None
