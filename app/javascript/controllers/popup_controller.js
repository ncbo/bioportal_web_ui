import { Controller } from '@hotwired/stimulus';
import { openPopup } from '../utils/open_popup';

// Connects to data-controller="popup"
export default class extends Controller {
  static values = {
    width: { type: Number, default: 800 },
    height: { type: Number, default: 600 },
  };

  open(event) {
    event.preventDefault();

    const url = event.currentTarget.getAttribute('href');
    const width = this.widthValue;
    const height = this.heightValue;

    openPopup(url, width, height);
  }
}
