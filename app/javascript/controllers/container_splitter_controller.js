import { Controller } from "@hotwired/stimulus"
import Split from "split.js";
// Connects to data-controller="container-splitter"
export default class extends Controller {
  static targets = ['container']

  connect() {
    this.element.style.display = 'flex';

    // Publish the distance from the top of the viewport to the top of
    // #bd_content as a CSS custom property, so the layout can size the class
    // browser to `calc(100dvh - var(--bd-content-top) - gap)` and keep both
    // columns scrolling internally instead of the whole page. Measured now, once
    // more after layout settles (fonts/images above can shift the offset), and
    // kept current on resize.
    this.updateTopOffset = this.updateTopOffset.bind(this);
    this.updateTopOffset();
    requestAnimationFrame(this.updateTopOffset);
    window.addEventListener('resize', this.updateTopOffset);

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

  disconnect() {
    if (this.updateTopOffset) {
      window.removeEventListener('resize', this.updateTopOffset);
    }
  }

  updateTopOffset() {
    const top = Math.round(this.element.getBoundingClientRect().top + window.scrollY);
    this.element.style.setProperty('--bd-content-top', `${top}px`);
  }
}
