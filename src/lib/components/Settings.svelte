<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import type { Settings } from "$lib/types";

  let {
    visible,
    onClose,
  }: {
    visible: boolean;
    onClose: () => void;
  } = $props();

  let binaryPath = $state("");
  let project = $state("");
  let location = $state("");
  let model = $state("");
  let lang = $state("");
  let saving = $state(false);
  let message = $state("");

  $effect(() => {
    if (visible) {
      loadSettings();
    }
  });

  async function loadSettings() {
    try {
      const s: Settings = await invoke("get_settings");
      binaryPath = s.binary_path;
      project = s.env_vars.project;
      location = s.env_vars.location;
      model = s.env_vars.model;
      lang = s.env_vars.lang;
      message = "";
    } catch (e) {
      message = `Failed to load settings: ${e}`;
    }
  }

  async function saveSettings() {
    saving = true;
    message = "";
    try {
      const settings: Settings = {
        binary_path: binaryPath,
        env_vars: { project, location, model, lang },
      };
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
        <label for="binary-path">mail-analyzer binary path</label>
        <input id="binary-path" type="text" bind:value={binaryPath} placeholder="/usr/local/bin/mail-analyzer" />
      </div>

      <h3>Environment Variables</h3>

      <div class="field">
        <label for="env-project">MAIL_ANALYZER_PROJECT</label>
        <input id="env-project" type="text" bind:value={project} placeholder="GCP Project ID" />
      </div>

      <div class="field">
        <label for="env-location">MAIL_ANALYZER_LOCATION</label>
        <input id="env-location" type="text" bind:value={location} placeholder="us-central1" />
      </div>

      <div class="field">
        <label for="env-model">MAIL_ANALYZER_MODEL</label>
        <input id="env-model" type="text" bind:value={model} placeholder="gemini-2.5-flash" />
      </div>

      <div class="field">
        <label for="env-lang">MAIL_ANALYZER_LANG</label>
        <input id="env-lang" type="text" bind:value={lang} placeholder="(optional)" />
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
    width: 480px;
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
    .btn-secondary { background: #444; color: #eee; }
    .btn-secondary:hover { background: #555; }
  }
</style>
