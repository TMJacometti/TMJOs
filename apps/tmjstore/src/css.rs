//! TMJStore CSS — paleta neon TMJOs.

pub const STORE_CSS: &str = r#"
window { background-color: #0a0e2a; }

.tmjstore-app-row {
    background-color: rgba(20, 24, 60, 0.6);
    border-radius: 12px;
    border: 1px solid rgba(0, 212, 255, 0.12);
    padding: 12px;
    margin: 6px 0;
}
.tmjstore-app-row:hover {
    background-color: rgba(20, 24, 60, 0.85);
    border: 1px solid rgba(0, 212, 255, 0.3);
}

.tmjstore-install-btn {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.3), rgba(255, 0, 170, 0.3));
    border: 1px solid rgba(0, 212, 255, 0.5);
    border-radius: 8px;
    padding: 6px 16px;
    font-weight: bold;
}
.tmjstore-install-btn:hover {
    background: linear-gradient(135deg, rgba(0, 212, 255, 0.5), rgba(255, 0, 170, 0.5));
}

.tmjstore-busy-btn {
    background: linear-gradient(135deg, rgba(50, 200, 80, 0.4), rgba(0, 212, 100, 0.4));
    border: 1px solid rgba(50, 200, 80, 0.7);
    border-radius: 8px;
    padding: 6px 16px;
    color: #d0ffd0;
    font-weight: bold;
}

.tmjstore-installed-tag {
    color: #00d4ff;
    font-weight: bold;
}

.tmjstore-chip {
    background-color: rgba(0, 212, 255, 0.15);
    border: 1px solid rgba(0, 212, 255, 0.3);
    border-radius: 999px;
    padding: 2px 10px;
    font-size: 0.85em;
}

.tmjstore-release {
    background-color: rgba(20, 24, 60, 0.4);
    border-left: 3px solid rgba(0, 212, 255, 0.5);
    border-radius: 6px;
    padding: 8px 12px;
}
"#;
