//! TMJOs dark theme CSS — paleta neon TMJOs.
//! Cyan #00d4ff, magenta #ff2d95, navy #0a0e2a, dark #050714, light #e6e6e6.

pub const DARK_CSS: &str = r#"
window { background-color: #0a0e2a; }

.tmjpad-textview, .tmjpad-textview text {
    background-color: #0a0e2a;
    color: #e6e6e6;
    font-family: 'JetBrains Mono', 'Cascadia Code', 'Fira Code', monospace;
    font-size: 13pt;
    caret-color: #00d4ff;
}
.tmjpad-textview text selection {
    background-color: alpha(#9d4edd, 0.5);
    color: #ffffff;
}

.tmjpad-status {
    background-color: #050714;
    color: #00d4ff;
    padding: 4px 12px;
    font-family: monospace;
    font-size: 10pt;
    border-top: 1px solid #1a1e3a;
}

notebook header {
    background-color: #050714;
    border-bottom: 1px solid #1a1e3a;
}
notebook tab {
    background-color: #0a0e2a;
    color: #888;
    padding: 4px 12px;
    border-radius: 0;
    border-right: 1px solid #1a1e3a;
}
notebook tab:checked {
    background-color: #1a1e3a;
    color: #00d4ff;
}
notebook tab button {
    min-width: 16px;
    min-height: 16px;
    padding: 2px;
}

headerbar {
    background-color: #050714;
    color: #e6e6e6;
    border-bottom: 1px solid #1a1e3a;
}

.tmjpad-find-bar {
    background-color: #050714;
    border-bottom: 1px solid #1a1e3a;
}
.tmjpad-find-bar entry {
    background-color: #0a0e2a;
    color: #e6e6e6;
    border: 1px solid #1a1e3a;
    border-radius: 4px;
    padding: 4px 8px;
}
.tmjpad-find-bar entry:focus {
    border-color: #00d4ff;
    box-shadow: 0 0 0 1px #00d4ff;
}
.tmjpad-find-bar entry.error {
    border-color: #ff2d95;
    color: #ff2d95;
}
.tmjpad-find-bar button {
    background-color: #1a1e3a;
    color: #00d4ff;
    border-radius: 4px;
}
.tmjpad-find-bar button:hover {
    background-color: #252a4d;
}
"#;
