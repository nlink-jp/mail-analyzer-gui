mod analyzer;
mod commands;
#[cfg(target_os = "macos")]
mod native_drop;
mod settings;
mod types;
mod window_state;

use tauri::Manager;

use commands::{analyze_file, export_json, get_settings, save_settings};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            analyze_file,
            get_settings,
            save_settings,
            export_json,
        ])
        .setup(|app| {
            let handle = app.handle().clone();

            // Restore saved window position/size.
            window_state::restore(&handle);

            #[cfg(target_os = "macos")]
            {
                if let Err(e) = native_drop::setup(&handle) {
                    eprintln!("[setup] native_drop failed: {e}");
                }
            }

            // Save window position/size on move/resize, then show the window.
            let h = handle.clone();
            if let Some(window) = handle.get_webview_window("main") {
                window.on_window_event(move |event| {
                    use tauri::WindowEvent;
                    match event {
                        WindowEvent::Moved(_) | WindowEvent::Resized(_) => {
                            window_state::save(&h);
                        }
                        _ => {}
                    }
                });
                let _ = window.show();
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
