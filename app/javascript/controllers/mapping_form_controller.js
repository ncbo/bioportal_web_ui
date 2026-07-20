import { Controller } from '@hotwired/stimulus';
import { useTomSelect } from '../mixins/useTomSelect';

// Coordinates the new-mapping form (app/views/mappings/_form.html.haml):
// a single Tom Select searches classes across all ontologies
// (/search/classes); selecting a result records its ontology and previews
// its details.
//
// Connects to data-controller="mapping-form"
export default class extends Controller {
  static targets = ['classSelect', 'ontologyId', 'detailsFrame'];

  connect() {
    this.classPicker = useTomSelect(
      this.classSelectTarget,
      {
        valueField: 'id',
        labelField: 'prefLabel',
        searchField: [], // results come relevance-ranked from the server
        sortField: [{ field: '$order' }],
        placeholder: this.classSelectTarget.dataset.placeholder,
        shouldLoad: (query) => query.length >= 2,
        load: this.#loadOptions.bind(this),
        render: {
          option: this.#renderResult,
          item: this.#renderResult,
        },
      },
      this.classChanged.bind(this),
    );
  }

  disconnect() {
    this.classPicker.destroy();
  }

  classChanged(classId) {
    const option = this.classPicker.options[classId];
    this.ontologyIdTarget.value = option ? option.acronym : '';
    if (option) {
      this.detailsFrameTarget.src =
        `/mappings/target_details?ontology=${encodeURIComponent(option.acronym)}` +
        `&conceptid=${encodeURIComponent(classId)}`;
    } else {
      this.detailsFrameTarget.removeAttribute('src');
      this.detailsFrameTarget.innerHTML = '';
    }
  }

  #loadOptions(query, callback) {
    fetch(`/search/classes?q=${encodeURIComponent(query)}`, { headers: { Accept: 'application/json' } })
      .then((response) => (response.ok ? response.json() : []))
      .then((results) => {
        // Drop the previous query's options so only fresh results show
        // (searchField: [] disables Tom Select's own filtering)
        this.classPicker.clearOptions();
        callback(results);
      })
      .catch(() => callback());
  }

  #renderResult(data, escape) {
    return `<div>${escape(data.prefLabel)} <span class="text-muted ms-1">${escape(data.acronym)}</span></div>`;
  }
}
