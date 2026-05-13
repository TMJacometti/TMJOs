//! Tab — uma aba do editor: TextBuffer + ScrolledWindow + autosave.

use gtk::prelude::*;
use gtk::{glib, Label, ScrolledWindow, TextBuffer, TextView, WrapMode};
use std::cell::{Cell, RefCell};
use std::path::Path;
use std::rc::Rc;

use crate::persistence::{read_buffer, write_buffer, TabState};

const AUTOSAVE_DEBOUNCE_MS: u32 = 500;

/// Tab — uma aba do editor.
pub struct Tab {
    pub state: RefCell<TabState>,
    pub buffer: TextBuffer,
    pub text_view: TextView,
    pub scroller: ScrolledWindow,
    pub title_label: RefCell<Option<Label>>,
    pub dirty: Cell<bool>,
    autosave_source: RefCell<Option<glib::SourceId>>,
}

impl Tab {
    pub fn new(state: TabState) -> Rc<Self> {
        let buffer = TextBuffer::new(None);
        let text_view = TextView::builder()
            .buffer(&buffer)
            .wrap_mode(WrapMode::None)
            .monospace(true)
            .top_margin(8)
            .bottom_margin(8)
            .left_margin(12)
            .right_margin(12)
            .build();
        text_view.add_css_class("tmjpad-textview");

        let scroller = ScrolledWindow::builder()
            .hexpand(true)
            .vexpand(true)
            .child(&text_view)
            .build();

        let tab = Rc::new(Self {
            state: RefCell::new(state),
            buffer: buffer.clone(),
            text_view,
            scroller,
            title_label: RefCell::new(None),
            dirty: Cell::new(false),
            autosave_source: RefCell::new(None),
        });

        tab.load_initial_content();

        // Restaura cursor depois do conteúdo carregado.
        let state_borrow = tab.state.borrow();
        let offset = state_borrow.cursor_offset;
        drop(state_borrow);
        if offset >= 0 && offset <= buffer.char_count() {
            let it = buffer.iter_at_offset(offset);
            buffer.place_cursor(&it);
        }

        tab
    }

    fn load_initial_content(&self) {
        let state = self.state.borrow();
        let mut content = read_buffer(&state);
        if content.is_empty() {
            if let Some(path) = &state.path {
                if Path::new(path).exists() {
                    content = std::fs::read_to_string(path).unwrap_or_default();
                }
            }
        }
        self.buffer.set_text(&content);
    }

    pub fn text(&self) -> String {
        let (start, end) = self.buffer.bounds();
        self.buffer.text(&start, &end, false).to_string()
    }

    pub fn cursor_offset(&self) -> i32 {
        self.buffer.property::<i32>("cursor-position")
    }

    /// Salva pro path setado. Retorna true em sucesso, false em erro ou
    /// se o path não tá setado.
    pub fn save_to_disk(&self) -> bool {
        let state = self.state.borrow();
        let Some(path) = state.path.clone() else {
            return false;
        };
        drop(state);

        if std::fs::write(&path, self.text()).is_err() {
            eprintln!("tmjpad: save failed");
            return false;
        }
        self.dirty.set(false);
        true
    }

    /// Cancela autosave pendente e escreve snapshot final do buffer.
    pub fn cleanup_for_close(&self) {
        if let Some(source) = self.autosave_source.borrow_mut().take() {
            source.remove();
        }
        let mut state = self.state.borrow_mut();
        state.cursor_offset = self.buffer.property::<i32>("cursor-position");
        let snapshot = self.text();
        let _ = write_buffer(&state, &snapshot);
    }

    /// Agenda autosave debounced. Retorna o callback que faz o flush.
    /// O caller (window) precisa setar isso via setup_autosave (separado
    /// pra evitar ciclo de borrow com window).
    pub fn schedule_autosave<F: Fn() + 'static>(self: &Rc<Self>, on_save: F) {
        if let Some(source) = self.autosave_source.borrow_mut().take() {
            source.remove();
        }
        let tab = self.clone();
        let on_save = Rc::new(on_save);
        let source = glib::timeout_add_local_once(
            std::time::Duration::from_millis(AUTOSAVE_DEBOUNCE_MS as u64),
            move || {
                *tab.autosave_source.borrow_mut() = None;
                let state = tab.state.borrow();
                let _ = write_buffer(&state, &tab.text());
                drop(state);
                {
                    let mut state = tab.state.borrow_mut();
                    state.cursor_offset = tab.buffer.property::<i32>("cursor-position");
                }
                (on_save)();
            },
        );
        *self.autosave_source.borrow_mut() = Some(source);
    }
}
