import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="change-requests"
export default class extends Controller {
  static targets = [ 'proposalForm' ]

  clearProposalForm() {
    this.proposalFormTarget.innerHTML = '';
  }

  hideForm(event) {
    if (event.detail.success) {
      this.clearProposalForm();
    }
  }
}
