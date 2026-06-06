function results = run_and_plot_egr_constant_current()
%RUN_AND_PLOT_EGR_CONSTANT_CURRENT Run and plot fixed-flow EGR scans.
%
% The scan uses fixed total compressor inlet mass flow. EGR return replaces
% equal fresh-air mass at each current-density baseline.

C = cegr_viz_utils("context");
[scan, runInfo] = cegr_viz_utils("runEgrConstantCurrent", C);
mainFig = cegr_viz_utils("plotEgrMain", scan);
diagFig = cegr_viz_utils("plotEgrDiagnostics", scan);

cegr_viz_utils("writeSheet", C, "egr_constant_current", scan);
cegr_viz_utils("writeSheet", C, "run_info", runInfo);

results = struct();
results.scan = scan;
results.runInfo = runInfo;
results.mainFigure = mainFig;
results.diagnosticFigure = diagFig;
results.workbookFile = C.workbookFile;

assignin('base', 'egrConstCurrentResults', results);
fprintf('Constant-current EGR figures opened. Data sheet updated: %s\n', C.workbookFile);
end
