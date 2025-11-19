// app/javascript/controllers/submissions_list_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [
        "row", "rowCheckbox", "moreLink", "lessLink", "divider", "deleteBtn", "headerCheckbox",
        "inlineConfirm", "inlineConfirmLabel", "inlineConfirmList", "status", "statusSpinner"
    ]
    static values = {
        total: Number,
        step: Number,
        min: Number,
        shown: Number,
        deleteUrl: String,
        pollUrlTemplate: String,
        rowsUrl: String
    }

    connect() {
        const total = this.hasTotalValue ? this.totalValue : this.rowTargets.length
        const min = this.hasMinValue ? this.minValue : 5
        const step = this.hasStepValue ? this.stepValue : 5
        this.totalValue = total
        this.minValue = min
        this.stepValue = step
        this.shownValue = Math.min(total, min)
        this.update()
    }

    // UI actions
    showMore(e) {
        e.preventDefault();
        this.shownValue = Math.min(this.totalValue, this.shownValue + this.stepValue);
        this.update()
    }

    showLess(e) {
        e.preventDefault();
        this.shownValue = Math.max(this.minValue, this.shownValue - this.stepValue);
        this.update()
    }

    // Stage 1: called when any row checkbox changes
    syncSelection() {
        this.updateDeleteButtonState()
        this.updateHeaderCheckboxState()
    }

    // Internal
    update() {
        // Show first N rows, hide the rest
        this.rowTargets.forEach((tr, idx) => tr.classList.toggle("d-none", idx >= this.shownValue))

        // Uncheck any rows that just became hidden so they don't count toward selection
        this.uncheckHiddenRows()

        // Toggle footer links & divider
        const showMoreVisible = this.shownValue < this.totalValue
        const showLessVisible = this.shownValue > this.minValue

        if (this.hasMoreLinkTarget) this.moreLinkTarget.classList.toggle("d-none", !showMoreVisible)
        if (this.hasLessLinkTarget) this.lessLinkTarget.classList.toggle("d-none", !showLessVisible)
        if (this.hasDividerTarget) this.dividerTarget.classList.toggle("d-none", !(showMoreVisible && showLessVisible))

        // Recompute delete button state after any visibility change
        this.updateDeleteButtonState()
        this.updateHeaderCheckboxState()
    }

    updateDeleteButtonState() {
        if (!this.hasDeleteBtnTarget) return
        const anyVisibleChecked = this.visibleRowCheckboxes().some(cb => cb.checked)
        this.deleteBtnTarget.disabled = !anyVisibleChecked
    }

    visibleRowCheckboxes() {
        // Row checkboxes whose parent <tr> is not hidden
        const visibleRows = this.rowTargets.filter(tr => !tr.classList.contains("d-none"))
        const boxes = []
        visibleRows.forEach(tr => {
            const cb = tr.querySelector('input[type="checkbox"]')
            if (cb) boxes.push(cb)
        })
        return boxes
    }

    uncheckHiddenRows() {
        // Uncheck any checkboxes that are no longer visible
        this.rowTargets.forEach((tr, idx) => {
            if (idx >= this.shownValue) {
                const cb = tr.querySelector('input[type="checkbox"]')
                if (cb && cb.checked) cb.checked = false
            }
        })
    }

    toggleAllVisible(e) {
        if (!this.hasHeaderCheckboxTarget) return
        const checked = this.headerCheckboxTarget.checked
        this.visibleRowCheckboxes().forEach(cb => { cb.checked = checked })
        this.updateDeleteButtonState()
        this.updateHeaderCheckboxState()
    }

    updateHeaderCheckboxState() {
        if (!this.hasHeaderCheckboxTarget) return
        const boxes = this.visibleRowCheckboxes()
        if (boxes.length === 0) {
            this.headerCheckboxTarget.indeterminate = false
            this.headerCheckboxTarget.checked = false
            this.headerCheckboxTarget.disabled = true
            return
        }
        this.headerCheckboxTarget.disabled = false
        const checkedCount = boxes.filter(cb => cb.checked).length
        this.headerCheckboxTarget.indeterminate = checkedCount > 0 && checkedCount < boxes.length
        this.headerCheckboxTarget.checked = checkedCount > 0 && checkedCount === boxes.length
    }

    toggleInlineConfirm(e) {
        e.preventDefault()
        // Gather selected IDs from visible checked boxes
        const selectedIds = this.visibleRowCheckboxes()
            .filter(cb => cb.checked)
            .map(cb => cb.closest("tr").dataset.submissionId || cb.closest("tr").getAttribute("data-submission-id"))
        this.pendingDeleteIds = selectedIds

        if (!this.hasInlineConfirmTarget) return

        // If none selected, hide the panel and stop
        if (selectedIds.length === 0) {
            this.inlineConfirmTarget.classList.add("d-none")
            return
        }

        // 1) First line: singular vs plural
        if (this.hasInlineConfirmLabelTarget) {
            this.inlineConfirmLabelTarget.textContent =
                selectedIds.length === 1
                    ? "Are you sure you want to delete the submission:"
                    : "Are you sure you want to delete the submissions:"
        }

        // 2) Second line: always list the IDs (even for a single selection)
        if (this.hasInlineConfirmListTarget) {
            this.inlineConfirmListTarget.textContent = selectedIds.join(", ")
        }

        // Show the inline confirmation panel
        this.inlineConfirmTarget.classList.remove("d-none")
    }

    cancelInlineConfirm(e) {
        e.preventDefault()
        if (this.hasInlineConfirmTarget) {
            this.inlineConfirmTarget.classList.add("d-none")
        }
    }

    performDelete(e) {
        e.preventDefault()
        const ids = this.pendingDeleteIds || []
        if (ids.length === 0) return

        // Hide inline confirm if present
        if (this.hasInlineConfirmTarget) this.inlineConfirmTarget.classList.add("d-none")
        // Disable delete while deleting
        if (this.hasDeleteBtnTarget) this.deleteBtnTarget.disabled = true

        this.showStatus("Processing. Please wait…")
        this.showSpinner()
        this.markRowsPending(ids)

        // CSRF
        const tokenEl = document.querySelector('meta[name="csrf-token"]')
        const headers = {
            "Accept": "application/json",
            "Content-Type": "application/json"
        }
        if (tokenEl) headers["X-CSRF-Token"] = tokenEl.content

        // Kick off DELETE to Rails proxy
        fetch(this.deleteUrlValue, {
            method: "DELETE",
            headers,
            body: JSON.stringify({ontology_submission_ids: ids})
        })
            .then(async (r) => {
                if (!r.ok) {
                    const txt = await r.text()
                    throw new Error(`DELETE failed: ${r.status} ${txt}`)
                }
                return r.json()
            })
            .then((json) => {
                const pid = json.process_id
                if (!pid) throw new Error("Missing process_id in response")
                // status already set above; keep spinner visible while polling
                this.startPolling(pid)
            })
            .catch((err) => {
                this.showStatus(`Error starting delete: ${err.message}`)
                this.hideSpinner()
                this.unmarkRowsPending(this.pendingDeleteIds || [])
                if (this.hasDeleteBtnTarget) this.deleteBtnTarget.disabled = false
            })
    }

    // --- fetch fresh rows, rebind, and reapply windowing ---
    async reloadTable() {
        const tbody = this.element.querySelector("tbody")
        if (!tbody) return
        try {
            const resp = await fetch(this.rowsUrlValue, {headers: {"Accept": "text/html"}})
            if (!resp.ok) throw new Error(`Reload failed: ${resp.status}`)
            const html = await resp.text()
            tbody.innerHTML = html

            // Stimulus will auto-pick up new targets inside this.element.
            // Recompute counts and reset UI windowing / selection.
            this.totalValue = this.rowTargets.length
            this.resetWindow()
            this.clearSelections()
            this.updateLinksVisibility()
            this.updateDeleteButtonState()
            if (this.hasHeaderCheckboxTarget) this.headerCheckboxTarget.checked = false

            // Done refreshing – stop spinner and clear the temporary message
            this.hideSpinner()
            this.showStatus("")
        } catch (e) {
            this.showErrorMessage(e.message || "Failed to reload submissions")
        }
    }

    // Show only min (or current shown) and hide the rest
    resetWindow() {
        // If shownValue not set, start from min
        const showCount = this.shownValue || this.minValue || 5
        this.rowTargets.forEach((tr, idx) => {
            tr.classList.toggle("d-none", idx >= showCount)
        })
        this.shownValue = Math.min(showCount, this.rowTargets.length)
    }

    clearSelections() {
        // Uncheck all visible/hidden row checkboxes
        this.rowTargets.forEach(tr => {
            const cb = tr.querySelector('input[type="checkbox"]')
            if (cb) cb.checked = false
        })
        this.pendingDeleteIds = []
    }

    updateLinksVisibility() {
        const total = this.rowTargets.length
        const shown = this.shownValue || 0
        const canMore = shown < total
        const canLess = shown > (this.minValue || 5)

        this.moreLinkTarget.classList.toggle("d-none", !canMore)
        this.lessLinkTarget.classList.toggle("d-none", !canLess)
        this.dividerTarget.classList.toggle("d-none", !(canMore && canLess))
    }

    // --- poll until not "processing"
    startPolling(processId) {
        const pollUrl = this.pollUrlTemplateValue.replace(":process_id", processId)

        const tick = () => {
            fetch(pollUrl, { headers: { "Accept": "application/json" } })
                .then(async (r) => {
                    if (!r.ok) {
                        const txt = await r.text()
                        throw new Error(`Polling failed: ${r.status} ${txt}`)
                    }
                    return r.json()
                })
                .then((json) => {
                    const data = (json && json.table) ? json.table : json
                    const status = (data && data.status) || "done"

                    if (status === "processing") {
                        this.showStatus("Processing. Please wait…")
                        this._pollTimer = setTimeout(tick, 1500)
                    } else {
                        const deletedIds = data.deleted_ids || data.deleted || data.ids || []

                        // Collect error text (if any)
                        let errText = ""
                        if (data.errors && Array.isArray(data.errors) && data.errors.length > 0) {
                            // Prefer a compact summary like: "7: not found; 9: forbidden"
                            errText = data.errors
                                .map(e => (e && (e.message || e.error)) ? `${e.id ?? ""}${e.id ? ": " : ""}${e.message || e.error}` : "")
                                .filter(Boolean)
                                .join("; ")
                        } else if (data.error) {
                            errText = String(data.error)
                        } else if (data.message && String(data.status).toLowerCase() === "error") {
                            errText = String(data.message)
                        }

                        if (String(status).toLowerCase() === "error" || errText) {
                            this.showErrorMessage(errText || "Unknown error")
                        } else {
                            this.showSuccessDeleted(deletedIds)
                            // remove immediately so the user sees instant change
                            // this.removeRowsByIds(this.pendingDeleteIds || [])
                            // show that we’re refreshing from server
                            this.showStatus("Deleted. Refreshing submissions list…")
                            this.showSpinner()
                            this.reloadTable()
                        }

                        if (this.hasDeleteBtnTarget) this.deleteBtnTarget.disabled = false
                        this._pollTimer = null
                    }
                })
                .catch((err) => {
                    this.showStatus(`Polling error: ${err.message}`)
                    this.hideSpinner()
                    this.unmarkRowsPending(this.pendingDeleteIds || [])
                    if (this.hasDeleteBtnTarget) this.deleteBtnTarget.disabled = false
                    this._pollTimer = null
                })
        }

        tick()
    }

    disconnect() {
        if (this._pollTimer) {
            clearTimeout(this._pollTimer)
            this._pollTimer = null
        }
    }

    showStatus(message) {
        if (this.hasStatusTarget) this.statusTarget.textContent = message
    }

    showSpinner() {
        if (this.hasStatusSpinnerTarget) this.statusSpinnerTarget.style.display = 'inline-block'
    }

    hideSpinner() {
        if (this.hasStatusSpinnerTarget) this.statusSpinnerTarget.style.display = 'none'
    }

    // Friendly “2, 5 and 7” formatting
    formatIdList(ids = []) {
        const a = (ids || []).map(String)
        if (a.length <= 1) return a.join("")
        if (a.length === 2) return a.join(" and ")
        return `${a.slice(0, -1).join(", ")} and ${a[a.length - 1]}`
    }

    showSuccessDeleted(ids) {
        const list = this.formatIdList(ids)
        const label = ids.length === 1 ? "Submission" : "Submissions"
        this.showStatus(`${label} ${list} successfully deleted`)
        if (this.hasStatusTarget) {
            this.statusTarget.classList.remove("text-danger")
            this.statusTarget.classList.add("text-success")
        }
        this.hideSpinner()
    }

    showErrorMessage(msg) {
        this.showStatus(`Error: ${msg}`)
        if (this.hasStatusTarget) {
            this.statusTarget.classList.remove("text-success")
            this.statusTarget.classList.add("text-danger")
        }
        this.hideSpinner()
    }

    // mark rows as pending (dim + disable checkbox)
    markRowsPending(ids) {
        this.rowTargets.forEach(tr => {
            const id = tr.dataset.submissionId
            if (ids.includes(Number(id)) || ids.includes(String(id))) {
                tr.classList.add("opacity-50")
                const cb = tr.querySelector('input[type="checkbox"]')
                if (cb) cb.disabled = true
            }
        })
    }

    unmarkRowsPending(ids) {
        this.rowTargets.forEach(tr => {
            const id = tr.dataset.submissionId
            if (ids.includes(Number(id)) || ids.includes(String(id))) {
                tr.classList.remove("opacity-50")
                const cb = tr.querySelector('input[type="checkbox"]')
                if (cb) cb.disabled = false
            }
        })
    }

    // remove rows immediately (optimistic)
    // removeRowsByIds(ids) {
    //     this.rowTargets.forEach(tr => {
    //         const id = tr.dataset.submissionId
    //         if (ids.includes(Number(id)) || ids.includes(String(id))) {
    //             tr.remove()
    //         }
    //     })
    //     // re-evaluate windowing and controls
    //     this.totalValue = this.rowTargets.length
    //     this.updateLinksVisibility()
    //     this.updateDeleteButtonState()
    // }
}