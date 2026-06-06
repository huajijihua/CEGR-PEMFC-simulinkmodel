function results = run_cegr_visualization_console(caseConfig, options)
%RUN_CEGR_VISUALIZATION_CONSOLE Run the CEGR visualization console.
%
% This opens eight MATLAB figures and writes all tabular results into one
% workbook. No image files are generated.

if nargin < 1
    caseConfig = struct();
end
if nargin < 2
    options = struct();
end
if ~isfield(options, 'UseExistingData')
    options.UseExistingData = false;
end

C = cegr_viz_utils("context");
cegr_viz_utils("closeFigures");

[topologyRow, topologyDetail] = cegr_viz_utils("runSingleCase", C, caseConfig);
figTopology = cegr_viz_utils("plotTopology", topologyRow, topologyDetail);
topologyTable = struct2table(topologyRow);
cegr_viz_utils("writeSheet", C, "single_case_topology", topologyTable);

if options.UseExistingData
    validation = readtable(C.workbookFile, 'Sheet', 'no_egr_validation', 'TextType', 'string');
    validationStats = readtable(C.workbookFile, 'Sheet', 'no_egr_validation_stats', 'TextType', 'string');
else
    [validation, validationStats] = cegr_viz_utils("makeNoEgrValidation", C);
    cegr_viz_utils("writeSheet", C, "no_egr_validation", validation);
    cegr_viz_utils("writeSheet", C, "no_egr_validation_stats", validationStats);
end
figValidation = cegr_viz_utils("plotNoEgrValidation", validation, validationStats);

if options.UseExistingData
    constantCurrent = readtable(C.workbookFile, 'Sheet', 'egr_constant_current', 'TextType', 'string');
    runInfoCurrent = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), "plot_existing_egr_constant_current", string(C.model), string(C.modelFile), string(C.workbookFile), ...
        'VariableNames', {'run_time','run_type','model_name','model_file','workbook_file'});
else
    [constantCurrent, runInfoCurrent] = cegr_viz_utils("runEgrConstantCurrent", C, "BaseStep", 0.10);
    cegr_viz_utils("writeSheet", C, "egr_constant_current", constantCurrent);
end
figCurrentMain = cegr_viz_utils("plotEgrMain", constantCurrent);
figCurrentDiag = cegr_viz_utils("plotEgrDiagnostics", constantCurrent);

if options.UseExistingData
    constantVoltage = readtable(C.workbookFile, 'Sheet', 'egr_constant_voltage', 'TextType', 'string');
    voltageTargets = readtable(C.workbookFile, 'Sheet', 'constant_voltage_targets', 'TextType', 'string');
    runInfoVoltage = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), "plot_existing_egr_constant_voltage", string(C.model), string(C.modelFile), string(C.workbookFile), ...
        'VariableNames', {'run_time','run_type','model_name','model_file','workbook_file'});
else
    [constantVoltage, runInfoVoltage, voltageTargets] = cegr_viz_utils("runEgrConstantVoltage", C, "BaseStep", 0.10);
    cegr_viz_utils("writeSheet", C, "egr_constant_voltage", constantVoltage);
    cegr_viz_utils("writeSheet", C, "constant_voltage_targets", voltageTargets);
end
figVoltageMain = cegr_viz_utils("plotEgrMain", constantVoltage);
figVoltageDiag = cegr_viz_utils("plotEgrDiagnostics", constantVoltage);

if options.UseExistingData
    constantPO2 = readtable(C.workbookFile, 'Sheet', 'egr_constant_pO2', 'TextType', 'string');
    runInfoPO2 = table(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), "plot_existing_egr_constant_pO2", string(C.model), string(C.modelFile), string(C.workbookFile), ...
        'VariableNames', {'run_time','run_type','model_name','model_file','workbook_file'});
else
    [constantPO2, runInfoPO2] = cegr_viz_utils("runEgrConstantPO2", C, "BaseStep", 0.10);
    cegr_viz_utils("writeSheet", C, "egr_constant_pO2", constantPO2);
end
figPO2Main = cegr_viz_utils("plotEgrMain", constantPO2);
figPO2Diag = cegr_viz_utils("plotEgrDiagnostics", constantPO2);

runInfo = [runInfoCurrent; runInfoVoltage; runInfoPO2];
if ~options.UseExistingData
    cegr_viz_utils("writeSheet", C, "run_info", runInfo);
end

results = struct();
results.topology = topologyTable;
results.validation = validation;
results.validationStats = validationStats;
results.constantCurrent = constantCurrent;
results.constantVoltage = constantVoltage;
results.voltageTargets = voltageTargets;
results.constantPO2 = constantPO2;
results.figures = [figTopology, figValidation, figCurrentMain, figCurrentDiag, ...
    figVoltageMain, figVoltageDiag, figPO2Main, figPO2Diag];
results.workbookFile = C.workbookFile;

assignin('base', 'cegrVisualizationConsoleResults', results);
fprintf('CEGR visualization console opened 8 figures. Data workbook updated: %s\n', C.workbookFile);
end
