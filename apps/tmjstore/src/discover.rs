//! Discovery de apps TMJOs via APT + AppStream XML.

use quick_xml::events::Event;
use quick_xml::Reader;
use std::path::{Path, PathBuf};
use std::process::Command;

const TMJ_REPO_ORIGINS: &[&str] = &["packages.tmjos.com.br", "tmjacometti.github.io/tmjos"];

const CORE_PACKAGES: &[&str] = &["tmjmenu", "tmjstore"];

#[derive(Clone, Debug)]
pub struct TMJRelease {
    pub version: String,
    pub date: String,
    pub description: String,
}

#[derive(Clone, Debug)]
pub struct TMJApp {
    pub pkg_name: String,
    pub display_name: String,
    pub summary: String,
    pub description: String,
    pub icon_name: String,
    pub installed: bool,
    pub installed_version: String,
    pub candidate_version: String,
    pub homepage: String,
    pub developer: String,
    pub license: String,
    pub categories: Vec<String>,
    pub releases: Vec<TMJRelease>,
    pub has_update: bool,
}

fn metainfo_dirs() -> Vec<PathBuf> {
    let mut paths = Vec::new();
    if let Some(home) = dirs::home_dir() {
        paths.push(home.join(".local/share/metainfo"));
    }
    paths.push(PathBuf::from("/usr/share/metainfo"));
    paths
}

fn list_tmj_packages() -> Vec<String> {
    let output = Command::new("apt-cache")
        .args(["search", "tmjos"])
        .output();

    let Ok(output) = output else {
        return Vec::new();
    };

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut pkg_names: Vec<String> = stdout
        .lines()
        .filter_map(|line| {
            let name = line.split(" - ").next()?.trim().to_string();
            if name.is_empty() {
                return None;
            }
            if CORE_PACKAGES.contains(&name.as_str()) {
                return None;
            }
            Some(name)
        })
        .filter(|name| is_from_tmj_repo(name))
        .collect();

    pkg_names.sort();
    pkg_names.dedup();
    pkg_names
}

fn is_from_tmj_repo(pkg_name: &str) -> bool {
    let output = Command::new("apt-cache")
        .args(["policy", pkg_name])
        .output();

    let Ok(output) = output else {
        return false;
    };

    let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
    TMJ_REPO_ORIGINS.iter().any(|origin| stdout.contains(origin))
}

fn pkg_versions(pkg_name: &str) -> (bool, String, String) {
    let output = Command::new("apt-cache")
        .args(["policy", pkg_name])
        .output();

    let Ok(output) = output else {
        return (false, String::new(), String::new());
    };

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut installed = false;
    let mut inst_ver = String::new();
    let mut cand_ver = String::new();

    for line in stdout.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("Installed:") {
            let v = rest.trim();
            if v != "(none)" {
                installed = true;
                inst_ver = v.to_string();
            }
        } else if let Some(rest) = trimmed.strip_prefix("Candidate:") {
            cand_ver = rest.trim().to_string();
        }
    }

    (installed, inst_ver, cand_ver)
}

fn find_appdata_xml(pkg_name: &str) -> Option<PathBuf> {
    for dir in metainfo_dirs() {
        if !dir.is_dir() {
            continue;
        }
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if name.contains(pkg_name) && name.ends_with(".appdata.xml") {
                return Some(path);
            }
        }
    }
    None
}

fn parse_appdata_xml(path: &Path) -> AppDataInfo {
    let mut info = AppDataInfo::default();
    let Ok(content) = std::fs::read_to_string(path) else {
        return info;
    };

    let mut reader = Reader::from_str(&content);
    let mut current_tag = String::new();
    let mut in_component = false;
    let mut in_description = false;
    let mut in_release = false;
    let mut current_release = TMJRelease {
        version: String::new(),
        date: String::new(),
        description: String::new(),
    };
    let mut desc_parts: Vec<String> = Vec::new();

    loop {
        match reader.read_event() {
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                let tag_local = tag.split('}').last().unwrap_or(&tag).to_string();
                current_tag = tag_local.clone();

                if tag_local == "component" {
                    in_component = true;
                }
                if tag_local == "description" && in_component && !in_release {
                    in_description = true;
                    desc_parts.clear();
                }
                if tag_local == "release" {
                    in_release = true;
                    current_release = TMJRelease {
                        version: String::new(),
                        date: String::new(),
                        description: String::new(),
                    };
                    for attr in e.attributes().flatten() {
                        let key = String::from_utf8_lossy(attr.key.as_ref()).to_string();
                        let val = String::from_utf8_lossy(&attr.value).to_string();
                        if key == "version" {
                            current_release.version = val;
                        } else if key == "date" {
                            current_release.date = val;
                        }
                    }
                }
                if tag_local == "url" {
                    for attr in e.attributes().flatten() {
                        let key = String::from_utf8_lossy(attr.key.as_ref()).to_string();
                        let val = String::from_utf8_lossy(&attr.value).to_string();
                        if key == "type" && val == "homepage" {
                            current_tag = "url_homepage".to_string();
                        }
                    }
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.unescape().unwrap_or_default().trim().to_string();
                if text.is_empty() {
                    continue;
                }
                match current_tag.as_str() {
                    "name" if in_component && info.display_name.is_empty() => {
                        info.display_name = text;
                    }
                    "summary" if in_component && info.summary.is_empty() => {
                        info.summary = text;
                    }
                    "p" if in_description => {
                        desc_parts.push(text);
                    }
                    "li" if in_description => {
                        desc_parts.push(format!("  - {text}"));
                    }
                    "url_homepage" => {
                        info.homepage = text;
                    }
                    "project_license" => {
                        info.license = text;
                    }
                    "category" => {
                        info.categories.push(text);
                    }
                    _ => {}
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                let tag_local = tag.split('}').last().unwrap_or(&tag);
                if tag_local == "description" && in_description && !in_release {
                    in_description = false;
                    info.description = desc_parts.join("\n\n");
                }
                if tag_local == "release" {
                    in_release = false;
                    if !current_release.version.is_empty() {
                        info.releases.push(current_release.clone());
                    }
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    info
}

fn apt_cache_metadata(pkg_name: &str) -> AppDataInfo {
    let mut info = AppDataInfo::default();
    let output = Command::new("apt-cache")
        .args(["show", pkg_name])
        .output();

    let Ok(output) = output else {
        return info;
    };

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut in_desc = false;
    let mut desc_lines: Vec<String> = Vec::new();

    for line in stdout.lines() {
        if line.starts_with("Description:") || line.starts_with("Description-en:") {
            if let Some((_, summary)) = line.split_once(':') {
                info.summary = summary.trim().to_string();
            }
            in_desc = true;
            continue;
        }
        if in_desc {
            if line.starts_with(' ') {
                let stripped = &line[1..];
                if stripped == "." {
                    desc_lines.push(String::new());
                } else {
                    desc_lines.push(stripped.to_string());
                }
            } else {
                break;
            }
        }
    }

    if !desc_lines.is_empty() {
        info.description = desc_lines.join("\n");
    }

    info
}

#[derive(Default, Clone)]
struct AppDataInfo {
    display_name: String,
    summary: String,
    description: String,
    homepage: String,
    developer: String,
    license: String,
    categories: Vec<String>,
    releases: Vec<TMJRelease>,
}

pub fn discover_tmj_apps() -> Vec<TMJApp> {
    let mut apps = Vec::new();

    for pkg in list_tmj_packages() {
        let (installed, inst_ver, cand_ver) = pkg_versions(&pkg);
        let has_update = installed && !cand_ver.is_empty() && inst_ver != cand_ver;

        let info = if let Some(xml_path) = find_appdata_xml(&pkg) {
            parse_appdata_xml(&xml_path)
        } else {
            apt_cache_metadata(&pkg)
        };

        let display_name = if info.display_name.is_empty() {
            capitalize(&pkg)
        } else {
            info.display_name
        };
        let summary = if info.summary.is_empty() {
            format!("Pacote {pkg}")
        } else {
            info.summary
        };

        apps.push(TMJApp {
            pkg_name: pkg.clone(),
            display_name,
            summary,
            description: info.description,
            icon_name: pkg,
            installed,
            installed_version: inst_ver,
            candidate_version: cand_ver,
            homepage: info.homepage,
            developer: info.developer,
            license: info.license,
            categories: info.categories,
            releases: info.releases,
            has_update,
        });
    }

    apps
}

fn capitalize(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    }
}
