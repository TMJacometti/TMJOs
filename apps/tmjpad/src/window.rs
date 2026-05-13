//! TMJPadWindow — janela principal com Notebook de Tabs.

use adw::prelude::*;
use adw::subclass::prelude::*;
use adw::{ApplicationWindow, HeaderBar};
use gtk::glib::clone;
use gtk::{
    gio, glib, Align, Box as GtkBox, Button, FileDialog, Label, Notebook, Orientation,
};
use std::cell::RefCell;
use std::path::Path;
use std::rc::Rc;

use crate::find_replace::FindReplaceBar;
use crate::persistence::{next_untitled_title, remove_buffer, Session, TabState};
use crate::tab::Tab;

mod imp {
    use super::*;
    use std::cell::OnceCell;

    #[derive(Default)]
    pub struct TMJPadWindow {
        pub notebook: OnceCell<Notebook>,
        pub status_label: OnceCell<Label>,
        pub find_bar: OnceCell<Rc<FindReplaceBar>>,
        pub session: RefCell<Session>,
        pub tabs: RefCell<Vec<Rc<Tab>>>,
        pub suppress_session_save: std::cell::Cell<bool>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for TMJPadWindow {
        const NAME: &'static str = "TMJPadWindow";
        type Type = super::TMJPadWindow;
        type ParentType = ApplicationWindow;
    }

    impl ObjectImpl for TMJPadWindow {}
    impl WidgetImpl for TMJPadWindow {}
    impl WindowImpl for TMJPadWindow {}
    impl ApplicationWindowImpl for TMJPadWindow {}
    impl AdwApplicationWindowImpl for TMJPadWindow {}
}

glib::wrapper! {
    pub struct TMJPadWindow(ObjectSubclass<imp::TMJPadWindow>)
        @extends gtk::Widget, gtk::Window, gtk::ApplicationWindow, ApplicationWindow,
        @implements gio::ActionGroup, gio::ActionMap;
}

impl TMJPadWindow {
    pub fn new(app: &impl IsA<gtk::Application>, session: Session) -> Self {
        let window: Self = glib::Object::builder()
            .property("application", app)
            .build();

        window.set_title(Some("TMJPad"));
        window.set_default_size(session.window_width, session.window_height);

        *window.imp().session.borrow_mut() = session;
        window.build_ui();
        window.wire_actions(app);
        window.restore_tabs();

        let win_clone = window.clone();
        window.connect_close_request(move |_| {
            win_clone.on_close_request();
            glib::Propagation::Proceed
        });

        window
    }

    fn build_ui(&self) {
        let header = HeaderBar::new();

        let new_btn = Button::from_icon_name("document-new-symbolic");
        new_btn.set_tooltip_text(Some("New tab (Ctrl+N)"));
        new_btn.connect_clicked(clone!(@weak self as win => move |_| { win.new_tab(); }));

        let open_btn = Button::from_icon_name("document-open-symbolic");
        open_btn.set_tooltip_text(Some("Open file (Ctrl+O)"));
        open_btn.connect_clicked(clone!(@weak self as win => move |_| { win.open_file_dialog(); }));

        let save_btn = Button::from_icon_name("document-save-symbolic");
        save_btn.set_tooltip_text(Some("Save (Ctrl+S)"));
        save_btn.connect_clicked(clone!(@weak self as win => move |_| { win.save_active_tab(); }));

        header.pack_start(&new_btn);
        header.pack_start(&open_btn);
        header.pack_start(&save_btn);

        let notebook = Notebook::builder()
            .scrollable(true)
            .show_border(false)
            .build();

        let status_label = Label::builder()
            .xalign(0.0)
            .label("Ln 1, Col 1  │  UTF-8")
            .halign(Align::Start)
            .build();
        status_label.add_css_class("tmjpad-status");

        let find_bar = FindReplaceBar::new();

        let box_v = GtkBox::new(Orientation::Vertical, 0);
        box_v.append(&header);
        box_v.append(&find_bar.container);
        box_v.append(&notebook);
        box_v.append(&status_label);
        self.set_content(Some(&box_v));

        notebook.connect_switch_page(clone!(@weak self as win => move |_, _, index| {
            win.on_tab_switched(index as usize);
        }));
        notebook.connect_page_reordered(clone!(@weak self as win => move |_, widget, new_index| {
            win.on_tab_reordered(widget, new_index as usize);
        }));

        let _ = self.imp().notebook.set(notebook);
        let _ = self.imp().status_label.set(status_label);

        // Configura active_target da find_bar
        let win_weak = self.downgrade();
        find_bar.set_active_target(move || {
            let win = win_weak.upgrade()?;
            let tab = win.active_tab()?;
            Some((tab.buffer.clone(), tab.text_view.clone()))
        });

        let _ = self.imp().find_bar.set(find_bar);
    }

    fn wire_actions(&self, app: &impl IsA<gtk::Application>) {
        let actions = [
            ("new-tab", "<Ctrl>n"),
            ("open-file", "<Ctrl>o"),
            ("save-tab", "<Ctrl>s"),
            ("save-tab-as", "<Ctrl><Shift>s"),
            ("close-tab", "<Ctrl>w"),
            ("next-tab", "<Ctrl>Tab"),
            ("prev-tab", "<Ctrl><Shift>Tab"),
            ("find", "<Ctrl>f"),
            ("find-replace", "<Ctrl>h"),
        ];

        for (name, accel) in actions.iter() {
            let action = gio::SimpleAction::new(name, None);
            let win = self.clone();
            let name_owned = name.to_string();
            action.connect_activate(move |_, _| match name_owned.as_str() {
                "new-tab" => {
                    win.new_tab();
                }
                "open-file" => win.open_file_dialog(),
                "save-tab" => win.save_active_tab(),
                "save-tab-as" => win.save_as_active_tab(),
                "close-tab" => win.close_active_tab(),
                "next-tab" => win.cycle_tab(1),
                "prev-tab" => win.cycle_tab(-1),
                "find" => {
                    if let Some(bar) = win.imp().find_bar.get() {
                        bar.open(false);
                    }
                }
                "find-replace" => {
                    if let Some(bar) = win.imp().find_bar.get() {
                        bar.open(true);
                    }
                }
                _ => {}
            });
            self.add_action(&action);
            app.set_accels_for_action(&format!("win.{name}"), &[accel]);
        }
    }

    fn restore_tabs(&self) {
        self.imp().suppress_session_save.set(true);

        let tabs_to_create: Vec<TabState> = {
            let session = self.imp().session.borrow();
            if session.tabs.is_empty() {
                vec![TabState::new("Untitled-1", None)]
            } else {
                session.tabs.clone()
            }
        };

        let target = {
            let session = self.imp().session.borrow();
            session.active_index.min(tabs_to_create.len().saturating_sub(1))
        };

        for state in tabs_to_create {
            self.add_tab(state);
        }

        if let Some(notebook) = self.imp().notebook.get() {
            notebook.set_current_page(Some(target as u32));
        }

        self.imp().suppress_session_save.set(false);

        // Focus active tab
        if let Some(tab) = self.imp().tabs.borrow().get(target).cloned() {
            glib::idle_add_local_once(move || {
                tab.text_view.grab_focus();
            });
        }
    }

    fn add_tab(&self, state: TabState) -> Rc<Tab> {
        let tab = Tab::new(state);
        let title_text = self.format_title(&tab);

        let title_label = Label::new(Some(&title_text));
        let close_btn = Button::from_icon_name("window-close-symbolic");
        close_btn.set_has_frame(false);

        let label_box = GtkBox::new(Orientation::Horizontal, 6);
        label_box.append(&title_label);
        label_box.append(&close_btn);
        *tab.title_label.borrow_mut() = Some(title_label);

        if let Some(notebook) = self.imp().notebook.get() {
            notebook.append_page(&tab.scroller, Some(&label_box));
            notebook.set_tab_reorderable(&tab.scroller, true);
        }

        let tab_clone = tab.clone();
        let win_weak = self.downgrade();
        close_btn.connect_clicked(move |_| {
            if let Some(win) = win_weak.upgrade() {
                win.close_tab(&tab_clone);
            }
        });

        // Conecta sinais de buffer change + cursor move + autosave
        {
            let tab_weak = Rc::downgrade(&tab);
            let win_weak = self.downgrade();
            tab.buffer.connect_changed(move |_| {
                let Some(t) = tab_weak.upgrade() else { return };
                let Some(win) = win_weak.upgrade() else { return };
                t.dirty.set(true);
                win.update_tab_label(&t);
                t.schedule_autosave(clone!(@weak win => move || {
                    win.save_session();
                }));
            });
        }
        {
            let win_weak = self.downgrade();
            tab.buffer.connect_cursor_position_notify(move |_| {
                if let Some(win) = win_weak.upgrade() {
                    win.update_status_bar();
                }
            });
        }

        self.imp().tabs.borrow_mut().push(tab.clone());
        tab
    }

    fn format_title(&self, tab: &Tab) -> String {
        let state = tab.state.borrow();
        let prefix = if tab.dirty.get() { "● " } else { "" };
        format!("{}{}", prefix, state.title)
    }

    fn update_tab_label(&self, tab: &Rc<Tab>) {
        if let Some(label) = tab.title_label.borrow().as_ref() {
            label.set_label(&self.format_title(tab));
        }
    }

    fn update_status_bar(&self) {
        let Some(status) = self.imp().status_label.get() else { return };
        let Some(tab) = self.active_tab() else {
            status.set_label("");
            return;
        };
        let offset = tab.cursor_offset();
        let it = tab.buffer.iter_at_offset(offset);
        let line = it.line() + 1;
        let col = it.line_offset() + 1;
        let state = tab.state.borrow();
        let path = state.path.as_deref().unwrap_or("(unsaved)");
        status.set_label(&format!("Ln {line}, Col {col}  │  UTF-8  │  {path}"));
    }

    fn active_tab(&self) -> Option<Rc<Tab>> {
        let notebook = self.imp().notebook.get()?;
        let idx = notebook.current_page()? as usize;
        self.imp().tabs.borrow().get(idx).cloned()
    }

    fn on_tab_switched(&self, index: usize) {
        self.update_status_bar();
        self.save_session();
        if let Some(tab) = self.imp().tabs.borrow().get(index).cloned() {
            glib::idle_add_local_once(move || {
                tab.text_view.grab_focus();
            });
        }
    }

    fn on_tab_reordered(&self, widget: &gtk::Widget, new_index: usize) {
        let mut tabs = self.imp().tabs.borrow_mut();
        let old_index = tabs.iter().position(|t| t.scroller.upcast_ref::<gtk::Widget>() == widget);
        if let Some(old) = old_index {
            let moved = tabs.remove(old);
            let target = new_index.min(tabs.len());
            tabs.insert(target, moved);
            drop(tabs);
            self.save_session();
        }
    }

    pub fn new_tab(&self) -> Rc<Tab> {
        self.new_tab_with_path(None)
    }

    pub fn new_tab_with_path(&self, path: Option<String>) -> Rc<Tab> {
        let state = if let Some(p) = path.as_ref() {
            let title = Path::new(p)
                .file_name()
                .map(|s| s.to_string_lossy().into_owned())
                .unwrap_or_else(|| p.clone());
            TabState::new(title, Some(p.clone()))
        } else {
            let existing: Vec<String> = self
                .imp()
                .tabs
                .borrow()
                .iter()
                .map(|t| t.state.borrow().title.clone())
                .collect();
            TabState::new(next_untitled_title(existing), None)
        };

        let tab = self.add_tab(state);

        if let Some(notebook) = self.imp().notebook.get() {
            let last_idx = notebook.n_pages().saturating_sub(1);
            notebook.set_current_page(Some(last_idx));
        }
        self.save_session();

        let tab_clone = tab.clone();
        glib::idle_add_local_once(move || {
            tab_clone.text_view.grab_focus();
        });

        tab
    }

    fn open_file_dialog(&self) {
        let dialog = FileDialog::builder().title("Open File").build();
        dialog.open(
            Some(self),
            None::<&gio::Cancellable>,
            clone!(@weak self as win => move |result| {
                let Ok(file) = result else { return };
                if let Some(path) = file.path() {
                    win.new_tab_with_path(Some(path.to_string_lossy().into_owned()));
                }
            }),
        );
    }

    fn save_active_tab(&self) {
        let Some(tab) = self.active_tab() else { return };
        let has_path = tab.state.borrow().path.is_some();
        if has_path {
            tab.save_to_disk();
            self.update_tab_label(&tab);
            self.save_session();
        } else {
            self.save_as(&tab);
        }
    }

    fn save_as_active_tab(&self) {
        if let Some(tab) = self.active_tab() {
            self.save_as(&tab);
        }
    }

    fn save_as(&self, tab: &Rc<Tab>) {
        let dialog = FileDialog::builder().title("Save As").build();
        let tab_clone = tab.clone();
        dialog.save(
            Some(self),
            None::<&gio::Cancellable>,
            clone!(@weak self as win => move |result| {
                let Ok(file) = result else { return };
                let Some(path) = file.path() else { return };
                let path_str = path.to_string_lossy().into_owned();
                let title = path
                    .file_name()
                    .map(|s| s.to_string_lossy().into_owned())
                    .unwrap_or_else(|| path_str.clone());
                {
                    let mut state = tab_clone.state.borrow_mut();
                    state.path = Some(path_str);
                    state.title = title;
                }
                tab_clone.save_to_disk();
                win.update_tab_label(&tab_clone);
                win.save_session();
            }),
        );
    }

    fn close_active_tab(&self) {
        if let Some(tab) = self.active_tab() {
            self.close_tab(&tab);
        }
    }

    fn close_tab(&self, tab: &Rc<Tab>) {
        let idx = {
            let tabs = self.imp().tabs.borrow();
            tabs.iter().position(|t| Rc::ptr_eq(t, tab))
        };
        let Some(idx) = idx else { return };

        tab.cleanup_for_close();
        remove_buffer(&tab.state.borrow());

        if let Some(notebook) = self.imp().notebook.get() {
            notebook.remove_page(Some(idx as u32));
        }
        self.imp().tabs.borrow_mut().remove(idx);

        if self.imp().tabs.borrow().is_empty() {
            // Sempre mantém pelo menos uma tab
            self.new_tab();
        } else {
            self.save_session();
        }
    }

    fn cycle_tab(&self, direction: i32) {
        let Some(notebook) = self.imp().notebook.get() else { return };
        let n = notebook.n_pages() as i32;
        if n == 0 {
            return;
        }
        let cur = notebook.current_page().unwrap_or(0) as i32;
        let next = ((cur + direction) % n + n) % n;
        notebook.set_current_page(Some(next as u32));
    }

    pub fn save_session(&self) {
        if self.imp().suppress_session_save.get() {
            return;
        }
        let Some(notebook) = self.imp().notebook.get() else { return };
        let tabs: Vec<TabState> = self
            .imp()
            .tabs
            .borrow()
            .iter()
            .map(|t| t.state.borrow().clone())
            .collect();
        let active_index = notebook.current_page().unwrap_or(0) as usize;
        let (w, h) = self.default_size();

        let mut session = self.imp().session.borrow_mut();
        session.tabs = tabs;
        session.active_index = active_index;
        session.window_width = w;
        session.window_height = h;
        let _ = session.save();
    }

    fn on_close_request(&self) {
        for tab in self.imp().tabs.borrow().iter() {
            tab.cleanup_for_close();
        }
        self.save_session();
    }
}
