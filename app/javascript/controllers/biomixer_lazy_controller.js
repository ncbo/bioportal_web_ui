import { Controller } from '@hotwired/stimulus'

// Loads the BioMixer visualization iframe only when the Visualization tab is actually
// opened, instead of on every class select. The iframe is rendered with no `src`; this
// controller sets it (once) when the user selects the tab — or right away if the
// Visualization pane is already the active one when the concept view renders (e.g. the
// page was opened directly on that view, once tab state is restored on load).
//
// Without this, the iframe had a hardcoded `src` and loaded eagerly inside a hidden
// pane on every class select, kicking off BioMixer's large fan-out of backend calls for
// a tab that is often never viewed. (The partial's old `original_src`/`@immediate_load`
// deferral was never wired up — nothing set the flag and nothing swapped the src.)
export default class extends Controller {
  static targets = ['frame']
  static values = { src: String, tabId: { type: String, default: 'visualization' } }

  connect () {
    this._loaded = false
    // Always listen for the tab being selected. Register the listener FIRST (before the
    // active-pane check below), so that if a `tab-selected` fires in the brief window
    // around this controller connecting after a Turbo frame swap, it isn't missed.
    // tabs-container dispatches `tab-selected` (bubbling) on tab click.
    this._onTabSelected = (e) => {
      if (e.detail?.data?.selectedTab === this.tabIdValue) this.#load()
    }
    document.addEventListener('tab-selected', this._onTabSelected)

    // Load right away if this tab's pane is already the active one on render. #load()
    // is idempotent, so doing this in addition to the listener can't double-load.
    if (this.#paneActive()) this.#load()
  }

  disconnect () {
    if (this._onTabSelected) document.removeEventListener('tab-selected', this._onTabSelected)
  }

  // Active only if the NEAREST enclosing tab-pane (this tab's own pane) is active.
  // Not `closest('.tab-pane.active')`: the concept panes are nested inside the
  // ontology-level tab panes, so an active *outer* pane would falsely match even when
  // this concept tab is hidden.
  #paneActive () {
    const pane = this.element.closest('.tab-pane')
    return !!pane && pane.classList.contains('active')
  }

  #load () {
    if (this._loaded || !this.hasFrameTarget || !this.srcValue) return
    this._loaded = true
    this.frameTarget.setAttribute('src', this.srcValue)
    if (this._onTabSelected) {
      document.removeEventListener('tab-selected', this._onTabSelected)
      this._onTabSelected = null
    }
  }
}
