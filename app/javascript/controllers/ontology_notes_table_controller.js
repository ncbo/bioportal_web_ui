import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-dt';

// Connects to data-controller="ontology-notes-table" on the notes table container
// (AJAX-loaded with the ontology Notes tab). Exposes the DataTables API instance as
// `window.ontNotesTable` for the legacy notes code (app/assets/javascripts/bp_notes.js),
// which adds rows for new notes and toggles the archived filter.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    window.ontNotesTable = new DataTable(table, {
      pageLength: 50,
      pagingType: 'full_numbers',
      order: [[7, 'desc']], // Created
      columns: [
        { visible: false }, // Delete
        { orderData: 2 }, // Subject link, sorted via the hidden subject column
        { visible: false }, // Subject for sort
        { visible: false }, // Archived for filter
        null, // Author
        null, // Type
        null, // Class
        null, // Created
      ],
    });
    // Important! Table is somehow getting set to zero width. Reset here.
    table.style.width = '100%';
    // Hide archived notes by default (the "Hide Archived" checkbox starts checked).
    window.ontNotesTable.column(3).search('false').draw();
  }
}
