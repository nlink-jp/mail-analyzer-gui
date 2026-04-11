export interface Settings {
  binary_path: string;
  env_vars: EnvVars;
}

export interface EnvVars {
  project: string;
  location: string;
  model: string;
  lang: string;
}

export interface AnalysisResult {
  source_file: string;
  hash: string;
  message_id: string;
  subject: string;
  from: string;
  to: string[];
  date: string;
  indicators: Indicators;
  judgment: Judgment;
}

export interface Indicators {
  authentication: AuthResult;
  sender: SenderResult;
  urls: UrlResult[];
  attachments: AttachResult[];
  routing: RoutingResult;
}

export interface AuthResult {
  spf: string;
  dkim: string;
  dmarc: string;
}

export interface SenderResult {
  from_return_path_mismatch: boolean;
  display_name_spoofing: boolean;
  reply_to_divergence: boolean;
  details: string;
}

export interface UrlResult {
  url: string;
  suspicious: boolean;
  reason: string;
}

export interface AttachResult {
  filename: string;
  mime_type: string;
  size: number;
  hash: string;
  suspicious: boolean;
  reason: string;
}

export interface RoutingResult {
  hop_count: number;
  x_mailer: string;
  x_mailer_suspicious: boolean;
  suspicious_hops: string[];
}

export interface Judgment {
  is_suspicious: boolean;
  category: string;
  confidence: number;
  summary: string;
  reasons: string[];
  tags: string[];
}

export interface AnalysisEntry {
  id: string;
  filename: string;
  status: "pending" | "analyzing" | "done" | "error";
  result?: AnalysisResult;
  error?: string;
}
