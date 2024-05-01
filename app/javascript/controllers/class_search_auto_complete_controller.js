import OntoportalAutocompleteController from "./ontoportal_autocomplete_controller";

// Connects to data-controller="class-search"
export default class extends OntoportalAutocompleteController {
    static values = {
        spinnerSrc: String
    }
    connect() {
        super.connect()
    }

    onFindValue(li) {
        jQuery.blockUI({ message: '<h1><img src="'+ this.spinnerSrcValue +'" /> Loading Class...</h1>', showOverlay: false });

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
            document.location = "/ontologies/" + jQuery(document).data().bp.ontology.acronym + "/?p=classes&conceptid=" + encodeURIComponent(sValue) + "&jump_to_nav=true";
            jQuery.blockUI({
                message: '<h1><img src="'+ this.spinnerSrcValue + '" /> Loading Class...</h1>',
                showOverlay: false
            });

        }
    }

    onItemSelect(li) {
        jQuery("#jump_to_concept_id").val(li.extra[0]);
        this.onFindValue(li);
    }
}
