fn main() {
    #[cfg(target_os = "macos")]
    {
        cc::Build::new()
            .file("src/objc_helper.m")
            .flag("-fobjc-arc")
            .compile("objc_helper");
        println!("cargo:rustc-link-lib=framework=AppKit");
        println!("cargo:rustc-link-lib=framework=CoreServices");
        println!("cargo:rerun-if-changed=src/objc_helper.m");
    }
    tauri_build::build()
}
