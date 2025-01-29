import {Controller} from "@hotwired/stimulus";
import {HistoryService} from "../../javascript/mixins/useHistory";

export default class extends Controller {

    connect() {
        this.event = null
    }


    selectTab(event) {
        this.event = event
        if (this.#parameter()) {
            this.#updateURL()
        }
        this.element.dispatchEvent(new CustomEvent("tab-selected", {
            bubbles: true,
            detail: {data: {selectedTab: this.#pageId()}}
        }))
    }

    #pageId() {
        return this.event.currentTarget.getAttribute("data-tab-id")
    }

    #title() {
        return this.event.currentTarget.getAttribute("data-tab-title")
    }

    #parameter() {
        return this.event.currentTarget.getAttribute("data-url-parameter")
    }


    #url() {
        return `?${this.#parameter()}=${this.#pageId()}`
    }

    #updateURL() {
        (new HistoryService()).pushState({[this.#parameter()]: this.#pageId()}, this.#title(), this.#url());
    }

}
