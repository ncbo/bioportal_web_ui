import ReadMore from "stimulus-read-more";

// Connects to data-controller="text-truncate"
export default class extends ReadMore {
    static targets = ['button']

    connect() {
        super.connect()

        this.resizeObserver = new ResizeObserver(() => {
            if (this.contentTarget.clientHeight > 0 && !this.open) {
                if (!this.#isTextClamped()) {
                    this.#hideButton()
                } else {
                    this.buttonTarget.style.display = ''
                }
            }
        })

        this.resizeObserver.observe(this.contentTarget)

        if (this.contentTarget.clientHeight > 0 && !this.#isTextClamped()) {
            this.#hideButton()
        }
    }

    disconnect() {
        if (this.resizeObserver) {
            this.resizeObserver.disconnect()
        }
    }

    #isTextClamped() {
        return this.contentTarget.scrollHeight > this.contentTarget.clientHeight
    }

    #hideButton() {
        this.buttonTarget.style.display = 'none'
    }
}
