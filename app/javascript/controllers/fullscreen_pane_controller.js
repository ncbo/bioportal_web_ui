import { Controller } from '@hotwired/stimulus';

// Full-screen the class browser (tree + details) into a full-window overlay, so
// you can browse an ontology using the whole browser window. Opt-in: the toggle
// button lives in the concept details tab strip (see fullscreen_pane_button in
// ontologies_helper) and reaches this controller by action bubbling; Esc or the
// button exits. The default page layout is untouched.
//
// Toggling adds `bd-content--fullscreen` to the element (#bd_content). The CSS
// (ontologies.scss) makes it position:fixed filling the viewport and swaps the
// button icon (expand arrows -> inward "contract" arrows); the pane's existing
// internal layout (split.js columns, per-column scrollers) fills the larger box
// on its own. We also lock body scroll behind the overlay, and always release it
// on teardown so the lock can never outlive the overlay.
export default class extends Controller {
  // Source of truth is the class on the element, not a shadow flag — so the
  // controller stays consistent even if it reconnects while already expanded.
  get isOpen() {
    return this.element.classList.contains('bd-content--fullscreen');
  }

  connect() {
    this._onKey = (ev) => {
      // Let dialogs consume Escape, including while Bootstrap finishes closing
      // and restores the body's scroll lock after its transition.
      if (ev.defaultPrevented || document.body.classList.contains('modal-open')) return;
      if (ev.key === 'Escape' && this.isOpen) this.toggle();
    };
    document.addEventListener('keydown', this._onKey);

    // Turbo caches the DOM before navigating away. Exit fullscreen before the
    // snapshot is taken so a restored page never comes back stuck in the overlay
    // (class present, scroll locked, no re-lock on the way back in).
    this._onBeforeCache = () => this.#exit();
    document.addEventListener('turbo:before-cache', this._onBeforeCache);

    // A class selection replaces the #concept_show frame, re-rendering the button
    // with its default (collapsed) label while the pane may still be fullscreen.
    // Re-sync the label to the current state whenever a frame lands.
    this._onFrameLoad = () => this.#syncLabel();
    document.addEventListener('turbo:frame-load', this._onFrameLoad);

    // Reconcile with the DOM in case we connect already expanded (e.g. a cached
    // page restored mid-fullscreen): re-establish the scroll lock and label.
    if (this.isOpen) {
      this.#lockBody();
      this.#syncLabel();
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this._onKey);
    document.removeEventListener('turbo:before-cache', this._onBeforeCache);
    document.removeEventListener('turbo:frame-load', this._onFrameLoad);
    this.#unlockBody();
  }

  toggle() {
    this.element.classList.toggle('bd-content--fullscreen');
    if (this.isOpen) this.#lockBody();
    else this.#unlockBody();
    this.#syncLabel();
    // The class browser sizes itself off --bd-content-top / viewport; nudge any
    // listeners (e.g. container-splitter) so columns re-fit to the new box.
    window.dispatchEvent(new Event('resize'));
  }

  // Force-exit without a resize nudge — used before Turbo caches the page.
  #exit() {
    if (!this.isOpen) return;
    this.element.classList.remove('bd-content--fullscreen');
    this.#unlockBody();
    this.#syncLabel();
  }

  // Keep the button's accessible name in step with what it will do next: "enter"
  // when collapsed, "exit" when expanded. Labels come from the server (data
  // attributes) so they stay translated.
  #syncLabel() {
    const btn = this.element.querySelector('.bd-content__fullscreen-btn');
    if (!btn) return;
    const label = this.isOpen ? btn.dataset.exitLabel : btn.dataset.enterLabel;
    if (!label) return;
    // The shared tooltip removes title to suppress the browser's native tooltip.
    // Before it connects, leave the current label in title for initialization.
    if (btn._tippy) btn._tippy.setContent(label);
    else btn.title = label;
    btn.setAttribute('aria-label', label);
  }

  #lockBody() {
    if (this._locked) return;
    this._prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    this._locked = true;
  }

  #unlockBody() {
    if (!this._locked) return;
    document.body.style.overflow = this._prevOverflow || '';
    this._locked = false;
  }
}
