<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import { listen } from "@tauri-apps/api/event";
  import { getCurrentWebviewWindow } from "@tauri-apps/api/webviewWindow";
  import type { AnalysisEntry } from "$lib/types";
  import DropZone from "$lib/components/DropZone.svelte";
  import ResultList from "$lib/components/ResultList.svelte";
  import Settings from "$lib/components/Settings.svelte";

  let entries = $state<AnalysisEntry[]>([]);
  let showSettings = $state(false);
  let counter = 0;

  onMount(async () => {
    // Source 1: Tauri built-in DragDrop (Finder drops with file URLs).
    const currentWindow = getCurrentWebviewWindow();
    await currentWindow.onDragDropEvent((event) => {
      if (event.payload.type === "drop") {
        handleFiles(event.payload.paths);
      }
    });

    // Source 2: Native file-promise handler (Apple Mail drops).
    await listen<string[]>("files-dropped", (event) => {
      handleFiles(event.payload);
    });
  });

  function isValidExtension(path: string): boolean {
    const lower = path.toLowerCase();
    return lower.endsWith(".eml") || lower.endsWith(".msg");
  }

  function filenameFromPath(path: string): string {
    return path.split("/").pop() || path;
  }

  async function handleFiles(paths: string[]) {
    const validPaths = paths.filter(isValidExtension);
    if (validPaths.length === 0) return;

    const newEntries: AnalysisEntry[] = validPaths.map((p) => ({
      id: `${++counter}`,
      filename: filenameFromPath(p),
      status: "pending" as const,
    }));

    entries = [...newEntries, ...entries];

    for (let idx = 0; idx < newEntries.length; idx++) {
      const entry = newEntries[idx];
      const path = validPaths[idx];

      entry.status = "analyzing";
      entries = entries.map((e) => (e.id === entry.id ? { ...entry } : e));

      try {
        const result = await invoke("analyze_file", { path });
        entry.result = result as AnalysisEntry["result"];
        entry.status = "done";
      } catch (e) {
        entry.error = String(e);
        entry.status = "error";
      }
      entries = entries.map((e) => (e.id === entry.id ? { ...entry } : e));
    }
  }

  async function handleExport() {
    const doneEntries = entries.filter((e) => e.result);
    if (doneEntries.length === 0) return;
    const results = doneEntries.map((e) => e.result!);
    try {
      const json: string = await invoke("export_json", { results });
      await navigator.clipboard.writeText(json);
      alert("JSON copied to clipboard.");
    } catch (e) {
      alert(`Export failed: ${e}`);
    }
  }
</script>

<main class="app">
  <div class="toolbar">
    <h1 class="app-title">mail-analyzer-gui</h1>
    <div class="toolbar-actions">
      {#if entries.length > 0}
        <button class="toolbar-btn" onclick={() => { entries = entries.filter((e) => e.status === "analyzing"); }}>Clear</button>
      {/if}
      {#if entries.some((e) => e.result)}
        <button class="toolbar-btn" onclick={handleExport}>Export JSON</button>
      {/if}
      <button class="toolbar-btn" onclick={() => (showSettings = true)}>Settings</button>
    </div>
  </div>

  <DropZone onFilesDropped={handleFiles} />

  <div class="results-area">
    <ResultList {entries} />
  </div>

  <Settings visible={showSettings} onClose={() => (showSettings = false)} />
</main>

<style>
  :global(body) {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 14px;
    color: #1a1a1a;
    background: #fafafa;
  }

  .app {
    display: flex;
    flex-direction: column;
    height: 100vh;
    padding: 16px;
    box-sizing: border-box;
    gap: 12px;
  }

  .toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .app-title {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
  }

  .toolbar-actions {
    display: flex;
    gap: 8px;
  }

  .toolbar-btn {
    background: none;
    border: 1px solid #ccc;
    border-radius: 6px;
    padding: 6px 12px;
    font-size: 13px;
    cursor: pointer;
    color: inherit;
    box-shadow: none;
  }

  .toolbar-btn:hover {
    border-color: #999;
    background: rgba(0, 0, 0, 0.03);
  }

  .results-area {
    flex: 1;
    overflow-y: auto;
  }

  @media (prefers-color-scheme: dark) {
    :global(body) {
      color: #e8e8e8;
      background: #1a1a1a;
    }
    .toolbar-btn { border-color: #555; }
    .toolbar-btn:hover { border-color: #888; background: rgba(255, 255, 255, 0.05); }
  }
</style>
