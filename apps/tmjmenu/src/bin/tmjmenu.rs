//! tmjmenu — popup search launcher do TMJOs.
//!
//! Aberto via Super+Space (configurado pelo tmjmenu-first-run.desktop).
//! Mostra search entry + lista filtered de .desktop apps. Enter lança.
//!
//! Fase 1: skeleton apenas (este file). UI completa vem na Fase 2.

use adw::prelude::*;
use gio::ApplicationFlags;
use gtk::glib;

fn main() -> glib::ExitCode {
    let app = adw::Application::builder()
        .application_id("dev.tmjos.TMJMenu")
        .flags(ApplicationFlags::FLAGS_NONE)
        .build();

    app.connect_startup(|_| {
        tmjmenu::widgets::install_shared_css();
    });

    app.connect_activate(|_app| {
        // FASE 2: criar window popup com search entry + list view.
        // Por enquanto, só loga e sai.
        eprintln!("tmjmenu v{} — Fase 1 skeleton (UI vem na Fase 2)", tmjmenu::VERSION);
        eprintln!(
            "  Apps descobertos: {}",
            tmjmenu::search::discover_apps().len()
        );
        eprintln!("  Pinned: {:?}", tmjmenu::config::load_pinned());
    });

    app.run()
}
