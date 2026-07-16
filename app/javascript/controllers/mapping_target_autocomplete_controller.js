import OntoportalAutocompleteController from './ontoportal_autocomplete_controller';

// Target-class autocomplete for the new-mapping form. Unlike its parent, the
// ontology being searched can change while connected: mapping_form_controller
// rewrites the ontology-acronym value and the search is retargeted in place.
//
// Connects to data-controller="mapping-target-autocomplete"
export default class extends OntoportalAutocompleteController {
  onItemSelect(li) {
    this.dispatch('selected', { detail: { classId: li.extra[0] } });
  }

  onFindValue(li) {
    if (li) {
      this.onItemSelect(li);
    }
  }

  ontologyAcronymValueChanged(value) {
    // Fires once before connect(), when the jQuery autocompleter doesn't exist yet
    const autocompleter = this.element.autocompleter;
    if (!autocompleter) return;

    autocompleter.getOptions().url = `/search/json_search/${value}`;
    autocompleter.flushCache();
  }
}
