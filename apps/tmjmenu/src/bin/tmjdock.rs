//! tmjdock — dock bottom-center do TMJOs.
//!
//! Bar com botao TMJOs (abre tmjmenu), separator, pinned apps.
//! Anchor via gtk4-layer-shell (Wayland) com fallback X11 hints.

use adw::prelude::*;
use gio::ApplicationFlags;
use gtk::glib::clone;
use gtk::{
    gdk, gio, glib, Align, Box as GtkBox, Button, Image, Label, Orientation, Separator, Window,
};
use std::cell::Cell;
use std::rc::Rc;

use tmjmenu::config;
use tmjmenu::launcher;
use tmjmenu::monitors;
use tmjmenu::search;
use tmjmenu::widgets;
use tmjmenu::x11;

const DOCK_HEIGHT: i32 = 56;
const ICON_SIZE: i32 = 36;

fn main() -> glib::ExitCode {
    let app = adw::Application::builder()
        .application_id("dev.tmjos.TMJDock")
        .flags(ApplicationFlags::FLAGS_NONE)
        .build();

    app.connect_startup(|_| {
        adw::StyleManager::default().set_color_scheme(adw::ColorScheme::ForceDark);
        widgets::install_shared_css();
    });

    app.connect_activate(|app| {
        build_dock(app);
    });

    app.run()
}

fn build_dock(app: &adw::Application) {
    let all_apps = search::discover_apps();
    let pinned = config::load_pinned();

    let bar = GtkBox::builder()
        .orientation(Orientation::Horizontal)
        .spacing(4)
        .halign(Align::Center)
        .valign(Align::Center)
        .build();
    bar.add_css_class("tmjdock-bar");

    // TMJOs menu button
    let menu_btn = Button::builder()
        .tooltip_text("TMJOs Menu (Super+Space)")
        .build();
    let menu_icon = Image::from_icon_name("view-app-grid-symbolic");
    menu_icon.set_pixel_size(ICON_SIZE);
    menu_btn.set_child(Some(&menu_icon));
    menu_btn.add_css_class("tmjdock-menu-button");
    menu_btn.connect_clicked(|_| {
        let _ = std::process::Command::new("tmjmenu")
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
    });
    bar.append(&menu_btn);

    // Separator
    let sep = Separator::new(Orientation::Vertical);
    sep.add_css_class("tmjdock-separator");
    sep.set_margin_start(4);
    sep.set_margin_end(4);
    bar.append(&sep);

    // Pinned apps
    for desktop_id in &pinned {
        let app_entry = all_apps.iter().find(|a| a.desktop_id == *desktop_id);
        let btn = Button::builder()
            .tooltip_text(
                app_entry
                    .map(|a| a.name.as_str())
                    .unwrap_or(desktop_id.as_str()),
            )
            .build();

        let icon_name = app_entry
            .map(|a| a.icon.as_str())
            .unwrap_or("application-x-executable");
        let icon = if icon_name.is_empty() {
            Image::from_icon_name("application-x-executable")
        } else {
            Image::from_icon_name(icon_name)
        };
        icon.set_pixel_size(ICON_SIZE);
        btn.set_child(Some(&icon));
        btn.add_css_class("tmjdock-app-button");

        if let Some(entry) = app_entry.cloned() {
            btn.connect_clicked(move |_| {
                launcher::launch(&entry);
            });
        }

        bar.append(&btn);
    }

    let window = Window::builder()
        .application(app)
        .decorated(false)
        .resizable(false)
        .default_height(DOCK_HEIGHT)
        .build();
    window.add_css_class("tmjdock-window");
    window.set_child(Some(&bar));

    // Try layer-shell first (Wayland), fallback to X11
    let use_layer_shell = try_setup_layer_shell(&window);

    window.present();

    if !use_layer_shell {
        // X11 fallback: position and make dock after window is mapped
        let win_ref = window.clone();
        glib::idle_add_local_once(move || {
            setup_x11_dock(&win_ref);
        });
    }
}

fn try_setup_layer_shell(window: &Window) -> bool {
    #[cfg(feature = "wayland")]
    {
        if !gtk4_layer_shell::is_supported() {
            return false;
        }

        gtk4_layer_shell::init_for_window(window);
        gtk4_layer_shell::set_layer(window, gtk4_layer_shell::Layer::Top);
        gtk4_layer_shell::set_namespace(window, "tmjdock");

        gtk4_layer_shell::set_anchor(window, gtk4_layer_shell::Edge::Bottom, true);
        gtk4_layer_shell::set_anchor(window, gtk4_layer_shell::Edge::Left, false);
        gtk4_layer_shell::set_anchor(window, gtk4_layer_shell::Edge::Right, false);

        gtk4_layer_shell::set_margin(window, gtk4_layer_shell::Edge::Bottom, 8);
        gtk4_layer_shell::set_exclusive_zone(window, DOCK_HEIGHT);

        if let Some(monitor) = monitors::shell_monitor() {
            gtk4_layer_shell::set_monitor(window, &monitor);
        }

        return true;
    }

    #[cfg(not(feature = "wayland"))]
    false
}

fn setup_x11_dock(window: &Window) {
    let Some(surface) = window.surface() else {
        return;
    };

    // Get XID from GDK X11 surface
    let xid = get_x11_window_id(&surface);
    let Some(xid) = xid else {
        eprintln!("tmjdock: no X11 surface, can't set dock hints");
        return;
    };

    let geom = monitors::shell_geometry().unwrap_or(monitors::MonitorGeometry {
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
    });

    let (dock_width, _) = window.default_size();
    let dock_width = if dock_width > 0 { dock_width } else { 400 };

    if let Err(e) = x11::make_dock(
        xid,
        geom.x,
        geom.y,
        geom.width,
        geom.height,
        dock_width,
        DOCK_HEIGHT,
    ) {
        eprintln!("tmjdock: X11 make_dock failed: {e}");
    }
}

fn get_x11_window_id(surface: &gdk::Surface) -> Option<u32> {
    #[cfg(all(unix, feature = "x11"))]
    {
        use gdk_x11::X11Surface;
        if let Some(x11_surface) = surface.downcast_ref::<X11Surface>() {
            return Some(x11_surface.xid() as u32);
        }
    }
    // Fallback: try to read from GDK property
    None
}
