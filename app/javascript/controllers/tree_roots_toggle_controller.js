import { Controller } from '@hotwired/stimulus';

const STORAGE_PREFIX = 'tree-roots-mode:';

// Connects to data-controller="tree-roots-toggle"
//
// A radio group choosing which roots the class tree starts at: the ontology's
// preferred roots (IAO:0000700, the default) or all structural roots (up to
// owl:Thing). Choosing a radio sets/clears the tree_roots=full parameter on the
// tree turbo-frame's src, which re-fetches the tree with the chosen root set.
//
// This is a SEPARATE control from the "show parent paths" toggle
// (tree-paths-toggle): that one chooses how many paths to a class are shown; this
// one chooses where the tree starts. They compose.
//
// The choice is remembered in localStorage PER ONTOLOGY (keyed by acronym), so
// choosing "all roots" for one ontology doesn't change where another one starts.
// Only rendered when the ontology declares root terms (otherwise the two options
// are identical).
export default class extends Controller {
  static values = {
    frameId: { type: String, default: 'concepts_tree_view' },
    ontology: String,
  };
  static targets = ['preferred', 'all'];

  // Per-ontology localStorage key. Falls back to a shared key if no acronym was
  // provided, so preference still persists (just not scoped) rather than breaking.
  get #storageKey() {
    return STORAGE_PREFIX + (this.ontologyValue || '_');
  }

  connect() {
    // The server renders the full hierarchy when tree_roots=full is in the URL.
    // If the stored preference says full but this page was loaded without it
    // (fresh visit / clean URL), switch the tree to the full hierarchy now.
    if (this.#storedPreference() === 'full' && !this.#frameIsFull()) {
      this.#setFull(true);
    }
    this.#reflect(this.#frameIsFull());
  }

  // A radio was chosen: "all" -> full hierarchy, "preferred" -> declared roots.
  select(event) {
    this.#setFull(event.target.value === 'all');
  }

  #setFull(on) {
    const frame = document.getElementById(this.frameIdValue);
    if (!frame) return;

    const src = frame.getAttribute('src');
    if (!src) return;

    const url = new URL(src, document.location.origin);
    if (on) {
      url.searchParams.set('tree_roots', 'full');
    } else {
      url.searchParams.delete('tree_roots');
    }

    // Keep the currently-selected class selected across the change. Read the
    // conceptid from the page URL (kept current as the user navigates the tree),
    // NOT the tree's active node: each root list auto-highlights its first entry,
    // which differs between modes and would otherwise change the selection.
    const conceptId = this.#currentConceptId();
    if (conceptId) {
      url.searchParams.set('conceptid', conceptId);
    }

    this.#storePreference(on);
    this.#reflect(on);
    frame.setAttribute('src', url.pathname + url.search);
  }

  // The class the page currently has open. Read from the page URL's `conceptid`,
  // which is kept current as the user navigates the tree (selecting a node pushes
  // it into the URL). The ontology viewer's bp.ont_viewer.concept_id global is only
  // set on full page load and goes stale on in-tree navigation, so it is NOT used
  // here. Null on the bare root view.
  #currentConceptId() {
    try {
      const id = new URL(window.location.href).searchParams.get('conceptid');
      return id && id !== 'root' ? id : null;
    } catch {
      return null;
    }
  }

  #frameIsFull() {
    const frame = document.getElementById(this.frameIdValue);
    const src = frame && frame.getAttribute('src');
    return !!src && new URL(src, document.location.origin).searchParams.get('tree_roots') === 'full';
  }

  // Keep the radios in sync with the actual mode (e.g. when connect() forces full
  // from a stored preference, or after a mode change).
  // Keep the radios in sync with the actual mode (native radios show the state via
  // :checked, so just set it — no wrapper class needed).
  #reflect(full) {
    if (!this.hasPreferredTarget || !this.hasAllTarget) return;
    this.preferredTarget.checked = !full;
    this.allTarget.checked = full;
  }

  #storedPreference() {
    try {
      return window.localStorage.getItem(this.#storageKey);
    } catch {
      return null;
    }
  }

  #storePreference(on) {
    try {
      if (on) {
        window.localStorage.setItem(this.#storageKey, 'full');
      } else {
        window.localStorage.removeItem(this.#storageKey);
      }
    } catch {
      // localStorage unavailable (private mode / disabled) — the mode still works
      // for this page via the frame src; it just won't be remembered.
    }
  }
}
