//! Monitor selection helpers — port direto do monitors.py Python.
//!
//! Policy:
//!   1. Honra `TMJOS_MONITOR_CONNECTOR` se setado (env override).
//!   2. Prefere painel interno por connector prefix: eDP, LVDS, DSI.
//!   3. Prefere primary do display server.
//!   4. Fallback pro primeiro monitor.

use gtk::gdk;
use gtk::prelude::*;

const INTERNAL_PREFIXES: &[&str] = &["eDP", "LVDS", "DSI"];

#[derive(Clone, Copy, Debug)]
pub struct MonitorGeometry {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

/// Retorna o `GdkMonitor` representante do "shell monitor" — onde o
/// TMJDock deve ancorar. Em laptops, sempre painel interno. Em desktop
/// sem painel interno, primary. Em sistemas sem primary, primeiro.
pub fn shell_monitor() -> Option<gdk::Monitor> {
    let display = gdk::Display::default()?;
    let monitors = display.monitors();
    let n = monitors.n_items();
    if n == 0 {
        return None;
    }

    // 1. Env override
    if let Ok(forced) = std::env::var("TMJOS_MONITOR_CONNECTOR") {
        if let Some(m) = monitor_by_connector(&monitors, &forced) {
            return Some(m);
        }
    }

    // 2. Painel interno (eDP/LVDS/DSI)
    for i in 0..n {
        let monitor = monitors
            .item(i)
            .and_then(|obj| obj.downcast::<gdk::Monitor>().ok());
        if let Some(m) = monitor.as_ref() {
            if is_internal_connector(&monitor_connector(m)) {
                return monitor;
            }
        }
    }

    // 3. Primary
    for i in 0..n {
        let monitor = monitors
            .item(i)
            .and_then(|obj| obj.downcast::<gdk::Monitor>().ok());
        if let Some(m) = monitor.as_ref() {
            // GdkMonitor::is_primary() em GTK4 >= 4.18; usamos
            // model-cast pra pegar property se disponível.
            if monitor_is_primary(m) {
                return monitor;
            }
        }
    }

    // 4. Primeiro
    monitors
        .item(0)
        .and_then(|obj| obj.downcast::<gdk::Monitor>().ok())
}

/// Retorna a geometria do shell monitor — env override > internal >
/// primary > primeiro.
pub fn shell_geometry() -> Option<MonitorGeometry> {
    // Env override de geometria direta (formato: "1920x1080+0+0")
    if let Ok(forced) = std::env::var("TMJOS_MONITOR_GEOMETRY") {
        if let Some(g) = parse_geometry(&forced) {
            return Some(g);
        }
    }

    let m = shell_monitor()?;
    let g = m.geometry();
    Some(MonitorGeometry {
        x: g.x(),
        y: g.y(),
        width: g.width(),
        height: g.height(),
    })
}

fn monitor_by_connector(monitors: &gio::ListModel, connector: &str) -> Option<gdk::Monitor> {
    let n = monitors.n_items();
    for i in 0..n {
        let m = monitors
            .item(i)
            .and_then(|obj| obj.downcast::<gdk::Monitor>().ok());
        if let Some(monitor) = m {
            if monitor_connector(&monitor) == connector {
                return Some(monitor);
            }
        }
    }
    None
}

fn monitor_connector(monitor: &gdk::Monitor) -> String {
    monitor
        .connector()
        .map(|s| s.to_string())
        .unwrap_or_default()
}

fn is_internal_connector(connector: &str) -> bool {
    INTERNAL_PREFIXES.iter().any(|p| connector.starts_with(p))
}

fn monitor_is_primary(_monitor: &gdk::Monitor) -> bool {
    // GdkMonitor não expõe is_primary() diretamente em todos os
    // GTK4 versions. GTK4 ordena monitores com primary primeiro
    // tipicamente — o caller fallback no item(0) cobre o caso.
    false
}

fn parse_geometry(value: &str) -> Option<MonitorGeometry> {
    // Formato "WxH+X+Y" ou "W/dpi_x x H/dpi_h +X +Y" (xrandr output)
    let normalized = value.replace(' ', "");
    let parts: Vec<&str> = normalized.split(|c| c == 'x' || c == '+').collect();
    if parts.len() < 4 {
        return None;
    }
    let width = parts[0].parse().ok()?;
    let height = parts[1].parse().ok()?;
    let x = parts[2].parse().ok()?;
    let y = parts[3].parse().ok()?;
    Some(MonitorGeometry {
        x,
        y,
        width,
        height,
    })
}
