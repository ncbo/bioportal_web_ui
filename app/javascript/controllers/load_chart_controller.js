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

    const hasSecondaryAxis = datasets.some(d => d.yAxisID && d.yAxisID !== 'y')

    const scales = {
      x: this.#xScale(),
      y: this.#scales('y')
    }
    if (hasSecondaryAxis) {
      scales.y1 = this.#secondaryScale()
    }

    this.chart = new Chart(context, {
      type: this.typeValue,
      data: {
        labels: labels,
        datasets: datasets
      },
      plugins: [this.#yearSeparatorPlugin()],
      options: {
        indexAxis: this.indexAxisValue,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          colors: {enabled: true},
          title: {
            display: this.hasTitleValue,
            text: this.titleValue
          },
          legend: {
            display: this.legendValue,
            position: 'top',
            labels: {
              usePointStyle: true,
              boxWidth: 8,
              padding: 16
            }
          },
          tooltip: {
            backgroundColor: 'rgba(33, 33, 33, 0.92)',
            padding: 10,
            titleFont: { weight: '600' },
            bodySpacing: 4,
            cornerRadius: 6,
            usePointStyle: true,
            callbacks: {
              label: (ctx) => this.#tooltipLabel(ctx)
            }
          }
        },
        responsive: true,
        scales: scales,
      }
    })

  }

  #tooltipLabel (ctx) {
    const value = ctx.parsed.y
    const formatted = value.toLocaleString()
    const label = ctx.dataset.label || ''
    if (ctx.dataset.cumulative) {
      const previous = ctx.dataIndex > 0 ? ctx.dataset.data[ctx.dataIndex - 1] : 0
      const delta = value - previous
      const sign = delta >= 0 ? '+' : ''
      return `${label}: ${formatted} (${sign}${delta.toLocaleString()} this month)`
    }
    return `${label}: ${formatted}`
  }

  #xScale () {
    if (this.indexAxisValue !== 'x') {
      return this.#scales('x')
    }
    return {
      border: { display: false },
      grid: { display: false, drawTicks: false },
      ticks: {
        beginAtZero: false,
        maxRotation: 0,
        autoSkipPadding: 16,
        color: '#6c757d'
      }
    }
  }

  #yearSeparatorPlugin () {
    return {
      id: 'yearSeparator',
      beforeDatasetsDraw: (chart) => {
        const xScale = chart.scales.x
        if (!xScale) return
        const labels = chart.data.labels || []
        const { top, bottom } = chart.chartArea
        const yearOf = (label) => {
          const match = String(label || '').match(/(\d{4})/)
          return match ? match[1] : null
        }
        const ctx = chart.ctx
        ctx.save()
        ctx.strokeStyle = 'rgba(0, 0, 0, 0.15)'
        ctx.lineWidth = 1
        ctx.setLineDash([3, 3])
        let prev = null
        for (let i = 0; i < labels.length; i++) {
          const year = yearOf(labels[i])
          if (year && prev && year !== prev) {
            const x = xScale.getPixelForValue(i)
            ctx.beginPath()
            ctx.moveTo(x, top)
            ctx.lineTo(x, bottom)
            ctx.stroke()
          }
          if (year) prev = year
        }
        ctx.restore()
      }
    }
  }

  #secondaryScale () {
    return {
      position: 'right',
      border: { display: false },
      grid: { drawOnChartArea: false },
      ticks: {
        color: '#6c757d',
        padding: 8,
        maxTicksLimit: 6
      },
      beginAtZero: true
    }
  }

  disconnect () {
    this.chart.destroy()
    this.chart = null
  }

  #scales (axe) {
    if (this.indexAxisValue === axe) {
      return {
        border: { display: false },
        grid: { display: false },
        ticks: {
          beginAtZero: false,
          maxRotation: 0,
          autoSkipPadding: 16,
          color: '#6c757d'
        }
      }
    } else {
      return {
        border: { display: false },
        grid: {
          color: 'rgba(0, 0, 0, 0.06)',
          drawTicks: false
        },
        ticks: {
          color: '#6c757d',
          padding: 8,
          maxTicksLimit: 6
        },
        beginAtZero: true
      }
    }
  }
}
