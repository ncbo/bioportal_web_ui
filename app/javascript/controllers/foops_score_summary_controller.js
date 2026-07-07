import { Controller } from "@hotwired/stimulus"
import { FairScorePrincipleBar, FairScoreCriteriaRadar, FairScoreChartContainer } from "../mixins/useFairScore";

export default class extends Controller {
  connect() {
    let fairScoreBar   = new FairScorePrincipleBar('ont-foops-scores-canvas')
    let fairScoreRadar = new FairScoreCriteriaRadar('ont-foops-criteria-scores-canvas')
    let fairContainer  = new FairScoreChartContainer('foops-score-charts-container', [fairScoreRadar, fairScoreBar])

    fairContainer.ajaxCall = function(ontologies) {
      return new Promise((resolve, reject) => {
        $.get(`/ajax/fair_score/json/?ontologies=${ontologies}&foops=true`, (data) => {
          if (data) {
            const badge = document.getElementById('foops-total-score')
            if (badge) {
              badge.textContent = `Total score : ${data.score} ( ${data.normalizedScore}%)`
              badge.closest('.right-button')?.classList.remove('d-none')
            }
            resolve(data)
          } else {
            reject('no data')
          }
        }).fail(() => reject('error'))
      })
    }

    fairContainer.getFairScoreData(window.location.pathname.split('/')[2])
  }
}
