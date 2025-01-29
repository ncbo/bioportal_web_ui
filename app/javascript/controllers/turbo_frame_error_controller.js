import Turbo_frame_controller from "./turbo_frame_controller";

// Connects to data-controller="turbo-frame-error"
export default class extends Turbo_frame_controller {

  static targets = ['frame', 'errorMessage']

  hideError(){
    this.#hideError()
  }

  showError(event) {
    let response = event.detail.fetchResponse
    if (!response.succeeded) {
      event.preventDefault()
      response = response.response.clone()
      response.text().then(text => {
          this.#hideContent()
          this.#displayError(text)
      })

    }
  }

  #hideContent(){
    $(this.frameTarget.firstElementChild).hide()
  }

  #displayError(error){
    let el = document.createElement('div')
    el.innerHTML = error

    let styles = el.getElementsByTagName('style')
    Array.from(styles).forEach(e => el.removeChild(e))

    let body = el.querySelector('h1')
    this.errorMessageTarget.firstElementChild.querySelector('.alert-message').innerHTML =  (body ? body.innerText : el.innerHTML)
    $(this.errorMessageTarget).show()
  }

  #hideError(){
    let count = this.errorMessageTarget.firstElementChild.childElementCount
    if(count !== 0) {
      $(this.errorMessageTarget).hide()
    }
  }
}
