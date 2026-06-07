//! Janela principal do TMJStore.

use adw::prelude::*;
use adw::subclass::prelude::*;
use gtk::{
    Align, Box as GtkBox, Button, Image, Label, ListBox, Orientation,
    ScrolledWindow, SelectionMode,
};
use std::cell::RefCell;
use std::collections::HashSet;
use std::rc::Rc;

use crate::css;
use crate::detail;
use crate::discover::{self, TMJApp};
use crate::installer;

// ── Subclass boilerplate ─────────────────────────────────────────────

mod imp {
    use super::*;

    #[derive(Default)]
    pub struct TMJStoreApp;

    #[glib::object_subclass]
    impl ObjectSubclass for TMJStoreApp {
        const NAME: &'static str = "TMJStoreApp";
        type Type = super::TMJStoreApp;
        type ParentType = adw::Application;
    }

    impl ObjectImpl for TMJStoreApp {}
    impl ApplicationImpl for TMJStoreApp {
        fn activate(&self) {
            self.parent_activate();
            let app = self.obj();
            build_window(&app);
        }
    }
    impl GtkApplicationImpl for TMJStoreApp {}
    impl AdwApplicationImpl for TMJStoreApp {}
}

glib::wrapper! {
    pub struct TMJStoreApp(ObjectSubclass<imp::TMJStoreApp>)
        @extends adw::Application, gtk::Application, gio::Application,
        @implements gio::ActionGroup, gio::ActionMap;
}

impl TMJStoreApp {
    pub fn new() -> Self {
        glib::Object::builder()
            .property("application-id", "com.tmjos.store")
            .build()
    }
}

// ── Window ───────────────────────────────────────────────────────────

fn build_window(app: &TMJStoreApp) {
    load_css();

    let nav = adw::NavigationView::new();
    let toast_overlay = adw::ToastOverlay::new();
    toast_overlay.set_child(Some(&nav));

    let window = adw::ApplicationWindow::builder()
        .application(app)
        .title("TMJStore")
        .default_width(900)
        .default_height(680)
        .content(&toast_overlay)
        .build();

    let busy_pkgs: Rc<RefCell<HashSet<String>>> = Rc::new(RefCell::new(HashSet::new()));

    let apps_list = ListBox::builder()
        .selection_mode(SelectionMode::None)
        .css_classes(vec!["boxed-list".to_string()])
        .build();
    let installed_list = ListBox::builder()
        .selection_mode(SelectionMode::None)
        .css_classes(vec!["boxed-list".to_string()])
        .build();
    let updates_list = ListBox::builder()
        .selection_mode(SelectionMode::None)
        .css_classes(vec!["boxed-list".to_string()])
        .build();

    let stack = adw::ViewStack::new();
    stack.add_titled_with_icon(&wrap_list(&apps_list), Some("apps"), "Apps", "system-software-install-symbolic");
    stack.add_titled_with_icon(&wrap_list(&installed_list), Some("installed"), "Instalados", "emblem-ok-symbolic");
    stack.add_titled_with_icon(&wrap_list(&updates_list), Some("updates"), "Atualizacoes", "software-update-available-symbolic");

    let switcher = adw::ViewSwitcher::new();
    switcher.set_stack(Some(&stack));

    let header = adw::HeaderBar::new();
    header.set_title_widget(Some(&switcher));

    let refresh_btn = Button::from_icon_name("view-refresh-symbolic");
    refresh_btn.set_tooltip_text(Some("Atualizar lista"));
    header.pack_end(&refresh_btn);

    let toolbar = adw::ToolbarView::new();
    toolbar.add_top_bar(&header);
    toolbar.set_content(Some(&stack));

    let main_page = adw::NavigationPage::builder()
        .title("TMJStore")
        .child(&toolbar)
        .build();
    nav.push(&main_page);

    let state = AppState {
        nav: nav.clone(),
        toast_overlay: toast_overlay.clone(),
        apps_list: apps_list.clone(),
        installed_list: installed_list.clone(),
        updates_list: updates_list.clone(),
        busy_pkgs: busy_pkgs.clone(),
    };

    let state_rc = Rc::new(state);

    refresh_apps(state_rc.clone());

    let st = state_rc.clone();
    refresh_btn.connect_clicked(move |_| {
        refresh_apps(st.clone());
    });

    window.present();
}

fn load_css() {
    let provider = gtk::CssProvider::new();
    provider.load_from_string(css::STORE_CSS);
    gtk::style_context_add_provider_for_display(
        &gtk::gdk::Display::default().expect("display"),
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}

fn wrap_list(list: &ListBox) -> ScrolledWindow {
    let bx = GtkBox::builder()
        .orientation(Orientation::Vertical)
        .margin_top(12)
        .margin_bottom(12)
        .margin_start(16)
        .margin_end(16)
        .build();
    bx.append(list);
    ScrolledWindow::builder()
        .vexpand(true)
        .child(&bx)
        .build()
}

// ── State ────────────────────────────────────────────────────────────

#[derive(Clone)]
struct AppState {
    nav: adw::NavigationView,
    toast_overlay: adw::ToastOverlay,
    apps_list: ListBox,
    installed_list: ListBox,
    updates_list: ListBox,
    busy_pkgs: Rc<RefCell<HashSet<String>>>,
}

// ── Refresh ──────────────────────────────────────────────────────────

fn refresh_apps(state: Rc<AppState>) {
    clear_list(&state.apps_list);
    clear_list(&state.installed_list);
    clear_list(&state.updates_list);

    let (tx, rx) = std::sync::mpsc::channel::<Vec<TMJApp>>();
    std::thread::spawn(move || {
        let apps = discover::discover_tmj_apps();
        let _ = tx.send(apps);
    });

    let st = state.clone();
    glib::idle_add_local(move || {
        match rx.try_recv() {
            Ok(apps) => {
                populate_lists(&st, &apps);
                glib::ControlFlow::Break
            }
            Err(std::sync::mpsc::TryRecvError::Empty) => glib::ControlFlow::Continue,
            Err(_) => glib::ControlFlow::Break,
        }
    });
}

fn clear_list(list: &ListBox) {
    while let Some(row) = list.row_at_index(0) {
        list.remove(&row);
    }
}

fn populate_lists(state: &Rc<AppState>, apps: &[TMJApp]) {
    for app in apps {
        let row = build_app_row(app, state);
        state.apps_list.append(&row);

        if app.installed {
            let row = build_app_row(app, state);
            state.installed_list.append(&row);
        }

        if app.has_update {
            let row = build_app_row(app, state);
            state.updates_list.append(&row);
        }
    }
}

// ── App row card ─────────────────────────────────────────────────────

fn build_app_row(app: &TMJApp, state: &Rc<AppState>) -> GtkBox {
    let row = GtkBox::builder()
        .orientation(Orientation::Horizontal)
        .spacing(12)
        .build();
    row.add_css_class("tmjstore-app-row");

    let icon = if app.icon_name.is_empty() {
        Image::from_icon_name("application-x-executable")
    } else {
        Image::from_icon_name(&app.icon_name)
    };
    icon.set_pixel_size(48);
    row.append(&icon);

    let text = GtkBox::builder()
        .orientation(Orientation::Vertical)
        .hexpand(true)
        .valign(Align::Center)
        .spacing(2)
        .build();
    row.append(&text);

    let name = Label::builder()
        .label(&app.display_name)
        .halign(Align::Start)
        .build();
    name.add_css_class("heading");
    text.append(&name);

    let summary = Label::builder()
        .label(&app.summary)
        .halign(Align::Start)
        .ellipsize(gtk::pango::EllipsizeMode::End)
        .build();
    summary.add_css_class("dim-label");
    text.append(&summary);

    let is_busy = state.busy_pkgs.borrow().contains(&app.pkg_name);
    let action_btn = if is_busy {
        let b = Button::with_label("...");
        b.set_sensitive(false);
        b.add_css_class("tmjstore-busy-btn");
        b
    } else if app.has_update {
        let b = Button::with_label("Atualizar");
        b.add_css_class("tmjstore-install-btn");
        let st = state.clone();
        let pkg = app.pkg_name.clone();
        b.connect_clicked(move |btn| do_action(&st, &pkg, "upgrade", btn));
        b
    } else if app.installed {
        let b = Button::with_label("Remover");
        let st = state.clone();
        let pkg = app.pkg_name.clone();
        b.connect_clicked(move |btn| do_action(&st, &pkg, "remove", btn));
        b
    } else {
        let b = Button::with_label("Instalar");
        b.add_css_class("tmjstore-install-btn");
        let st = state.clone();
        let pkg = app.pkg_name.clone();
        b.connect_clicked(move |btn| do_action(&st, &pkg, "install", btn));
        b
    };
    action_btn.set_valign(Align::Center);
    row.append(&action_btn);

    let detail_click = gtk::GestureClick::new();
    let app_clone = app.clone();
    let state_clone = state.clone();
    detail_click.connect_released(move |_, _, _, _| {
        show_detail(&state_clone, &app_clone);
    });
    row.add_controller(detail_click);

    row
}

// ── Actions ──────────────────────────────────────────────────────────

fn do_action(state: &Rc<AppState>, pkg: &str, action: &str, btn: &Button) {
    state.busy_pkgs.borrow_mut().insert(pkg.to_string());
    btn.set_label("...");
    btn.set_sensitive(false);
    btn.remove_css_class("tmjstore-install-btn");
    btn.add_css_class("tmjstore-busy-btn");

    let st = state.clone();
    let pkg_s = pkg.to_string();
    let action_s = action.to_string();

    let done_cb = move |ok: bool, msg: &str| {
        st.busy_pkgs.borrow_mut().remove(&pkg_s);
        let text = if ok {
            match action_s.as_str() {
                "install" => format!("{pkg_s} instalado!"),
                "remove" => format!("{pkg_s} removido!"),
                "upgrade" => format!("{pkg_s} atualizado!"),
                _ => "OK".to_string(),
            }
        } else {
            format!("Erro: {msg}")
        };
        st.toast_overlay.add_toast(adw::Toast::new(&text));
        refresh_apps(Rc::new((*st).clone()));
    };

    match action {
        "install" => installer::install(pkg, done_cb),
        "remove" => installer::remove(pkg, done_cb),
        "upgrade" => installer::upgrade(pkg, done_cb),
        _ => {}
    }
}

// ── Detail ───────────────────────────────────────────────────────────

fn show_detail(state: &Rc<AppState>, app: &TMJApp) {
    let st = state.clone();
    let on_install = {
        let st = st.clone();
        Rc::new(move |a: &TMJApp| {
            installer::install(&a.pkg_name, {
                let st = st.clone();
                let pkg = a.pkg_name.clone();
                move |ok, msg| {
                    finish_detail_action(&st, &pkg, ok, msg, "instalado");
                }
            });
        })
    };

    let on_remove = {
        let st = st.clone();
        Rc::new(move |a: &TMJApp| {
            installer::remove(&a.pkg_name, {
                let st = st.clone();
                let pkg = a.pkg_name.clone();
                move |ok, msg| {
                    finish_detail_action(&st, &pkg, ok, msg, "removido");
                }
            });
        })
    };

    let on_upgrade = {
        let st = st.clone();
        Rc::new(move |a: &TMJApp| {
            installer::upgrade(&a.pkg_name, {
                let st = st.clone();
                let pkg = a.pkg_name.clone();
                move |ok, msg| {
                    finish_detail_action(&st, &pkg, ok, msg, "atualizado");
                }
            });
        })
    };

    let page_content = detail::build_detail_page(app, on_install, on_remove, on_upgrade);
    let nav_page = adw::NavigationPage::builder()
        .title(&app.display_name)
        .child(&page_content)
        .build();
    state.nav.push(&nav_page);
}

fn finish_detail_action(state: &AppState, pkg: &str, ok: bool, msg: &str, verb: &str) {
    let text = if ok {
        format!("{pkg} {verb}!")
    } else {
        format!("Erro: {msg}")
    };
    state.toast_overlay.add_toast(adw::Toast::new(&text));
    state.nav.pop();
}
