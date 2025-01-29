import OntoportalAutocompleteController from "./ontoportal_autocomplete_controller";

// Connects to data-controller="class-search"
export default class extends OntoportalAutocompleteController {
    static values = {
        spinnerSrc: String,
        ontologyAcronym: String,
        lang: String,
    }
    connect() {
        super.connect()
    }

    onFindValue(li) {
        if (li == null) {
            // User performs a search
            let search = confirm("Class could not be found.\n\nPress OK to go to the Search page or Cancel to continue browsing");

            if (search) {
                jQuery("#search_keyword").val(jQuery("#search_box").val());
                jQuery("#search_form").submit();
                return
            }
        }

        // Appropriate value selected
        if (li.extra) {
            let sValue = jQuery("#jump_to_concept_id").val()
            Turbo.visit("/ontologies/" + this.ontologyAcronymValue + "/?p=classes&lang=" + this.langValue + "&conceptid=" + encodeURIComponent(sValue) + "&jump_to_nav=true")
        }
    }

    onItemSelect(li) {
        jQuery("#jump_to_concept_id").val(li.extra[0]);
        this.onFindValue(li);
    }
}
