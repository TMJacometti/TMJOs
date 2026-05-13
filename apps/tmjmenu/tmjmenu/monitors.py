"""Monitor selection helpers for TMJOS shell components.

Policy:
1. If explicitly configured, honor `TMJOS_MONITOR_CONNECTOR`.
2. Prefer built-in laptop panels by connector prefix: eDP, LVDS, DSI.
3. Prefer the display server primary monitor.
4. Fall back to the first reported monitor.

This must stay generic: no user-specific monitor index assumptions.
"""

from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass

from gi.repository import Gdk


INTERNAL_PREFIXES = ("eDP", "LVDS", "DSI")


@dataclass(frozen=True)
class MonitorGeometry:
    x: int
    y: int
    width: int
    height: int


def shell_monitor() -> Gdk.Monitor | None:
    display = Gdk.Display.get_default()
    if display is None:
        return None
    monitors = display.get_monitors()
    if monitors.get_n_items() == 0:
        return None

    forced_connector = os.environ.get("TMJOS_MONITOR_CONNECTOR")
    if forced_connector:
        monitor = _monitor_by_connector(monitors, forced_connector)
        if monitor is not None:
            return monitor

    for i in range(monitors.get_n_items()):
        monitor = monitors.get_item(i)
        if _is_internal_connector(_monitor_connector(monitor)):
            return monitor

    for i in range(monitors.get_n_items()):
        monitor = monitors.get_item(i)
        if monitor is not None and monitor.is_primary():
            return monitor

    return monitors.get_item(0)


def shell_geometry() -> MonitorGeometry | None:
    forced = os.environ.get("TMJOS_MONITOR_GEOMETRY")
    if forced:
        parsed = _parse_geometry(forced)
        if parsed is not None:
            return parsed

    forced_connector = os.environ.get("TMJOS_MONITOR_CONNECTOR")
    if forced_connector:
        geometry = _xrandr_geometry_for_connector(forced_connector)
        if geometry is not None:
            return geometry

    geometry = _xrandr_internal_geometry()
    if geometry is not None:
        return geometry

    geometry = _xrandr_primary_geometry()
    if geometry is not None:
        return geometry

    monitor = shell_monitor()
    if monitor is None:
        return None
    g = monitor.get_geometry()
    return MonitorGeometry(g.x, g.y, g.width, g.height)


def _monitor_by_connector(monitors, connector: str) -> Gdk.Monitor | None:
    for i in range(monitors.get_n_items()):
        monitor = monitors.get_item(i)
        if _monitor_connector(monitor) == connector:
            return monitor
    return None


def _monitor_connector(monitor: Gdk.Monitor | None) -> str:
    if monitor is None or not hasattr(monitor, "get_connector"):
        return ""
    try:
        return monitor.get_connector() or ""
    except Exception:
        return ""


def _is_internal_connector(connector: str) -> bool:
    return connector.startswith(INTERNAL_PREFIXES)


def _xrandr_internal_geometry() -> MonitorGeometry | None:
    for name, geometry, _primary in _xrandr_connected_outputs():
        if _is_internal_connector(name):
            return geometry
    return None


def _xrandr_primary_geometry() -> MonitorGeometry | None:
    for _name, geometry, primary in _xrandr_connected_outputs():
        if primary:
            return geometry
    return None


def _xrandr_geometry_for_connector(connector: str) -> MonitorGeometry | None:
    for name, geometry, _primary in _xrandr_connected_outputs():
        if name == connector:
            return geometry
    return None


def _xrandr_connected_outputs() -> list[tuple[str, MonitorGeometry, bool]]:
    try:
        result = subprocess.run(
            ["xrandr", "--query"],
            capture_output=True,
            text=True,
            timeout=1,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return []

    if result.returncode != 0:
        return []

    outputs: list[tuple[str, MonitorGeometry, bool]] = []
    for line in result.stdout.splitlines():
        if " connected " not in line:
            continue
        parts = line.split()
        if len(parts) < 3:
            continue
        name = parts[0]
        primary = "primary" in parts
        geometry = None
        for part in parts:
            geometry = _parse_geometry(part)
            if geometry is not None:
                break
        if geometry is not None:
            outputs.append((name, geometry, primary))
    return outputs


def _parse_geometry(value: str) -> MonitorGeometry | None:
    match = re.search(r"(\d+)/\d+x(\d+)/\d+\+(-?\d+)\+(-?\d+)", value)
    if match:
        width, height, x, y = match.groups()
        return MonitorGeometry(int(x), int(y), int(width), int(height))

    match = re.search(r"(\d+)x(\d+)\+(-?\d+)\+(-?\d+)", value)
    if match:
        width, height, x, y = match.groups()
        return MonitorGeometry(int(x), int(y), int(width), int(height))
    return None
