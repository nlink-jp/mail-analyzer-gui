use tauri::AppHandle;

use crate::analyzer;
use crate::settings;
use crate::types::{AnalysisResult, Settings};

#[tauri::command]
pub async fn analyze_file(app: AppHandle, path: String) -> Result<AnalysisResult, String> {
    eprintln!("[cmd] analyze_file called: {path}");
    let s = settings::load(&app)?;
    eprintln!("[cmd] settings loaded, binary: {}", s.binary_path);

    // Run the blocking subprocess on a dedicated thread.
    let (tx, rx) = tokio::sync::oneshot::channel();
    std::thread::spawn(move || {
        let result = analyzer::run_analysis(&s, &path);
        let _ = tx.send(result);
    });

    let result = rx.await.map_err(|e| format!("Channel error: {e}"))?;

    match &result {
        Ok(r) => eprintln!("[cmd] analysis ok: {} -> {}", r.source_file, r.judgment.category),
        Err(e) => eprintln!("[cmd] analysis error: {e}"),
    }
    result
}

#[tauri::command]
pub fn get_settings(app: AppHandle) -> Result<Settings, String> {
    settings::load(&app)
}

#[tauri::command]
pub fn save_settings(app: AppHandle, settings: Settings) -> Result<(), String> {
    settings::save(&app, &settings)
}

#[tauri::command]
pub fn export_json(results: Vec<AnalysisResult>) -> Result<String, String> {
    serde_json::to_string_pretty(&results).map_err(|e| format!("Failed to serialize: {}", e))
}
