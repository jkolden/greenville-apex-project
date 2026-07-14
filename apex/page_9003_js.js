// =============================================================================
// Page 9003 — BICC File Loader — Master JavaScript Reference
// =============================================================================
// Location: APEX Page 9003 > Page Properties > JavaScript >
//           Function and Global Variable Declaration
//
// Last verified: 2026-07-14
//
// If functions go missing from the page, paste this entire file back into
// the Function and Global Variable Declaration field in Page Designer.
// =============================================================================

// =============================================================================
// TAB: BICC Extract Files
// Callbacks: LOAD_FILE, MERGE_JOB
// =============================================================================

function loadBiccFile(fileName, loadType) {
    if (!confirm('Load file: ' + fileName + '?')) {
        return;
    }

    apex.server.process('LOAD_FILE', {
        x01: fileName,
        x02: loadType
    }, {
        success: function(data) {
            if (data.success) {
                apex.message.showPageSuccess('Loaded Job ID: ' + data.job_id);
                apex.region('load_jobs').refresh();
            } else {
                apex.message.showErrors([{
                    type: 'error',
                    location: 'page',
                    message: data.error
                }]);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            apex.message.showErrors([{
                type: 'error',
                location: 'page',
                message: 'Error: ' + errorThrown
            }]);
        }
    });
}

function mergeJob(jobId, loadType) {
    if (!confirm('Merge Job ID ' + jobId + ' to FBX Table(s)?')) {
        return;
    }

    apex.server.process('MERGE_JOB', {
        x01: jobId,
        x02: loadType
    }, {
        success: function(data) {
            if (data.success) {
                apex.message.showPageSuccess('Merge completed!');
                apex.region('load_jobs').refresh();
            } else {
                apex.message.showErrors([{
                    type: 'error',
                    location: 'page',
                    message: data.error
                }]);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            apex.message.showErrors([{
                type: 'error',
                location: 'page',
                message: 'Error: ' + errorThrown
            }]);
        }
    });
}

// =============================================================================
// TAB: REST Manual Trigger
// Callback: SYNC_REST_SOURCE
// Button: SYNC_SELECTED
// Status panel: #status_list
// Checkbox column: f03
// =============================================================================

function syncSelected() {
    var selectedIds = [];
    $("input[name='f03']:checked").each(function () {
        selectedIds.push($(this).val());
    });

    if (selectedIds.length === 0) {
        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: "Select at least one REST source."
        }]);
        return;
    }

    var syncMode = $v("P9003_SYNC_MODE");

    apex.message.confirm(
        "Sync " + selectedIds.length + " REST source(s)"
            + (syncMode === "FULL" ? " (full refresh)" : "") + "?",
        function (ok) {
            if (!ok) return;

            apex.message.clearErrors();
            $("#SYNC_SELECTED").prop("disabled", true);
            $("#status_list").parent().addClass("is-visible");
            $("#status_list").empty();

            runSyncSequence(selectedIds, syncMode, 0, 0, 0);
        }
    );
}

function runSyncSequence(ids, syncMode, idx, okCount, errCount) {
    if (idx >= ids.length) {
        finishSync(okCount, errCount);
        return;
    }

    var sourceId = ids[idx];
    var sourceName = getSourceName(sourceId);
    var $row = $("<div class=\"sync-row\"><span class=\"fa fa-refresh fa-anim-spin\"></span> "
        + apex.util.escapeHTML(sourceName) + "...</div>");
    $("#status_list").append($row);

    apex.server.process("SYNC_REST_SOURCE", {
        x03: sourceId,
        x04: syncMode
    }, {
        dataType: "json",
        timeout: 600000,
        success: function (data) {
            if (data.status === "OK") {
                $row.html("<span class=\"fa fa-check-circle status-success\"></span> "
                    + apex.util.escapeHTML(sourceName));
                runSyncSequence(ids, syncMode, idx + 1, okCount + 1, errCount);
            } else {
                $row.html("<span class=\"fa fa-times-circle status-error\"></span> "
                    + apex.util.escapeHTML(sourceName) + " \u2014 " + apex.util.escapeHTML(data.message));
                runSyncSequence(ids, syncMode, idx + 1, okCount, errCount + 1);
            }
        },
        error: function (jqXHR, textStatus, errorThrown) {
            $row.html("<span class=\"fa fa-times-circle status-error\"></span> "
                + apex.util.escapeHTML(sourceName) + " \u2014 " + apex.util.escapeHTML(errorThrown));
            runSyncSequence(ids, syncMode, idx + 1, okCount, errCount + 1);
        }
    });
}

function finishSync(okCount, errCount) {
    $("#SYNC_SELECTED").prop("disabled", false);

    if (errCount === 0) {
        apex.message.showPageSuccess(okCount + " source(s) synced successfully.");
    } else {
        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: errCount + " source(s) failed. " + okCount + " succeeded."
        }]);
    }

    $(".a-IRR-region").trigger("apexrefresh");
}

function getSourceName(sourceId) {
    var name = null;
    $("input[name='f03']").each(function () {
        if ($(this).val() === sourceId) {
            name = $(this).closest("tr").find("td:nth-child(4)").text().trim();
        }
    });
    return name || ("Source #" + sourceId);
}

// =============================================================================
// TAB: REST Manual Trigger — Recruiting
// Callback: RUN_RECRUITING
// Button: RUN_RECRUITING
// Status panel: #recruiting_status_panel
// =============================================================================

function runRecruiting() {
    apex.message.confirm(
        "Launch recruiting sync (requisitions + candidates) in background?",
        function(ok) {
            if (!ok) return;

            apex.message.clearErrors();
            $("#RUN_RECRUITING").prop("disabled", true);
            $("#recruiting_status_panel").addClass("is-visible");
            $("#recruiting_status_icon").attr("class", "fa fa-refresh fa-anim-spin");
            $("#recruiting_status_text").text("Submitting...");

            apex.server.process("RUN_RECRUITING", {}, {
                dataType: "json",
                success: function(data) {
                    if (data.status === "OK") {
                        $("#recruiting_status_icon").attr("class",
                            "fa fa-check-circle status-success");
                        $("#recruiting_status_text").text(
                            "Job submitted \u2014 running in background. "
                            + "Refresh the page or check Scheduler Jobs tab for results.");
                        apex.message.showPageSuccess(
                            "Recruiting sync launched in background.");
                    } else if (data.status === "ALREADY_RUNNING") {
                        $("#recruiting_status_icon").attr("class",
                            "fa fa-info-circle");
                        $("#recruiting_status_text").text(data.message);
                    } else {
                        $("#recruiting_status_icon").attr("class",
                            "fa fa-times-circle status-error");
                        $("#recruiting_status_text").text(
                            "Failed: " + data.message);
                    }
                    $("#RUN_RECRUITING").prop("disabled", false);
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    $("#recruiting_status_icon").attr("class",
                        "fa fa-times-circle status-error");
                    $("#recruiting_status_text").text("Error: " + errorThrown);
                    $("#RUN_RECRUITING").prop("disabled", false);
                }
            });
        }
    );
}

// =============================================================================
// TAB: BICC Manual Trigger
// Callbacks: SUBMIT_BICC_EXTRACT, CHECK_BICC_STATUS
// Button: SUBMIT_EXTRACT
// Status panel: #status_panel > #status_icon, #status_text
// Checkbox column: f01
// Item: P9003_EXTRACT_TYPE, P9003_REQUEST_ID
// =============================================================================

var gPollTimer = null;

function submitExtract() {
    var selectedIds = [];
    $("input[name='f01']:checked").each(function() {
        selectedIds.push($(this).val());
    });

    if (selectedIds.length === 0) {
        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: "Select at least one datastore."
        }]);
        return;
    }

    var extractType = $v("P9003_EXTRACT_TYPE");

    apex.message.confirm(
        "Submit BICC extract for " + selectedIds.length + " datastore(s)?",
        function(ok) {
            if (!ok) return;

            $("#SUBMIT_EXTRACT").prop("disabled", true);
            $("#status_panel").addClass("is-visible");
            $("#status_text").text("Submitting...");
            $("#status_icon").attr("class", "fa fa-refresh fa-anim-spin");

            apex.server.process("SUBMIT_BICC_EXTRACT", {
                x01: selectedIds.join(","),
                x02: extractType
            }, {
                dataType: "json",
                success: function(data) {
                    if (data.success) {
                        $s("P9003_REQUEST_ID", data.request_id);
                        $("#status_text").text("Submitted - Request ID: "
                            + data.request_id + " \u2014 polling...");
                        startPolling(data.request_id);
                    } else {
                        $("#status_icon").attr("class", "fa fa-times-circle status-error");
                        $("#status_text").text("Submit failed: " + data.error);
                        $("#SUBMIT_EXTRACT").prop("disabled", false);
                    }
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    $("#status_icon").attr("class", "fa fa-times-circle status-error");
                    $("#status_text").text("Error: " + errorThrown);
                    $("#SUBMIT_EXTRACT").prop("disabled", false);
                }
            });
        }
    );
}

function startPolling(requestId) {
    if (gPollTimer) clearInterval(gPollTimer);
    gPollTimer = setInterval(function() {
        pollStatus(requestId);
    }, 5000);
}

function pollStatus(requestId) {
    apex.server.process("CHECK_BICC_STATUS", {
        x01: String(requestId)
    }, {
        dataType: "json",
        success: function(data) {
            if (!data.success) {
                stopPolling();
                $("#status_icon").attr("class", "fa fa-times-circle status-error");
                $("#status_text").text("Poll error: " + data.error);
                $("#SUBMIT_EXTRACT").prop("disabled", false);
                return;
            }
            var state = data.state;
            $("#status_text").text("Request " + requestId + ": " + state);

            if (state === "SUCCEEDED") {
                stopPolling();
                $("#status_icon").attr("class", "fa fa-check-circle status-success");
                apex.message.showPageSuccess("BICC extract completed successfully!");
                $("#SUBMIT_EXTRACT").prop("disabled", false);
            } else if (state === "ERROR" || state === "CANCELLED"
                    || state === "WARNING" || state === "EXPIRED") {
                stopPolling();
                $("#status_icon").attr("class", "fa fa-times-circle status-error");
                apex.message.showErrors([{
                    type: "error",
                    location: "page",
                    message: "Extract " + state + " (Request " + requestId + ")"
                }]);
                $("#SUBMIT_EXTRACT").prop("disabled", false);
            } else {
                $("#status_icon").attr("class", "fa fa-refresh fa-anim-spin");
            }
        },
        error: function() {
            $("#status_text").text("Request " + requestId + ": polling (network retry)...");
        }
    });
}

function stopPolling() {
    if (gPollTimer) {
        clearInterval(gPollTimer);
        gPollTimer = null;
    }
}

// =============================================================================
// TAB: BIP Manual Trigger
// Callback: RUN_BIP_REPORT
// Button: RUN_BIP
// Status panel: #bip_status > #bip_status_list
// Checkbox column: f05
// =============================================================================

function runBipSelected() {
    var selectedKeys = [];
    $("input[name='f05']:checked").each(function() {
        selectedKeys.push($(this).val());
    });

    if (selectedKeys.length === 0) {
        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: "Select at least one BIP report."
        }]);
        return;
    }

    apex.message.confirm(
        "Run " + selectedKeys.length + " BIP report(s)?",
        function(ok) {
            if (!ok) return;

            apex.message.clearErrors();
            $("#RUN_BIP").prop("disabled", true);
            $("#bip_status_list").parent().addClass("is-visible");
            $("#bip_status_list").empty();

            runBipSequence(selectedKeys, 0, 0, 0);
        }
    );
}

function runBipSequence(keys, idx, okCount, errCount) {
    if (idx >= keys.length) {
        finishBip(okCount, errCount);
        return;
    }

    var reportKey = keys[idx];
    var $row = $("<div class=\"sync-row\"><span class=\"fa fa-refresh fa-anim-spin\"></span> "
        + apex.util.escapeHTML(reportKey) + "...</div>");
    $("#bip_status_list").append($row);

    apex.server.process("RUN_BIP_REPORT", {
        x01: reportKey
    }, {
        dataType: "json",
        timeout: 600000,
        success: function(data) {
            if (data.status === "OK") {
                $row.html("<span class=\"fa fa-check-circle status-success\"></span> "
                    + apex.util.escapeHTML(reportKey));
                runBipSequence(keys, idx + 1, okCount + 1, errCount);
            } else {
                $row.html("<span class=\"fa fa-times-circle status-error\"></span> "
                    + apex.util.escapeHTML(reportKey) + " \u2014 " + apex.util.escapeHTML(data.message));
                runBipSequence(keys, idx + 1, okCount, errCount + 1);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            $row.html("<span class=\"fa fa-times-circle status-error\"></span> "
                + apex.util.escapeHTML(reportKey) + " \u2014 " + apex.util.escapeHTML(errorThrown));
            runBipSequence(keys, idx + 1, okCount, errCount + 1);
        }
    });
}

function finishBip(okCount, errCount) {
    $("#RUN_BIP").prop("disabled", false);

    if (errCount === 0) {
        apex.message.showPageSuccess(okCount + " BIP report(s) loaded successfully.");
    } else {
        apex.message.showErrors([{
            type: "error",
            location: "page",
            message: errCount + " report(s) failed. " + okCount + " succeeded."
        }]);
    }

    $(".a-IRR-region").trigger("apexrefresh");
}
