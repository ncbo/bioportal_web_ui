import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ['source', 'copiedIndicator']

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.textContent);

    this.copiedIndicatorTarget.classList.remove('hidden');

    setTimeout(() => {
      this.copiedIndicatorTarget.classList.add('hidden');
    }, 2000);
  }
}
