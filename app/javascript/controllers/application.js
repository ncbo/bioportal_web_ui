import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

import NestedForm from 'stimulus-rails-nested-form'
application.register('nested-form', NestedForm)

export { application }
