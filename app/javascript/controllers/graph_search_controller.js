import OntoportalAutocompleteController from './ontoportal_autocomplete_controller'

// Search-driven Entity Graph tab. Reuses the ontology-scoped class autocomplete
// (same "Jump To" backend as the Classes tab), but on selecting a class it loads
// that class's entity graph into the concept_entity_graph turbo-frame instead of
// navigating the page.
//
// Connects to data-controller="graph-search"
export default class extends OntoportalAutocompleteController {
  static values = {
    ontologyAcronym: String,
    lang: String,
    frameId: { type: String, default: 'concept_entity_graph' }
  }

  connect () {
    super.connect()
  }

  onFindValue (li) {
    // li is null when the typed text matched no class — leave the field as-is
    // (unlike the Classes tab we don't bounce the user to global Search).
    if (li == null) return
    if (li.extra) this.#loadGraph(li.extra[0])
  }

  onItemSelect (li) {
    if (li && li.extra) this.#loadGraph(li.extra[0])
  }

  #loadGraph (conceptId) {
    if (!conceptId) return
    const frame = document.getElementById(this.frameIdValue)
    const src = `/ajax/entity_graph?ontologyid=${encodeURIComponent(this.ontologyAcronymValue)}&conceptid=${encodeURIComponent(conceptId)}`
    if (frame) {
      // setting src makes the turbo-frame fetch and swap its content
      frame.setAttribute('src', src)
    } else {
      // no frame yet (first selection) — Turbo will resolve the matching frame
      // in the response
      window.Turbo ? window.Turbo.visit(src, { frame: this.frameIdValue }) : (window.location = src)
    }
  }
}
