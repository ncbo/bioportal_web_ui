import {Controller} from "@hotwired/stimulus"
import {useBioportalAutoComplete} from "../mixins/useBioportalAutoComplete";
// Connects to data-controller="ontoportal-autocomplete"
export default class extends Controller {
    static  values = {
        objectTypes: String, default: 'class',
        ontologyAcronym: String
    }

    connect() {
        useBioportalAutoComplete(this.element,
            "/search/json_search/" + this.ontologyAcronymValue,
            {objecttypes: this.objectTypesValue},
            this.onFindValue.bind(this),
            this.onItemSelect.bind(this),
            this.#formatItem.bind(this)
        )
    }

    onFindValue(li){
        throw new Error('You have to implement the method');
    }

    onItemSelect(li){
        throw new Error('You have to implement the method');
    }

    #formatItem(row) {
        let specials = /[.*+?|()\[\]{}\\]/g;
        let keywords = this.element.value.trim().replace(specials, "\\$&").split(' ').join('|');
        let regex = new RegExp('(' + keywords + ')', 'gi');
        let matchType = "";
        if (typeof row[2] !== "undefined" && row[2] !== "") {
            matchType = " <span style='font-size:9px;color:blue;'>(" + row[2] + ")</span>";
        }

        if (row[0].match(regex) == null) {
            let contents = row[6].split("\t");
            let synonym = contents[0] || "";
            synonym = synonym.split(";");
            if (synonym.length !== 0) {
                let matchSynonym = jQuery.grep(synonym, function (e) {
                    return e.match(regex) != null;
                });
                row[0] = row[0] + " (synonym: " + matchSynonym.join(" ") + ")";
            }
        }
        // Cleanup obsolete class tag before markup for search keywords.
        let obsolete_prefix = "";
        let obsolete_suffix = "";

        if (row[0].indexOf("[obsolete]") !== -1) {
            row[0] = row[0].replace("[obsolete]", "");
            obsolete_prefix = "<span class='obsolete_class' title='obsolete class'>";
            obsolete_suffix = "</span>";
        }

        // Markup the search keywords.
        let row0_markup = row[0].replace(regex, "<b><span style='color:#006600;'>$1</span></b>");
        return obsolete_prefix + row0_markup + matchType + obsolete_suffix;
    }


}
