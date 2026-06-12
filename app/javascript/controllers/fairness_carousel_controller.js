import CarouselController from "./carousel_controller"

export default class extends CarouselController {
  static values = {
    ...CarouselController.values,
    prevSelector: { type: String, default: ".fairness-carousel-btn-prev" },
    nextSelector: { type: String, default: ".fairness-carousel-btn-next" },
  }
}
