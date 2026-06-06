//! Tela de detalhe de um app TMJOs.

use adw::prelude::*;
use gtk::{Align, Box as GtkBox, Button, Grid, Image, Label, LinkButton, Orientation, ScrolledWindow};
use std::rc::Rc;

use crate::discover::TMJApp;

pub fn build_detail_page(
    app: &TMJApp,
    on_install: Rc<dyn Fn(&TMJApp)>,
    on_remove: Rc<dyn Fn(&TMJApp)>,
    on_upgrade: Rc<dyn Fn(&TMJApp)>,
) -> adw::ToolbarView {
    let toolbar = adw::ToolbarView::new();

    let header = adw::HeaderBar::new();
    let title = adw::WindowTitle::new(&app.display_name, &app.summary);
    header.set_title_widget(Some(&title));
    toolbar.add_top_bar(&header);

    let scrolled = ScrolledWindow::builder()
        .vexpand(true)
        .build();
    toolbar.set_content(Some(&scrolled));

    let content = GtkBox::builder()
        .orientation(Orientation::Vertical)
        .spacing(20)
        .margin_top(20)
        .margin_bottom(20)
        .margin_start(24)
        .margin_end(24)
        .build();
    scrolled.set_child(Some(&content));

    // Header: icon + name + summary + action button
    let header_app = GtkBox::builder()
        .orientation(Orientation::Horizontal)
        .spacing(20)
        .build();
    content.append(&header_app);

    let icon = if app.icon_name.is_empty() {
        Image::from_icon_name("application-x-executable")
    } else {
        Image::from_icon_name(&app.icon_name)
    };
    icon.set_pixel_size(96);
    header_app.append(&icon);

    let text_col = GtkBox::builder()
        .orientation(Orientation::Vertical)
        .spacing(4)
        .hexpand(true)
        .valign(Align::Center)
        .build();
    header_app.append(&text_col);

    let name_label = Label::builder()
        .label(&app.display_name)
        .halign(Align::Start)
        .build();
    name_label.add_css_class("title-1");
    text_col.append(&name_label);

    let summary_label = Label::builder()
        .label(&app.summary)
        .halign(Align::Start)
        .wrap(true)
        .build();
    summary_label.add_css_class("title-4");
    summary_label.add_css_class("dim-label");
    text_col.append(&summary_label);

    if app.installed && !app.installed_version.is_empty() {
        let ver = Label::builder()
            .label(&format!("Instalado: {}", app.installed_version))
            .halign(Align::Start)
            .build();
        ver.add_css_class("caption");
        ver.add_css_class("tmjstore-installed-tag");
        text_col.append(&ver);
    }

    let action_btn = build_action_button(app, on_install, on_remove, on_upgrade);
    action_btn.set_valign(Align::Center);
    header_app.append(&action_btn);

    // Description
    if !app.description.is_empty() {
        content.append(&section_header("Descricao"));
        let desc = Label::builder()
            .label(&app.description)
            .halign(Align::Start)
            .wrap(true)
            .selectable(true)
            .max_width_chars(80)
            .build();
        content.append(&desc);
    }

    // Categories
    if !app.categories.is_empty() {
        let cat_box = GtkBox::builder()
            .orientation(Orientation::Horizontal)
            .spacing(6)
            .halign(Align::Start)
            .build();
        for cat in &app.categories {
            let chip = Label::new(Some(cat));
            chip.add_css_class("tmjstore-chip");
            cat_box.append(&chip);
        }
        content.append(&cat_box);
    }

    // Info grid
    content.append(&section_header("Informacoes"));
    let grid = Grid::builder()
        .column_spacing(18)
        .row_spacing(6)
        .hexpand(true)
        .build();
    content.append(&grid);

    let mut rows: Vec<(&str, String)> = vec![
        ("Versao atual:", if app.candidate_version.is_empty() { "-".to_string() } else { app.candidate_version.clone() }),
        ("Pacote:", app.pkg_name.clone()),
    ];
    if !app.developer.is_empty() {
        rows.push(("Desenvolvedor:", app.developer.clone()));
    }
    if !app.license.is_empty() {
        rows.push(("Licenca:", app.license.clone()));
    }
    if !app.homepage.is_empty() {
        rows.push(("Homepage:", app.homepage.clone()));
    }

    for (i, (key, value)) in rows.iter().enumerate() {
        let k = Label::builder()
            .label(*key)
            .halign(Align::Start)
            .build();
        k.add_css_class("dim-label");
        grid.attach(&k, 0, i as i32, 1, 1);

        if value.starts_with("http") {
            let link = LinkButton::with_label(value, value);
            link.set_halign(Align::Start);
            grid.attach(&link, 1, i as i32, 1, 1);
        } else {
            let v = Label::builder()
                .label(value)
                .halign(Align::Start)
                .selectable(true)
                .build();
            grid.attach(&v, 1, i as i32, 1, 1);
        }
    }

    // Release history
    if !app.releases.is_empty() {
        content.append(&section_header("Historico de versoes"));
        for r in &app.releases {
            let rel_box = GtkBox::builder()
                .orientation(Orientation::Vertical)
                .spacing(2)
                .margin_bottom(8)
                .build();
            rel_box.add_css_class("tmjstore-release");
            content.append(&rel_box);

            let header_text = if r.date.is_empty() {
                r.version.clone()
            } else {
                format!("{} - {}", r.version, r.date)
            };
            let hdr = Label::builder()
                .label(&header_text)
                .halign(Align::Start)
                .build();
            hdr.add_css_class("heading");
            rel_box.append(&hdr);

            if !r.description.is_empty() {
                let body = Label::builder()
                    .label(&r.description)
                    .halign(Align::Start)
                    .wrap(true)
                    .selectable(true)
                    .build();
                body.add_css_class("dim-label");
                rel_box.append(&body);
            }
        }
    }

    toolbar
}

fn section_header(text: &str) -> Label {
    let label = Label::builder()
        .label(text)
        .halign(Align::Start)
        .margin_top(8)
        .build();
    label.add_css_class("title-3");
    label
}

fn build_action_button(
    app: &TMJApp,
    on_install: Rc<dyn Fn(&TMJApp)>,
    on_remove: Rc<dyn Fn(&TMJApp)>,
    on_upgrade: Rc<dyn Fn(&TMJApp)>,
) -> Button {
    let app_clone = app.clone();
    if app.has_update {
        let btn = Button::with_label("Atualizar");
        btn.add_css_class("tmjstore-install-btn");
        btn.connect_clicked(move |_| on_upgrade(&app_clone));
        btn
    } else if app.installed {
        let btn = Button::with_label("Remover");
        btn.connect_clicked(move |_| on_remove(&app_clone));
        btn
    } else {
        let btn = Button::with_label("Instalar");
        btn.add_css_class("tmjstore-install-btn");
        btn.connect_clicked(move |_| on_install(&app_clone));
        btn
    }
}
