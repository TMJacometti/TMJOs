//! tmjdock — dock bottom-center do TMJOs.
//!
//! Bar com botão TMJOs (abre tmjmenu), botão "Todos os apps", separator,
//! e pinned apps. Anchor via gtk4-layer-shell (Wayland) com fallback
//! X11 hints.
//!
//! Fase 1: skeleton apenas. Window + layer-shell + pinned bar vem na
//! Fase 3.

use adw::prelude::*;
use gio::ApplicationFlags;
use gtk::glib;

fn main() -> glib::ExitCode {
    let app = adw::Application::builder()
        .application_id("dev.tmjos.TMJDock")
        .flags(ApplicationFlags::FLAGS_NONE)
        .build();

    app.connect_startup(|_| {
        tmjmenu::widgets::install_shared_css();
    });

    app.connect_activate(|_app| {
        // FASE 3: criar window dock + anchor layer-shell + pinned bar.
        // Por enquanto, só loga monitor detection.
        eprintln!("tmjdock v{} — Fase 1 skeleton (UI vem na Fase 3)", tmjmenu::VERSION);
        match tmjmenu::monitors::shell_geometry() {
            Some(g) => eprintln!(
                "  Monitor interno: {}x{} @ ({}, {})",
                g.width, g.height, g.x, g.y
            ),
            None => eprintln!("  Monitor interno: não detectado"),
        }
    });

    app.run()
}
