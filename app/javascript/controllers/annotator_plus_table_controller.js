import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-dt';

// Connects to data-controller="annotator-plus-table" on the static #annotations_container.
// Exposes the DataTables API instance as `window.annotationsTable` for the legacy
// annotator code (app/assets/javascripts/bp_annotatorplus.js), which drives filtering,
// column visibility, and row updates.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    window.annotationsTable = new DataTable(table, {
      paging: false,
      autoWidth: false,
      order: [],
      // Suppress DataTables' built-in chrome (global search box, info line, etc.).
      // The annotator has its own per-column filter popups and #result_counts;
      // searching stays enabled so those column filters keep working.
      layout: {
        topStart: null,
        topEnd: null,
        bottomStart: null,
        bottomEnd: null,
      },
      language: { zeroRecords: 'No annotations found' },
      columns: [
        { width: '15%' }, // Class
        { width: '15%' }, // Ontology
        { width: '5%' }, // Type
        { width: '5%', visible: false }, // Semantic types (hidden by default)
        { width: '20%' }, // Context
        { width: '15%' }, // Matched class
        { width: '15%' }, // Matched ontology
        { width: '5%', visible: false }, // Score
        { width: '5%', visible: false }, // Negation
        { width: '5%', visible: false }, // Experiencer
        { width: '5%', visible: false }, // Temporality
      ],
    });
  }
}
