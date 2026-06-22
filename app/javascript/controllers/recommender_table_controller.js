import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-dt';

// Connects to data-controller="recommender-table" on the static #recommender-results container.
// The <table> is built in JS from the /recommender JSON response and appended to the container;
// `tableTargetConnected` fires when it appears.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    new DataTable(table, {
      paging: false,
      info: false,
      searching: false,
      order: [[0, 'asc']],
      columnDefs: [
        { targets: [2, 3, 4, 5, 6, 7], orderSequence: ['desc', 'asc'] },
      ],
    });
  }
}
