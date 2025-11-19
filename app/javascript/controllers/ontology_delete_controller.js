// app/javascript/controllers/ontology_delete_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [
        "button", "input", "confirm"
    ]

    static values = {
        acronym: String,
        url: String,
        redirectUrl: String
    }

    connect() {
        this.sync()
    }

    sync() {
        const typed = (this.hasInputTarget ? this.inputTarget.value.trim() : "")
        const shouldEnable = typed.toUpperCase() === String(this.acronymValue || "").toUpperCase()
        if (this.hasButtonTarget) {
            this.buttonTarget.disabled = !shouldEnable
        }
    }

    openConfirm() {
        if (this.hasConfirmTarget) {
            this.confirmTarget.classList.remove("d-none")
        }
    }

    confirm() {
        if (this.hasButtonTarget && this.buttonTarget.disabled) return
        if (this.hasConfirmTarget) this.confirmTarget.classList.add("d-none")

        if (!this.urlValue) {
            console.error("ontology-delete: missing urlValue (DELETE endpoint)")
            return
        }

        // Disable button and show progress label
        const originalLabel = this.hasButtonTarget ? this.buttonTarget.textContent : ""
        if (this.hasButtonTarget) {
            this.buttonTarget.disabled = true
            this.buttonTarget.classList.add("disabled")
            this.buttonTarget.innerHTML = '<span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>Deleting ontology ' + this.acronymValue + '. Please wait…'
        }

        // Fire DELETE to UI proxy (expects 200/202/204)
        const csrf = document.querySelector('meta[name="csrf-token"]')?.content
        fetch(this.urlValue, {
            method: "DELETE",
            headers: {
                "Accept": "application/json",
                "X-CSRF-Token": csrf,
                "X-Requested-With": "XMLHttpRequest"
            } })
            .then(async (r) => {
                const data = await r.json().catch(() => ({}))
                if (!r.ok) {
                    const msg = data && data.error ? data.error : `DELETE failed: ${r.status}`
                    throw new Error(msg)
                }
                if (this.hasButtonTarget) {
                    this.buttonTarget.innerHTML = '<span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>Ontology deleted. Redirecting…'
                }
                const to = data.redirect_url || this.redirectUrlValue || "/ontologies"
                window.location.assign(to)
            })
            .catch((err) => {
                console.error(err)
                // Optional: surface error to user; for now, restore button state
                if (this.hasButtonTarget) {
                    this.buttonTarget.disabled = false
                    this.buttonTarget.classList.remove("disabled")
                    this.buttonTarget.textContent = originalLabel || `Delete ontology “${this.acronymValue || ""}”`
                }
            })
    }

    cancel() {
        if (this.hasConfirmTarget) {
            this.confirmTarget.classList.add("d-none")
        }
    }
}