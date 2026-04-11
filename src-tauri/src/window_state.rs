use serde::{Deserialize, Serialize};
use tauri::Manager;
use tauri_plugin_store::StoreExt;

const STORE_FILE: &str = "settings.json";
const WINDOW_KEY: &str = "window_state";

#[derive(Debug, Serialize, Deserialize)]
struct WindowState {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
}

pub fn restore(app: &tauri::AppHandle) {
    let window = match app.get_webview_window("main") {
        Some(w) => w,
        None => return,
    };

    let store = match app.store(STORE_FILE) {
        Ok(s) => s,
        Err(_) => return,
    };

    let state: WindowState = match store.get(WINDOW_KEY) {
        Some(v) => match serde_json::from_value(v) {
            Ok(s) => s,
            Err(_) => return,
        },
        None => return,
    };

    // Sanity check: don't restore to offscreen or tiny sizes.
    if state.width < 200 || state.height < 200 {
        return;
    }

    let _ = window.set_position(tauri::PhysicalPosition::new(state.x, state.y));
    let _ = window.set_size(tauri::PhysicalSize::new(state.width, state.height));
}

pub fn save(app: &tauri::AppHandle) {
    let window = match app.get_webview_window("main") {
        Some(w) => w,
        None => return,
    };

    let pos = match window.outer_position() {
        Ok(p) => p,
        Err(_) => return,
    };
    let size = match window.outer_size() {
        Ok(s) => s,
        Err(_) => return,
    };

    let state = WindowState {
        x: pos.x,
        y: pos.y,
        width: size.width,
        height: size.height,
    };

    let store = match app.store(STORE_FILE) {
        Ok(s) => s,
        Err(_) => return,
    };

    if let Ok(value) = serde_json::to_value(&state) {
        store.set(WINDOW_KEY, value);
        let _ = store.save();
    }
}
