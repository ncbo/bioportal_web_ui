import { Controller } from "@hotwired/stimulus"
import debounce from "debounce"

// Connects to data-controller="ror-search"
// When agent type is organization, typing in the name field searches
// https://api.ror.org/v2/organizations and fills name, acronym, homepage,
// and the ROR identifier from the selected result.
export default class extends Controller {
    static targets = ["nameInput", "results", "acronymInput", "homepageInput", "identifierInput", "organizationRadio"]
    static values = {
        apiUrl: { type: String, default: "https://api.ror.org/v2/organizations" },
        minLength: { type: Number, default: 2 },
        debounceMs: { type: Number, default: 300 }
    }

    connect() {
        this.search = debounce(this.search.bind(this), this.debounceMsValue)
    }

    search() {
        if (!this.#isOrganizationMode()) {
            this.hideResults()
            return
        }

        const query = this.nameInputTarget.value.trim()
        if (query.length < this.minLengthValue) {
            this.hideResults()
            return
        }

        fetch(`${this.apiUrlValue}?query=${encodeURIComponent(query)}`)
            .then(r => r.ok ? r.json() : Promise.reject(r.statusText))
            .then(data => this.renderResults(data.items || []))
            .catch(err => {
                console.error("ROR search error", err)
                this.hideResults()
            })
    }

    prevent(event) {
        event.preventDefault()
    }

    blur() {
        this.resultsTarget.style.display = "none"
    }

    hide() {
        this.hideResults()
    }

    renderResults(items) {
        if (items.length === 0) {
            this.hideResults()
            return
        }

        this.resultsTarget.innerHTML = ""
        items.slice(0, 10).forEach(item => {
            const display = this.#displayName(item)
            const acronym = this.#acronym(item)
            const country = item.locations?.[0]?.geonames_details?.country_name || ""
            const rorId = item.id?.split("/").pop() || ""

            const a = document.createElement("a")
            a.href = "#"
            a.className = "search-content"
            a.innerHTML = `
                <p class="search-element">
                    <strong>${this.#escape(display)}</strong>
                    ${acronym ? `<small> (${this.#escape(acronym)})</small>` : ""}
                    ${country ? `<small> — ${this.#escape(country)}</small>` : ""}
                </p>
                <p class="home-result-type"><small>${this.#escape(rorId)}</small></p>
            `
            a.addEventListener("click", (e) => {
                e.preventDefault()
                this.select(item)
            })
            this.resultsTarget.appendChild(a)
        })

        this.resultsTarget.style.display = "block"
    }

    select(item) {
        const englishName = this.#englishName(item)
        const acronym = this.#acronym(item)
        const homepage = this.#homepage(item)
        const rorId = item.id || ""

        const finalName = englishName || this.#rorDisplayName(item) || acronym
        if (finalName) this.#setValue(this.nameInputTarget, finalName)
        if (this.hasAcronymInputTarget && acronym) this.#setValue(this.acronymInputTarget, acronym)
        if (this.hasHomepageInputTarget && homepage) this.#setValue(this.homepageInputTarget, homepage)
        if (this.hasIdentifierInputTarget && rorId) this.#setValue(this.identifierInputTarget, rorId)

        this.hideResults()
    }

    hideResults() {
        this.resultsTarget.style.display = "none"
        this.resultsTarget.innerHTML = ""
    }

    #isOrganizationMode() {
        if (!this.hasOrganizationRadioTarget) return true
        return this.organizationRadioTarget.checked
    }

    #setValue(input, value) {
        input.value = value
        input.dispatchEvent(new Event("input", { bubbles: true }))
        input.dispatchEvent(new Event("change", { bubbles: true }))
    }

    #displayName(item) {
        return this.#englishName(item) || this.#rorDisplayName(item) || (item.names?.[0]?.value ?? "")
    }

    #englishName(item) {
        const en = (item.names || []).find(n => n.lang === "en" && (n.types || []).includes("label"))
        return en?.value || ""
    }

    #rorDisplayName(item) {
        const d = (item.names || []).find(n => (n.types || []).includes("ror_display"))
        return d?.value || ""
    }

    #acronym(item) {
        const ac = (item.names || []).find(n => (n.types || []).includes("acronym"))
        return ac?.value || ""
    }

    #homepage(item) {
        const domain = (item.domains || [])[0]
        if (domain) {
            return domain.startsWith("http") ? domain : `https://${domain}`
        }
        const link = (item.links || []).find(l => l.type === "website")
        return link?.value || ""
    }

    #escape(str) {
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;")
    }
}
