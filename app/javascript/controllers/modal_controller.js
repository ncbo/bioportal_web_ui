import { Controller } from '@hotwired/stimulus';
import { Modal } from 'bootstrap';

// Manages the lifecycle of a Bootstrap modal rendered into the "modal" Turbo
// Frame (see layouts/_header). The modal shows itself as soon as it connects,
// and empties the frame after it closes so the trigger link works repeatedly.
//
// Connects to data-controller="modal"
export default class extends Controller {
  connect() {
    this.modal = Modal.getOrCreateInstance(this.element);
    this.boundTeardown = this.teardown.bind(this);
    this.element.addEventListener('hidden.bs.modal', this.boundTeardown);
    this.modal.show();
  }

  disconnect() {
    this.element.removeEventListener('hidden.bs.modal', this.boundTeardown);
    this.modal.dispose();
  }

  // Close the modal when a form inside it submits successfully
  // (data-action="turbo:submit-end->modal#submitEnd").
  submitEnd(event) {
    if (event.detail.success) {
      this.modal.hide();
    }
  }

  teardown() {
    const frame = this.element.closest('turbo-frame');
    this.element.remove();
    if (frame) {
      frame.removeAttribute('src');
    }
  }
}
