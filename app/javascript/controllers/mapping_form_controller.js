import { Controller } from '@hotwired/stimulus';
import { useTomSelect } from '../mixins/useTomSelect';

// Coordinates the new-mapping form (app/views/mappings/_form.html.haml):
// enables the target-class autocomplete once a target ontology is picked,
// records the selected class, and previews its details.
//
// Connects to data-controller="mapping-form"
export default class extends Controller {
  static targets = ['ontologySelect', 'classInput', 'classId', 'detailsFrame'];

  connect() {
    this.ontologyPicker = useTomSelect(
      this.ontologySelectTarget,
      {
        placeholder: this.ontologySelectTarget.dataset.placeholder,
      },
      this.ontologyChanged.bind(this),
    );
  }

  disconnect() {
    this.ontologyPicker.destroy();
  }

  ontologyChanged() {
    this.classInputTarget.value = '';
    this.classIdTarget.value = '';
    this.detailsFrameTarget.removeAttribute('src');
    this.detailsFrameTarget.innerHTML = '';
    this.classInputTarget.disabled = this.acronym === '';
    // Retargets the autocomplete (see mapping_target_autocomplete_controller.js)
    this.classInputTarget.dataset.mappingTargetAutocompleteOntologyAcronymValue = this.acronym;
  }

  // A class was picked in the autocomplete (mapping-target-autocomplete:selected)
  targetClassSelected(event) {
    const classId = event.detail.classId;
    this.classIdTarget.value = classId;
    this.detailsFrameTarget.src =
      `/ajax/class_details?ontology=${encodeURIComponent(this.acronym)}` +
      `&conceptid=${encodeURIComponent(classId)}&frame_id=${this.detailsFrameTarget.id}`;
  }

  get acronym() {
    return this.ontologySelectTarget.value;
  }
}
