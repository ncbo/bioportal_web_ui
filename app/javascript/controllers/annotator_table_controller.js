import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-bs5';
import { buildAnnotationsSummary } from '../utils/annotations_info';

// Connects to data-controller="annotator-table" on the static #annotations_container.
// Exposes the DataTables API instance as `window.annotationsTable` for the legacy
// annotator code (app/assets/javascripts/bp_annotator.js), which drives filtering,
// column visibility, and row updates.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    // Filterable columns get a ColumnControl dropdown (hamburger icon) holding a
    // searchList of the column's values. Cells contain HTML links, so the list
    // labels use the 'filter' orthogonal data (tags stripped) instead of the
    // default 'display'.
    const searchListDropdown = ['order', [{ extend: 'searchList', orthogonal: 'filter' }]];

    const annotationsTable = new DataTable(table, {
      paging: true,
      pageLength: 25,
      autoWidth: false,
      order: [],
      // Ordering is handled by the ColumnControl 'order' buttons, so DataTables'
      // own header click handler and sort indicators are turned off.
      ordering: { indicators: false, handler: false },
      columnControl: ['order'],
      // A custom grand-total summary lives in the top-start `div` feature
      // (replacing the old #result_counts div); it's populated on each draw
      // below. The default per-page "Showing X to Y of Z" info sits bottom-start
      // (kept as the sole `info` feature so it retains the aria-live/status
      // semantics). Page-length selector sits top-end, pagination bottom-end. The
      // global search box stays off — the ColumnControl column filters cover
      // per-column searching.
      layout: {
        topStart: { div: { id: 'annotations_summary', className: 'text-muted' } },
        topEnd: 'pageLength',
        bottomStart: 'info',
        bottomEnd: 'paging',
      },
      language: { zeroRecords: 'No annotations found' },
      columns: [
        { width: '15%', columnControl: searchListDropdown },
        { width: '15%', columnControl: searchListDropdown },
        { width: '5%', columnControl: searchListDropdown },
        { width: '5%', visible: false },
        { width: '30%' },
        { width: '15%', columnControl: searchListDropdown },
        { width: '15%', columnControl: searchListDropdown },
      ],
    });

    // The top-start `div` feature is static, so populate it ourselves. "Total
    // results" is a grand total (ignores column filters), so recomputing on each
    // draw is cheap and keeps it correct after row and column-visibility changes.
    annotationsTable.on('draw', () => {
      const summaryEl = this.element.querySelector('#annotations_summary');
      if (summaryEl) {
        summaryEl.textContent = buildAnnotationsSummary(annotationsTable);
      }
    });

    window.annotationsTable = annotationsTable;
  }
}
