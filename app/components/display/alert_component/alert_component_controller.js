import { Controller } from "@hotwired/stimulus";

export default class extends Controller {

  static  values = {
    autoCloseAfter: { type: Number, default: 5000 },
    autoClose: { type: Boolean, default: false },
  }
  connect(){
    if (this.autoCloseValue){
      setTimeout(() => {
       this.close()
      }, this.autoCloseAfterValue);
    }
  }
  close(){
    this.element.style.display = "none"
  }
}
