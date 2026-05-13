//! Discovery e search de aplicações via XDG .desktop entries.
//!
//! Lê todas .desktop files dos dirs XDG padrão e fornece busca fuzzy
//! por nome, comment, exec, keywords. Idêntico ao que GNOME Shell /
//! Activities faz.

use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

/// Representa um app instalado, parseado de uma .desktop entry.
#[derive(Clone, Debug)]
pub struct AppEntry {
    pub desktop_id: String,
    pub name: String,
    pub comment: String,
    pub exec_cmd: String,
    pub icon: String,
    pub categories: Vec<String>,
    pub keywords: Vec<String>,
    pub no_display: bool,
}

fn applications_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if let Some(home) = dirs::home_dir() {
        dirs.push(home.join(".local/share/applications"));
    }
    dirs.push(PathBuf::from("/usr/local/share/applications"));
    dirs.push(PathBuf::from("/usr/share/applications"));
    dirs
}

fn parse_desktop(path: &PathBuf) -> Option<AppEntry> {
    let raw = fs::read_to_string(path).ok()?;
    let mut in_section = false;
    let mut fields: HashMap<String, String> = HashMap::new();

    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            // Só processamos [Desktop Entry], ignoramos outras seções
            // (ex: [Desktop Action ...])
            in_section = trimmed == "[Desktop Entry]";
            continue;
        }
        if !in_section {
            continue;
        }
        // Pega só Key=Value (sem locale variants tipo Name[pt_BR]=...)
        if let Some(eq) = trimmed.find('=') {
            let key = trimmed[..eq].trim();
            if !key.contains('[') {
                let value = trimmed[eq + 1..].trim().to_string();
                fields.insert(key.to_string(), value);
            }
        }
    }

    // Filtros básicos — desktop spec
    if fields.get("Type").map(|s| s.as_str()) != Some("Application") {
        return None;
    }
    if fields
        .get("Hidden")
        .map(|s| s.to_lowercase())
        .as_deref()
        == Some("true")
    {
        return None;
    }
    let name = fields.get("Name").cloned().unwrap_or_default();
    let exec_cmd = fields.get("Exec").cloned().unwrap_or_default();
    if name.is_empty() || exec_cmd.is_empty() {
        return None;
    }

    let desktop_id = path
        .file_name()?
        .to_string_lossy()
        .into_owned();
    let categories = fields
        .get("Categories")
        .map(|s| s.split(';').filter(|c| !c.is_empty()).map(String::from).collect())
        .unwrap_or_default();
    let keywords = fields
        .get("Keywords")
        .map(|s| s.split(';').filter(|c| !c.is_empty()).map(String::from).collect())
        .unwrap_or_default();
    let no_display = fields
        .get("NoDisplay")
        .map(|s| s.to_lowercase() == "true")
        .unwrap_or(false);

    Some(AppEntry {
        desktop_id,
        name,
        comment: fields.get("Comment").cloned().unwrap_or_default(),
        exec_cmd,
        icon: fields.get("Icon").cloned().unwrap_or_default(),
        categories,
        keywords,
        no_display,
    })
}

/// Lista todos os apps instalados (não-ocultos), dedup por desktop_id.
/// User overrides em `~/.local/share/applications/` ganham de `/usr/share/`.
pub fn discover_apps() -> Vec<AppEntry> {
    let mut seen: HashMap<String, AppEntry> = HashMap::new();

    for d in applications_dirs() {
        if !d.is_dir() {
            continue;
        }
        let Ok(entries) = fs::read_dir(&d) else {
            continue;
        };
        let mut paths: Vec<PathBuf> = entries
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .filter(|p| p.extension().map(|e| e == "desktop").unwrap_or(false))
            .collect();
        paths.sort();
        for p in paths {
            let Some(filename) = p.file_name().map(|n| n.to_string_lossy().into_owned()) else {
                continue;
            };
            if seen.contains_key(&filename) {
                continue;
            }
            let Some(entry) = parse_desktop(&p) else {
                continue;
            };
            if entry.no_display {
                continue;
            }
            seen.insert(filename, entry);
        }
    }

    seen.into_values().collect()
}

/// Score >=0 se app casa com query, ou None se não.
/// Maior = melhor match.
pub fn fuzzy_match(query: &str, app: &AppEntry) -> Option<i32> {
    if query.is_empty() {
        return Some(0);
    }
    let q = query.to_lowercase();
    let name = app.name.to_lowercase();
    let comment = app.comment.to_lowercase();
    let exec_cmd = app.exec_cmd.to_lowercase();

    if name.starts_with(&q) {
        return Some(100);
    }
    if name.contains(&q) {
        return Some(50);
    }
    if comment.contains(&q) {
        return Some(20);
    }
    if app.keywords.iter().any(|k| k.to_lowercase().contains(&q)) {
        return Some(15);
    }
    if exec_cmd.contains(&q) {
        return Some(10);
    }
    None
}

/// Filtra + ordena apps por relevância.
/// Query vazia → todos em ordem alfabética por nome.
pub fn search<'a>(apps: &'a [AppEntry], query: &str) -> Vec<&'a AppEntry> {
    if query.trim().is_empty() {
        let mut sorted: Vec<&AppEntry> = apps.iter().collect();
        sorted.sort_by_key(|a| a.name.to_lowercase());
        return sorted;
    }

    let mut scored: Vec<(i32, String, &AppEntry)> = apps
        .iter()
        .filter_map(|a| fuzzy_match(query, a).map(|s| (s, a.name.to_lowercase(), a)))
        .collect();
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
    scored.into_iter().map(|(_, _, a)| a).collect()
}
