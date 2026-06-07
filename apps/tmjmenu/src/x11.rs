//! X11 helpers — port do x11.py via x11rb (pure Rust, sem FFI Xlib).
//!
//! Roda apenas em backend X11/XWayland. Em Wayland nativo, o tmjdock
//! usa gtk4-layer-shell direto — esses hints são fallback.
//!
//! Todas as funções retornam `Ok(())` em sucesso, `Err(_)` em falha
//! (connection drop, atom interning falhou, etc). Callers tratam erro
//! como no-op (não é fatal).

use anyhow::{anyhow, Context, Result};
use x11rb::connection::Connection;
use x11rb::protocol::xproto::{
    AtomEnum, ConfigureWindowAux, ConnectionExt, PropMode,
};
use x11rb::rust_connection::RustConnection;
use x11rb::wrapper::ConnectionExt as WrapperConnectionExt;

/// Cria uma conexão X11 + retorna o atom de uma propriedade.
fn intern_atom(conn: &RustConnection, name: &str) -> Result<u32> {
    let reply = conn
        .intern_atom(false, name.as_bytes())?
        .reply()
        .with_context(|| format!("intern_atom({name})"))?;
    Ok(reply.atom)
}

/// Transforma a window XID em dock real (X11):
///   - _NET_WM_WINDOW_TYPE = _NET_WM_WINDOW_TYPE_DOCK
///   - _NET_WM_STRUT_PARTIAL (reserva bottom space)
///   - move pra bottom-center do monitor
///   - sticky em todos workspaces
pub fn make_dock(
    xid: u32,
    monitor_x: i32,
    monitor_y: i32,
    monitor_width: i32,
    monitor_height: i32,
    dock_width: i32,
    dock_height: i32,
) -> Result<()> {
    let (conn, _screen_num) = x11rb::connect(None)?;
    let win = xid;

    // Atoms
    let atom_window_type = intern_atom(&conn, "_NET_WM_WINDOW_TYPE")?;
    let atom_dock = intern_atom(&conn, "_NET_WM_WINDOW_TYPE_DOCK")?;
    let atom_strut = intern_atom(&conn, "_NET_WM_STRUT_PARTIAL")?;
    let atom_strut_old = intern_atom(&conn, "_NET_WM_STRUT")?;
    let atom_desktop = intern_atom(&conn, "_NET_WM_DESKTOP")?;

    // _NET_WM_WINDOW_TYPE = DOCK
    let dock_data: [u32; 1] = [atom_dock];
    conn.change_property32(
        PropMode::REPLACE,
        win,
        atom_window_type,
        AtomEnum::ATOM,
        &dock_data,
    )?;

    // Position: bottom-centered no monitor
    let margin = 4;
    let win_x = monitor_x + (monitor_width - dock_width) / 2;
    let win_y = monitor_y + monitor_height - dock_height - margin;
    conn.configure_window(
        win,
        &ConfigureWindowAux::new()
            .x(win_x)
            .y(win_y)
            .width(dock_width.max(1) as u32)
            .height(dock_height.max(1) as u32),
    )?;

    // _NET_WM_STRUT_PARTIAL (12 cardinals): left, right, top, bottom,
    // left_start_y, left_end_y, right_start_y, right_end_y,
    // top_start_x, top_end_x, bottom_start_x, bottom_end_x.
    let strut_bottom = (dock_height + margin) as u32;
    let bottom_start_x = win_x.max(0) as u32;
    let bottom_end_x = (win_x + dock_width - 1).max(0) as u32;
    let strut_partial: [u32; 12] = [
        0, 0, 0, strut_bottom,
        0, 0, 0, 0,
        0, 0,
        bottom_start_x, bottom_end_x,
    ];
    conn.change_property32(
        PropMode::REPLACE,
        win,
        atom_strut,
        AtomEnum::CARDINAL,
        &strut_partial,
    )?;

    // _NET_WM_STRUT (legacy, 4 cardinals)
    let strut_old: [u32; 4] = [0, 0, 0, strut_bottom];
    conn.change_property32(
        PropMode::REPLACE,
        win,
        atom_strut_old,
        AtomEnum::CARDINAL,
        &strut_old,
    )?;

    // Sticky em todos workspaces (0xFFFFFFFF = all)
    let all_workspaces: [u32; 1] = [0xFFFFFFFF];
    conn.change_property32(
        PropMode::REPLACE,
        win,
        atom_desktop,
        AtomEnum::CARDINAL,
        &all_workspaces,
    )?;

    conn.sync()?;
    Ok(())
}

/// Transforma window XID em popup (SPLASH type) — usado pelo TMJMenu.
/// Posiciona em (x, y) com size dado.
pub fn make_popup(xid: u32, x: i32, y: i32, width: i32, height: i32) -> Result<()> {
    let (conn, _) = x11rb::connect(None)?;

    let atom_window_type = intern_atom(&conn, "_NET_WM_WINDOW_TYPE")?;
    let atom_splash = intern_atom(&conn, "_NET_WM_WINDOW_TYPE_SPLASH")?;
    let atom_state = intern_atom(&conn, "_NET_WM_STATE")?;
    let atom_above = intern_atom(&conn, "_NET_WM_STATE_ABOVE")?;
    let atom_desktop = intern_atom(&conn, "_NET_WM_DESKTOP")?;

    let splash_data: [u32; 1] = [atom_splash];
    conn.change_property32(
        PropMode::REPLACE,
        xid,
        atom_window_type,
        AtomEnum::ATOM,
        &splash_data,
    )?;

    let above_data: [u32; 1] = [atom_above];
    conn.change_property32(
        PropMode::REPLACE,
        xid,
        atom_state,
        AtomEnum::ATOM,
        &above_data,
    )?;

    let all_ws: [u32; 1] = [0xFFFFFFFF];
    conn.change_property32(
        PropMode::REPLACE,
        xid,
        atom_desktop,
        AtomEnum::CARDINAL,
        &all_ws,
    )?;

    conn.configure_window(
        xid,
        &ConfigureWindowAux::new()
            .x(x)
            .y(y)
            .width(width.max(1) as u32)
            .height(height.max(1) as u32),
    )?;
    conn.sync()?;
    Ok(())
}

/// Retorna a posição Y do cursor em root coords. Usado pro auto-hide
/// detectar mouse near bottom edge. None se backend não-X11 ou erro.
pub fn query_pointer_y() -> Option<i32> {
    let (conn, screen_num) = x11rb::connect(None).ok()?;
    let screen = conn.setup().roots.get(screen_num)?;
    let root = screen.root;
    let reply = conn.query_pointer(root).ok()?.reply().ok()?;
    Some(reply.root_y as i32)
}

/// Esconde a dock movendo-a quase totalmente pra fora do monitor + zera
/// o strut. Mantém 2px visíveis pra facilitar reveal.
pub fn hide_window_offscreen(xid: u32, screen_bottom: i32, dock_height: i32) -> Result<()> {
    let (conn, _) = x11rb::connect(None)?;

    let atom_strut = intern_atom(&conn, "_NET_WM_STRUT_PARTIAL")?;
    let atom_strut_old = intern_atom(&conn, "_NET_WM_STRUT")?;

    let zeros_12: [u32; 12] = [0; 12];
    conn.change_property32(
        PropMode::REPLACE,
        xid,
        atom_strut,
        AtomEnum::CARDINAL,
        &zeros_12,
    )?;
    let zeros_4: [u32; 4] = [0; 4];
    conn.change_property32(
        PropMode::REPLACE,
        xid,
        atom_strut_old,
        AtomEnum::CARDINAL,
        &zeros_4,
    )?;

    let hidden_y = screen_bottom - 2;
    conn.configure_window(
        xid,
        &ConfigureWindowAux::new()
            .y(hidden_y)
            .height(dock_height.max(1) as u32),
    )?;
    conn.sync()?;
    Ok(())
}

/// Move a dock pra (x, y) + restaura strut. Usado pra "mostrar" no
/// auto-hide.
pub fn show_window_at(
    xid: u32,
    x: i32,
    y: i32,
    dock_width: i32,
    dock_height: i32,
) -> Result<()> {
    let (conn, _) = x11rb::connect(None)?;

    conn.configure_window(
        xid,
        &ConfigureWindowAux::new()
            .x(x)
            .y(y)
            .width(dock_width.max(1) as u32)
            .height(dock_height.max(1) as u32),
    )?;

    let margin = 4;
    let strut_bottom = (dock_height + margin) as u32;
    let bottom_start_x = x.max(0) as u32;
    let bottom_end_x = (x + dock_width - 1).max(0) as u32;

    let atom_strut = intern_atom(&conn, "_NET_WM_STRUT_PARTIAL")?;
    let strut: [u32; 12] = [
        0, 0, 0, strut_bottom,
        0, 0, 0, 0,
        0, 0,
        bottom_start_x, bottom_end_x,
    ];
    conn.change_property32(
        PropMode::REPLACE,
        xid,
        atom_strut,
        AtomEnum::CARDINAL,
        &strut,
    )?;

    let atom_strut_old = intern_atom(&conn, "_NET_WM_STRUT")?;
    let strut_old: [u32; 4] = [0, 0, 0, strut_bottom];
    conn.change_property32(
        PropMode::REPLACE,
        xid,
        atom_strut_old,
        AtomEnum::CARDINAL,
        &strut_old,
    )?;

    conn.sync()?;
    Ok(())
}

/// Force input focus to a window via X11 SetInputFocus.
pub fn focus_popup(xid: u32) -> Result<()> {
    let (conn, _) = x11rb::connect(None)?;
    conn.set_input_focus(
        x11rb::protocol::xproto::InputFocus::PARENT,
        xid,
        x11rb::CURRENT_TIME,
    )?;
    conn.sync()?;
    Ok(())
}

// Silenciar warnings se as features X11 não forem usadas.
#[allow(dead_code)]
fn _unused() -> Result<()> {
    Err(anyhow!("placeholder"))
}
