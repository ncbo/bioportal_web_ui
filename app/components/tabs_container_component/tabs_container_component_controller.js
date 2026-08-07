import {Controller} from "@hotwired/stimulus";
import {HistoryService} from "../../javascript/mixins/useHistory";

export default class extends Controller {

    connect() {
        this.event = null
    }


    selectTab(event) {
        this.event = event
        if (this.#parameter() && this.#parameter() !== "") {
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

    #merge() {
        return this.event.currentTarget.getAttribute("data-url-merge") === "true"
    }

    #url() {
        return `?${this.#parameter()}=${this.#pageId()}`
    }

    #updateURL() {
        const history = new HistoryService();
        if (this.#merge()) {
            // Merge this tab's param into the current query string, keeping the other
            // params. Used by tabs that coexist with other state — e.g. the concept
            // views, which must keep `conceptid` when the view changes.
            history.updateHistory(window.location.href, {[this.#parameter()]: this.#pageId()});
        } else {
            // Replace the query string with just this tab's param. Used by tabs that
            // own the URL — e.g. the top-level `p` sections — so switching them leaves
            // no stale params behind.
            history.pushState({[this.#parameter()]: this.#pageId()}, this.#title(), this.#url());
        }
    }

}
