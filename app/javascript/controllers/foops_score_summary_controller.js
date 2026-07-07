import { Controller } from "@hotwired/stimulus"
import { FairScorePrincipleBar, FairScoreCriteriaRadar, FairScoreChartContainer } from "../mixins/useFairScore";

export default class extends Controller {
  connect() {
    let fairScoreBar   = new FairScorePrincipleBar('ont-foops-scores-canvas')
    let fairScoreRadar = new FairScoreCriteriaRadar('ont-foops-criteria-scores-canvas')
    let fairContainer  = new FairScoreChartContainer('foops-score-charts-container', [fairScoreRadar, fairScoreBar])

    fairContainer.ajaxCall = function(ontologies) {
      return new Promise((resolve, reject) => {
        const badge = document.getElementById('foops-total-score')
        const hideBadge = () => badge?.closest('.right-button')?.classList.add('d-none')
        $.get(`/ajax/fair_score/json/?ontologies=${ontologies}&foops=true`, (data) => {
          if (data) {
            if (badge) {
              badge.textContent = `Total score : ${data.score} ( ${data.normalizedScore}%)`
              badge.closest('.right-button')?.classList.remove('fair-score-skeleton-pill')
            }
            resolve(data)
          } else {
            hideBadge()
            reject('no data')
          }
        }).fail(() => { hideBadge(); reject('error') })
      })
    }

    fairContainer.getFairScoreData(window.location.pathname.split('/')[2])
  }
}
