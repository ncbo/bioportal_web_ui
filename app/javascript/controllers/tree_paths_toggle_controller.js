import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="tree-paths-toggle"
//
// Toggles the class tree between the normal (single path + siblings) view and
// the "all paths" view, which shows every location of the selected class in the
// hierarchy. It works by flipping the tree_mode=paths parameter on the tree
// turbo-frame's src, which re-fetches the tree in the chosen mode.
export default class extends Controller {
  static values = { frameId: { type: String, default: 'concepts_tree_view' } }
  static classes = ['active']

  toggle () {
    const frame = document.getElementById(this.frameIdValue)
    if (!frame) return

    const src = frame.getAttribute('src')
    if (!src) return

    const url = new URL(src, document.location.origin)
    const on = url.searchParams.get('tree_mode') === 'paths'

    if (on) {
      url.searchParams.delete('tree_mode')
    } else {
      url.searchParams.set('tree_mode', 'paths')
    }

    this.#reflect(!on)
    // Assigning src (even to the same-looking URL) makes the turbo-frame reload.
    frame.setAttribute('src', url.pathname + url.search)
  }

  #reflect (on) {
    if (this.hasActiveClass) {
      this.element.classList.toggle(this.activeClass, on)
    }
    this.element.setAttribute('aria-pressed', on ? 'true' : 'false')
  }
}
