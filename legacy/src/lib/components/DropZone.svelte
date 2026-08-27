<script lang="ts">
  let { onFilesDropped }: { onFilesDropped: (paths: string[]) => void } = $props();
  let dragOver = $state(false);

  function handleDragOver(e: DragEvent) {
    e.preventDefault();
    dragOver = true;
  }

  function handleDragLeave() {
    dragOver = false;
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault();
    dragOver = false;
    // File paths from Tauri's drag-drop come through the onDrop event handler
    // registered at the app level. Browser drop events don't carry native paths.
    // This handler just manages the visual state.
  }
</script>

<div
  class="dropzone"
  class:dragover={dragOver}
  role="button"
  tabindex="0"
  ondragover={handleDragOver}
  ondragleave={handleDragLeave}
  ondrop={handleDrop}
>
  <div class="dropzone-content">
    <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="17 8 12 3 7 8" />
      <line x1="12" y1="3" x2="12" y2="15" />
    </svg>
    <p>.eml / .msg files here</p>
  </div>
</div>

<style>
  .dropzone {
    border: 2px dashed #666;
    border-radius: 12px;
    padding: 24px;
    text-align: center;
    transition: all 0.2s;
    cursor: pointer;
    min-height: 120px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .dropzone.dragover {
    border-color: #4a9eff;
    background-color: rgba(74, 158, 255, 0.08);
  }

  .dropzone-content {
    color: #888;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
  }

  .dropzone-content p {
    margin: 0;
    font-size: 14px;
  }
</style>
