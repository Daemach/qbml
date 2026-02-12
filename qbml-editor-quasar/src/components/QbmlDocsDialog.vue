<template>
  <q-dialog
    :model-value="modelValue"
    position="right"
    @update:model-value="onDialogUpdate"
  >
    <q-card
      class="column no-wrap qbml-docs"
      :style="cardStyle"
    >
      <!-- Header / drag handle -->
      <q-card-section
        class="row items-center q-pb-sm docs-drag-handle"
        @mousedown="startDrag"
      >
        <q-icon name="drag_indicator" size="xs" class="q-mr-xs text-grey" />
        <div class="text-h6">QBML Documentation</div>
        <q-space />
        <q-badge v-if="latestVersion" color="primary" class="q-mr-sm">
          v{{ latestVersion }}
        </q-badge>
        <q-btn
          flat
          round
          dense
          icon="open_in_new"
          :href="githubUrl"
          target="_blank"
          title="Open on GitHub"
          type="a"
        />
        <q-btn flat round dense icon="close" v-close-popup />
      </q-card-section>

      <!-- Version mismatch banner -->
      <q-banner v-if="versionMismatch" class="bg-warning text-dark q-mx-md q-mb-sm" rounded>
        Local version {{ localVersion }} differs from latest {{ latestVersion }}.
        <template #action>
          <q-btn
            flat
            dense
            label="View Releases"
            :href="releasesUrl"
            target="_blank"
            type="a"
          />
        </template>
      </q-banner>

      <!-- Content -->
      <q-card-section class="col q-pt-none" style="overflow-y: auto">
        <div v-if="loading" class="column items-center q-pa-xl">
          <q-spinner size="48px" color="primary" />
          <div class="q-mt-md text-grey">Loading documentation...</div>
        </div>
        <q-banner v-else-if="error" class="bg-negative text-white" rounded>
          {{ error }}
        </q-banner>
        <q-markdown v-else :src="readmeContent" no-line-numbers />
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, computed, watch, onUnmounted } from "vue";
import { QMarkdown } from "@quasar/quasar-ui-qmarkdown";
import "@quasar/quasar-ui-qmarkdown/dist/index.css";

const props = defineProps( {
  modelValue: { type: Boolean, default: false },
  githubRepo: { type: String, default: "" },
  localVersion: { type: String, default: "" },
} );

const emit = defineEmits( [ "update:modelValue" ] );

const readmeContent = ref( "" );
const latestVersion = ref( "" );
const loading = ref( false );
const error = ref( "" );
let fetched = false;

// Drag state
const dragOffset = ref( { x: 0, y: 0 } );
let isDragging = false;
let dragStart = { x: 0, y: 0 };
let offsetStart = { x: 0, y: 0 };

const cardStyle = computed( () => ( {
  width: "50vw",
  minWidth: "420px",
  maxWidth: "90vw",
  height: "100vh",
  transform: `translate(${dragOffset.value.x}px, ${dragOffset.value.y}px)`,
  transition: isDragging ? "none" : "transform 0.15s ease",
} ) );

function startDrag( e ) {
  // Don't drag when clicking interactive elements
  if ( e.target.closest( "button, a, .q-btn, .q-badge" ) ) return;

  isDragging = true;
  dragStart = { x: e.clientX, y: e.clientY };
  offsetStart = { x: dragOffset.value.x, y: dragOffset.value.y };

  document.addEventListener( "mousemove", onDrag );
  document.addEventListener( "mouseup", stopDrag );
  e.preventDefault();
}

function onDrag( e ) {
  if ( !isDragging ) return;
  dragOffset.value = {
    x: offsetStart.x + ( e.clientX - dragStart.x ),
    y: offsetStart.y + ( e.clientY - dragStart.y ),
  };
}

function stopDrag() {
  isDragging = false;
  document.removeEventListener( "mousemove", onDrag );
  document.removeEventListener( "mouseup", stopDrag );
}

function onDialogUpdate( val ) {
  if ( !val ) {
    // Reset drag position on close
    dragOffset.value = { x: 0, y: 0 };
  }
  emit( "update:modelValue", val );
}

onUnmounted( () => {
  document.removeEventListener( "mousemove", onDrag );
  document.removeEventListener( "mouseup", stopDrag );
} );

const githubUrl = computed( () =>
  props.githubRepo ? `https://github.com/${props.githubRepo}` : "",
);

const releasesUrl = computed( () =>
  props.githubRepo ? `https://github.com/${props.githubRepo}/releases` : "",
);

const versionMismatch = computed( () =>
  props.localVersion && latestVersion.value && props.localVersion !== latestVersion.value,
);

async function fetchDocs() {
  if ( fetched || !props.githubRepo ) return;

  loading.value = true;
  error.value = "";

  try {
    const [ readmeResult, versionResult ] = await Promise.allSettled( [
      fetch( `https://api.github.com/repos/${props.githubRepo}/readme`, {
        headers: { Accept: "application/vnd.github.raw" },
      } ),
      fetch( `https://api.github.com/repos/${props.githubRepo}/contents/box.json`, {
        headers: { Accept: "application/vnd.github.raw" },
      } ),
    ] );

    // Process README
    if ( readmeResult.status === "fulfilled" && readmeResult.value.ok ) {
      let md = await readmeResult.value.text();
      // Strip broken HTML image tags (ortussolutions.com serves SVGs as text/html + nosniff)
      md = md.replace( /<a[^>]*>\s*<img[^>]*>\s*<\/a>/gi, "" );
      readmeContent.value = md;
    } else {
      const status = readmeResult.status === "fulfilled"
        ? readmeResult.value.status
        : "network error";
      error.value = `Failed to load README (${status}). Check your network connection.`;
      return;
    }

    // Process version from box.json
    if ( versionResult.status === "fulfilled" && versionResult.value.ok ) {
      try {
        const boxJson = JSON.parse( await versionResult.value.text() );
        latestVersion.value = boxJson.version || "";
      } catch {
        // Non-critical — version check is optional
      }
    }

    fetched = true;
  } catch ( e ) {
    error.value = `Failed to fetch documentation: ${e.message}`;
  } finally {
    loading.value = false;
  }
}

// Fetch when dialog opens
watch( () => props.modelValue, ( open ) => {
  if ( open ) fetchDocs();
} );
</script>

<style scoped>
.docs-drag-handle {
  cursor: grab;
  user-select: none;
}

.docs-drag-handle:active {
  cursor: grabbing;
}

.qbml-docs :deep(.q-markdown) {
  font-size: 14px;
  line-height: 1.6;
}

.qbml-docs :deep(.q-markdown code) {
  background: rgba( 0, 0, 0, 0.06 );
  padding: 2px 6px;
  border-radius: 3px;
}

.qbml-docs :deep(.q-markdown pre) {
  background: #f6f8fa;
  padding: 12px;
  border-radius: 6px;
  overflow-x: auto;
}

.qbml-docs :deep(.q-markdown pre code) {
  background: transparent;
  padding: 0;
}

.qbml-docs :deep(.q-markdown img) {
  max-width: 200px;
}

.qbml-docs :deep(.q-markdown table) {
  border-collapse: collapse;
  width: 100%;
  margin: 12px 0;
}

.qbml-docs :deep(.q-markdown th),
.qbml-docs :deep(.q-markdown td) {
  border: 1px solid rgba( 0, 0, 0, 0.12 );
  padding: 8px 12px;
  text-align: left;
}

.qbml-docs :deep(.q-markdown th) {
  background: rgba( 0, 0, 0, 0.04 );
  font-weight: 600;
}

.qbml-docs :deep(.q-markdown blockquote) {
  border-left: 3px solid rgba( 0, 0, 0, 0.2 );
  margin: 12px 0;
  padding: 8px 16px;
  color: rgba( 0, 0, 0, 0.6 );
}

.qbml-docs :deep(.q-markdown h1) {
  border-bottom: 1px solid rgba( 0, 0, 0, 0.12 );
  padding-bottom: 8px;
}

.qbml-docs :deep(.q-markdown h2) {
  border-bottom: 1px solid rgba( 0, 0, 0, 0.08 );
  padding-bottom: 6px;
  margin-top: 24px;
}
</style>

<!-- Dark mode overrides — unscoped because q-dialog portals to body -->
<style>
.body--dark .qbml-docs .q-markdown code {
  background: rgba( 255, 255, 255, 0.1 );
}

.body--dark .qbml-docs .q-markdown pre {
  background: #1a1a2e;
}

.body--dark .qbml-docs .q-markdown th,
.body--dark .qbml-docs .q-markdown td {
  border-color: rgba( 255, 255, 255, 0.15 );
}

.body--dark .qbml-docs .q-markdown th {
  background: rgba( 255, 255, 255, 0.05 );
}

.body--dark .qbml-docs .q-markdown blockquote {
  border-left-color: rgba( 255, 255, 255, 0.3 );
  color: rgba( 255, 255, 255, 0.7 );
}

.body--dark .qbml-docs .q-markdown h1 {
  border-bottom-color: rgba( 255, 255, 255, 0.15 );
}

.body--dark .qbml-docs .q-markdown h2 {
  border-bottom-color: rgba( 255, 255, 255, 0.1 );
}
</style>
