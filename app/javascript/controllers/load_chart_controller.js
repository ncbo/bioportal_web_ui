import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="load-chart"
export default class extends Controller {

  static values = {
    labels: Array,
    datasets: Array
  }
  connect() {

    const labels = this.labelsValue;
    const datasets = this.datasetsValue;

    const context = this.element.getContext('2d');

    this.chart = new Chart(context, {
      type: 'line',
      data: {
        labels: labels,
        datasets: datasets
      },
      options: {
        responsive: true,
        legend: {
          display: false
        },
        scales: {
          yAxes: [{
            ticks: {
              beginAtZero: false,
              callback: function (value, index, values) {
                return numberWithCommas(value);
              }
            }
          }]
        },
        tooltips: {
          displayColors: false,
          callbacks: {
            label: function (tooltipItem, data) {
              return numberWithCommas(tooltipItem.yLabel);
            }
          }
        }
      }
    });
  }

  disconnect () {
    this.chart.destroy()
    this.chart = null
  }

}
