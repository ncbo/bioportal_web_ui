// app/javascript/controllers/user_ontology_log_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["content"]
    static values  = { url: String }

    connect() { this.load() }
    refresh(e){ if (e) e.preventDefault(); this.load() }

    load() {
        if (!this.hasUrlValue) { this.contentTarget.textContent = "Missing URL"; return }
        this.contentTarget.textContent = "Loading…"
        fetch(this.urlValue, { headers: { Accept: "text/plain" }})
            .then(r => r.text())
            .then(text => this.render(text))
            .catch(err => this.contentTarget.textContent = `Failed to load log: ${err}`)
    }

    render(text) {
        // 1) Escape HTML to avoid XSS
        const escape = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        let html = escape(text);

        // 2) Highlight Unix-y file paths FIRST, and avoid touching HTML tags.
        //    We capture a non-'<' prefix and re-insert it to avoid matching `</span>`.
        html = html.replace(
            /(^|[^<])((?:\/[A-Za-z0-9._\-]+)+)/gm,
            (_, pre, path) => `${pre}<span class="path">${path}</span>`
        );

        // ISO-ish at line start
        html = html.replace(
            /^(\d{4}-\d{2}-\d{2}T?\d{2}:\d{2}:\d{2}(?:[Z+-]\d{2}:\d{2})?)/gm,
            '<span class="ts">$1</span>'
        );

        // Short HH:MM:SS (no fraction)
        html = html.replace(
            /^(\d{2}:\d{2}:\d{2})/gm,
            '<span class="ts">$1</span>'
        );
        // 5) Levels (both single-letter and words)
        html = html
            .replace(/\b(INFO)\b/g,  '<span class="lvl-info">$1</span>')
            .replace(/\b(WARN|WARNING)\b/g, '<span class="lvl-warn">$1</span>')
            .replace(/\b(ERROR|ERR|FATAL)\b/g, '<span class="lvl-error">$1</span>')
            .replace(/\b(DEBUG)\b/g, '<span class="lvl-debug">$1</span>')
            .replace(/(?<=\s|\[|^)(I)(?=\s|,|\]|$)/g, '<span class="lvl-info">$1</span>')
            .replace(/(?<=\s|\[|^)(W)(?=\s|,|\]|$)/g, '<span class="lvl-warn">$1</span>')
            .replace(/(?<=\s|\[|^)(E)(?=\s|,|\]|$)/g, '<span class="lvl-error">$1</span>')
            .replace(/(?<=\s|\[|^)(D)(?=\s|,|\]|$)/g, '<span class="lvl-debug">$1</span>');

        // 5b) Optional: emphasize Ruby/Java-style exception class names ending with Error
        html = html.replace(/\b[A-Za-z0-9_:]*Error\b/g, '<span class="exc">$&</span>');

        // 5c) Line-level coloring based on presence of level spans
        html = html
            .split('\n')
            .map(line => {
                if (line.includes('lvl-error')) return `<span class="line-error">${line}</span>`;
                if (line.includes('lvl-warn'))  return `<span class="line-warn">${line}</span>`;
                return line;
            })
            .join('\n');

        // 6) Inject as HTML
        this.contentTarget.innerHTML = html;
    }
}