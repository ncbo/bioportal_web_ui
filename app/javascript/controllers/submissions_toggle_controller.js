import { Controller } from '@hotwired/stimulus';

// The template marks only submissions beyond its initial limit as row targets.
export default class extends Controller {
  static targets = ['row', 'toggle'];

  connect() {
    this.update(this.rowTargets.length > 0 && this.rowTargets.every((row) => !row.classList.contains('hidden_ont')));
  }

  toggle(event) {
    event.preventDefault();
    this.update(this.rowTargets.some((row) => row.classList.contains('hidden_ont')));
  }

  update(expanded) {
    this.rowTargets.forEach((row) => row.classList.toggle('hidden_ont', !expanded));
    if (this.hasToggleTarget) {
      this.toggleTarget.textContent = expanded ? 'less...' : 'more...';
      this.toggleTarget.setAttribute('aria-expanded', String(expanded));
    }
  }
}
