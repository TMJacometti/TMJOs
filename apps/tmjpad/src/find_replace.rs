//! FindReplaceBar — barra inline de busca + replace (Ctrl+F, Ctrl+H).

use gtk::prelude::*;
use gtk::{glib, Box as GtkBox, Button, Entry, EventControllerKey, Orientation, TextBuffer, TextSearchFlags, TextView};
use std::cell::RefCell;
use std::rc::{Rc, Weak};

pub struct FindReplaceBar {
    pub container: GtkBox,
    pub find_entry: Entry,
    replace_entry: Entry,
    replace_btn: Button,
    replace_all_btn: Button,
    /// Função fornecida pela window pra obter o buffer + textview ativos.
    active_target: RefCell<Option<Box<dyn Fn() -> Option<(TextBuffer, TextView)>>>>,
}

impl FindReplaceBar {
    pub fn new() -> Rc<Self> {
        let container = GtkBox::builder()
            .orientation(Orientation::Horizontal)
            .spacing(6)
            .margin_top(4)
            .margin_bottom(4)
            .margin_start(8)
            .margin_end(8)
            .visible(false)
            .build();
        container.add_css_class("tmjpad-find-bar");

        let find_entry = Entry::builder()
            .placeholder_text("Find")
            .hexpand(true)
            .build();
        let replace_entry = Entry::builder()
            .placeholder_text("Replace with")
            .hexpand(true)
            .build();

        let prev_btn = Button::from_icon_name("go-up-symbolic");
        prev_btn.set_tooltip_text(Some("Previous (Shift+Enter)"));
        let next_btn = Button::from_icon_name("go-down-symbolic");
        next_btn.set_tooltip_text(Some("Next (Enter)"));
        let replace_btn = Button::with_label("Replace");
        let replace_all_btn = Button::with_label("Replace All");
        let close_btn = Button::from_icon_name("window-close-symbolic");
        close_btn.set_tooltip_text(Some("Close (Esc)"));

        container.append(&find_entry);
        container.append(&prev_btn);
        container.append(&next_btn);
        container.append(&replace_entry);
        container.append(&replace_btn);
        container.append(&replace_all_btn);
        container.append(&close_btn);

        let bar = Rc::new(Self {
            container: container.clone(),
            find_entry: find_entry.clone(),
            replace_entry: replace_entry.clone(),
            replace_btn: replace_btn.clone(),
            replace_all_btn: replace_all_btn.clone(),
            active_target: RefCell::new(None),
        });

        // Signals
        {
            let bar_weak = Rc::downgrade(&bar);
            find_entry.connect_activate(move |_| {
                if let Some(b) = bar_weak.upgrade() {
                    b.find_next();
                }
            });
        }
        {
            let bar_weak = Rc::downgrade(&bar);
            replace_entry.connect_activate(move |_| {
                if let Some(b) = bar_weak.upgrade() {
                    b.replace_one();
                }
            });
        }
        {
            let bar_weak = Rc::downgrade(&bar);
            next_btn.connect_clicked(move |_| {
                if let Some(b) = bar_weak.upgrade() {
                    b.find_next();
                }
            });
        }
        {
            let bar_weak = Rc::downgrade(&bar);
            prev_btn.connect_clicked(move |_| {
                if let Some(b) = bar_weak.upgrade() {
                    b.find_prev();
                }
            });
        }
        {
            let bar_weak = Rc::downgrade(&bar);
            replace_btn.connect_clicked(move |_| {
                if let Some(b) = bar_weak.upgrade() {
                    b.replace_one();
                }
            });
        }
        {
            let bar_weak = Rc::downgrade(&bar);
            replace_all_btn.connect_clicked(move |_| {
                if let Some(b) = bar_weak.upgrade() {
                    b.replace_all();
                }
            });
        }
        {
            let bar_weak = Rc::downgrade(&bar);
            close_btn.connect_clicked(move |_| {
                if let Some(b) = bar_weak.upgrade() {
                    b.close();
                }
            });
        }

        // Esc fecha quando foco está num dos entries
        for entry in [&find_entry, &replace_entry] {
            let key_ctrl = EventControllerKey::new();
            let bar_weak: Weak<Self> = Rc::downgrade(&bar);
            key_ctrl.connect_key_pressed(move |_, key, _, _| {
                if key == gtk::gdk::Key::Escape {
                    if let Some(b) = bar_weak.upgrade() {
                        b.close();
                    }
                    return glib::Propagation::Stop;
                }
                glib::Propagation::Proceed
            });
            entry.add_controller(key_ctrl);
        }

        bar
    }

    /// Configura como obter o textview/buffer ativos. Chamado pela window
    /// depois de criar a bar.
    pub fn set_active_target<F>(&self, f: F)
    where
        F: Fn() -> Option<(TextBuffer, TextView)> + 'static,
    {
        *self.active_target.borrow_mut() = Some(Box::new(f));
    }

    pub fn open(&self, replace: bool) {
        self.replace_entry.set_visible(replace);
        self.replace_btn.set_visible(replace);
        self.replace_all_btn.set_visible(replace);
        self.container.set_visible(true);

        // Pre-fill find com seleção atual se houver
        if let Some(target) = self.active_target.borrow().as_ref() {
            if let Some((buf, _view)) = target() {
                if buf.has_selection() {
                    if let Some((start, end)) = buf.selection_bounds() {
                        self.find_entry
                            .set_text(&buf.text(&start, &end, false));
                    }
                }
            }
        }

        self.find_entry.grab_focus();
        self.find_entry.select_region(0, -1);
    }

    pub fn close(&self) {
        self.container.set_visible(false);
        // Devolve foco pro textview ativo
        if let Some(target) = self.active_target.borrow().as_ref() {
            if let Some((_buf, view)) = target() {
                view.grab_focus();
            }
        }
    }

    fn current_buffer_view(&self) -> Option<(TextBuffer, TextView)> {
        self.active_target.borrow().as_ref().and_then(|f| f())
    }

    fn search(&self, forward: bool) -> bool {
        let Some((buf, view)) = self.current_buffer_view() else {
            return false;
        };
        let needle = self.find_entry.text();
        if needle.is_empty() {
            return false;
        }

        let flags = TextSearchFlags::CASE_INSENSITIVE | TextSearchFlags::VISIBLE_ONLY;
        let cursor_iter = buf.iter_at_mark(&buf.get_insert());

        // Advance past current selection to avoid re-finding the same match
        let search_from = if forward {
            if buf.has_selection() {
                if let Some((_sel_start, sel_end)) = buf.selection_bounds() {
                    sel_end
                } else {
                    cursor_iter
                }
            } else {
                cursor_iter
            }
        } else {
            if buf.has_selection() {
                if let Some((sel_start, _sel_end)) = buf.selection_bounds() {
                    sel_start
                } else {
                    cursor_iter
                }
            } else {
                cursor_iter
            }
        };

        let result = if forward {
            search_from
                .forward_search(&needle, flags, None)
                .or_else(|| buf.start_iter().forward_search(&needle, flags, None))
        } else {
            search_from
                .backward_search(&needle, flags, None)
                .or_else(|| buf.end_iter().backward_search(&needle, flags, None))
        };

        let Some((start, end)) = result else {
            return false;
        };
        buf.select_range(&start, &end);
        view.scroll_to_iter(&mut start.clone(), 0.1, false, 0.0, 0.5);
        true
    }

    pub fn find_next(&self) {
        if !self.search(true) {
            self.flash_no_match();
        }
    }

    pub fn find_prev(&self) {
        if !self.search(false) {
            self.flash_no_match();
        }
    }

    fn flash_no_match(&self) {
        let entry = self.find_entry.clone();
        entry.add_css_class("error");
        glib::timeout_add_local_once(std::time::Duration::from_millis(400), move || {
            entry.remove_css_class("error");
        });
    }

    pub fn replace_one(&self) {
        let Some((buf, _view)) = self.current_buffer_view() else {
            return;
        };
        if !buf.has_selection() {
            self.find_next();
            return;
        }
        let needle = self.find_entry.text();
        if needle.is_empty() {
            return;
        }
        if let Some((start, end)) = buf.selection_bounds() {
            let selected = buf.text(&start, &end, false);
            if selected.to_lowercase() == needle.to_lowercase() {
                let mut s = start;
                let mut e = end;
                buf.delete(&mut s, &mut e);
                buf.insert_at_cursor(&self.replace_entry.text());
            }
        }
        self.find_next();
    }

    pub fn replace_all(&self) {
        let Some((buf, _view)) = self.current_buffer_view() else {
            return;
        };
        let needle = self.find_entry.text();
        let replacement = self.replace_entry.text();
        if needle.is_empty() {
            return;
        }

        let flags = TextSearchFlags::CASE_INSENSITIVE | TextSearchFlags::VISIBLE_ONLY;
        buf.begin_user_action();
        let mut it = buf.start_iter();
        loop {
            let Some((mut start, mut end)) = it.forward_search(&needle, flags, None) else {
                break;
            };
            buf.delete(&mut start, &mut end);
            buf.insert(&mut start, &replacement);
            it = start;
        }
        buf.end_user_action();
    }
}
