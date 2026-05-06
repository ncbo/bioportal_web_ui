import { Controller } from '@hotwired/stimulus'
import { useTomSelect } from '../../javascript/mixins/useTomSelect'

export default class SelectInput extends Controller {
  static DISPLAY_VALUE = 'value'
  static DISPLAY_TEXT = 'text'

  static values = {
    multiple: { type: Boolean, default: false },
    openAdd: { type: Boolean, default: false },
    required: { type: Boolean, default: false },
    searchable: { type: Boolean, default: true },
    displayField: { type: String, default: SelectInput.DISPLAY_TEXT },
    remoteUrl: { type: String, default: '' },
    remoteQueryParam: { type: String, default: 'q' }
  }

  connect () {
    let myOptions = {}
    myOptions = {
      render: {
        option: (data) => {
          return `<div> ${data.text} </div>`
        },
        item: (data) => {
          if (this.displayFieldValue === SelectInput.DISPLAY_TEXT) {
            return `<div> ${data.text} </div>`
          } else {
            return `<div> ${data.value} </div>`
          }
        }
      }
    }

    myOptions['maxOptions'] = 100

    if(!this.searchableValue){
      myOptions['controlInput'] = null
    }

    if (this.multipleValue) {
      myOptions['onItemAdd'] = function () {
        this.setTextboxValue('')
        this.refreshOptions()
      }
      myOptions['plugins'] = ['remove_button']
    }

    if (this.openAddValue) {
      myOptions['create'] = true
    }

    if (this.remoteUrlValue) {
      const url = this.remoteUrlValue
      const param = this.remoteQueryParamValue
      myOptions['loadThrottle'] = 250
      myOptions['shouldLoad'] = (q) => q.length >= 3
      myOptions['load'] = (query, callback) => {
        fetch(`${url}?${param}=${encodeURIComponent(query)}`, {
          headers: { Accept: 'application/json' }
        })
          .then((r) => (r.ok ? r.json() : []))
          .then(callback)
          .catch(() => callback())
      }
    }

    this.select = useTomSelect(this.element, myOptions, this.#triggerChange.bind(this))
    this.element.style.visibilty = 'hidden';

    [...this.element.attributes].forEach(attribute => {
      if(attribute.name !== 'class' && attribute.name !== 'style' && attribute.name !== 'id' && attribute.name !== 'name'){
        this.select.control.setAttribute(attribute.name, attribute.value.replace('select-input', ''))
        if(attribute.name === 'title'){
          this.select.control.setAttribute('data-controller', 'tooltip')
        }
      }
    })
  }

  #triggerChange () {
    if (this.#isRequired() && !this.#isMultiple() && this.#isEmpty()) {
      this.#selectFirstItem()
    }

    document.dispatchEvent(new Event('change', { target: this.element }))
  }

  #isRequired () {
    return this.requiredValue
  }

  #isMultiple () {
    return this.multipleValue
  }

  #isEmpty () {
    return this.select.getValue() === ''
  }

  #selectFirstItem () {
    this.select.setValue(Object.keys(this.select.options)[0], true)
  }
}