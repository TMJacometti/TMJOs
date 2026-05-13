//! Spawn de apps a partir de uma AppEntry — usa GLib pra detach correto.

use crate::search::AppEntry;

/// Field codes XDG (https://specifications.freedesktop.org/desktop-entry-spec/)
/// %f %F %u %U são pra arquivos passados pelo file manager — pra lançar
/// do menu sem arquivo, strip estes.
fn strip_field_codes(exec_cmd: &str) -> String {
    let mut result = String::with_capacity(exec_cmd.len());
    let chars: Vec<char> = exec_cmd.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '%' && i + 1 < chars.len() {
            let next = chars[i + 1];
            if matches!(next, 'f' | 'F' | 'u' | 'U' | 'd' | 'D' | 'n' | 'N' | 'i' | 'c' | 'k' | 'v' | 'm') {
                i += 2;
                continue;
            }
        }
        result.push(chars[i]);
        i += 1;
    }
    result.trim().to_string()
}

/// Lança o app em background, detached do tmjmenu/tmjdock.
/// Retorna true se conseguiu spawn (não significa que o app não vai
/// crashar logo em seguida — só significa que o exec rolou).
pub fn launch(app: &AppEntry) -> bool {
    let cmd = strip_field_codes(&app.exec_cmd);
    if cmd.is_empty() {
        return false;
    }

    // Parse shell-style (semelhante a shlex.split)
    let argv = match shell_split(&cmd) {
        Some(v) if !v.is_empty() => v,
        _ => return false,
    };

    // std::process::Command + setsid pra detach do processo pai
    let mut command = std::process::Command::new(&argv[0]);
    if argv.len() > 1 {
        command.args(&argv[1..]);
    }
    // Detach: stdin/stdout/stderr → /dev/null, processo independente.
    command.stdin(std::process::Stdio::null());
    command.stdout(std::process::Stdio::null());
    command.stderr(std::process::Stdio::null());

    // Spawn em new session (setsid) pra sobreviver à morte do parent.
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        unsafe {
            command.pre_exec(|| {
                // setsid — process group novo, vira leader
                if libc_setsid() < 0 {
                    return Err(std::io::Error::last_os_error());
                }
                Ok(())
            });
        }
    }

    command.spawn().is_ok()
}

#[cfg(unix)]
extern "C" {
    #[link_name = "setsid"]
    fn libc_setsid() -> i32;
}

#[cfg(not(unix))]
fn libc_setsid() -> i32 {
    0
}

/// Simple shell-style splitter (subset de shlex). Trata aspas simples
/// e duplas, escapes básicos.
fn shell_split(cmd: &str) -> Option<Vec<String>> {
    let mut args: Vec<String> = Vec::new();
    let mut current = String::new();
    let mut chars = cmd.chars().peekable();
    let mut in_single = false;
    let mut in_double = false;

    while let Some(c) = chars.next() {
        match c {
            '\\' if !in_single => {
                if let Some(&next) = chars.peek() {
                    current.push(next);
                    chars.next();
                }
            }
            '\'' if !in_double => in_single = !in_single,
            '"' if !in_single => in_double = !in_double,
            c if c.is_whitespace() && !in_single && !in_double => {
                if !current.is_empty() {
                    args.push(std::mem::take(&mut current));
                }
            }
            c => current.push(c),
        }
    }

    if in_single || in_double {
        return None;
    }
    if !current.is_empty() {
        args.push(current);
    }
    Some(args)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strip_basic() {
        assert_eq!(strip_field_codes("/usr/bin/code %F"), "/usr/bin/code");
        assert_eq!(strip_field_codes("/usr/bin/firefox %u"), "/usr/bin/firefox");
    }

    #[test]
    fn shell_split_basic() {
        assert_eq!(
            shell_split("/usr/bin/code"),
            Some(vec!["/usr/bin/code".to_string()])
        );
        assert_eq!(
            shell_split("/usr/bin/env code --foo"),
            Some(vec!["/usr/bin/env".to_string(), "code".to_string(), "--foo".to_string()])
        );
    }

    #[test]
    fn shell_split_quoted() {
        assert_eq!(
            shell_split(r#"foo "bar baz""#),
            Some(vec!["foo".to_string(), "bar baz".to_string()])
        );
    }
}
