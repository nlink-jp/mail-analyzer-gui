use tauri::AppHandle;
use tauri_plugin_store::StoreExt;

use crate::types::Settings;

const STORE_FILE: &str = "settings.json";
const SETTINGS_KEY: &str = "settings";

pub fn load(app: &AppHandle) -> Result<Settings, String> {
    let store = app
        .store(STORE_FILE)
        .map_err(|e| format!("Failed to open store: {}", e))?;

    match store.get(SETTINGS_KEY) {
        Some(value) => {
            serde_json::from_value(value).map_err(|e| format!("Failed to parse settings: {}", e))
        }
        None => Ok(Settings::default()),
    }
}

pub fn save(app: &AppHandle, settings: &Settings) -> Result<(), String> {
    let store = app
        .store(STORE_FILE)
        .map_err(|e| format!("Failed to open store: {}", e))?;

    let value =
        serde_json::to_value(settings).map_err(|e| format!("Failed to serialize settings: {}", e))?;

    store.set(SETTINGS_KEY, value);
    store
        .save()
        .map_err(|e| format!("Failed to save store: {}", e))
}
