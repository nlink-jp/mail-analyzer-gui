<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import type { Settings, EnvTemplate } from "$lib/types";

  let {
    visible,
    onClose,
  }: {
    visible: boolean;
    onClose: () => void;
  } = $props();

  let binaryPath = $state("");
  let envEntries = $state<{ key: string; value: string }[]>([]);
  let saving = $state(false);
  let message = $state("");

  const templates: EnvTemplate[] = [
    {
      name: "mail-analyzer (Vertex AI)",
      vars: [
        { key: "MAIL_ANALYZER_PROJECT", placeholder: "GCP Project ID" },
        { key: "MAIL_ANALYZER_LOCATION", placeholder: "us-central1" },
        { key: "MAIL_ANALYZER_MODEL", placeholder: "gemini-2.5-flash" },
        { key: "MAIL_ANALYZER_LANG", placeholder: "(optional)" },
      ],
    },
    {
      name: "mail-analyzer-local (Local LLM)",
      vars: [
        { key: "MAIL_ANALYZER_LOCAL_ENDPOINT", placeholder: "http://localhost:1234/v1" },
        { key: "MAIL_ANALYZER_LOCAL_MODEL", placeholder: "google/gemma-4-26b-a4b" },
        { key: "MAIL_ANALYZER_LOCAL_API_KEY", placeholder: "(optional)" },
        { key: "MAIL_ANALYZER_LOCAL_LANG", placeholder: "(optional)" },
      ],
    },
  ];

  $effect(() => {
    if (visible) {
      loadSettings();
    }
  });

  async function loadSettings() {
    try {
      const s: Settings = await invoke("get_settings");
      binaryPath = s.binary_path;
      envEntries = Object.entries(s.env_vars).map(([key, value]) => ({ key, value }));
      if (envEntries.length === 0) {
        envEntries = [{ key: "", value: "" }];
      }
      message = "";
    } catch (e) {
      message = `Failed to load settings: ${e}`;
    }
  }

  function applyTemplate(tmpl: EnvTemplate) {
    // Preserve existing values for matching keys.
    const existing = new Map(envEntries.map((e) => [e.key, e.value]));
    envEntries = tmpl.vars.map((v) => ({
      key: v.key,
      value: existing.get(v.key) || "",
    }));
  }

  function addEntry() {
    envEntries = [...envEntries, { key: "", value: "" }];
  }

  function removeEntry(idx: number) {
    envEntries = envEntries.filter((_, i) => i !== idx);
  }

  function placeholderFor(key: string): string {
    for (const tmpl of templates) {
      for (const v of tmpl.vars) {
        if (v.key === key) return v.placeholder;
      }
    }
    return "";
  }

  async function saveSettings() {
    saving = true;
    message = "";
    try {
      const env_vars: Record<string, string> = {};
      for (const e of envEntries) {
        if (e.key.trim()) {
          env_vars[e.key.trim()] = e.value;
        }
      }
      const settings: Settings = { binary_path: binaryPath, env_vars };
      await invoke("save_settings", { settings });
      message = "Settings saved.";
      setTimeout(() => onClose(), 600);
    } catch (e) {
      message = `Failed to save: ${e}`;
    } finally {
      saving = false;
    }
  }
</script>

{#if visible}
  <div class="overlay" role="dialog" aria-modal="true">
    <div class="dialog">
      <h2>Settings</h2>

      <div class="field">
        <label for="binary-path">Analyzer binary path</label>
        <input id="binary-path" type="text" bind:value={binaryPath} placeholder="/usr/local/bin/mail-analyzer" />
      </div>

      <h3>Environment Variables</h3>

      <div class="templates">
        {#each templates as tmpl}
          <button class="template-btn" onclick={() => applyTemplate(tmpl)}>{tmpl.name}</button>
        {/each}
      </div>

      <div class="env-list">
        {#each envEntries as entry, idx}
          <div class="env-row">
            <input
              class="env-key"
              type="text"
              bind:value={entry.key}
              placeholder="KEY"
            />
            <input
              class="env-value"
              type="text"
              bind:value={entry.value}
              placeholder={placeholderFor(entry.key)}
            />
            <button class="env-remove" onclick={() => removeEntry(idx)}>x</button>
          </div>
        {/each}
        <button class="add-btn" onclick={addEntry}>+ Add variable</button>
      </div>

      {#if message}
        <p class="message">{message}</p>
      {/if}

      <div class="actions">
        <button class="btn-secondary" onclick={onClose}>Cancel</button>
        <button class="btn-primary" onclick={saveSettings} disabled={saving}>
          {saving ? "Saving..." : "Save"}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }

  .dialog {
    background: #fff;
    border-radius: 12px;
    padding: 24px;
    width: 540px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  }

  h2 {
    margin: 0 0 16px;
    font-size: 18px;
  }

  h3 {
    margin: 16px 0 8px;
    font-size: 14px;
    color: #666;
  }

  .field {
    margin-bottom: 12px;
  }

  .field label {
    display: block;
    font-size: 12px;
    font-weight: 500;
    margin-bottom: 4px;
    color: #555;
  }

  .field input {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 14px;
    box-sizing: border-box;
    background: #fff;
    color: #333;
    box-shadow: none;
  }

  .templates {
    display: flex;
    gap: 6px;
    margin-bottom: 10px;
    flex-wrap: wrap;
  }

  .template-btn {
    padding: 4px 10px;
    border: 1px solid #4a9eff;
    border-radius: 4px;
    background: none;
    color: #4a9eff;
    font-size: 12px;
    cursor: pointer;
    box-shadow: none;
  }

  .template-btn:hover {
    background: rgba(74, 158, 255, 0.08);
  }

  .env-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .env-row {
    display: flex;
    gap: 6px;
    align-items: center;
  }

  .env-key {
    width: 45%;
    padding: 6px 8px;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 13px;
    font-family: monospace;
    box-sizing: border-box;
    background: #fff;
    color: #333;
    box-shadow: none;
  }

  .env-value {
    flex: 1;
    padding: 6px 8px;
    border: 1px solid #ddd;
    border-radius: 6px;
    font-size: 13px;
    box-sizing: border-box;
    background: #fff;
    color: #333;
    box-shadow: none;
  }

  .env-remove {
    padding: 0;
    width: 24px;
    height: 24px;
    border: none;
    background: none;
    color: #999;
    cursor: pointer;
    font-size: 14px;
    border-radius: 4px;
    box-shadow: none;
    flex-shrink: 0;
  }

  .env-remove:hover {
    background: rgba(231, 76, 60, 0.1);
    color: #e74c3c;
  }

  .add-btn {
    background: none;
    border: 1px dashed #ccc;
    border-radius: 6px;
    padding: 6px;
    font-size: 12px;
    color: #888;
    cursor: pointer;
    box-shadow: none;
  }

  .add-btn:hover {
    border-color: #999;
    color: #555;
  }

  .message {
    font-size: 13px;
    color: #888;
    margin: 8px 0;
  }

  .actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 16px;
  }

  .btn-primary, .btn-secondary {
    padding: 8px 16px;
    border-radius: 6px;
    font-size: 14px;
    cursor: pointer;
    border: 1px solid transparent;
    box-shadow: none;
  }

  .btn-primary {
    background: #4a9eff;
    color: white;
  }

  .btn-primary:hover { background: #3a8eef; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .btn-secondary {
    background: #eee;
    color: #333;
  }

  .btn-secondary:hover { background: #ddd; }

  @media (prefers-color-scheme: dark) {
    .dialog { background: #2a2a2a; }
    h3 { color: #aaa; }
    .field label { color: #aaa; }
    .field input { background: #333; color: #eee; border-color: #555; }
    .env-key, .env-value { background: #333; color: #eee; border-color: #555; }
    .btn-secondary { background: #444; color: #eee; }
    .btn-secondary:hover { background: #555; }
    .template-btn { border-color: #5a8edd; color: #5a8edd; }
    .template-btn:hover { background: rgba(90, 142, 221, 0.15); }
    .add-btn { border-color: #555; color: #888; }
  }
</style>
