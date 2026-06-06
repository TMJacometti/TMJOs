//! tmjmenu — popup search launcher do TMJOs.
//!
//! Super+Space abre popup com search entry + lista de apps.
//! Digita pra filtrar, Enter lança, Esc fecha.

use adw::prelude::*;
use gio::ApplicationFlags;
use gtk::glib::clone;
use gtk::{
    gdk, gio, glib, Align, Box as GtkBox, EventControllerKey, Image, Label, ListBox,
    ListBoxRow, Orientation, ScrolledWindow, SearchEntry, SelectionMode, Window,
};
use std::cell::RefCell;
use std::rc::Rc;

use tmjmenu::launcher;
use tmjmenu::search::{self, AppEntry};
use tmjmenu::widgets;

const POPUP_WIDTH: i32 = 560;
const POPUP_HEIGHT: i32 = 480;

fn main() -> glib::ExitCode {
    let app = adw::Application::builder()
        .application_id("dev.tmjos.TMJMenu")
        .flags(ApplicationFlags::FLAGS_NONE)
        .build();

    app.connect_startup(|_| {
        adw::StyleManager::default().set_color_scheme(adw::ColorScheme::ForceDark);
        widgets::install_shared_css();
    });

    app.connect_activate(|app| {
        build_popup(app);
    });

    app.run()
}

fn build_popup(app: &adw::Application) {
    let all_apps = Rc::new(search::discover_apps());

    let search_entry = SearchEntry::builder()
        .placeholder_text("Search apps...")
        .hexpand(true)
        .build();
    search_entry.add_css_class("tmj-popup-search");

    let list_box = ListBox::builder()
        .selection_mode(SelectionMode::Browse)
        .build();
    list_box.add_css_class("tmj-popup");

    let scroller = ScrolledWindow::builder()
        .hexpand(true)
        .vexpand(true)
        .child(&list_box)
        .build();

    let container = GtkBox::builder()
        .orientation(Orientation::Vertical)
        .spacing(8)
        .margin_top(12)
        .margin_bottom(12)
        .margin_start(12)
        .margin_end(12)
        .build();
    container.append(&search_entry);
    container.append(&scroller);

    let window = Window::builder()
        .application(app)
        .default_width(POPUP_WIDTH)
        .default_height(POPUP_HEIGHT)
        .decorated(false)
        .resizable(false)
        .build();
    window.add_css_class("tmj-popup");
    window.set_child(Some(&container));

    populate_list(&list_box, &search::search(&all_apps, ""));

    let apps_for_search = all_apps.clone();
    let list_for_search = list_box.clone();
    search_entry.connect_search_changed(move |entry| {
        let query = entry.text().to_string();
        let results = search::search(&apps_for_search, &query);
        populate_list(&list_for_search, &results);
    });

    let win_for_activate = window.clone();
    list_box.connect_row_activated(move |_, row| {
        if let Some(name) = row.widget_name().as_str().strip_prefix("app:") {
            launch_by_desktop_id(&all_apps, name);
            win_for_activate.close();
        }
    });

    let key_ctrl = EventControllerKey::new();
    let win_for_key = window.clone();
    let list_for_key = list_box.clone();
    let search_for_key = search_entry.clone();
    key_ctrl.connect_key_pressed(move |_, key, _, _| {
        match key {
            gdk::Key::Escape => {
                win_for_key.close();
                return glib::Propagation::Stop;
            }
            gdk::Key::Return | gdk::Key::KP_Enter => {
                if let Some(row) = list_for_key.selected_row() {
                    list_for_key.emit_by_name::<()>("row-activated", &[&row]);
                }
                return glib::Propagation::Stop;
            }
            gdk::Key::Down => {
                list_for_key.grab_focus();
                return glib::Propagation::Stop;
            }
            gdk::Key::Up => {
                search_for_key.grab_focus();
                return glib::Propagation::Stop;
            }
            _ => {}
        }
        glib::Propagation::Proceed
    });
    window.add_controller(key_ctrl);

    window.connect_close_request(|win| {
        if let Some(app) = win.application() {
            app.quit();
        }
        glib::Propagation::Proceed
    });

    window.present();
    search_entry.grab_focus();

    // X11 popup hints (fallback quando não tem layer-shell)
    glib::idle_add_local_once(clone!(@weak window => move || {
        if let Some(surface) = window.surface() {
            if let Some(native) = surface.downcast_ref::<gdk::Surface>() {
                // Try to get XID for X11 popup positioning
                // On Wayland this is a no-op
            }
        }
    }));
}

fn populate_list(list_box: &ListBox, apps: &[&AppEntry]) {
    while let Some(child) = list_box.first_child() {
        list_box.remove(&child);
    }

    for app in apps {
        let row = create_app_row(app);
        list_box.append(&row);
    }

    if let Some(first) = list_box.row_at_index(0) {
        list_box.select_row(Some(&first));
    }
}

fn create_app_row(app: &AppEntry) -> ListBoxRow {
    let icon = if app.icon.is_empty() {
        Image::from_icon_name("application-x-executable")
    } else {
        Image::from_icon_name(&app.icon)
    };
    icon.set_pixel_size(32);

    let name_label = Label::builder()
        .label(&app.name)
        .halign(Align::Start)
        .build();
    name_label.add_css_class("heading");

    let comment_label = Label::builder()
        .label(if app.comment.is_empty() { &app.exec_cmd } else { &app.comment })
        .halign(Align::Start)
        .build();
    comment_label.set_opacity(0.6);

    let text_box = GtkBox::builder()
        .orientation(Orientation::Vertical)
        .spacing(2)
        .build();
    text_box.append(&name_label);
    text_box.append(&comment_label);

    let hbox = GtkBox::builder()
        .orientation(Orientation::Horizontal)
        .spacing(12)
        .build();
    hbox.append(&icon);
    hbox.append(&text_box);

    let row = ListBoxRow::builder()
        .child(&hbox)
        .build();
    row.add_css_class("tmj-app-row");
    row.set_widget_name(&format!("app:{}", app.desktop_id));
    row
}

fn launch_by_desktop_id(apps: &[AppEntry], desktop_id: &str) {
    if let Some(app) = apps.iter().find(|a| a.desktop_id == desktop_id) {
        launcher::launch(app);
    }
}
