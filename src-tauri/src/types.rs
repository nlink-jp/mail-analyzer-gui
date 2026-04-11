use serde::{Deserialize, Serialize};

/// Settings persisted via tauri-plugin-store.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub binary_path: String,
    pub env_vars: EnvVars,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnvVars {
    pub project: String,
    pub location: String,
    pub model: String,
    pub lang: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            binary_path: String::new(),
            env_vars: EnvVars {
                project: String::new(),
                location: "us-central1".to_string(),
                model: "gemini-2.5-flash".to_string(),
                lang: String::new(),
            },
        }
    }
}

/// Top-level result from mail-analyzer JSON output.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub source_file: String,
    pub hash: String,
    #[serde(default)]
    pub message_id: String,
    #[serde(default)]
    pub subject: String,
    #[serde(default)]
    pub from: String,
    #[serde(default, deserialize_with = "deserialize_null_vec")]
    pub to: Vec<String>,
    #[serde(default)]
    pub date: String,
    pub indicators: Indicators,
    pub judgment: Judgment,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Indicators {
    pub authentication: AuthResult,
    pub sender: SenderResult,
    #[serde(default, deserialize_with = "deserialize_null_vec")]
    pub urls: Vec<UrlResult>,
    #[serde(default, deserialize_with = "deserialize_null_vec")]
    pub attachments: Vec<AttachResult>,
    pub routing: RoutingResult,
}

/// Deserialize a JSON `null` as an empty Vec.
fn deserialize_null_vec<'de, D, T>(deserializer: D) -> Result<Vec<T>, D::Error>
where
    D: serde::Deserializer<'de>,
    T: serde::Deserialize<'de>,
{
    Ok(Option::<Vec<T>>::deserialize(deserializer)?.unwrap_or_default())
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthResult {
    #[serde(default)]
    pub spf: String,
    #[serde(default)]
    pub dkim: String,
    #[serde(default)]
    pub dmarc: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SenderResult {
    #[serde(default)]
    pub from_return_path_mismatch: bool,
    #[serde(default)]
    pub display_name_spoofing: bool,
    #[serde(default)]
    pub reply_to_divergence: bool,
    #[serde(default)]
    pub details: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UrlResult {
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub suspicious: bool,
    #[serde(default)]
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttachResult {
    #[serde(default)]
    pub filename: String,
    #[serde(default)]
    pub mime_type: String,
    #[serde(default)]
    pub size: u64,
    #[serde(default)]
    pub hash: String,
    #[serde(default)]
    pub suspicious: bool,
    #[serde(default)]
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoutingResult {
    #[serde(default)]
    pub hop_count: u32,
    #[serde(default)]
    pub x_mailer: String,
    #[serde(default)]
    pub x_mailer_suspicious: bool,
    #[serde(default, deserialize_with = "deserialize_null_vec")]
    pub suspicious_hops: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Judgment {
    pub is_suspicious: bool,
    #[serde(default)]
    pub category: String,
    #[serde(default)]
    pub confidence: f64,
    #[serde(default)]
    pub summary: String,
    #[serde(default, deserialize_with = "deserialize_null_vec")]
    pub reasons: Vec<String>,
    #[serde(default, deserialize_with = "deserialize_null_vec")]
    pub tags: Vec<String>,
}
