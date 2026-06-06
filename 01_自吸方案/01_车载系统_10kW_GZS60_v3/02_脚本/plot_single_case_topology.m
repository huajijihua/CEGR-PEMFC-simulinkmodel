function results = plot_single_case_topology(caseConfig)
%PLOT_SINGLE_CASE_TOPOLOGY Run one case and show topology key quantities.
%
% Example:
%   caseConfig.current_density_A_cm2 = 0.1;
%   caseConfig.oxygen_stoich = 5.0;
%   caseConfig.egr_ratio = 0.3;
%   results = plot_single_case_topology(caseConfig);

if nargin < 1
    caseConfig = struct();
end

C = cegr_viz_utils("context");
[row, detail] = cegr_viz_utils("runSingleCase", C, caseConfig);
fig = cegr_viz_utils("plotTopology", row, detail);

topologyTable = struct2table(row);
cegr_viz_utils("writeSheet", C, "single_case_topology", topologyTable);

results = struct();
results.case = row;
results.detail = detail;
results.figure = fig;
results.workbookFile = C.workbookFile;

assignin('base', 'singleCaseTopologyResults', results);
fprintf('Single-case topology figure opened. Data sheet updated: %s\n', C.workbookFile);
end
