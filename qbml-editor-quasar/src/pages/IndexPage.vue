<template>
  <q-page class="editor-page">
    <div class="editor-container">
      <MonacoJsonEditor
        v-model="queryData"
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
        </template>
      </MonacoJsonEditor>
    </div>
  </q-page>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { useQuasar } from "quasar";
import MonacoJsonEditor from "src/components/MonacoJsonEditor.vue";
import { useJsonSchema } from "src/composables/useJsonSchema";
import { schemaReady } from "src/boot/monaco";

const $q = useQuasar();

const { getEditorProps } = useJsonSchema();
const qbmlEditorProps = ref( {} );

// Wait for schema to be loaded before getting editor props
onMounted( async () => {
  await schemaReady;
  qbmlEditorProps.value = getEditorProps( "qbml" );
  console.log( "[IndexPage] Editor props loaded:", qbmlEditorProps.value );
} );

const fileInput = ref( null );

// Sample QBML query
const queryData = ref( [
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
] );

const onValidation = ( result ) => {
  if ( !result.valid && result.errors.length > 0 ) {
    console.log( "Validation errors:", result.errors );
  }
};

const copyToClipboard = async () => {
  try {
    const json = JSON.stringify( queryData.value, null, 2 );
    await navigator.clipboard.writeText( json );
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
  const json = JSON.stringify( queryData.value, null, 2 );
  const blob = new Blob( [ json ], { type: "application/json" } );
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
      const content = JSON.parse( e.target.result );
      queryData.value = content;
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
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 16px;
  min-height: 0;
}
</style>
