import { Controller } from '@hotwired/stimulus'
import Chart from 'chart.js/auto'

// Connects to data-controller="load-chart"
export default class extends Controller {

  static values = {
    labels: Array,
    datasets: Array,
    type: { type: String, default: 'line' },
    title: String,
    indexAxis: { type: String, default: 'x' },
    legend: { type: Boolean, default: false }
  }

  connect () {

    const labels = this.labelsValue
    const datasets = this.datasetsValue

    const context = this.element.getContext('2d')

    this.chart = new Chart(context, {
      type: this.typeValue,
      data: {
        labels: labels,
        datasets: datasets
      },
      options: {
        indexAxis: this.indexAxisValue,
        plugins: {
          colors: {enabled: true},
          title: {
            display: this.hasTitleValue,
            text: this.titleValue
          },
          legend: {
            display: this.legendValue
          }
        },
        responsive: true,
        scales: {
          x: this.#scales('x'),
          y: this.#scales('y')
        },
      }
    })

  }

  disconnect () {
    this.chart.destroy()
    this.chart = null
  }

  #scales (axe) {
    if (this.indexAxisValue === axe) {
      return {
        border: {
          display: false
        },
        grid: {
          display: false
        },
        ticks: {
          beginAtZero: false
        }
      }
    } else {
      return {
        border: {
          display: false
        },
        grid: {
          display: false
        },
        ticks: {
          display: false
        }
      }
    }
  }
}
