//! Session and buffer persistence.
//!
//! Cada tab tem um buffer file em `~/.config/tmjpad/buffers/<uuid>.txt`
//! que espelha o texto atual. session.json contém lista de tabs (ordem,
//! paths, cursor positions, active tab, window size).
//!
//! Auto-save escreve nos buffer files em cada modificação (debounced).
//! session.json é re-escrito em open/close/save/reorder de tab.
//!
//! Source of truth no restart: os buffer files. session.json descreve
//! como mostrar.

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::{fs, io};
use uuid::Uuid;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TabState {
    pub id: String,
    pub title: String,
    pub path: Option<String>, // None = untitled
    #[serde(default)]
    pub cursor_offset: i32,
}

impl TabState {
    pub fn new(title: impl Into<String>, path: Option<String>) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            title: title.into(),
            path,
            cursor_offset: 0,
        }
    }

    pub fn buffer_path(&self, base: &Path) -> PathBuf {
        base.join(format!("{}.txt", self.id))
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Session {
    #[serde(default)]
    pub tabs: Vec<TabState>,
    #[serde(default)]
    pub active_index: usize,
    #[serde(default = "default_width")]
    pub window_width: i32,
    #[serde(default = "default_height")]
    pub window_height: i32,
}

fn default_width() -> i32 {
    1100
}

fn default_height() -> i32 {
    700
}

impl Default for Session {
    fn default() -> Self {
        Self {
            tabs: Vec::new(),
            active_index: 0,
            window_width: default_width(),
            window_height: default_height(),
        }
    }
}

pub fn config_dir() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from(".config"))
        .join("tmjpad")
}

pub fn buffers_dir() -> PathBuf {
    config_dir().join("buffers")
}

pub fn session_file() -> PathBuf {
    config_dir().join("session.json")
}

impl Session {
    /// Lê session.json. Retorna `Session::default()` se ausente ou corrupto.
    /// Em caso de corrupção, renomeia o arquivo ruim pra `.json.bak`.
    pub fn load() -> Self {
        let session_path = session_file();
        if !session_path.exists() {
            return Self::default();
        }

        let raw = match fs::read_to_string(&session_path) {
            Ok(s) => s,
            Err(_) => return Self::default(),
        };

        match serde_json::from_str::<Session>(&raw) {
            Ok(s) => s,
            Err(_) => {
                let bak = session_path.with_extension("json.bak");
                let _ = fs::rename(&session_path, &bak);
                Self::default()
            }
        }
    }

    /// Atomic write: arquivo tmp + rename.
    pub fn save(&self) -> io::Result<()> {
        let session_path = session_file();
        if let Some(parent) = session_path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::create_dir_all(buffers_dir())?;

        let tmp = session_path.with_extension("json.tmp");
        let json = serde_json::to_string_pretty(self)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        fs::write(&tmp, json)?;
        fs::rename(&tmp, &session_path)?;
        Ok(())
    }
}

/// Gera próximo nome 'Untitled-N' não usado.
pub fn next_untitled_title<I: IntoIterator<Item = S>, S: AsRef<str>>(existing: I) -> String {
    let existing: std::collections::HashSet<String> =
        existing.into_iter().map(|s| s.as_ref().to_string()).collect();
    let mut n = 1;
    loop {
        let candidate = format!("Untitled-{n}");
        if !existing.contains(&candidate) {
            return candidate;
        }
        n += 1;
    }
}

/// Atomic write do buffer file.
pub fn write_buffer(state: &TabState, content: &str) -> io::Result<()> {
    let base = buffers_dir();
    fs::create_dir_all(&base)?;
    let buf = state.buffer_path(&base);
    let tmp = buf.with_extension("tmp");
    fs::write(&tmp, content)?;
    fs::rename(&tmp, &buf)?;
    Ok(())
}

pub fn read_buffer(state: &TabState) -> String {
    let buf = state.buffer_path(&buffers_dir());
    fs::read_to_string(&buf).unwrap_or_default()
}

pub fn remove_buffer(state: &TabState) {
    let buf = state.buffer_path(&buffers_dir());
    let _ = fs::remove_file(&buf);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn next_untitled_with_empty() {
        let empty: Vec<&str> = vec![];
        assert_eq!(next_untitled_title(empty), "Untitled-1");
    }

    #[test]
    fn next_untitled_skips_existing() {
        assert_eq!(
            next_untitled_title(vec!["Untitled-1", "Untitled-2"]),
            "Untitled-3"
        );
    }

    #[test]
    fn session_default_dimensions() {
        let s = Session::default();
        assert_eq!(s.window_width, 1100);
        assert_eq!(s.window_height, 700);
    }

    #[test]
    fn tab_state_new_has_uuid() {
        let t = TabState::new("foo", None);
        assert!(!t.id.is_empty());
        assert_eq!(t.title, "foo");
        assert!(t.path.is_none());
    }
}
