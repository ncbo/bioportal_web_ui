import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="language-change"
export default class extends Controller {

  dispatchLangChangeEvent() {
    this.element.dispatchEvent(new CustomEvent('lang_changed', {
      bubbles: true,
      cancelable: true,
      detail: {
        data: {
          language: [this.element.value]
        }
      }
    }));

  }
}
