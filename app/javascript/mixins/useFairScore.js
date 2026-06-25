function round(val , base = 1){
    return Math.floor( val * 100 * base) / 100
}

function getObtainedNotObtainedNA(scoresIn, portalMax , max , normalize = true){
    const delimiter = (val) => (normalize ? val : 1)
    const notObtained = portalMax.map((x,i) => {
        return round((x - scoresIn[i]) / delimiter(max[i]) ,(normalize ? 100 : 1))
    })
    const na = max.map((x,i) => {
        return round((x - portalMax[i]) / delimiter(max[i]), (normalize ? 100 : 1))
    })

    const scores  = scoresIn.map((x, i ) => {
        return round(x / delimiter(max[i]), (normalize ? 100 : 1))
    })
    return {scores , notObtained , na}
}

function printScore(score, normalizedScore){
    return score +" "+'('+normalizedScore+"%)"
}


class FairScoreChartContainer{
    constructor(fairChartsContainerId , charts) {
        this.fairChartsContainer = jQuery("#"+fairChartsContainerId)
        this.fairAverageScoreSpan = jQuery("#fair-score-average")
        this.fairMinScoreSpan = jQuery("#fair-score-min")

        this.fairMaxScoreSpan = jQuery("#fair-score-max")


        this.fairMedianScoreSpan = jQuery("#fair-score-median")


        this.requestLink = jQuery("#fairness-service-url")
        this.requestHrefBase = (this.requestLink != null ?this.requestLink.attr("href") : "")

        this.fairSpinner = jQuery("<div id='fair-spinner-container' class='w-100 text-center'> <div class='spinner-grow'></div> </div>")
        this.fairMsgErr =  jQuery("<div id='fair-msg-container' class='w-100 text-center'>" + (this.fairChartsContainer.data('error-message') || 'We could not collect the data from the fairness service') + "</div>")
        this.fairMsgErr.hide()
        this.fairChartsContainer.before(this.fairSpinner)
        this.fairChartsContainer.before(this.fairMsgErr)
        this.charts = charts
    }


    ajaxCall(ontologies){
        return new Promise( (resolve  ,reject) => {
            $.get( "/ajax/fair_score/json/?ontologies="+ontologies, (data) => {
                if(data) {
                    resolve(data)
                }else {
                    reject("error")
                }
            }).fail(function(err) {
                reject("error")
            })
        })
    }
    getFairScoreData(ontologies) {
        if(this.fairChartsContainer){
            this.hideMsgError()
            this.showLoader();
            this.#updateLink(ontologies)
            this.ajaxCall(ontologies).then(data => {
                this.hideLoader()
                this.charts.forEach( x => x.setFairScoreData(data))
                this.#fillScoreSpans(data)
            }).catch(err => {
                this.hideLoader()
                this.showMsgError()
            })
        }


    }

    showMsgError(){
        this.fairChartsContainer.hide()
        this.fairMsgErr.show()
    }

    hideMsgError(){
        this.fairMsgErr.hide()
        this.fairChartsContainer.show()
    }
    showLoader(){
        this.fairChartsContainer.hide()
        this.fairSpinner.show()
    }
    hideLoader(){
        this.fairSpinner.hide()
        this.fairChartsContainer.show()
    }

    #updateLink(ontologies){
        if(this.requestLink){
            this.requestLink.attr("href" , this.requestHrefBase + "&ontologies=" + ontologies
                + (ontologies==="all" || ontologies.includes(",") ? "&combined": ""))

        }
    }
    #fillScoreSpans(data){

        if(this.fairAverageScoreSpan){
            this.fairAverageScoreSpan.html(printScore(data.score,data.normalizedScore))
        }

        if(data.resourceCount > 1){
            this.#showScoreLabel(this.fairMinScoreSpan, data.minScore, data.maxCredits)
            this.#showScoreLabel(this.fairMaxScoreSpan, data.maxScore, data.maxCredits)
            this.#showScoreLabel(this.fairMedianScoreSpan, data.medianScore, data.maxCredits)

        }else {
            this.#hideScoreLabel((this.fairMinScoreSpan))
            this.#hideScoreLabel((this.fairMaxScoreSpan))
            this.#hideScoreLabel((this.fairMedianScoreSpan))
        }


    }

    #showScoreLabel(elem, score , maxCredits){
        if(elem){
            elem.parent().parent().show()
            elem.html(printScore(score,round(score/maxCredits , 100)))
        }

    }

    #hideScoreLabel(elem){
        if(elem)
            elem.parent().parent().hide()
    }
}

class FairScoreChart{
    constructor(fairCanvasId , dataField) {
        this.dataField = dataField
        this.fairScoreChartCanvas =  jQuery("#"+fairCanvasId)
        this.chart= null
    }

    setFairScoreData(data){
        if(this.fairScoreChartCanvas){
            Object.entries(data[this.dataField]).forEach( ([key, value]) => this.fairScoreChartCanvas.data(key , value))
            this.fairScoreChartCanvas.data("resourceCount" , data["resourceCount"])
            if(this.chart === null)
                this.chart = this.initChart()
            else {
                this.chart.data.datasets = this.getFairScoreDataSet()
                this.chart.update()
            }
        }

    }

    getFairScoreDataSet(){
        return []
    }

    initChart(){
        return new Chart(this.fairScoreChartCanvas , {})
    }

}

class FairScorePrincipleBar extends  FairScoreChart{

    constructor(fairCanvasId) {
        super(fairCanvasId , 'principles');
    }
    initChart() {
        const labels = this.fairScoreChartCanvas.data('labels')
        const data = {
            labels: labels,
            datasets: this.getFairScoreDataSet()
        };
        const config = {
            type: 'horizontalBar',
            data: data,
            options: {
                title: {
                    display: false,
                    text: 'FAIRness Scores'
                },
                elements: {
                    bar: {
                        borderWidth: 2,
                    }
                },
                indexAxis: 'y',
                legend: {
                    display: true
                },
                scales: {
                    xAxes: [{
                        stacked: true,
                        ticks: {
                            beginAtZero: true
                        }
                    }],
                    yAxes: [{
                        stacked: true,
                        ticks: {
                            beginAtZero: true
                        }
                    }]
                },
                tooltips: {
                    callbacks: {
                        label: function (tooltipItem, data) {
                            let score =jQuery(this._chart.canvas).data("scores")[tooltipItem.index]
                            let maxScore =jQuery(this._chart.canvas).data("maxCredits")[tooltipItem.index]
                            let portalMaxScore =jQuery(this._chart.canvas).data("portalMaxCredits")[tooltipItem.index]

                            let normalizedScore = data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index]
                            let na = maxScore - portalMaxScore
                            let notObtained = portalMaxScore - score
                            return  printScore([score, notObtained, na][tooltipItem.datasetIndex], normalizedScore)
                        },

                    }
                }
            }
        }

        return new Chart(this.fairScoreChartCanvas, config);
    }
    getFairScoreDataSet(){
        const maxCredits = this.fairScoreChartCanvas.data('maxCredits')
        const portalMaxCredits = this.fairScoreChartCanvas.data('portalMaxCredits')
        const {scores, notObtained , na } = getObtainedNotObtainedNA( this.fairScoreChartCanvas.data('scores') , portalMaxCredits , maxCredits )
        return [
            {
                label: 'Obtained score',
                data: scores,
                fill: true,
                backgroundColor: 'rgba(102, 187, 106, 0.5)',
                borderColor: 'rgba(102, 187, 106, 1)',
                pointBorderColor: 'rgba(102, 187, 106, 1)',
                pointBackgroundColor: 'rgba(102, 187, 106, 1)'
            },
            {
                label: 'Not obtained score',
                data: notObtained,
                fill: true,
                backgroundColor: 'rgba(251, 192, 45, 0.5)',
                borderColor: 'rgba(251, 192, 45, 1)',
                pointBorderColor: 'rgba(251, 192, 45, 1)',
                pointBackgroundColor: 'rgba(251, 192, 45, 1)'
            },
            {
                label: 'Not yet supported',
                data: na,
                fill: true,
                backgroundColor: 'rgba(176, 190, 197, 0.5)',
                borderColor: 'rgba(176, 190, 197, 1)',
                pointBorderColor: 'rgba(176, 190, 197, 1)',
                pointBackgroundColor: 'rgba(176, 190, 197, 1)'
            }
        ]
    }
}

class FairScoreCriteriaRadar extends FairScoreChart{

    constructor(fairCanvasId) {
        super( fairCanvasId , 'criteria');
    }

    customTooltips(){
        return function (tooltipModel)  {
            // Tooltip Element
            let tooltipEl = document.getElementById('chartjs-tooltip');
            let canvas = jQuery(this._chart.canvas)
            let descriptions = canvas.data("descriptions")
            // Create element on first render
            if (!tooltipEl) {
                tooltipEl = document.createElement('div');
                tooltipEl.id = 'chartjs-tooltip';
                tooltipEl.innerHTML = '<table style="max-width: 250px"></table>';
                document.body.appendChild(tooltipEl);
            }

            // Hide if no tooltip
            if (tooltipModel.opacity === 0) {
                tooltipEl.style.opacity = 0;
                return;
            }

            // Set caret Position
            tooltipEl.classList.remove('above', 'below', 'no-transform');
            if (tooltipModel.yAlign) {
                tooltipEl.classList.add(tooltipModel.yAlign);
            } else {
                tooltipEl.classList.add('no-transform');
            }

            function getBody(bodyItem) {
                return bodyItem.lines;
            }
            // Set Text
            if (tooltipModel.body) {
                let titleLines = tooltipModel.title || [];
                let bodyLines = tooltipModel.body.map(getBody);

                let innerHtml = '<thead>';

                titleLines.forEach(function(title ,index) {
                    innerHtml += '<tr><th>' + title + ' : '+  descriptions[tooltipModel.dataPoints[0].index] + '</th></tr>';
                });
                innerHtml += '</thead><tbody>';

                bodyLines.forEach(function(body, i) {
                    let colors = tooltipModel.labelColors[i];
                    let style = 'background:' + colors.backgroundColor;
                    style += '; border-color:' + colors.borderColor;
                    style += '; border-width: 2px;';
                    style += '; font-size: 12px;';
                    innerHtml += '<tr><td class="badge" style="'+ style+'" >' + body + '</td></tr>';
                });
                innerHtml += '</tbody>';

                let tableRoot = tooltipEl.querySelector('table');
                tableRoot.innerHTML = innerHtml;
            }

            // `this` will be the overall tooltip
            let position = this._chart.canvas.getBoundingClientRect();

            // Display, position, and set styles for font
            tooltipEl.style.background = 'rgba(0, 0, 0, 0.7)';
            tooltipEl.style.borderRadius = '3px';
            tooltipEl.style.color = 'white';
            tooltipEl.style.opacity = 1;
            tooltipEl.style.position = 'absolute';
            tooltipEl.style.left = position.left + window.pageXOffset + tooltipModel.caretX + 'px';
            tooltipEl.style.top = position.top + window.pageYOffset + tooltipModel.caretY + 'px';
            tooltipEl.style.fontFamily = tooltipModel._bodyFontFamily;
            tooltipEl.style.fontSize = tooltipModel.bodyFontSize + 'px';
            tooltipEl.style.fontStyle = tooltipModel._bodyFontStyle;
            tooltipEl.style.padding = tooltipModel.yPadding + 'px ' + tooltipModel.xPadding + 'px';
            tooltipEl.style.pointerEvents = 'none';
        }
    }

    initChart() {
        const labels = this.fairScoreChartCanvas.data('labels')

        const data = {
            labels: labels,
            datasets: this.getFairScoreDataSet()
        };
        const config = {
            type: 'radar',
            data: data,
            options: {
                title: {
                    display: false,
                    text: 'FAIRness Wheel'
                },
                legend: {
                    display: false
                },
                elements: {
                    line: {
                        borderWidth: 3
                    }
                },
                tooltips: {
                    enabled: false,
                    custom: this.customTooltips(),
                    callbacks: {
                        label: function (tooltipItem, data) {
                            let scores =jQuery(this._chart.canvas).data("scores")
                            let normalizedScore = data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index]
                            let score = scores[tooltipItem.index]
                            return  printScore(score, normalizedScore)
                        },

                    }
                }
            }
        }

        return new Chart(this.fairScoreChartCanvas, config);
    }

    getFairScoreDataSet() {
        const scores = this.fairScoreChartCanvas.data('normalizedScores')
        return [
            {
                label: 'Fair score',
                data: scores,
                fill: true,
                backgroundColor: 'rgba(151, 187, 205, 0.5)',
                borderColor: 'rgba(151, 187, 205, 1)',
                pointBorderColor: 'rgba(151, 187, 205, 1)',
                pointBackgroundColor: 'rgba(151, 187, 205, 1)'
            }
        ]
    }



}
class FairScoreCriteriaBar extends  FairScoreChart{
    constructor(fairCanvasId) {
        super(fairCanvasId , 'criteria');
        this.questions = []
    }
    customTooltips(){
        return function (tooltipModel)  {
            let tooltipContainer = document.getElementById('chartjs-tooltip-container')
            // Tooltip Element
            let tooltipEl = document.getElementById('chartjs-tooltip')
            let canvas = jQuery(this._chart.canvas)
            let questions = canvas.data("questions")
            let descriptions = canvas.data("descriptions")
            let resourceCount  = canvas.data("resourceCount")

            // Create element on first render
            if (!tooltipEl) {
                tooltipEl = document.createElement('div');
                tooltipEl.id = 'chartjs-tooltip';
                tooltipEl.innerHTML = '<div class="card"></div>';
                tooltipContainer.appendChild(tooltipEl);
            }

            // Hide if no tooltip
            if (tooltipModel.opacity === 0) {
                tooltipEl.style.opacity = 1;
                return;
            }

            // Set caret Position
            tooltipEl.classList.remove('above', 'below', 'no-transform');
            if (tooltipModel.yAlign) {
                tooltipEl.classList.add(tooltipModel.yAlign);
            } else {
                tooltipEl.classList.add('no-transform');
            }

            function getBody(bodyItem) {
                return bodyItem.lines;
            }

            // Set Text
            if (tooltipModel.body) {
                let titleLines = tooltipModel.title || [];
                let bodyLines = tooltipModel.body.map(getBody);

                let innerHtml = '<div class="card-body" style="text-align: start">';

                titleLines.forEach(function(title ,index) {
                    innerHtml += '<h5 class="card-title">' + title + ' : '+  descriptions[tooltipModel.dataPoints[0].index] + '</h5>';
                });

                innerHtml += "<div class='d-flex flex-wrap'>"
                bodyLines.forEach(function(body, i) {
                    let colors = tooltipModel.labelColors[i];
                    let style = 'background:' + colors.backgroundColor;
                    style += '; border-color:' + colors.borderColor;
                    style += '; border-width: 2px';
                    style += '; width: 100%';
                    innerHtml += '<span class="btn card-subtitle m-2 text-muted" style="'+ style+'">' + body + '</span>';
                });

                innerHtml+='</div> <ul class="list-group list-group-flush" style="font-size: medium">'


                for (const [key, value] of Object.entries(questions[tooltipModel.dataPoints[0].index])) {
                    let count = (value.state ? (value.state.success + value.state.average) : (value.score === value.maxCredits ? 1: 0) )
                    innerHtml+=`<li class="list-group-item">
                        <strong>${printScore(count,round((count / resourceCount) * 100))}</strong>
                        responded successfully to: <strong>${key}: </strong>
                        <span class="font-italic">"${value.question}"</span></li>`
                }
                innerHtml += '</ul></div>';

                let tableRoot = tooltipEl.querySelector('div');
                tableRoot.innerHTML = innerHtml;
            }

            // `this` will be the overall tooltip
            let position = this._chart.canvas.getBoundingClientRect()
            let topOffset = tooltipModel.caretY - (tooltipEl.clientHeight / 2)


            if (topOffset  <= 0)
                topOffset = 0
            else if( (topOffset + tooltipEl.clientHeight) >=  position.height)
                topOffset = position.height - tooltipEl.clientHeight

            // Display, position, and set styles for font
            tooltipEl.style.opacity = 1;
            tooltipEl.style.position = 'absolute';
            tooltipEl.style.top = topOffset +'px';
            //tooltipEl.style.fontFamily = tooltipModel._bodyFontFamily;
            tooltipEl.style.fontSize = tooltipModel.bodyFontSize + 'px';
            tooltipEl.style.fontStyle = tooltipModel._bodyFontStyle;
            tooltipEl.style.padding = tooltipModel.yPadding + 'px ' + tooltipModel.xPadding + 'px';
            tooltipEl.style.pointerEvents = 'none';
        }
    }
    initChart() {
        const labels = this.fairScoreChartCanvas.data('labels')
        const data = {
            labels: labels,
            datasets: this.getFairScoreDataSet()
        };
        const config = {
            type: 'horizontalBar',
            data: data,
            options: {
                title: {
                    display: false,
                    text: 'FAIRness Scores'
                },
                elements: {
                    bar: {
                        borderWidth: 2,
                    }
                },
                indexAxis: 'y',
                legend: {
                    display: true
                },
                scales: {
                    xAxes: [{
                        stacked: true,
                        ticks: {
                            beginAtZero: true,

                        }
                    }],
                    yAxes: [{
                        stacked: true,
                        ticks: {
                            beginAtZero: true,

                        }
                    }]
                },
                tooltips: {
                    enabled: false,
                    mode: 'index',
                    position: 'nearest',
                    intersect: false,
                    custom: this.customTooltips(),
                    callbacks: {
                        label: function (tooltipItem, data) {
                            const canvas = jQuery(this._chart.canvas)
                            const max = canvas.data('maxCredits')
                            const scores = canvas.data('scores')
                            const portalMax = canvas.data("portalMaxCredits")

                            const label  = data.datasets[tooltipItem.datasetIndex].label
                            const score =   data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index]
                            const normalizedScore =Object.values(getObtainedNotObtainedNA(scores ,portalMax , max , false))[tooltipItem.datasetIndex][tooltipItem.index]

                            return  label +': '+ printScore(score, normalizedScore)

                        }
                    }
                }

            }
        }

        return new Chart(this.fairScoreChartCanvas, config);
    }
    getFairScoreDataSet(){
        const maxCredits = this.fairScoreChartCanvas.data('maxCredits')
        const portalMaxCredits = this.fairScoreChartCanvas.data('portalMaxCredits')
        const {scores , notObtained , na } = getObtainedNotObtainedNA(this.fairScoreChartCanvas.data('scores'), portalMaxCredits ,maxCredits , true)
        return [
            {
                label: 'Obtained score',
                data: scores ,
                fill: true,
                backgroundColor: 'rgba(102, 187, 106, 0.5)',
                borderColor: 'rgba(102, 187, 106, 1)',
                pointBorderColor: 'rgba(102, 187, 106, 1)',
                pointBackgroundColor: 'rgba(102, 187, 106, 1)'
            },
            {
                label: 'Not obtained score',
                data:  notObtained,
                fill: true,
                backgroundColor: 'rgba(251, 192, 45, 0.5)',
                borderColor: 'rgba(251, 192, 45, 1)',
                pointBorderColor: 'rgba(251, 192, 45, 1)',
                pointBackgroundColor: 'rgba(251, 192, 45, 1)',
            },
            {
                label: 'Not yet supported',
                data: na,
                fill: true,
                backgroundColor: 'rgba(176, 190, 197, 0.5)',
                borderColor: 'rgba(176, 190, 197, 1)',
                pointBorderColor: 'rgba(176, 190, 197, 1)',
                pointBackgroundColor: 'rgba(176, 190, 197, 1)'
            }
        ]
    }
    setFairScoreData(data) {
        super.setFairScoreData(data);
        if(this.chart){
            this.showFirstToolTip()
        }
    }

    showFirstToolTip(){
        let meta = this.chart.getDatasetMeta(0),
            rect = this.chart.canvas.getBoundingClientRect(),
            point = meta.data[0].getCenterPoint(),
            evt = new MouseEvent('mousemove', {
                clientX: rect.left + point.x,
                clientY: rect.top + point.y
            }),
            node = this.chart.canvas;
        node.dispatchEvent(evt);
    }
}

export {round, getObtainedNotObtainedNA, FairScoreChartContainer, FairScoreChart, FairScorePrincipleBar, FairScoreCriteriaRadar, FairScoreCriteriaBar}

