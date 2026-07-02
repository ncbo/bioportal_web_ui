import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-bs5';

// Connects to data-controller="annotator-plus-table" on the static #annotations_container.
// Exposes the DataTables API instance as `window.annotationsTable` for the legacy
// annotator code (app/assets/javascripts/bp_annotatorplus.js), which drives filtering,
// column visibility, and row updates.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    // Filterable columns get a ColumnControl dropdown (hamburger icon) holding a
    // searchList of the column's values. Cells contain HTML links, so the list
    // labels use the 'filter' orthogonal data (tags stripped) instead of the
    // default 'display'.
    const searchListDropdown = ['order', [{ extend: 'searchList', orthogonal: 'filter' }]];

    window.annotationsTable = new DataTable(table, {
      paging: false,
      autoWidth: false,
      order: [],
      // Ordering is handled by the ColumnControl 'order' buttons, so DataTables'
      // own header click handler and sort indicators are turned off.
      ordering: { indicators: false, handler: false },
      columnControl: ['order'],
      // Suppress DataTables' built-in chrome (global search box, info line, etc.).
      // The annotator has its own #result_counts; searching stays enabled so the
      // ColumnControl column filters keep working.
      layout: {
        topStart: null,
        topEnd: null,
        bottomStart: null,
        bottomEnd: null,
      },
      language: { zeroRecords: 'No annotations found' },
      columns: [
        { width: '15%', columnControl: searchListDropdown }, // Class
        { width: '15%', columnControl: searchListDropdown }, // Ontology
        { width: '5%', columnControl: searchListDropdown }, // Type
        { width: '5%', visible: false }, // Semantic types (hidden by default)
        { width: '20%' }, // Context
        { width: '15%', columnControl: searchListDropdown }, // Matched class
        { width: '15%', columnControl: searchListDropdown }, // Matched ontology
        { width: '5%', visible: false }, // Score
        { width: '5%', visible: false }, // Negation
        { width: '5%', visible: false }, // Experiencer
        { width: '5%', visible: false }, // Temporality
      ],
    });
  }
}
