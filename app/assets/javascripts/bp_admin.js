/**
 * Created by mdorf on 3/27/15.
 * Updated by Syphax.Bouazzouni on 28/04/21 , users admin part
 */


var DUMMY_ONTOLOGY = "DUMMY_ONT";
if (window.BP_CONFIG === undefined) {
  window.BP_CONFIG = jQuery(document).data().bp.config;
}
var problemOnly = true;

function toggleShow(val) {
  problemOnly = val;
}

function millisToMinutesAndSeconds(millis) {
  var minutes = Math.floor(millis / 60000);
  var seconds = ((millis % 60000) / 1000).toFixed(0);
  return minutes + " minutes " + seconds + " seconds";
}

function parseReportDate(dateStr) {
  //parse date in a format: 10/05/2011 01:19PM
  if (dateStr.trim() === "") return "";
  var reggie = /^(((0[13578]|1[02])[\/\.-](0[1-9]|[12]\d|3[01])[\/\.-]((19|[2-9]\d)\d{2}),\s(0[0-9]|1[0-2]):(0[0-9]|[1-59]\d)\s(AM|am|PM|pm))|((0[13456789]|1[012])[\/\.-](0[1-9]|[12]\d|30)[\/\.-]((19|[2-9]\d)\d{2}),\s(0[0-9]|1[0-2]):(0[0-9]|[1-59]\d)\s(AM|am|PM|pm))|((02)[\/\.-](0[1-9]|1\d|2[0-8])[\/\.-]((19|[2-9]\d)\d{2}),\s(0[0-9]|1[0-2]):(0[0-9]|[1-59]\d)\s(AM|am|PM|pm))|((02)[\/\.-](29)[\/\.-]((1[6-9]|[2-9]\d)(0[48]|[2468][048]|[13579][26])|((16|[2468][048]|[3579][26])00)),\s(0[0-9]|1[0-2]):(0[0-9]|[1-59]\d)\s(AM|am|PM|pm)))$/g;
  var dateArr = reggie.exec(dateStr);
  dateArr = dateArr.filter(function(e){return e});
  var hours = Number(dateArr[7]);
  var ampm = dateArr[9].toUpperCase();
  if (ampm == "PM" && hours < 12) hours = hours + 12;
  if (ampm == "AM" && hours == 12) hours = hours - 12;
  var strHours = hours.toString();
  var strMonth = (Number(dateArr[3]) - 1).toString();
  var dateObj = new Date(dateArr[5], strMonth, dateArr[4], strHours, dateArr[8], "00", "00");
  return dateObj.toLocaleString([], {month: '2-digit', day: '2-digit', year: 'numeric', hour: '2-digit', minute:'2-digit'});
}

var AjaxAction = function(httpMethod, operation, path, isLongOperation, params) {
  params = params || {};
  this.httpMethod = httpMethod;
  this.operation = operation;
  this.path = path;
  this.isLongOperation = isLongOperation;
  this.ontologies = [DUMMY_ONTOLOGY];
  this.isProgressMessageEnabled = true;

  if (params["ontologies"]) {
    this.ontologies = params["ontologies"].split(",");
    delete params["ontologies"];
  }
  this.params = params;
  this.confirmMsg = "Are you sure?";
};

AjaxAction.prototype.setConfirmMsg = function(msg) {
  this.confirmMsg = msg;
};

AjaxAction.prototype.setProgressMessageEnabled = function(isEnabled) {
  this.isProgressMessageEnabled = isEnabled;
};

AjaxAction.prototype.clearStatusMessages = function() {
  jQuery("#progress_message").hide();
  jQuery("#success_message").hide();
  jQuery("#error_message").hide();
  jQuery("#info_message").hide();
  jQuery("#progress_message").html("");
  jQuery("#success_message").html("");
  jQuery("#error_message").html("");
  jQuery("#info_message").html("");
};

AjaxAction.prototype.showProgressMessage = function() {
  this.clearStatusMessages();
  var msg = "Performing " + this.operation;

  if (this.ontologies[0] !== DUMMY_ONTOLOGY) {
    msg += " for " + this.ontologies.join(", ");
  }
  jQuery("#progress_message").text(msg).html();
  jQuery("#progress_message").show();
};

AjaxAction.prototype.showStatusMessages = function(success, errors, notices, isAppendMode) {
  _showStatusMessages(success, errors, notices, isAppendMode);
};

AjaxAction.prototype.getSelectedOntologiesForDisplay = function() {
  var msg = '';

  if (this.ontologies.length > 0) {
    var ontMsg = this.ontologies.join(", ");
    msg = "<br style='margin-bottom:5px;'/><span style='color:red;font-weight:bold;'>" + ontMsg + "</span><br/>";
  }
  return msg;
};

AjaxAction.prototype._ajaxCall = function() {
  var self = this;
  var success = [];
  var errors = [];
  var notices = [];
  var promises = [];
  var params = jQuery.extend(true, {}, self.params);

  if (self.isProgressMessageEnabled) {
    self.showProgressMessage();
  }

  // using javascript closure for passing index to asynchronous calls
  jQuery.each(self.ontologies, function(index, ontology) {
    if (ontology != DUMMY_ONTOLOGY) {
      params["ontologies"] = ontology;
    }
    var deferredObj = jQuery.Deferred();
    if (!self.isLongOperation) {
      deferredObj.resolve();
    }
    promises.push(deferredObj);
    var errorState = false;

    var req = jQuery.ajax({
      method: self.httpMethod,
      url: "/admin/" + self.path,
      data: params,
      dataType: "json",
      success: function(data, msg) {
        var reg = /\s*,\s*/g;

        if (data.errors) {
          errorState = true;
          var err = data.errors.replace(reg, ',');
          errors.push.apply(errors, err.split(","));

          if (self.path === 'update_info') {
            // Note the appliance ID, regardless of error status
            errors.appliance_id = data.update_info.appliance_id
          }

          self.onErrorAction(errors);

          if (deferredObj.state() === "pending") {
            deferredObj.resolve();
          }
        }

        if (data.success) {
          self.onSuccessAction(data, ontology, deferredObj);

          if (data.success) {
            var suc = data.success.replace(reg, ',');
            success.push.apply(success, suc.split(","));
          }

          if (data.notices) {
            var notice = data.notices.replace(reg, ',');
            notices.push.apply(notices, notice.split(","));
          }
        }
        self.showStatusMessages(success, errors, notices, false);
      },
      error: function(request, textStatus, errorThrown) {
        errorState = true;
        errors.push(request.status + ": " + errorThrown);
        self.onErrorAction(errors);
        self.showStatusMessages(success, errors, notices, false);
      },
      complete: function(request, textStatus) {
        if (errorState || !self.isLongOperation) {
          self.removeSelectedRow(ontology);
        }
      }
    });
    promises.push(req);
  });

  // hide progress message and deselect rows after ALL operations have completed
  jQuery.when.apply(null, promises).always(function() {
    jQuery("#progress_message").hide();
    jQuery("#progress_message").html("");
  });
};

AjaxAction.prototype.removeSelectedRow = function(ontology) {
  if (ontology != DUMMY_ONTOLOGY) {
    var jQueryRow = jQuery("#tr_" + ontology);
    jQueryRow.removeClass('selected');
  }
};

AjaxAction.prototype.ajaxCall = function() {
  var self = this;

  if (self.ontologies.length === 0) {
    alertify.alert("Please select at least one ontology from the table to perform action on.<br/>To select/de-select ontologies, simply click anywhere in the ontology row.");
    return;
  }

  if (self.confirmMsg) {
    alertify.confirm(self.confirmMsg, function(e) {
      if (e) {
        self._ajaxCall();
      }
    });
  } else {
    self._ajaxCall();
  }
};

AjaxAction.prototype.onSuccessAction = function(data, ontology, deferredObj) {
  var self = this;
  if (!self.isLongOperation) {
    return;
  }
  var processId = data["process_id"];
  var success = [];
  var errors = [];
  var done = [];
  data.success = '';
  var start = new Date().getTime();
  var timer = setInterval(function() {
    jQuery.ajax({
      url: determineHTTPS(BP_CONFIG.rest_url) + "/admin/ontologies_report/" + processId,
      data: {
        apikey: BP_CONFIG.apikey,
        userapikey: BP_CONFIG.userapikey,
        format: "jsonp"
      },
      dataType: "jsonp",
      timeout: 30000,
      success: function(data) {
        if (typeof data === 'string') {
          // still processing
          jQuery("#progress_message").append(".");
        } else {
          if (jQuery.inArray(ontology, done) != -1) {
            return;
          }
          done.push(ontology);
          clearInterval(timer);

          // done processing, show errors or process data
          if (data.errors && data.errors.length > 0) {
            errors[0] = data.errors[0];
          } else {
            var end = new Date().getTime();
            var tm = end - start;

            if (ontology === DUMMY_ONTOLOGY) {
              success[0] = self.operation + " completed in " + millisToMinutesAndSeconds(tm);
            } else {
              success[0] = self.operation + " for " + ontology + " completed in " + millisToMinutesAndSeconds(tm);
            }
            self.onSuccessActionLongOperation(data, ontology);
          }
          deferredObj.resolve();
          self.showStatusMessages(success, errors, [], true);
        }
      },
      error: function(request, textStatus, errorThrown) {
        if (jQuery.inArray(ontology, done) != -1) {
          return;
        }
        done.push(ontology);
        clearInterval(timer);
        errors.push(request.status + ": " + errorThrown);
        deferredObj.resolve();
        self.showStatusMessages(success, errors, [], true);
      }
    });
  }, 5000);
};

AjaxAction.prototype.onErrorAction = function(errors) {
  // nothing to do by default
};

AjaxAction.prototype.onSuccessActionLongOperation = function(data, ontology) {
  // nothing to do by default
};

AjaxAction.prototype.setSelectedOntologies = function() {
  var acronyms = '';
  var ontTable = jQuery('#adminOntologies').DataTable();
  ontTable.rows('.selected').every(function() {
    var trId = this.node().id;
    acronyms += trId.substring("tr_".length) + ",";
  });

  if (acronyms.length) {
    this.ontologies = acronyms.slice(0, -1).split(",");
  } else {
    this.ontologies = [];
  }
};

AjaxAction.prototype.act = function() {
  alert("AjaxAction.act is not implemented");
};

function ResetMemcacheConnection() {
  AjaxAction.call(this, "POST", "UI CACHE CONNECTION RESET", "resetcache", false);
  this.setConfirmMsg('');
}

ResetMemcacheConnection.prototype = Object.create(AjaxAction.prototype);
ResetMemcacheConnection.prototype.constructor = ResetMemcacheConnection;

ResetMemcacheConnection.act = function() {
  new ResetMemcacheConnection().ajaxCall();
};

function FlushMemcache() {
  AjaxAction.call(this, "POST", "FLUSHING OF UI CACHE", "clearcache", false);
  this.setConfirmMsg('');
}

FlushMemcache.prototype = Object.create(AjaxAction.prototype);
FlushMemcache.prototype.constructor = FlushMemcache;

FlushMemcache.act = function() {
  new FlushMemcache().ajaxCall();
};

function ClearGooCache() {
  AjaxAction.call(this, "POST", "FLUSHING OF GOO CACHE", "clear_goo_cache", false);
  this.setConfirmMsg('');
}

ClearGooCache.prototype = Object.create(AjaxAction.prototype);
ClearGooCache.prototype.constructor = ClearGooCache;

ClearGooCache.act = function() {
  new ClearGooCache().ajaxCall();
};

function ClearHttpCache() {
  AjaxAction.call(this, "POST", "FLUSHING OF HTTP CACHE", "clear_http_cache", false);
  this.setConfirmMsg('');
}

ClearHttpCache.prototype = Object.create(AjaxAction.prototype);
ClearHttpCache.prototype.constructor = ClearHttpCache;

ClearHttpCache.act = function() {
  new ClearHttpCache().ajaxCall();
};

function DeleteSubmission(ontology, submissionId) {
  AjaxAction.call(this, "DELETE", "SUBMISSION DELETION", "ontologies/" + ontology + "/submissions/" + submissionId, false, {ontologies: ontology});
  this.submissionId = submissionId;
  this.setConfirmMsg("Are you sure you want to delete submission <span style='color:red;font-weight:bold;'>" + submissionId + "</span> for ontology <span style='color:red;font-weight:bold;'>" + ontology + "</span>?<br/><b>This action CAN NOT be undone!!!</b>");
}

DeleteSubmission.prototype = Object.create(AjaxAction.prototype);
DeleteSubmission.prototype.constructor = DeleteSubmission;

DeleteSubmission.prototype.onSuccessAction = function(data, ontology, deferredObj) {
  jQuery.facebox({
    ajax: "/admin/ontologies/" + ontology + "/submissions?time=" + new Date().getTime()
  });
};

DeleteSubmission.act = function(ontology, submissionId) {
  new DeleteSubmission(ontology, submissionId).ajaxCall();
};

function RefreshReport() {
  AjaxAction.call(this, "POST", "REFRESH OF ONTOLOGIES REPORT", "refresh_ontologies_report", true);
  var msg = "Refreshing this report takes a while...<br/>Are you sure you're ready for some coffee time?";
  this.setSelectedOntologies();

  if (this.ontologies.length > 0) {
    msg = "Ready to refresh report for ontologies:" + this.getSelectedOntologiesForDisplay() + "Proceed?";
  } else {
    this.ontologies = [DUMMY_ONTOLOGY];
  }
  this.setConfirmMsg(msg);
}

RefreshReport.prototype = Object.create(AjaxAction.prototype);
RefreshReport.prototype.constructor = RefreshReport;

RefreshReport.prototype.onSuccessActionLongOperation = function(data, ontology) {
  displayOntologies(data, ontology);
};

RefreshReport.act = function() {
  new RefreshReport().ajaxCall();
};

function DeleteOntologies() {
  AjaxAction.call(this, "DELETE", "ONTOLOGY DELETION", "ontologies", false);
  this.setSelectedOntologies();
  this.setConfirmMsg("You are about to delete the following ontologies:" + this.getSelectedOntologiesForDisplay() + "<b>This action CAN NOT be undone!!! Are you sure?</b>");
}

DeleteOntologies.prototype = Object.create(AjaxAction.prototype);
DeleteOntologies.prototype.constructor = DeleteOntologies;
DeleteOntologies.prototype.onSuccessAction = function(data, ontology, deferredObj) {
  var ontTable = jQuery('#adminOntologies').DataTable();
  // remove ontology row from the table
  ontTable.row(jQuery("#tr_" + ontology)).remove().draw();
};

DeleteOntologies.act = function() {
  new DeleteOntologies().ajaxCall();
};

function ProcessOntologies(action) {
  var actions = {
    all: "FULL ONTOLOGY RE-PROCESSING",
    process_annotator: "PROCESSING OF ONTOLOGY FOR ANNOTATOR",
    diff: "CALCULATION OF ONTOLOGY DIFFS",
    index_search: "PROCESSING OF ONTOLOGY FOR SEARCH",
    run_metrics: "CALCULATION OF ONTOLOGY METRICS"
  };
  AjaxAction.call(this, "PUT", actions[action], "ontologies", false, {actions: action});
  this.setSelectedOntologies();
  this.setConfirmMsg("You are about to perform " + actions[action] + " on the following ontologies:" + this.getSelectedOntologiesForDisplay() + "The ontologies will be added to the queue and processed on the next cron job execution.<br style='margin:10px 0;'/><b>Should I proceed?</b>");
}

ProcessOntologies.prototype = Object.create(AjaxAction.prototype);
ProcessOntologies.prototype.constructor = ProcessOntologies;

ProcessOntologies.act = function(action) {
  new ProcessOntologies(action).ajaxCall();
};

function UpdateCheck(forceCheck) {
  var params = {};

  if (forceCheck) {
    params["force_check"] = forceCheck;
  }
  AjaxAction.call(this, "GET", "CHECK FOR UPDATE", "update_info", false, params);
  this.setProgressMessageEnabled(forceCheck);
  this.setConfirmMsg('');
}

UpdateCheck.prototype = Object.create(AjaxAction.prototype);
UpdateCheck.prototype.constructor = UpdateCheck;

UpdateCheck.prototype.onSuccessAction = function(data, ontology, deferredObj) {
  var self = this;
  delete data["success"];
  updateInfo = data["update_info"];

  if (updateInfo["update_check_enabled"]) {
    var lastCheck = "";

    if (updateInfo["date_checked"]) {
      var updateDate = parseReportDate(updateInfo["date_checked"]);

      if (updateDate) {
        lastCheck = "Last update check on: " + updateDate;
      }
    }

    if (updateInfo["update_available"]) {
      // update found - show in all cases
      data["notices"] = "Update available. You are running the version: " + updateInfo["current_version"] + ". Updated version: " + updateInfo["update_version"] + ".";

      if (lastCheck) {
        data["notices"] += " " + lastCheck + ".";
      }

      if (updateInfo["notes"]) {
        data["notices"] += " Update notes: " + updateInfo["notes"];
      }
    } else if (self.params && self.params["force_check"]) {
      // no update found, but user was checking explicitly - show message
      data["notices"] = "No update available. You are running the latest version: " + updateInfo["current_version"] + ".";

      if (lastCheck) {
        data["notices"] += " " + lastCheck + ".";
      }
    } else {
      // no update found, and user wasn't checking,
      // just a default check on page load - show nothing
      delete data["notices"];
    }

    if (updateInfo.hasOwnProperty("appliance_id")) {
      document.querySelector("#appliance-id span").textContent = updateInfo["appliance_id"];
    }
  }
};

UpdateCheck.prototype.onErrorAction = function(errors) {
  var self = this;

  // hide errors unless user explicitly requested an update check
  if (!self.params || !self.params["force_check"]) {
    errors.length = 0;
  }

  // Always show the appliance ID, even when update checking fails
  document.querySelector('#appliance-id span').textContent = errors['appliance_id'];
};

UpdateCheck.isUpdateCheckEnabled = false;
UpdateCheck.act = function(forceCheck) {
  if (UpdateCheck.isUpdateCheckEnabled) {
    new UpdateCheck(forceCheck).ajaxCall();
  } else {
    jQuery.ajax({
      url: "/admin/update_check_enabled",
      success: function (data) {
        if (data) {
          jQuery("#update_check").show();
          jQuery("#site-admin-appliance-id").show();
          jQuery("#site-admin-update-check").show();
          new UpdateCheck(forceCheck).ajaxCall();
          UpdateCheck.isUpdateCheckEnabled = true;
        }
      },
      error: function () {
        console.log("An error occurred while performing a check for the latest version.");
      }
    });
  }
};

// end: individual actions classes -----------------------

function performActionOnOntologies() {
  var action = jQuery('#admin_action').val();

  if (!action) {
    alertify.alert("Please choose an action to perform on the selected ontologies.");
    return;
  }

  switch(action) {
    case "delete":
      DeleteOntologies.act();
      break;
    default:
      ProcessOntologies.act(action);
      break;
  }
}

function populateOntologyRows(data) {
  var ontologies = data.ontologies;
  var allRows = [];
  var hideFields = ["format", "administeredBy", "date_created", "report_date_updated", "errErrorStatus", "errMissingStatus", "problem", "logFilePath"];

  for (var acronym in ontologies) {
    var errorMessages = [];
    var ontology = ontologies[acronym];
    var ontLink = "<a href='" + "/ontologies/" + acronym + "' target='_blank' style='" + (ontology["problem"] === true ? "color:red;" : "") + "'>" + acronym + "</a>";
    var bpLinks = '';
    var format = ontology["format"];
    var admin = ontology["administeredBy"];
    var reportDateUpdated = parseReportDate(ontology["report_date_updated"]);
    var ontologyDateCreated = parseReportDate(ontology["date_created"]);

    if (ontology["logFilePath"] != '') {
      bpLinks += "<a href='" + "/admin/ontologies/" + acronym + "/log' target='_blank'>Log</a>&nbsp;&nbsp;|&nbsp;&nbsp;";
    }
    bpLinks += "<a href='" + BP_CONFIG.rest_url + "/ontologies/" + acronym + "?apikey=" + BP_CONFIG.apikey + "&userapikey=" + BP_CONFIG.userapikey + "' target='_blank'>REST</a>&nbsp;&nbsp;|&nbsp;&nbsp;";
    bpLinks += "<a id='link_submissions_" + acronym + "' href='javascript:;' onclick='showSubmissions(event, \"" + acronym + "\")'>Submissions</a>";

    var errStatus = ontology["errErrorStatus"] ? ontology["errErrorStatus"].join(", ") : '';
    var missingStatus = ontology["errMissingStatus"] ? ontology["errMissingStatus"].join(", ") : '';

    for (var k in ontology) {
      if (jQuery.inArray(k, hideFields) === -1) {
        errorMessages.push(ontology[k]);
      }
    }
    var row = [ontLink, admin.join("<br/>"), format, ontologyDateCreated, reportDateUpdated, bpLinks, errStatus, missingStatus, errorMessages.join("<br/>"), ontology["problem"]];
    allRows.push(row);
  }
  return allRows;
}

function isDateGeneratedSet(data) {
  var dateRe = /^\d{2}\/\d{2}\/\d{4}\,\s\d{2}:\d{2}\s\w{2}$/i;
  return dateRe.test(data.report_date_generated);
}

function setDateGenerated(data) {
  var buttonText = "Generate";

  if (isDateGeneratedSet(data)) {
    buttonText = "Refresh";
  }
  jQuery(".report_date_generated").text(data.report_date_generated).html();
  jQuery(".report_date_generated_button").text(buttonText).html();
}

function _showStatusMessages(success, errors, notices, isAppendMode) {
  if (success.length > 0) {
    if (isAppendMode) {
      var appendStr = (jQuery.trim(jQuery('#success_message').html()).length) ? ", " : "";
      jQuery("#success_message").append(appendStr + success.join(", ")).html();
    } else {
      jQuery("#success_message").text(success.join(", ")).html();
    }
    jQuery("#success_message").show();
  }

  if (errors.length > 0) {
    if (isAppendMode) {
      var appendStr = (jQuery.trim(jQuery('#error_message').html()).length) ? ", " : "";
      jQuery("#error_message").append(appendStr + errors.join(", ")).html();
    } else {
      jQuery("#error_message").text(errors.join(", ")).html();
    }
    jQuery("#error_message").show();
  }

  if (notices.length > 0) {
    if (isAppendMode) {
      var appendStr = (jQuery.trim(jQuery('#info_message').html()).length) ? ", " : "";
      jQuery("#info_message").append(appendStr + notices.join(", ")).html();
    } else {
      jQuery("#info_message").text(notices.join(", ")).html();
    }
    jQuery("#info_message").show();
  }
}

function displayOntologies(data, ontology) {
  var ontTable = null;

  if (jQuery.fn.dataTable.isDataTable('#adminOntologies')) {
    ontTable = jQuery('#adminOntologies').DataTable();

    if (ontology === DUMMY_ONTOLOGY) {
      // refreshing entire table
      allRows = populateOntologyRows(data);
      ontTable.clear();
      ontTable.rows.add(allRows);
      ontTable.draw();
      setDateGenerated(data);
    } else {
      // refreshing individual row
      var jQueryRow = jQuery("#tr_" + ontology);
      var row = ontTable.row(jQueryRow);
      var rowData = {ontologies: {}};
      rowData["ontologies"][ontology] = data["ontologies"][ontology];
      allRows = populateOntologyRows(rowData);
      row.data(allRows[0]);
      row.invalidate().draw();
      jQueryRow.removeClass('selected');
    }
  } else {
    ontTable = jQuery("#adminOntologies").DataTable({
      "ajax": {
        "url": "/admin/ontologies_report",
        "contentType": "application/json",
        "dataSrc": function (json) {
          return populateOntologyRows(json);
        }
      },
      "rowCallback": function(row, data, index) {
        var acronym = jQuery('td:first', row).text();
        jQuery(row).attr("id", "tr_" + acronym);

        if (data[data.length - 1] === true) {
          jQuery(row).addClass("problem");
        }
      },
      "initComplete": function(settings, json) {
        if (json.errors && isDateGeneratedSet(data)) {
          _showStatusMessages([], [json.errors], [], false);
        }
        setDateGenerated(json);
        // Keep header at top of table even when scrolling
        // new jQuery.fn.dataTable.FixedHeader(ontTable);
      },
      "columnDefs": [
        {
          "targets": 0,
          "searchable": true,
          "title": "Ontology",
          "width": "160px"
        },
        {
          "targets": 1,
          "searchable": true,
          "title": "Admin",
          "width": "160px"
        },
        {
          "targets": 2,
          "searchable": true,
          "title": "Format",
          "width": "55px"
        },
        {
          "targets": 3,
          "searchable": true,
          "title": "Date Created",
          "type": "date",
          "width": "170px"
        },
        {
          "targets": 4,
          "searchable": true,
          "title": "Report Date",
          "type": "date",
          "width": "170px"
        },
        {
          "targets": 5,
          "searchable": false,
          "orderable": false,
          "title": "URL",
          "width": "140px"
        },
        {
          "targets": 6,
          "searchable": true,
          "title": "Error Status",
          "width": "130px"
        },
        {
          "targets": 7,
          "searchable": true,
          "title": "Missing Status",
          "width": "130px"
        },
        {
          "targets": 8,
          "searchable": true,
          "title": "Issues"
        },
        {
          "targets": 9,
          "searchable": true,
          "visible": false
        }
      ],
      "autoWidth": false,
      "lengthChange": false,
      "searching": true,
      "language": {
        "search": "Filter: ",
        "emptyTable": "No ontologies available"
      },
      "info": true,
      "paging": true,
      "pageLength": 100,
      "ordering": true,
      "stripeClasses": ["", "alt"],
      "dom": '<"ontology_nav"><"top"fi>rtip',
      "customAllowOntologiesFilter": true
    });
  }
  return ontTable;
}

function showSubmissions(ev, acronym) {
  ev.preventDefault();
  jQuery.facebox({ ajax: "/admin/ontologies/" + acronym + "/submissions" });
}

function showOntologiesToggleLinks(problemOnly) {
  var str = 'View Ontologies:&nbsp;&nbsp;&nbsp;&nbsp;';

  if (problemOnly) {
    str += '<a id="show_all_ontologies_action" href="javascript:;">All</a>&nbsp;&nbsp;|&nbsp;&nbsp;<strong>Problem Only</strong>';
  } else {
    str += '<strong>All</strong>&nbsp;&nbsp;|&nbsp;&nbsp;<a id="show_problem_only_ontologies_action" href="javascript:;">Problem Only</a>';
  }
  return str;
}

jQuery(".admin.index").ready(function() {
  // display ontologies table on load
  displayOntologies({}, DUMMY_ONTOLOGY);
  displayUsers({});
  UpdateCheck.act();

  // make sure facebox window is empty before populating it
  // otherwise ajax requests stack up and you see more than
  // one ontology's submissions
  jQuery(document).bind('beforeReveal.facebox', function() {
    jQuery("#facebox .content").empty();
  });

  // remove hidden divs for submissions of previously
  // clicked ontologies
  jQuery(document).bind('reveal.facebox', function() {
    jQuery('div[id=facebox]:hidden').remove();
  });

  // convert facebox window into a modal mode
  jQuery(document).bind('loading.facebox', function() {
    jQuery(document).unbind('keydown.facebox');
    jQuery('#facebox_overlay').unbind('click');
  });

  jQuery("div.ontology_nav").html(`
    <span class="toggle-row-display">
      ${showOntologiesToggleLinks(problemOnly)}
    </span>
    <span style="padding-left:30px;">
      Apply to Selected Rows:&nbsp;&nbsp;&nbsp;
      <select id="admin_action" name="admin_action">
        <option value="">Please Select</option>
        <option value="delete">Delete</option>
        <option value="all">Process</option>
        <option value="process_annotator">Annotate</option>
        <option value="diff">Diff</option>
        <option value="index_search">Index</option>
        <option value="run_metrics">Metrics</option>
      </select>
      &nbsp;&nbsp;&nbsp;
      <a class="btn btn-outline-primary btn-sm" href="javascript:;" id="admin_action_submit">
        Go
      </a>
    </span>
  `);

  // toggle between all and problem ontologies
  jQuery.fn.dataTable.ext.search.push(
    function(settings, data, dataIndex) {
      if (!settings.oInit.customAllowOntologiesFilter) {
        return true;
      }

      var row = settings.aoData[dataIndex].nTr;
      if (!problemOnly || row.classList.contains("problem") || data[data.length - 1] === "true") {
        return true;
      }
      return false;
    }
  );

  // for toggling between all and problem ontologies
  jQuery(".toggle-row-display a").live("click", function() {
    toggleShow(!problemOnly);
    jQuery("#adminOntologies").DataTable().draw();
    str = showOntologiesToggleLinks(problemOnly);
    jQuery(".toggle-row-display").html(str);
    return false;
  });

  // allow selecting of rows, except on link clicks
  jQuery('#adminOntologies tbody').on('click', 'tr', function(event) {
    if (event.target.tagName.toLowerCase() != 'a') {
      jQuery(this).toggleClass('selected');
    }
  });

  jQuery('#adminUsers').on('click', '.delete-user', function(event) {
    DeleteUsers.act(this.dataset.accountName);
  });

  // BUTTON onclick actions ---------------------------------------

  // onclick action for "Go" button for performing an action on a set of ontologies
  jQuery("#admin_action_submit").click(function() {
    performActionOnOntologies();
  });

  // onclick action for "Flush UI Cache" button
  jQuery("#flush_memcache_action").click(function() {
    FlushMemcache.act();
  });

  // onclick action for "Reset Memcache Connection" button
  jQuery("#reset_memcache_connection_action").click(function() {
    ResetMemcacheConnection.act();
  });

  // onclick action for "Flush Goo Cache" button
  jQuery("#flush_goo_cache_action").click(function() {
    ClearGooCache.act();
  });

  // onclick action for "Flush HTTP Cache" button
  jQuery("#flush_http_cache_action").click(function() {
    ClearHttpCache.act();
  });

  // onclick action for "Refresh Report" button
    jQuery("#refresh_report_action").click(function() {
        RefreshReport.act();
    });

  // onclick action for "Update Check" button
  jQuery("#update_check_action").click(function() {
    UpdateCheck.act(true);
  });

  // end: BUTTON onclick actions -----------------------------------
});


/* users part */
function populateUserRows(data) {
    let users = data['users'];
    let allRows = [];
    // let hideFields = ["format", "administeredBy", "date_created", "report_date_updated", "errErrorStatus", "errMissingStatus", "problem", "logFilePath"];
    users.forEach(user =>{
        let id = '<a href="'+ user['@id']+'" >' + user['@id'] + '</a>';
        let email = user['email'];
        let username = user['username'];
        let roles = user['role'];
        let firstname = user['firstName']
        let lastname = user['lastName']
        let created = user['created']
        let actions = [
            '<a href="/accounts/'+ user['username'] +'"  class="mx-1">Detail</a>' ,
            '<a href="javascript:;" class="delete-user mx-1" data-account-name="' + username + '">Delete</a>',
            '<a href="/login_as/'+ encodeURIComponent(username) +'" class="mx-1">Login as</a>',

        ]
        let row = [firstname, lastname, username, email , roles , id , created , actions.join('|')];
        allRows.push(row);
    })

    return allRows;
}

function displayUsers(data) {
    let ontTable = null;
    let allRows
    if (jQuery.fn.dataTable.isDataTable('#adminUsers')) {
        ontTable = jQuery('#adminUsers').DataTable();

        if (ontology === DUMMY_ONTOLOGY) {
            // refreshing entire table
            allRows = populateUserRows(data);
            ontTable.clear();
            ontTable.rows.add(allRows);
            ontTable.draw();
        } else {
            // refreshing individual row
        }
    } else {
        ontTable = jQuery("#adminUsers").DataTable({
            "ajax": {
                "url": "/admin/users",
                "contentType": "application/json",
                "dataSrc": function (json) {
                    return populateUserRows(json);
                }
            },
            "rowCallback": function(row, data, index) {
                var acronym = jQuery('td:nth-child(3)', row).text();

                jQuery(row).attr("id", "tr_" + acronym);
                if (data[data.length - 1] === true) {
                    jQuery(row).addClass("problem");
                }
            },
            "initComplete": function(settings, json) {
            },
            "columnDefs": [
                {
                    "targets": 0,
                    "searchable": true,
                    "title": "First Name",
                },
                {
                    "targets": 1,
                    "searchable": true,
                    "title": "Last Name",
                },
                {
                    "targets": 2,
                    "searchable": true,
                    "title": "Username",
                },
                {
                    "targets": 3,
                    "searchable": true,
                    "title": "Email",
                },
                {
                    "targets": 4,
                    "searchable": true,
                    "title": "Roles",
                },
                {
                    "targets": 5,
                    "searchable": true,
                    "orderable": false,
                    "title": "Id",
                },
                {
                    "targets": 6,
                    "searchable": true,
                    "orderable": true,
                    "title": "Created at",
                },
                {
                    "targets": 7,
                    "searchable": false,
                    "orderable": false,
                    "title": "Actions",
                    "width": "210px"
                }
            ],
            "autoWidth": false,
            "lengthChange": false,
            "searching": true,
            "language": {
                "search": "Filter: ",
                "emptyTable": "No users available"
            },
            "info": true,
            "paging": true,
            "pageLength": 100,
            "ordering": true,
            "responsive": true,
            "stripeClasses": ["", "alt"],
        });
    }
    return ontTable;
}

function DeleteUsers(user) {
  AjaxAction.call(this, "DELETE", "USERS DELETION", "accounts/"+user, false);
  this.setConfirmMsg('Permanently delete "' + user +'"?');
}

DeleteUsers.prototype = Object.create(AjaxAction.prototype);
DeleteUsers.prototype.constructor = DeleteUsers;
DeleteUsers.prototype.onSuccessAction = function(username) {
    let ontTable = jQuery('#adminUsers').DataTable();
    ontTable.row(jQuery("#tr_" + username)).remove().draw();
};

DeleteUsers.prototype._ajaxCall =  function (username)  {
    let errors = [];
    let success = [];
    let notices = [];
    jQuery.ajax({
        method: 'DELETE',
        url: `accounts/${encodeURIComponent(username)}`,
        data: [],
        dataType: "json",
        success: (data, msg) => {
            success.push('"' + username + '" user successfully deleted')
            this.onSuccessAction(username)
            _showStatusMessages(success, errors, notices, false);
        },
        error: function(request, textStatus, errorThrown) {
            console.log('error')
            errorState = true;
            errors.push(request.status + ": " + errorThrown);
            _showStatusMessages(success, errors, notices, false);
        },
        complete: function(request, textStatus) {

        }
    });

}

DeleteUsers.prototype.ajaxCall = function (username){
    alertify.confirm(this.confirmMsg, (e) => {
        if (e) {
            this._ajaxCall(username);
        }
    });
}
DeleteUsers.act = function(user) {
    new DeleteUsers(user).ajaxCall(user);
};
