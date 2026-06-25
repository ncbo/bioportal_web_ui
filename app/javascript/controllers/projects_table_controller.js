import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-dt';
import 'datatables.net-fixedheader-dt';

// Connects to data-controller="projects-table" on the static wrapper around #projects.
// data-controller sits on the wrapper (not the <table>) because DataTables wraps the
// table in its own <div>, which would otherwise re-trigger Stimulus connect/disconnect.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    // The app's top navbar is `position: fixed`, so the floating header must be
    // offset below it — otherwise FixedHeader pins the clone at top:0, hidden
    // behind the navbar. Measure the navbar instead of hardcoding its height.
    const navbar = document.querySelector('nav.navbar.fixed-top');
    const headerOffset = navbar ? navbar.offsetHeight : 0;

    new DataTable(table, {
      autoWidth: false,
      lengthChange: false,
      searching: false,
      info: false,
      paging: false,
      fixedHeader: { header: true, headerOffset },
    });
    // Restore full width after DataTables adjusts the table layout.
    table.style.width = '100%';
  }
}
