import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-bs5';

// Connects to data-controller="mapping-count-table" on the static #mappingCount container.
// The <table> arrives dynamically (jQuery `.load()`); `tableTargetConnected` fires when it appears.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    new DataTable(table, {
      paging: false,
      info: false,
      searching: false,
      columns: [
        { className: 'text-left' },
        { type: 'num-fmt', orderSequence: ['desc', 'asc'], className: 'text-right' },
      ],
    });
  }
}
