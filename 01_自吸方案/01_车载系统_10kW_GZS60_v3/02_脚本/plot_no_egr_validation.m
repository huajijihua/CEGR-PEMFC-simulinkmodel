function results = plot_no_egr_validation()
%PLOT_NO_EGR_VALIDATION Show no-EGR bench/simulation validation figures.

C = cegr_viz_utils("context");
[validation, stats] = cegr_viz_utils("makeNoEgrValidation", C);
fig = cegr_viz_utils("plotNoEgrValidation", validation, stats);

cegr_viz_utils("writeSheet", C, "no_egr_validation", validation);
cegr_viz_utils("writeSheet", C, "no_egr_validation_stats", stats);

results = struct();
results.validation = validation;
results.stats = stats;
results.figure = fig;
results.workbookFile = C.workbookFile;

assignin('base', 'noEgrValidationResults', results);
fprintf('No-EGR validation figure opened. Data sheet updated: %s\n', C.workbookFile);
end
