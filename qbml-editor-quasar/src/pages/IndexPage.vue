<template>
  <q-page class="editor-page">
    <div ref="editorContainer" class="editor-container">
      <MonacoJsonEditor
        v-model="queryString"
        title="QBML Query Editor"
        :schema="qbmlEditorProps.schema"
        :schema-uri="qbmlEditorProps.schemaUri"
        :schema-name="qbmlEditorProps.schemaName"
        :snippets="qbmlEditorProps.snippets"
        @validation="onValidation"
      >
        <template #title-actions>
          <q-btn
            flat
            dense
            icon="content_copy"
            title="Copy to clipboard"
            @click="copyToClipboard"
          />
          <q-btn
            flat
            dense
            icon="file_download"
            title="Download JSON"
            @click="downloadJson"
          />
          <q-btn
            flat
            dense
            icon="file_upload"
            title="Load JSON file"
            @click="triggerFileUpload"
          />
          <input
            ref="fileInput"
            type="file"
            accept=".json"
            style="display: none"
            @change="loadFile"
          />
          <q-separator vertical class="q-mx-xs" />
          <q-btn
            flat
            dense
            icon="menu_book"
            title="QBML Documentation"
            @click="showDocs = true"
          />
        </template>
      </MonacoJsonEditor>
    </div>
    <QbmlDocsDialog
      v-model="showDocs"
      :github-repo="qbmlEditorProps.githubRepo"
      :local-version="qbmlEditorProps.version"
    />
  </q-page>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { useQuasar } from "quasar";
import stringify from "json-stringify-pretty-compact";
import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
import QbmlDocsDialog from "src/components/QbmlDocsDialog.vue";
import { useJsonSchema } from "src/composables/useJsonSchema";
import { schemaReady } from "src/boot/monaco";

const $q = useQuasar();

const { getEditorProps } = useJsonSchema();
const qbmlEditorProps = ref( {} );
const editorContainer = ref( null );
let resizeObserver = null;

// Track viewport height so editor bottom follows viewport bottom
// (handles browser dev tools open/close, window resize, etc.)
const updateContainerHeight = () => {
  const el = editorContainer.value;
  if ( !el ) return;
  const top = el.getBoundingClientRect().top;
  el.style.height = `${window.innerHeight - top}px`;
};

onMounted( async () => {
  // Viewport tracking via ResizeObserver on <html>
  resizeObserver = new ResizeObserver( updateContainerHeight );
  resizeObserver.observe( document.documentElement );
  updateContainerHeight();

  await schemaReady;
  qbmlEditorProps.value = getEditorProps( "qbml" );
} );

onUnmounted( () => {
  resizeObserver?.disconnect();
} );

const fileInput = ref( null );
const showDocs = ref( false );

// Sample QBML query (string for v-model)
const sampleQuery = [
  { "from": "users" },
  { "select": [ "id", "name", "email", "created_at" ] },
  {
    "when": { "param": "search", "notEmpty": true },
    "whereLike": [ "name", { "$param": "search" } ]
  },
  {
    "when": { "param": "status", "notEmpty": true },
    "where": [ "status", { "$param": "status" } ]
  },
  { "orderByDesc": "created_at" },
  { "paginate": { "page": 1, "maxRows": 25 } }
];
const queryString = ref( stringify( sampleQuery, { indent: 2, maxLength: 80 } ) );

const onValidation = ( result ) => {
  if ( !result.valid && result.errors.length > 0 ) {
    console.log( "Validation errors:", result.errors );
  }
};

const copyToClipboard = async () => {
  try {
    await navigator.clipboard.writeText( queryString.value );
    $q.notify( {
      type: "positive",
      message: "Copied to clipboard",
      timeout: 1500,
    } );
  } catch {
    $q.notify( {
      type: "negative",
      message: "Failed to copy",
      timeout: 1500,
    } );
  }
};

const downloadJson = () => {
  const blob = new Blob( [ queryString.value ], { type: "application/json" } );
  const url = URL.createObjectURL( blob );
  const a = document.createElement( "a" );
  a.href = url;
  a.download = "qbml-query.json";
  a.click();
  URL.revokeObjectURL( url );
  $q.notify( {
    type: "positive",
    message: "Downloaded qbml-query.json",
    timeout: 1500,
  } );
};

const triggerFileUpload = () => {
  fileInput.value?.click();
};

const loadFile = ( event ) => {
  const file = event.target.files[ 0 ];
  if ( !file ) return;

  const reader = new FileReader();
  reader.onload = ( e ) => {
    try {
      // Validate it's valid JSON, then pretty-print it
      const parsed = JSON.parse( e.target.result );
      queryString.value = stringify( parsed, { indent: 2, maxLength: 80 } );
      $q.notify( {
        type: "positive",
        message: `Loaded ${file.name}`,
        timeout: 1500,
      } );
    } catch {
      $q.notify( {
        type: "negative",
        message: "Invalid JSON file",
        timeout: 2000,
      } );
    }
  };
  reader.readAsText( file );
  event.target.value = "";
};
</script>

<style scoped>
.editor-page {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.editor-container {
  display: flex;
  flex-direction: column;
  padding: 16px;
  min-height: 0;
  overflow: hidden;
}
</style>
