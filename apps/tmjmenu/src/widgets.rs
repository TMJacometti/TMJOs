//! Widgets e CSS compartilhados entre tmjmenu e tmjdock.

use gtk::gdk;
use gtk::CssProvider;

/// CSS TMJOs — paleta neon shared por tmjmenu (popup) e tmjdock.
///
/// Cyan #00d4ff, magenta #ff2d95, navy #0a0e2a, dark #050714.
pub const SHARED_CSS: &str = r#"
.tmj-popup {
    background-color: rgba(10, 14, 42, 0.96);
    border-radius: 12px;
    border: 1px solid rgba(0, 212, 255, 0.25);
}

.tmj-popup-search {
    background-color: rgba(26, 30, 58, 0.8);
    color: #e6e6e6;
    border: 1px solid rgba(0, 212, 255, 0.3);
    border-radius: 8px;
    padding: 8px 12px;
    font-family: 'JetBrains Mono', monospace;
    caret-color: #00d4ff;
}
.tmj-popup-search:focus {
    border-color: #00d4ff;
    box-shadow: 0 0 0 1px rgba(0, 212, 255, 0.4);
}

.tmj-app-row {
    background: transparent;
    border-radius: 8px;
    padding: 6px 10px;
    color: #e6e6e6;
}
.tmj-app-row:hover {
    background-color: rgba(0, 212, 255, 0.12);
}
.tmj-app-row:selected {
    background-color: rgba(0, 212, 255, 0.22);
    color: #00d4ff;
}

.tmjdock-window {
    background: transparent;
}

.tmjdock-bar {
    background-color: rgba(10, 14, 42, 0.88);
    border-radius: 18px;
    padding: 8px;
    border: 1px solid rgba(0, 212, 255, 0.18);
    box-shadow: 0 6px 24px rgba(0, 0, 0, 0.4);
}

.tmjdock-app-button {
    background: transparent;
    border-radius: 12px;
    padding: 6px;
    transition: background 150ms ease;
}
.tmjdock-app-button:hover {
    background-color: rgba(255, 255, 255, 0.08);
}
.tmjdock-app-button:active {
    background-color: rgba(0, 212, 255, 0.2);
}

.tmjdock-menu-button {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.25), rgba(255, 45, 149, 0.25));
    border-radius: 14px;
    padding: 6px;
    border: 1px solid rgba(0, 212, 255, 0.4);
}
.tmjdock-menu-button:hover {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.45), rgba(255, 45, 149, 0.45));
    border: 1px solid rgba(0, 212, 255, 0.7);
}

.tmjdock-separator {
    background-color: rgba(255, 255, 255, 0.12);
    min-width: 1px;
}
"#;

/// Instala o CSS provider global (uma vez por app).
pub fn install_shared_css() {
    let provider = CssProvider::new();
    provider.load_from_string(SHARED_CSS);
    if let Some(display) = gdk::Display::default() {
        gtk::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}
