import { Controller } from "@hotwired/stimulus"
import Split from "split.js";
// Connects to data-controller="container-splitter"
export default class extends Controller {
  static targets = ['container']

  connect() {
    this.element.style.display = 'flex';
    if (this.element.getAttribute('splitter-data-initial') == 0) {
      return;
    }

    Split(this.containerTargets, {
      elementStyle: function (dimension, size, gutterSize) {
        return {
          'flex-basis': 'calc(' + size + '% - ' + gutterSize + 'px)'
        }
      },
      gutterStyle: function (dimension, gutterSize) {
        return {
          'flex-basis': gutterSize + 'px'
        }
      },
      gutterSize: 10,
      direction: "horizontal",
      sizes: [30, 70],
      cursor: "col-resize"
    });
    this.element.setAttribute('splitter-data-initial', 0);
  }
}
