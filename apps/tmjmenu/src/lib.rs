//! TMJMenu/TMJDock — shared library entre os 2 binários.
//!
//! Reescrita em Rust + gtk4-rs em v2.0.0 (era Python + PyGObject).

pub mod config;
pub mod launcher;
pub mod monitors;
pub mod search;
pub mod widgets;
pub mod x11;

/// Versão exposta pros bins.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
