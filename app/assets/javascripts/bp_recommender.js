// Namespace for global variables and functions
var rec = { }
rec.maxInputWords = 500;

rec.showOrHideAdvancedOptions = function() {
  $("#advancedOptions").toggle();
  var text = $("#advancedOptions").is(':visible') ? "Hide advanced options <<" : "Show advanced options >>";
  $("#advancedOptionsLink").text(text);
}

rec.insertInput = function(event) {
    event.preventDefault();
    rec.prepareForRealInput();
    if ($("#radioItText").is(":checked")) {
        rec.insertSampleText()
    }
    else {
        rec.insertSampleKeywords()
    }
}

rec.defaultMessage = true;
rec.prepareForRealInput = function() {
    rec.emptyInput = false;
    if (rec.defaultMessage == true) {
        $("#inputText").val('');
        rec.defaultMessage = false;
    }
}

rec.enableEdition = function() {
    $("#inputText").show();
    $("#inputTextHighlighted").hide();
    $("#resultsHeader").empty();
    $("#recommender-results").empty();
    $("#editButton").hide();
    $("#recommenderButton").show();
    $("#insertInputLink").show();
    $("input[name=input_type]").attr("disabled",false);
}

rec.insertSampleText = function() {
    rec.enableEdition();
    var text = 'Primary treatment of DCIS now includes 3 options: lumpectomy without lymph node surgery plus whole breast radiation (category 1); total mastectomy with or without sentinel node biopsy with or without reconstruction (category 2A); lumpectomy without lymph node surgery without radiation (category 2B). Workup for patients with clinical stage l, llA, llB, or T3,N1,M0 disease was reorganized to distinguish optional additional studies from those recommended for all of these patients. Recommendation for locoregional treatment for patients with clinical stage l, llA, llB, or T3,N1,M0 disease with 1-3 positive axillary nodes following total mastectomy was changed from "Consider" to "Strongly consider" postmastectomy radiation therapy. ';
    jQuery("#inputText").focus();
    jQuery("#inputText").val(text);
    $(".notTextError").hide();
    $("#radioItText").prop("checked", true);
}

rec.insertSampleKeywords = function() {
    rec.enableEdition();
    var text = "Backpain, White blood cell, Carcinoma, Cavity of stomach, Ductal Carcinoma in Situ, Adjuvant chemotherapy, Axillary lymph node staging, Mastectomy, tamoxifen, serotonin reuptake inhibitors, Invasive Breast Cancer, hormone receptor positive breast cancer, ovarian ablation, premenopausal women, surgical management, biopsy of breast tumor, Fine needle aspiration, entinel lymph node, breast preservation, adjuvant radiation therapy, prechemotherapy, Inflammatory Breast Cancer, ovarian failure, Bone scan, lumpectomy, brain metastases, pericardial effusion, aromatase inhibitor, postmenopausal, Palliative care, Guidelines, Stage IV breast cancer disease, Trastuzumab, Breast MRI examination";
    jQuery("#inputText").focus();
    jQuery("#inputText").val(text);
    $(".notTextError").hide();
    $("#radioItKeywords").prop("checked", true);
}

rec.colors = ["#234979" , "#cc0000", "#339900", "#ff9900"];
rec.getHighlightedTerms = function(data, rowNumber) {
    var inputText = document.getElementById("inputText").value;
    var newText = '';
    var lastPosition = 0;
    var ontologyIds = [ ];
    for (var k = 0; k < data[rowNumber].ontologies.length; k++) {
        ontologyIds[k] = data[rowNumber].ontologies[k]["@id"];
    }
    for (var j = 0; j < data[rowNumber].coverageResult.annotations.length; j++) {
        var from = data[rowNumber].coverageResult.annotations[j].from-1;
        var to = data[rowNumber].coverageResult.annotations[j].to;
        var term = inputText.substring(from, to);
        var ontologyId = data[rowNumber].coverageResult.annotations[j].annotatedClass.links.ontology;
        
        // Color selection - Single ontology
        if (data[rowNumber].ontologies.length == 1) {
            var color = rec.colors[0];
        }
        // Color selection - Set of ontologies
        else {
            var index = ontologyIds.indexOf(ontologyId);
            var color = rec.colors[index];
        }

        var clsId = data[rowNumber].coverageResult.annotations[j].annotatedClass["@id"];
        var ontAcronym = ontologyId.slice(ontologyId.lastIndexOf("/") + 1);
        var replacement = '<a style="font-weight: bold; color:' + color + '" target="_blank" href=' + bp_cls_link(clsId, ontAcronym) + '>' + term + '</a>';

        if (from>lastPosition) {
            newText+=inputText.substring(lastPosition, from);
        }
        newText += replacement;
        lastPosition = to;
    }

    if (lastPosition < inputText.length) {
        newText += inputText.substring(lastPosition, inputText.length);
    }
    return newText;
}

rec.hideErrorMessages = function() {
    $(".generalError").hide();
    $(".inputSizeError").hide();
    $(".invalidWeightsError").hide();
    $(".rangeWeightsError").hide();
    $(".sumWeightsError").hide();
    $(".maxOntologiesError").hide();
    $(".invalidMaxOntError").hide();
    $(".notTextError").hide();
    $("#noResults").hide();
    $("#noResultsSets").hide();
}

rec.getRecommendations = function() {
    rec.hideErrorMessages();
    var errors = false;
    // Checks if the input text field is empty
    if (($("#inputText").val().length == 0) || (rec.emptyInput==true))  {
        $(".notTextError").show();
        errors = true;
    }
    // Checks the input size using a basic word counter
    if ($("#inputText").val().split(' ').length > rec.maxInputWords) {
        $(".inputSizeError").show();
        errors = true;
    }
    var wc = parseFloat($("#input_wc").val());
    var wa = parseFloat($("#input_wa").val());
    var wd = parseFloat($("#input_wd").val());
    var ws = parseFloat($("#input_ws").val());
    // Parameters validation
    if (isNaN(wc)||isNaN(wa)||isNaN(wd)||isNaN(ws)) {
        $(".invalidWeightsError").show();
        errors = true;
    }

    if ((wc < 0)||(wa < 0)||(wd < 0)||(ws < 0)) {
        $(".rangeWeightsError").show();
        errors = true;
    }

    if (wc + wa + wd + ws <= 0) {
        $(".sumWeightsError").show();
        errors = true;
    }

    var maxOntologies = parseInt($('#input_max_ontologies').val());

    if (isNaN(maxOntologies)||(maxOntologies%1!=0)) {
        $(".invalidMaxOntError").show();
        errors = true;
    }

    if ((maxOntologies < 2)||(maxOntologies > 4)) {
        $(".maxOntologiesError").show();
        errors = true;
    }

    if (!errors) {
        rec.hideErrorMessages();
        $(".recommenderSpinner").show();
        var params = {};
        var ont_select = jQuery("#ontology_ontologyId");
        params.input = $("#inputText").val();
        params.ontologies = (ont_select.val() === null) ? [] : ont_select.val();
        // Input type (text or keywords)
        if ($("#radioItText").is(":checked"))
            params.input_type = 1; //text
        else
            params.input_type = 2; //keywords
        // Output type (ontologies or ontology sets)
        if ($("#radioOtSingle").is(":checked"))
            params.output_type = 1; //ontologies
        else
            params.output_type = 2; //ontology sets
        // Weights
        params.wc = $("#input_wc").val();
        params.wa = $("#input_wa").val();
        params.wd = $("#input_wd").val();
        params.ws = $("#input_ws").val();
        // Maximum number of ontologies per set (only for the "ontology sets" output)
        params.max_elements_set = $('#input_max_ontologies').val();
        $.ajax({
            type: "POST",
            url: "/recommender",
            data: params,
            dataType: "json",
            success: function(data) {
                $('.recommenderSpinner').hide();
                if (data) {
                    if (data.length > 0) {
                        $("#recommender-results").empty();
                        $("#resultsHeader").text("Recommended ontologies");

                        if (params.output_type == 1) {
                            var ontologyHeader = "Ontology";
                        }
                        else {
                            ontologyHeader = "Ontologies";
                        }
                        var table = $('<table id="recommendations" class="zebra" width="100%"></table>');
                        var header = $('<thead><tr><th title="Position of the ontology in the ranking">POS.</th>'
                        + '<th title="Ontology acronym">' + ontologyHeader + '</th>'
                        + '<th title="Final recommendation score for the ontology. It represents the appropriateness of the ontology to describe the input data">Final score</th>'
                        + '<th title="The coverage score represents the extent to what the ontology covers the input data">Coverage score</th>'
                        + '<th title="The acceptance score represents how well known and trusted is the ontology by the biomedical community">Acceptance score</th>'
                        + '<th title="The detail score represents the richness of the ontology representation for the input data">Detail score</th>'
                        + '<th title="The specialization score represents the level of specialization of the ontology to the domain of the input data">Specialization score</th>'
                        + '<th title="Number of annotations performed with the ontology for the input data">Annotations</th>'
                        + '<th title="This columns makes it possible to highlight the annotations performed with each ontology" style="text-align: center">Highlight annotations</th>'
                        + '</tr></thead>');
                        table.append(header);
                        table.append('<tbody>');
                        for (var i = 0; i < data.length; i++) {
                            var position = i + 1;
                            // Terms covered
                            var terms = '';
                            for (var j = 0; j < data[i].coverageResult.annotations.length; j++) {
                                terms += ('<a target="_blank" href=' + data[i].coverageResult.annotations[j].annotatedClass.links.ui + '>' + data[i].coverageResult.annotations[j].text + '</a>, ');
                            }
                            // Remove last comma and white
                            terms = terms.substring(0, terms.length - 2);

                            var finalScore = data[i].evaluationScore * 100;
                            var coverageScore = data[i].coverageResult.normalizedScore * 100;
                            var acceptanceScore = data[i].acceptanceResult.normalizedScore * 100;
                            var detailScore = data[i].detailResult.normalizedScore * 100;
                            var specializationScore = data[i].specializationResult.normalizedScore * 100;

                            var row = '<tr><td>' + position + '</td><td>';

                            $.each(data[i].ontologies, function (j, item) {
                                var ontologyLinkStyle = 1;
                                if (params.output_type == 2) {
                                    ontologyLinkStyle = 'style="color: ' + rec.colors[j] + '"';
                                }
                                var ontAcronym = data[i].ontologies[j].acronym;
                                row += '<a ' + ontologyLinkStyle + '" target="_blank" href=' + bp_ont_link(ontAcronym) + '>' + ontAcronym + '</a><br />'});

                            row += "</td>";
                            row += 
                              '<td><div style="width:' + finalScore.toFixed(0) + '%;" class="final-score"><span class="score-number">' + finalScore.toFixed(1) + '</span></div></td>'
                            + '<td><div style="width:' + coverageScore.toFixed(0) + '%;" class="result-scores"><span class="score-number">' + coverageScore.toFixed(1) + '</span></div></td>'
                            + '<td><div style="width:' + acceptanceScore.toFixed(0) + '%;" class="result-scores"><span class="score-number">' + acceptanceScore.toFixed(1) + '</span></div></td>'
                            + '<td><div style="width:' + detailScore.toFixed(0) + '%;" class="result-scores"><span class="score-number">' + detailScore.toFixed(1) + '</span></div></td>'
                            + '<td><div style="width:' + specializationScore.toFixed(0) + '%;" class="result-scores"><span class="score-number">' + specializationScore.toFixed(1) + '</span></div></td>'
                            + '<td>' + data[i].coverageResult.annotations.length + '</td>'
                            + '<td>' + '<div style="text-align:center"><input style="vertical-align:middle" id="chk' + i + '" type="checkbox"/></div>'
                            + '</tr>';
                            table.append(row); // Append row to table
                        }
                        table.append('</tbody>');
                        $("#recommender-results").append(table); // Append table to your dom wherever you want

                        // Hide "Get Recommendations" button
                        $("#recommenderButton").hide();
                        $("#insertInputLink").hide();
                        // Show edit button
                        $("#editButton").show();

                        // Check first checkbox and highlight annotations
                        rec.checkFirst(data);

                        // Checkboxes listeners
                        for (var i = 0; i < data.length; i++) {
                            $("#chk" + i).click( function(){
                                var $this = $(this);
                                var $rowNumber = $this.attr("id").substring(3);
                                if ($this.is(':checked')) {
                                    // Deselect all the rest checkboxes
                                    for (var j = 0; j < data.length; j++) {
                                        if (j!=$rowNumber) {
                                            $("#chk" + j).prop('checked', false);
                                            $("#chk" + j).parents(".row:first").css("background-color", "white");
                                        }
                                    }
                                    // Terms covered
                                    var terms = rec.getHighlightedTerms(data, $rowNumber);
                                    $("#inputTextHighlighted div.card-body").empty();
                                    $("#inputTextHighlighted div.card-body").append(terms);
                                    $("#inputTextHighlighted").show();
                                }
                                // Avoids to uncheck the selected row
                                else {
                                    $this.prop('checked', true);
                                }
                            });
                        }
                        // Edit input
                        $("#editButton").click( function(){
                            rec.enableEdition()
                        });

                        // DataTable initialization
                        jQuery("#recommendations").dataTable({
                            paging: false,
                            info: false,
                            searching: false,
                            order: [[ 0, "asc" ]],
                            columnDefs: [ {
                                targets: [ 2, 3, 4, 5, 6, 7 ],
                                orderSequence: [ "desc", "asc" ]
                            } ]
                        });

                    }
                    else { // No results
                        if ($("#radioOtSets").is(":checked"))
                            $("#noResultsSets").show();
                        else
                            $("#noResults").show();
                    }
                }
            },
            error: function(errorData) {
                $(".recommenderSpinner").hide();
                $(".generalError").show();
                console.log("error", errorData);
            }
        });
    }
}

// Check first checkbox and highlight annotations
rec.checkFirst = function(data) {
    var terms = rec.getHighlightedTerms(data, 0);
    $("#chk0").prop("checked", true);
    $("#inputText").hide();
    $("#inputTextHighlighted div.card-body").empty();
    $("#inputTextHighlighted div.card-body").append(terms);
    $("#inputTextHighlighted").show();
    $("#chk0").parents(".row:first").css("background-color", "#e2ebf0");
}

jQuery(document).ready(function() {
    // Abort it not right page
    var path = currentPathArray();
    if (path[0] !== "recommender") {
      return;
    }

    rec.emptyInput = true;
    $("#recommenderButton").click(rec.getRecommendations);
    $("#insertInputLink").click(rec.insertInput);
    $("input[name=input_type]:radio").change(function () {
        rec.enableEdition()});
    $("input[name=output_type]:radio").change(function () {
        rec.enableEdition()});
    $("#ontologyPicker").click(rec.enableEdition);
    $("#input_wc").click(rec.enableEdition);
    $("#input_wa").click(rec.enableEdition);
    $("#input_wd").click(rec.enableEdition);
    $("#input_ws").click(rec.enableEdition);
    $("#input_max_ontologies").click(rec.enableEdition);
    $("#input_wc").focus(rec.enableEdition);
    $("#input_wa").focus(rec.enableEdition);
    $("#input_wd").focus(rec.enableEdition);
    $("#input_ws").focus(rec.enableEdition);
    $("#input_max_ontologies").focus(rec.enableEdition);
    $("#inputText").click(rec.prepareForRealInput);
    $("#advancedOptionsLink").click(rec.showOrHideAdvancedOptions);
    $("#advancedOptions").hide();
    $(".recommenderSpinner").hide();
    $("#editButton").hide();
    rec.hideErrorMessages();
});
