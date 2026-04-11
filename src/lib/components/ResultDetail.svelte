<script lang="ts">
  import type { AnalysisResult } from "$lib/types";

  let { result }: { result: AnalysisResult } = $props();

  let showIndicators = $state(false);

  function categoryColor(category: string): string {
    switch (category) {
      case "phishing": return "#e74c3c";
      case "spam": return "#e67e22";
      case "malware-delivery": return "#c0392b";
      case "bec": return "#e74c3c";
      case "scam": return "#d35400";
      case "safe": return "#27ae60";
      default: return "#888";
    }
  }

  function confidencePercent(c: number): string {
    return `${Math.round(c * 100)}%`;
  }

  function authBadge(value: string): string {
    if (value === "pass") return "badge-pass";
    if (value === "fail" || value === "softfail" || value === "permerror") return "badge-fail";
    return "badge-neutral";
  }
</script>

<div class="result-detail">
  <div class="header">
    <div class="judgment-row">
      <span
        class="category-badge"
        style="background-color: {categoryColor(result.judgment.category)}"
      >
        {result.judgment.category.toUpperCase()}
      </span>
      <span class="confidence">{confidencePercent(result.judgment.confidence)}</span>
      {#if result.judgment.is_suspicious}
        <span class="suspicious-flag">SUSPICIOUS</span>
      {/if}
    </div>
    <div class="subject">{result.subject || "(no subject)"}</div>
    <div class="meta">
      <span class="from">{result.from}</span>
      <span class="date">{result.date}</span>
    </div>
  </div>

  <div class="summary">{result.judgment.summary}</div>

  {#if result.judgment.reasons.length > 0}
    <div class="reasons">
      {#each result.judgment.reasons as reason}
        <div class="reason-item">- {reason}</div>
      {/each}
    </div>
  {/if}

  {#if result.judgment.tags.length > 0}
    <div class="tags">
      {#each result.judgment.tags as tag}
        <span class="tag">{tag}</span>
      {/each}
    </div>
  {/if}

  <button class="toggle-btn" onclick={() => showIndicators = !showIndicators}>
    {showIndicators ? "Hide" : "Show"} Indicators
  </button>

  {#if showIndicators}
    <div class="indicators">
      <div class="indicator-section">
        <h4>Authentication</h4>
        <div class="auth-badges">
          <span class="auth-badge {authBadge(result.indicators.authentication.spf)}">
            SPF: {result.indicators.authentication.spf || "none"}
          </span>
          <span class="auth-badge {authBadge(result.indicators.authentication.dkim)}">
            DKIM: {result.indicators.authentication.dkim || "none"}
          </span>
          <span class="auth-badge {authBadge(result.indicators.authentication.dmarc)}">
            DMARC: {result.indicators.authentication.dmarc || "none"}
          </span>
        </div>
      </div>

      <div class="indicator-section">
        <h4>Sender</h4>
        <div class="sender-flags">
          {#if result.indicators.sender.from_return_path_mismatch}
            <span class="flag-warn">From/Return-Path mismatch</span>
          {/if}
          {#if result.indicators.sender.display_name_spoofing}
            <span class="flag-warn">Display name spoofing</span>
          {/if}
          {#if result.indicators.sender.reply_to_divergence}
            <span class="flag-warn">Reply-To divergence</span>
          {/if}
          {#if result.indicators.sender.details}
            <p class="detail-text">{result.indicators.sender.details}</p>
          {/if}
          {#if !result.indicators.sender.from_return_path_mismatch && !result.indicators.sender.display_name_spoofing && !result.indicators.sender.reply_to_divergence}
            <span class="flag-ok">No issues detected</span>
          {/if}
        </div>
      </div>

      {#if result.indicators.urls.length > 0}
        <div class="indicator-section">
          <h4>URLs ({result.indicators.urls.length})</h4>
          {#each result.indicators.urls as url}
            <div class="url-item" class:suspicious={url.suspicious}>
              <code>{url.url}</code>
              {#if url.suspicious}
                <span class="flag-warn">{url.reason}</span>
              {/if}
            </div>
          {/each}
        </div>
      {/if}

      {#if result.indicators.attachments.length > 0}
        <div class="indicator-section">
          <h4>Attachments ({result.indicators.attachments.length})</h4>
          {#each result.indicators.attachments as att}
            <div class="attach-item" class:suspicious={att.suspicious}>
              <span class="attach-name">{att.filename}</span>
              <span class="attach-meta">{att.mime_type} ({att.size} bytes)</span>
              {#if att.suspicious}
                <span class="flag-warn">{att.reason}</span>
              {/if}
            </div>
          {/each}
        </div>
      {/if}

      <div class="indicator-section">
        <h4>Routing</h4>
        <p class="detail-text">Hops: {result.indicators.routing.hop_count}</p>
        {#if result.indicators.routing.x_mailer}
          <p class="detail-text" class:suspicious={result.indicators.routing.x_mailer_suspicious}>
            X-Mailer: {result.indicators.routing.x_mailer}
          </p>
        {/if}
        {#if result.indicators.routing.suspicious_hops.length > 0}
          {#each result.indicators.routing.suspicious_hops as hop}
            <span class="flag-warn">{hop}</span>
          {/each}
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .result-detail {
    padding: 12px 0;
  }

  .header {
    margin-bottom: 8px;
  }

  .judgment-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
  }

  .category-badge {
    color: white;
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
  }

  .confidence {
    font-size: 14px;
    font-weight: 600;
    color: #555;
  }

  .suspicious-flag {
    color: #e74c3c;
    font-size: 12px;
    font-weight: 700;
    border: 1px solid #e74c3c;
    padding: 1px 6px;
    border-radius: 4px;
  }

  .subject {
    font-size: 16px;
    font-weight: 600;
    margin: 4px 0;
  }

  .meta {
    font-size: 12px;
    color: #888;
    display: flex;
    gap: 16px;
  }

  .summary {
    font-size: 14px;
    margin: 8px 0;
    line-height: 1.5;
  }

  .reasons {
    font-size: 13px;
    color: #666;
    margin: 4px 0 8px;
  }

  .reason-item {
    margin: 2px 0;
  }

  .tags {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
    margin-bottom: 8px;
  }

  .tag {
    background: #eee;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    color: #555;
  }

  .toggle-btn {
    background: none;
    border: 1px solid #ccc;
    border-radius: 4px;
    padding: 4px 12px;
    font-size: 12px;
    cursor: pointer;
    color: inherit;
    box-shadow: none;
  }

  .toggle-btn:hover {
    border-color: #999;
  }

  .indicators {
    margin-top: 12px;
    padding: 12px;
    background: rgba(0, 0, 0, 0.03);
    border-radius: 8px;
  }

  .indicator-section {
    margin-bottom: 12px;
  }

  .indicator-section:last-child {
    margin-bottom: 0;
  }

  .indicator-section h4 {
    margin: 0 0 6px;
    font-size: 13px;
    color: #666;
  }

  .auth-badges {
    display: flex;
    gap: 8px;
  }

  .auth-badge {
    padding: 2px 8px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
  }

  .badge-pass {
    background: #d4edda;
    color: #155724;
  }

  .badge-fail {
    background: #f8d7da;
    color: #721c24;
  }

  .badge-neutral {
    background: #e2e3e5;
    color: #383d41;
  }

  .flag-warn {
    color: #e74c3c;
    font-size: 12px;
    display: inline-block;
    margin: 2px 4px 2px 0;
  }

  .flag-ok {
    color: #27ae60;
    font-size: 12px;
  }

  .detail-text {
    font-size: 13px;
    color: #666;
    margin: 2px 0;
  }

  .url-item, .attach-item {
    font-size: 13px;
    margin: 4px 0;
  }

  .url-item code {
    font-size: 12px;
    word-break: break-all;
  }

  .attach-name {
    font-weight: 500;
  }

  .attach-meta {
    color: #888;
    font-size: 12px;
    margin-left: 8px;
  }

  .suspicious {
    color: #e74c3c;
  }

  @media (prefers-color-scheme: dark) {
    .confidence { color: #aaa; }
    .meta { color: #999; }
    .reasons { color: #aaa; }
    .tag { background: #444; color: #ccc; }
    .indicators { background: rgba(255, 255, 255, 0.05); }
    .indicator-section h4 { color: #aaa; }
    .detail-text { color: #aaa; }
    .badge-pass { background: #1e4d2b; color: #a3d9b1; }
    .badge-fail { background: #4d1c24; color: #f5a3a3; }
    .badge-neutral { background: #3a3a3a; color: #aaa; }
    .flag-ok { color: #2ecc71; }
    .attach-meta { color: #999; }
    .toggle-btn { border-color: #555; }
    .toggle-btn:hover { border-color: #888; }
  }
</style>
