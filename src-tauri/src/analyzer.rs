use std::process::Command;

use crate::types::{AnalysisResult, Settings};

/// Run the mail-analyzer binary on the given file path.
pub fn run_analysis(settings: &Settings, file_path: &str) -> Result<AnalysisResult, String> {
    if settings.binary_path.is_empty() {
        return Err(
            "mail-analyzer binary path is not configured. Please open Settings and set the path."
                .to_string(),
        );
    }

    let binary = std::path::Path::new(&settings.binary_path);
    if !binary.exists() {
        return Err(format!(
            "mail-analyzer binary not found at: {}\nPlease check the path in Settings.",
            settings.binary_path
        ));
    }

    if !binary.is_file() {
        return Err(format!(
            "Path is not a file: {}\nPlease set the path to the mail-analyzer binary.",
            settings.binary_path
        ));
    }

    let mut cmd = Command::new(&settings.binary_path);
    cmd.arg(file_path);

    // Set environment variables if configured.
    let env = &settings.env_vars;
    if !env.project.is_empty() {
        cmd.env("MAIL_ANALYZER_PROJECT", &env.project);
    }
    if !env.location.is_empty() {
        cmd.env("MAIL_ANALYZER_LOCATION", &env.location);
    }
    if !env.model.is_empty() {
        cmd.env("MAIL_ANALYZER_MODEL", &env.model);
    }
    if !env.lang.is_empty() {
        cmd.env("MAIL_ANALYZER_LANG", &env.lang);
    }

    let output = cmd
        .output()
        .map_err(|e| format!("Failed to execute mail-analyzer: {}\nBinary: {}", e, settings.binary_path))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        let mut msg = format!("mail-analyzer exited with code {}", output.status);
        if !stderr.is_empty() {
            msg.push_str(&format!("\n\nStderr:\n{}", stderr.trim()));
        }
        if !stdout.is_empty() && stderr.is_empty() {
            msg.push_str(&format!("\n\nOutput:\n{}", stdout.trim()));
        }
        return Err(msg);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    if stdout.trim().is_empty() {
        return Err("mail-analyzer returned empty output".to_string());
    }

    serde_json::from_str::<AnalysisResult>(&stdout).map_err(|e| {
        format!(
            "Failed to parse mail-analyzer output: {}\n\nRaw output (first 500 chars):\n{}",
            e,
            &stdout[..stdout.len().min(500)]
        )
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{EnvVars, Settings};

    #[test]
    fn test_empty_binary_path_returns_error() {
        let settings = Settings {
            binary_path: String::new(),
            env_vars: EnvVars {
                project: String::new(),
                location: String::new(),
                model: String::new(),
                lang: String::new(),
            },
        };
        let result = run_analysis(&settings, "/tmp/test.eml");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not configured"));
    }

    #[test]
    fn test_nonexistent_binary_returns_error() {
        let settings = Settings {
            binary_path: "/nonexistent/mail-analyzer".to_string(),
            env_vars: EnvVars {
                project: String::new(),
                location: String::new(),
                model: String::new(),
                lang: String::new(),
            },
        };
        let result = run_analysis(&settings, "/tmp/test.eml");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }
}
