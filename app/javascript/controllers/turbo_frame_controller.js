import { Controller } from "@hotwired/stimulus"
import { HistoryService } from "../mixins/useHistory";

// Connects to data-controller="turbo-frame"
export default class extends Controller {
    static values = {
        url: String,
        placeHolder: { type: String, default: 'Nothing loaded' },
    }
    static targets = ['frame']

    connect() {
        this.frame = this.frameTarget
    }

    updateFrame(event) {
        const { data } = event.detail
        const values = Object.values(data)

        // remove null and empty values
        values.filter((value) => value !== "" || value !== undefined)

        if (values.length === 0) {
            this.frame.innerHTML = this.placeHolderValue
        } else {
            this.frame.innerHTML = ""

            if(this.#isCurrentPage()){
                this.urlValue = this.#currentPageUrl()
            }

            this.urlValue = this.#updatedPageUrl(data)

            this.frame.src  = this.urlValue
        }
    }

    #isCurrentPage(){

        let currentDisplayedUrl = new URL(this.#currentPageUrl(), document.location.origin)

        let initUrl = new URL(this.urlValue, document.location.origin)

        if (currentDisplayedUrl.toString().includes(this.urlValue)){
            return true
        } else if (currentDisplayedUrl.searchParams.has('p') && currentDisplayedUrl.searchParams.get('p') === initUrl.searchParams.get('p')){
            // this is a custom fix for only the ontology viewer page,
            // that use the parameter ?p=section to tell which section is displayed
            return true
        }

        return false
    }


    #currentPageUrl(){
        return document.location.pathname + document.location.search
    }

    #updatedPageUrl(newUrlParams){
        return new HistoryService().getUpdatedURL(this.urlValue, newUrlParams)
    }
}
