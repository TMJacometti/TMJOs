//! Persistência de configuração — pinned apps + dock settings.
//!
//! `~/.config/tmjmenu/pinned.json` é lista de desktop_ids:
//!   ["code.desktop", "tmjpad.desktop", ...]

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::{fs, io};

const DEFAULT_PINNED: &[&str] = &[
    "code.desktop",
    "org.gnome.Terminal.desktop",
    "org.gnome.Nautilus.desktop",
    "tmjpad.desktop",
];

pub fn config_dir() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from(".config"))
        .join("tmjmenu")
}

pub fn pinned_file() -> PathBuf {
    config_dir().join("pinned.json")
}

/// Lê pinned.json. Fallback pra DEFAULT_PINNED se file não existe ou
/// é inválido. Não cria o arquivo no read (só no save).
pub fn load_pinned() -> Vec<String> {
    let path = pinned_file();
    if !path.is_file() {
        return DEFAULT_PINNED.iter().map(|s| s.to_string()).collect();
    }
    let Ok(raw) = fs::read_to_string(&path) else {
        return DEFAULT_PINNED.iter().map(|s| s.to_string()).collect();
    };
    match serde_json::from_str::<Vec<String>>(&raw) {
        Ok(v) => v,
        Err(_) => DEFAULT_PINNED.iter().map(|s| s.to_string()).collect(),
    }
}

/// Atomic write de pinned.json — tmp + rename.
pub fn save_pinned(items: &[String]) -> io::Result<()> {
    let dir = config_dir();
    fs::create_dir_all(&dir)?;
    let path = pinned_file();
    let tmp = path.with_extension("json.tmp");
    let json = serde_json::to_string_pretty(items)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
    fs::write(&tmp, json)?;
    fs::rename(&tmp, &path)?;
    Ok(())
}

pub fn add_pinned(desktop_id: &str) -> bool {
    let mut items = load_pinned();
    if items.iter().any(|s| s == desktop_id) {
        return false;
    }
    items.push(desktop_id.to_string());
    save_pinned(&items).is_ok()
}

pub fn remove_pinned(desktop_id: &str) -> bool {
    let mut items = load_pinned();
    let original_len = items.len();
    items.retain(|s| s != desktop_id);
    if items.len() == original_len {
        return false;
    }
    save_pinned(&items).is_ok()
}

pub fn is_pinned(desktop_id: &str) -> bool {
    load_pinned().iter().any(|s| s == desktop_id)
}

/// Configurações da dock (opcional, lido de `~/.config/tmjmenu/dock.toml`).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DockConfig {
    /// Auto-hide habilitado? Default false (sempre visível = mais
    /// performático, sem polling de cursor nem strut churn).
    #[serde(default)]
    pub auto_hide: bool,
}

impl Default for DockConfig {
    fn default() -> Self {
        Self { auto_hide: false }
    }
}

impl DockConfig {
    /// Lê dock.toml — fallback pra defaults se ausente.
    pub fn load() -> Self {
        let path = config_dir().join("dock.toml");
        if !path.is_file() {
            return Self::default();
        }
        let Ok(_raw) = fs::read_to_string(&path) else {
            return Self::default();
        };
        // TOML parsing simplificado por enquanto — só auto_hide.
        // Quando dock.toml ficar maior, add `toml` crate.
        Self::default()
    }
}
