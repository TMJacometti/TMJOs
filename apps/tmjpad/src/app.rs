//! TMJPadApp — Application principal (Adw.Application wrapper).

use adw::prelude::*;
use adw::subclass::prelude::*;
use gio::ApplicationFlags;
use gtk::{gdk, glib, CssProvider, StyleContext, STYLE_PROVIDER_PRIORITY_APPLICATION};

use crate::css::DARK_CSS;
use crate::persistence::{config_dir, Session};
use crate::window::TMJPadWindow;

mod imp {
    use super::*;
    use std::cell::OnceCell;

    #[derive(Default)]
    pub struct TMJPadApp {
        pub window: OnceCell<TMJPadWindow>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for TMJPadApp {
        const NAME: &'static str = "TMJPadApp";
        type Type = super::TMJPadApp;
        type ParentType = adw::Application;
    }

    impl ObjectImpl for TMJPadApp {}

    impl ApplicationImpl for TMJPadApp {
        fn startup(&self) {
            self.parent_startup();
            install_css();
            adw::StyleManager::default().set_color_scheme(adw::ColorScheme::ForceDark);
        }

        fn activate(&self) {
            let app = self.obj();
            let window = self.window.get_or_init(|| {
                let _ = std::fs::create_dir_all(config_dir());
                let session = Session::load();
                TMJPadWindow::new(&app, session)
            });
            window.present();
        }

        fn open(&self, files: &[gio::File], _hint: &str) {
            self.activate();
            if let Some(window) = self.window.get() {
                for file in files {
                    if let Some(path) = file.path() {
                        window.new_tab_with_path(Some(path.to_string_lossy().into_owned()));
                    }
                }
            }
        }
    }

    impl GtkApplicationImpl for TMJPadApp {}
    impl AdwApplicationImpl for TMJPadApp {}
}

glib::wrapper! {
    pub struct TMJPadApp(ObjectSubclass<imp::TMJPadApp>)
        @extends gio::Application, gtk::Application, adw::Application,
        @implements gio::ActionGroup, gio::ActionMap;
}

impl TMJPadApp {
    pub fn new() -> Self {
        glib::Object::builder()
            .property("application-id", "dev.tmjos.TMJPad")
            .property("flags", ApplicationFlags::HANDLES_OPEN)
            .build()
    }
}

impl Default for TMJPadApp {
    fn default() -> Self {
        Self::new()
    }
}

fn install_css() {
    let provider = CssProvider::new();
    provider.load_from_string(DARK_CSS);
    if let Some(display) = gdk::Display::default() {
        StyleContext::add_provider_for_display(
            &display,
            &provider,
            STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}
