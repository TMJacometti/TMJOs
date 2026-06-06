//! TMJStore — Software Center do TMJOs.
//!
//! Reescrita em Rust + gtk4-rs + libadwaita (era Python + PyGObject).
//! Descobre apps TMJOs via APT + AppStream, instala/remove via pkexec.

mod app;
mod css;
mod detail;
mod discover;
mod installer;

use gtk::prelude::*;

fn main() -> glib::ExitCode {
    let app = app::TMJStoreApp::new();
    app.run()
}
