import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "tab"]

  static values = {
    loop: { type: Boolean, default: false },
    prevSelector: { type: String, default: ".carousel-btn-prev" },
    nextSelector: { type: String, default: ".carousel-btn-next" },
  }

  connect() {
    this.current = 0
    this.updateUI()
  }

  get slidesCount() {
    return this.containerTarget.children.length
  }

  prev() {
    if (this.loopValue && this.current === 0) {
      this.current = this.slidesCount - 1
    } else if (this.current > 0) {
      this.current--
    } else {
      return
    }
    this.slideTo(this.current)
  }

  next() {
    if (this.loopValue && this.current >= this.slidesCount - 1) {
      this.current = 0
    } else if (this.current < this.slidesCount - 1) {
      this.current++
    } else {
      return
    }
    this.slideTo(this.current)
  }

  goTo(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    if (index >= 0) {
      this.current = index
      this.slideTo(this.current)
    }
  }

  slideTo(index) {
    if (this.hasContainerTarget) {
      this.containerTarget.style.transform = `translateX(-${index * 100}%)`
    }
    this.updateUI()
  }

  updateUI() {
    const max = this.slidesCount - 1
    const prevBtn = this.element.querySelector(this.prevSelectorValue)
    const nextBtn = this.element.querySelector(this.nextSelectorValue)

    if (prevBtn) {
      prevBtn.classList.toggle("disabled", !this.loopValue && this.current === 0)
    }
    if (nextBtn) {
      nextBtn.classList.toggle("disabled", !this.loopValue && this.current >= max)
    }

    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("active", i === this.current)
    })
  }
}
