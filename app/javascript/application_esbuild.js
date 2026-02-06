// Entry point for the build script in your package.json

import { Turbo } from '@hotwired/turbo-rails';
import './controllers';
import './component_controllers';
import * as bootstrap from 'bootstrap';

Turbo.session.drive = false;

Turbo.config.forms.confirm = (message) => {
  return new Promise((resolve) => {
    alertify.confirm(message, (e) => {
      resolve(e);
    });
  });
};
