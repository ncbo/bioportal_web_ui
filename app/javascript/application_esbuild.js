// Entry point for the build script in your package.json

import { Turbo } from '@hotwired/turbo-rails';
import DataTable from 'datatables.net-bs5';
import 'datatables.net-columncontrol-bs5';
import './controllers';
import './component_controllers';
import * as bootstrap from 'bootstrap';

// Expose DataTables for legacy Sprockets scripts (bp_admin.js) that initialize
// tables outside the esbuild bundle.
window.DataTable = DataTable;

Turbo.session.drive = false;

Turbo.config.forms.confirm = (message) => {
  return new Promise((resolve) => {
    alertify.confirm(message, (e) => {
      resolve(e);
    });
  });
};
