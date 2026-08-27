<script lang="ts">
  import type { AnalysisEntry } from "$lib/types";
  import ResultDetail from "./ResultDetail.svelte";

  let { entries }: { entries: AnalysisEntry[] } = $props();

  let expandedIds = $state<Set<string>>(new Set());

  function toggle(id: string) {
    const next = new Set(expandedIds);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    expandedIds = next;
  }

  function statusIcon(entry: AnalysisEntry): string {
    if (entry.status === "analyzing") return "...";
    if (entry.status === "error") return "!!";
    if (entry.result?.judgment.is_suspicious) return "!!";
    if (entry.result) return "OK";
    return "";
  }

  function statusClass(entry: AnalysisEntry): string {
    if (entry.status === "error") return "status-error";
    if (entry.status === "analyzing") return "status-analyzing";
    if (entry.result?.judgment.is_suspicious) return "status-suspicious";
    return "status-safe";
  }

  function categoryLabel(entry: AnalysisEntry): string {
    if (!entry.result) return "";
    const j = entry.result.judgment;
    return `${j.category} ${Math.round(j.confidence * 100)}%`;
  }
</script>

<div class="result-list">
  {#if entries.length === 0}
    <div class="empty">No results yet</div>
  {/if}

  {#each entries as entry (entry.id)}
    <div class="result-item">
      <button class="result-header" onclick={() => toggle(entry.id)}>
        <span class="status-icon {statusClass(entry)}">{statusIcon(entry)}</span>
        <span class="filename">{entry.filename}</span>
        {#if entry.status === "analyzing"}
          <span class="spinner"></span>
        {:else if entry.result}
          <span class="category-label {statusClass(entry)}">{categoryLabel(entry)}</span>
        {:else if entry.error}
          <span class="error-short">Error</span>
        {/if}
        <span class="expand-arrow">{expandedIds.has(entry.id) ? "v" : ">"}</span>
      </button>

      {#if expandedIds.has(entry.id)}
        <div class="result-body">
          {#if entry.result}
            <ResultDetail result={entry.result} />
          {:else if entry.error}
            <div class="error-detail">{entry.error}</div>
          {:else if entry.status === "analyzing"}
            <div class="analyzing-msg">Analyzing...</div>
          {/if}
        </div>
      {/if}
    </div>
  {/each}
</div>

<style>
  .result-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .empty {
    text-align: center;
    color: #888;
    padding: 24px;
    font-size: 14px;
  }

  .result-item {
    border: 1px solid #ddd;
    border-radius: 8px;
    overflow: hidden;
  }


  .result-header {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 12px;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 14px;
    text-align: left;
    color: inherit;
    box-shadow: none;
    border-radius: 0;
  }

  .result-header:hover {
    background: rgba(0, 0, 0, 0.03);
  }

  .status-icon {
    font-weight: 700;
    font-size: 12px;
    min-width: 24px;
    text-align: center;
  }

  .status-suspicious, .status-error {
    color: #e74c3c;
  }

  .status-safe {
    color: #27ae60;
  }

  .status-analyzing {
    color: #3498db;
  }

  .filename {
    flex: 1;
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .category-label {
    font-size: 12px;
    font-weight: 500;
  }

  .error-short {
    font-size: 12px;
    color: #e74c3c;
  }

  .expand-arrow {
    color: #888;
    font-size: 12px;
    min-width: 16px;
    text-align: center;
  }

  .spinner {
    width: 16px;
    height: 16px;
    border: 2px solid #ddd;
    border-top-color: #3498db;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .result-body {
    padding: 0 12px 12px;
    border-top: 1px solid #eee;
  }

  .error-detail {
    color: #e74c3c;
    font-size: 13px;
    padding: 8px 0;
    white-space: pre-wrap;
  }

  .analyzing-msg {
    color: #3498db;
    font-size: 13px;
    padding: 8px 0;
  }

  @media (prefers-color-scheme: dark) {
    .result-item { border-color: #444; }
    .result-header:hover { background: rgba(255, 255, 255, 0.05); }
    .result-body { border-top-color: #444; }
    .status-safe { color: #2ecc71; }
    .spinner { border-color: #555; border-top-color: #3498db; }
  }
</style>
