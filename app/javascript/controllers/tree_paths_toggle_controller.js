import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'tree-paths-mode'

// Connects to data-controller="tree-paths-toggle"
//
// Toggles the class tree between the normal (single path + siblings) view and
// the "all paths" view, which shows every location of the selected class in the
// hierarchy. It works by flipping the tree_mode=paths parameter on the tree
// turbo-frame's src, which re-fetches the tree in the chosen mode.
//
// The on/off choice is remembered in localStorage, so it applies to every class
// tree the user opens (across ontologies and visits) until they turn it off.
export default class extends Controller {
  static values = { frameId: { type: String, default: 'concepts_tree_view' } }
  static classes = ['active']

  connect () {
    // The server renders paths mode when tree_mode=paths is in the URL. If the
    // stored preference says paths but this page was loaded without it (e.g. a
    // fresh visit with a clean URL), switch the tree into paths mode now.
    if (this.#storedPreference() === 'paths' && !this.#frameHasPaths()) {
      this.#setPaths(true)
    }
  }

  toggle () {
    this.#setPaths(!this.#frameHasPaths())
  }

  // Turn paths mode on/off: update the stored preference, reflect it on the
  // button, and reload the tree frame in the chosen mode.
  #setPaths (on) {
    const frame = document.getElementById(this.frameIdValue)
    if (!frame) return

    const src = frame.getAttribute('src')
    if (!src) return

    const url = new URL(src, document.location.origin)
    if (on) {
      url.searchParams.set('tree_mode', 'paths')
    } else {
      url.searchParams.delete('tree_mode')
    }

    this.#storePreference(on)
    this.#reflect(on)
    // Assigning src (even to the same-looking URL) makes the turbo-frame reload.
    frame.setAttribute('src', url.pathname + url.search)
  }

  #frameHasPaths () {
    const frame = document.getElementById(this.frameIdValue)
    const src = frame && frame.getAttribute('src')
    return !!src && new URL(src, document.location.origin).searchParams.get('tree_mode') === 'paths'
  }

  #reflect (on) {
    if (this.hasActiveClass) {
      this.element.classList.toggle(this.activeClass, on)
    }
    this.element.setAttribute('aria-pressed', on ? 'true' : 'false')
  }

  #storedPreference () {
    try {
      return window.localStorage.getItem(STORAGE_KEY)
    } catch (e) {
      return null
    }
  }

  #storePreference (on) {
    try {
      if (on) {
        window.localStorage.setItem(STORAGE_KEY, 'paths')
      } else {
        window.localStorage.removeItem(STORAGE_KEY)
      }
    } catch (e) {
      // localStorage unavailable (private mode / disabled) — the mode still works
      // for this page via the frame src; it just won't be remembered.
    }
  }
}
