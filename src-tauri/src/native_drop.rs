//! macOS native file-promise drop handler.
//!
//! An overlay NSView that ONLY handles file-promise drags (Apple Mail).
//! Regular file-URL drags (Finder) are rejected by the overlay and fall
//! through to the WebView, where Tauri's built-in DragDropEvent handles them.

#[cfg(target_os = "macos")]
use std::ffi::{c_char, c_int, c_void};
#[cfg(target_os = "macos")]
use std::sync::atomic::{AtomicPtr, Ordering};

#[cfg(target_os = "macos")]
use tauri::{Emitter, Manager};

#[cfg(target_os = "macos")]
extern "C" {
    fn resolve_file_promises(
        pasteboard: *mut objc2::runtime::AnyObject,
        dest_dir_path: *const c_char,
        callback: extern "C" fn(*const *const c_char, c_int, *mut c_void),
        context: *mut c_void,
    );
}

#[cfg(target_os = "macos")]
static APP_HANDLE: AtomicPtr<c_void> = AtomicPtr::new(std::ptr::null_mut());

#[cfg(target_os = "macos")]
pub fn setup(app: &tauri::AppHandle) -> Result<(), String> {
    use objc2::msg_send;
    use objc2::runtime::*;
    use objc2_foundation::*;

    let window = app
        .get_webview_window("main")
        .ok_or("No main window")?;

    let handle = Box::new(app.clone());
    APP_HANDLE.store(Box::into_raw(handle) as *mut c_void, Ordering::Release);

    unsafe {
        let ns_window = window.ns_window().map_err(|e| e.to_string())? as *mut AnyObject;
        let content_view: *mut AnyObject = msg_send![ns_window, contentView];
        let frame: NSRect = msg_send![content_view, frame];

        let cls = get_or_create_class()?;
        let overlay: *mut AnyObject = msg_send![cls, alloc];
        let overlay: *mut AnyObject = msg_send![overlay, initWithFrame: frame];

        // Register ONLY file-promise types (not file URLs).
        register_promise_types(overlay)?;

        let _: () = msg_send![overlay, setAutoresizingMask: 18u64]; // flex W+H
        let _: () = msg_send![content_view, addSubview: overlay];
        let _: () = msg_send![overlay, release];
    }

    Ok(())
}

#[cfg(target_os = "macos")]
fn get_or_create_class() -> Result<&'static objc2::runtime::AnyClass, String> {
    use objc2::runtime::*;
    use objc2::sel;

    let name = c"FilePromiseDropView";
    if let Some(cls) = AnyClass::get(name) {
        return Ok(cls);
    }

    let superclass = AnyClass::get(c"NSView").ok_or("NSView not found")?;
    let mut builder =
        ClassBuilder::new(name, superclass).ok_or("Failed to create class")?;

    // hitTest: → nil — transparent to clicks, drags still route via registered types.
    extern "C" fn hit_test(
        _this: &AnyObject, _cmd: Sel, _point: objc2_foundation::NSPoint,
    ) -> *mut AnyObject {
        std::ptr::null_mut()
    }
    unsafe { builder.add_method(sel!(hitTest:), hit_test as extern "C" fn(_, _, _) -> _); }

    // draggingEntered: — accept only if pasteboard has file promises.
    extern "C" fn dragging_entered(
        _this: &AnyObject, _cmd: Sel, sender: *mut AnyObject,
    ) -> usize {
        unsafe {
            let pb: *mut AnyObject = objc2::msg_send![sender, draggingPasteboard];
            if has_file_promises(pb) {
                eprintln!("[file_promise] draggingEntered: accepting (file promise)");
                1 // NSDragOperationCopy
            } else {
                0 // NSDragOperationNone — let WebView handle it
            }
        }
    }
    unsafe {
        builder.add_method(
            sel!(draggingEntered:),
            dragging_entered as extern "C" fn(_, _, _) -> _,
        );
    }

    // performDragOperation:
    extern "C" fn perform_drag(
        _this: &AnyObject, _cmd: Sel, sender: *mut AnyObject,
    ) -> Bool {
        match handle_promise_drop(sender) {
            Ok(()) => Bool::YES,
            Err(e) => {
                eprintln!("[file_promise] error: {e}");
                if let Some(app) = get_app_handle() {
                    let _ = app.emit("drop-error", e);
                }
                Bool::NO
            }
        }
    }
    unsafe {
        builder.add_method(
            sel!(performDragOperation:),
            perform_drag as extern "C" fn(_, _, _) -> _,
        );
    }

    Ok(builder.register())
}

/// Register ONLY file-promise drag types on the view.
#[cfg(target_os = "macos")]
fn register_promise_types(view: *mut objc2::runtime::AnyObject) -> Result<(), String> {
    use objc2::runtime::*;
    use objc2::{class, msg_send};

    unsafe {
        let promise_cls = AnyClass::get(c"NSFilePromiseReceiver")
            .ok_or("NSFilePromiseReceiver not available")?;
        let types: *mut AnyObject = msg_send![promise_cls, readableDraggedTypes];
        let _: () = msg_send![view, registerForDraggedTypes: types];
    }
    Ok(())
}

/// Check if pasteboard contains file promises.
#[cfg(target_os = "macos")]
unsafe fn has_file_promises(pasteboard: *mut objc2::runtime::AnyObject) -> bool {
    use objc2::runtime::*;
    use objc2::{class, msg_send};

    let promise_cls = match AnyClass::get(c"NSFilePromiseReceiver") {
        Some(c) => c,
        None => return false,
    };
    let cls_ptr = promise_cls as *const AnyClass as *const AnyObject;
    let classes: *mut AnyObject = msg_send![class!(NSArray), arrayWithObject: cls_ptr];
    let options: *mut AnyObject = msg_send![class!(NSDictionary), dictionary];
    let result: *mut AnyObject =
        msg_send![pasteboard, readObjectsForClasses: classes, options: options];
    if result.is_null() {
        return false;
    }
    let count: usize = msg_send![result, count];
    count > 0
}

/// Handle a file-promise drop via the native ObjC helper.
#[cfg(target_os = "macos")]
fn handle_promise_drop(sender: *mut objc2::runtime::AnyObject) -> Result<(), String> {
    use objc2::msg_send;
    use objc2::runtime::AnyObject;

    unsafe {
        let pasteboard: *mut AnyObject = msg_send![sender, draggingPasteboard];
        let temp_dir = std::env::temp_dir().join("mail-analyzer-gui-drop");
        let _ = std::fs::create_dir_all(&temp_dir);
        let dest_cstr =
            std::ffi::CString::new(temp_dir.to_str().unwrap()).map_err(|e| e.to_string())?;

        eprintln!("[file_promise] calling resolve_file_promises");
        resolve_file_promises(pasteboard, dest_cstr.as_ptr(), on_resolved, std::ptr::null_mut());
    }
    Ok(())
}

/// Callback from ObjC when file promises are resolved.
#[cfg(target_os = "macos")]
extern "C" fn on_resolved(paths: *const *const c_char, count: c_int, _ctx: *mut c_void) {
    eprintln!("[file_promise] resolved: count={count}");
    if count <= 0 || paths.is_null() {
        return;
    }
    let mut result = Vec::new();
    for i in 0..count as isize {
        unsafe {
            let c_str = *paths.offset(i);
            if !c_str.is_null() {
                if let Ok(s) = std::ffi::CStr::from_ptr(c_str).to_str() {
                    eprintln!("[file_promise] path: {s}");
                    result.push(s.to_string());
                }
            }
        }
    }
    if !result.is_empty() {
        if let Some(app) = get_app_handle() {
            let _ = app.emit("files-dropped", &result);
        }
    }
}

#[cfg(target_os = "macos")]
fn get_app_handle() -> Option<tauri::AppHandle> {
    let ptr = APP_HANDLE.load(Ordering::Acquire);
    if ptr.is_null() {
        None
    } else {
        let handle = unsafe { &*(ptr as *const tauri::AppHandle) };
        Some(handle.clone())
    }
}
