import { Controller } from "@hotwired/stimulus"
import { HistoryService } from "../mixins/useHistory";

// Connects to data-controller="history"
export default class extends Controller {
    connect() {
        this.history = new HistoryService()
    }
    updateURL(event) {
        const { data } = event.detail
        if (data !== undefined && Object.keys(data).length > 0) {
            this.history.updateHistory(document.location.pathname + document.location.search, data)
        }
    }


}
