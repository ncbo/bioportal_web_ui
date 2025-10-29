// Entry point for the build script in your package.json


import { Turbo } from "@hotwired/turbo-rails";
import "./controllers";
import "./component_controllers";

Turbo.session.drive = false;
Turbo.config.forms.confirm = (message) => {
    return new Promise((resolve, reject) => {
        alertify.confirm(message, (e) => {
            resolve(e)
        })
    })
}


