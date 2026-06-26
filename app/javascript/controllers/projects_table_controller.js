import { Controller } from '@hotwired/stimulus';
import DataTable from 'datatables.net-bs5';

// Connects to data-controller="projects-table" on the static wrapper around #projects.
// data-controller sits on the wrapper (not the <table>) because DataTables wraps the
// table in its own <div>, which would otherwise re-trigger Stimulus connect/disconnect.
export default class extends Controller {
  static targets = ['table'];

  tableTargetConnected(table) {
    new DataTable(table, {
      autoWidth: false,
      lengthChange: false,
      searching: false,
      info: false,
      paging: false,
    });
    // Restore full width after DataTables adjusts the table layout.
    table.style.width = '100%';

    // Sticky header (replaces the DataTables FixedHeader plugin). The app's top
    // navbar is `position: fixed`, so the sticky header must sit just below it.
    // Measure the navbar and expose its height as the sticky offset; the actual
    // `position: sticky` styling lives in projects.scss.
    const navbar = document.querySelector('nav.navbar.fixed-top');
    const headerOffset = navbar ? navbar.offsetHeight : 0;
    table.style.setProperty('--bp-sticky-top', `${headerOffset}px`);
  }
}
