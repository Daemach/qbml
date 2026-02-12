/**
 * Monaco Editor Boot File for Quasar
 *
 * Configures Monaco editor workers for proper operation in Vite/Quasar
 * and initializes the QBML schema for the JSON editor.
 */

import * as monaco from "monaco-editor";
import editorWorker from "monaco-editor/esm/vs/editor/editor.worker?worker";
import jsonWorker from "monaco-editor/esm/vs/language/json/json.worker?worker";
import { initQBMLSchema, qbmlSnippets, registerSchema } from "src/composables/useJsonSchema";

// Configure Monaco environment to use web workers
self.MonacoEnvironment = {
  getWorker( _, label ) {
    if ( label === "json" ) {
      return new jsonWorker();
    }
    return new editorWorker();
  },
};

// Fetch and initialize QBML schema from public folder
console.log( "[monaco boot] Fetching QBML schema from /qbml.schema.json" );
const schemaReady = fetch( "/qbml.schema.json" )
  .then( response => {
    console.log( "[monaco boot] Fetch response:", response.status, response.ok );
    if ( !response.ok ) {
      throw new Error( `HTTP ${response.status}: ${response.statusText}` );
    }
    return response.json();
  } )
  .then( qbmlSchema => {
    console.log( "[monaco boot] Schema parsed, keys:", Object.keys( qbmlSchema ) );
    initQBMLSchema( qbmlSchema );
    console.log( "[monaco boot] QBML schema loaded successfully" );
    return qbmlSchema;
  } )
  .catch( err => {
    console.error( "[monaco boot] Failed to load QBML schema:", err );
    // Register schema with just snippets if fetch fails
    registerSchema( "qbml", {
      schema: null,
      name: "QBML",
      uri: "https://qbml.ortusbooks.com/schemas/qbml.schema.json",
      snippets: qbmlSnippets,
      description: "Query Builder Markup Language",
      docsUrl: "https://qb.ortusbooks.com/",
    } );
    return null;
  } );

// Expose for dev tools / testing
window.monaco = monaco;

export { monaco, schemaReady };
