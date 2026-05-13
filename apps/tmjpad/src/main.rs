//! TMJPad — text editor proprietário do TMJOs com session persistence total.
//!
//! Reescrita em Rust + gtk4-rs + libadwaita (era Python+PyGObject).
//! Paridade de features com a versão 0.1.2-2 Python:
//!   - Multi-tab com reordenação
//!   - Auto-save debounced
//!   - Session persistence (~/.config/tmjpad/session.json + buffers/)
//!   - Find & Replace inline (Ctrl+F, Ctrl+H)
//!   - Dark theme TMJOs (cyan/magenta, JetBrains Mono)

mod app;
mod css;
mod find_replace;
mod persistence;
mod tab;
mod window;

use gtk::prelude::*;

fn main() -> glib::ExitCode {
    let application = app::TMJPadApp::new();
    application.run()
}
