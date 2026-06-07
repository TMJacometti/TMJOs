//! Install/remove/upgrade de apps via pkexec + apt-get.
//!
//! pkexec eleva privilegio com prompt grafico (PolicyKit).

use gtk::glib;

pub fn install(pkg: &str, on_done: impl Fn(bool, &str) + 'static) {
    spawn_apt("install", pkg, on_done);
}

pub fn remove(pkg: &str, on_done: impl Fn(bool, &str) + 'static) {
    spawn_apt("remove", pkg, on_done);
}

pub fn upgrade(pkg: &str, on_done: impl Fn(bool, &str) + 'static) {
    spawn_apt("install", pkg, on_done);
}

fn spawn_apt(action: &str, pkg: &str, on_done: impl Fn(bool, &str) + 'static) {
    let mut argv = vec![
        "pkexec".to_string(),
        "apt-get".to_string(),
        "-y".to_string(),
        "-q".to_string(),
    ];
    if action == "install" {
        argv.push("--no-install-recommends".to_string());
    }
    argv.push(action.to_string());
    argv.push(pkg.to_string());

    let (tx, rx) = std::sync::mpsc::channel::<(bool, String)>();

    std::thread::spawn(move || {
        let result = std::process::Command::new(&argv[0])
            .args(&argv[1..])
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status();

        let (success, msg) = match result {
            Ok(status) => {
                if status.success() {
                    (true, "OK".to_string())
                } else {
                    (false, format!("apt-get retornou {}", status.code().unwrap_or(-1)))
                }
            }
            Err(e) => (false, format!("Falha ao spawn: {e}")),
        };

        let _ = tx.send((success, msg));
    });

    glib::idle_add_local(move || {
        match rx.try_recv() {
            Ok((success, msg)) => {
                on_done(success, &msg);
                glib::ControlFlow::Break
            }
            Err(std::sync::mpsc::TryRecvError::Empty) => glib::ControlFlow::Continue,
            Err(_) => glib::ControlFlow::Break,
        }
    });
}
