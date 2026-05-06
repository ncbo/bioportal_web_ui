import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "searchWrapper", "picked", "deleteIconTemplate"]
  static values = {
    namePrefix: String,
    rowClass: { type: String, default: "nested-class-picker-form-input-row" },
    showUri: { type: Boolean, default: false },
    single: { type: Boolean, default: false }
  }

  addResult(event) {
    event.preventDefault()
    const target = event.currentTarget

    const uriSpan = target.querySelector('.class-uri')
    const labelSpan = target.querySelector('.class-label_name')
    if (!uriSpan || !labelSpan) return

    const uri = uriSpan.textContent.trim()
    const label = labelSpan.textContent.trim()

    if (this.singleValue) {
      this.replacePicked(label, uri)
    } else {
      this.appendRow(label, uri)
    }
  }

  replacePicked(label, uri) {
    if (!this.hasPickedTarget) return
    this.pickedTarget.replaceChildren()

    const wrapper = document.createElement("div")
    wrapper.className = "d-flex align-items-center nested-form-wrapper my-1"

    const displayWrapper = document.createElement("div")
    displayWrapper.style.width = "90%"
    displayWrapper.appendChild(this.buildDisplay(label, uri))

    const deleteWrapper = document.createElement("div")
    deleteWrapper.className = "d-flex justify-content-end"
    deleteWrapper.style.width = "10%"

    const removeBtn = document.createElement("div")
    removeBtn.className = "delete"
    removeBtn.dataset.action = "click->class-picker#removePicked"
    removeBtn.innerHTML = this.deleteIconHtml()
    deleteWrapper.appendChild(removeBtn)

    wrapper.appendChild(displayWrapper)
    wrapper.appendChild(deleteWrapper)

    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = this.namePrefixValue
    hiddenInput.value = uri

    this.pickedTarget.appendChild(wrapper)
    this.pickedTarget.appendChild(hiddenInput)

    if (this.hasSearchWrapperTarget) {
      this.searchWrapperTarget.remove()
    }
  }

  removePicked(event) {
    event.preventDefault()
    if (!this.hasPickedTarget) return
    this.pickedTarget.replaceChildren()

    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = this.namePrefixValue
    hiddenInput.value = ""
    this.pickedTarget.appendChild(hiddenInput)
  }

  deleteIconHtml() {
    if (this.hasDeleteIconTemplateTarget) {
      return this.deleteIconTemplateTarget.innerHTML
    }
    const existing = this.element.querySelector(".delete svg")
    return existing ? existing.outerHTML : ""
  }

  appendRow(label, uri) {
    const namePrefix = this.namePrefixValue
    const rowClass = this.rowClassValue
    const nextIndex = document.querySelectorAll(`.${rowClass}`).length

    const row = document.createElement("div")
    row.className = rowClass

    if (this.showUriValue) {
      row.appendChild(this.buildDisplay(label, uri))
    } else {
      const visibleInput = document.createElement("input")
      visibleInput.type = "text"
      visibleInput.name = `${namePrefix}[${nextIndex}]`
      visibleInput.value = label
      visibleInput.readOnly = true
      visibleInput.className = "form-control"
      visibleInput.style.fontSize = "13px"
      row.appendChild(visibleInput)
    }

    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = `${namePrefix}[${nextIndex}]`
    hiddenInput.value = uri
    row.appendChild(hiddenInput)

    this.element.appendChild(row)

    if (this.hasSearchWrapperTarget) {
      this.searchWrapperTarget.remove()
    }
  }

  buildDisplay(label, uri) {
    const display = document.createElement("div")
    display.className = "class-picker-display"

    const labelEl = document.createElement("p")
    labelEl.className = "class-label_name"
    labelEl.textContent = label

    const uriEl = document.createElement("small")
    uriEl.className = "class-uri"
    uriEl.textContent = uri

    display.appendChild(labelEl)
    display.appendChild(uriEl)
    return display
  }
}
