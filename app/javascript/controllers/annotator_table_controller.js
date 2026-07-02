import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-bs5';

// Connects to data-controller="annotator-table" on the static #annotations_container.
// Exposes the DataTables API instance as `window.annotationsTable` for the legacy
// annotator code (app/assets/javascripts/bp_annotator.js), which drives filtering,
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
        { width: '15%' },
        { width: '15%' },
        { width: '5%' },
        { width: '5%', visible: false },
        { width: '30%' },
        { width: '15%' },
        { width: '15%' },
      ],
    });
  }
}
