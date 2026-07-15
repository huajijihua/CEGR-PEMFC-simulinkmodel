% Route A A9.8 FCU/BoP control interface audit.
% Runs short closed-loop checks for the explicit air and cEGR control
% interfaces. The script writes only a summary struct to base workspace.
% Optional base workspace controls:
% - routeA_a9_8_case_filter: caseId or group string array for split runs.
% - routeA_a9_8_stop_time_override: stop time override in seconds.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a9_8_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');
paths = routeA_block_paths(model);

audit = struct();
audit.model = model;
audit.phase = "A9.8";
audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.scope = "FCU/BoP control interface explicitization audit";
audit.generated = false;
audit.preflight = runPreflight(model, mw, paths);
audit.caseDefinitions = buildCaseDefinitions(mw);
audit.stopTime = 10;
audit.caseFilter = getBaseWorkspaceValue('routeA_a9_8_case_filter', strings(0, 1));
audit.stopTime = getBaseWorkspaceValue('routeA_a9_8_stop_time_override', audit.stopTime);
audit.caseDefinitions = filterCaseDefinitions(audit.caseDefinitions, audit.caseFilter);
audit.caseResults = repmat(emptyCaseResult(), numel(audit.caseDefinitions), 1);

fprintf('\nRoute A A9.8 FCU/BoP control audit\n');
fprintf('  model=%s\n', model);
fprintf('  timestamp=%s\n', audit.timestamp);
fprintf('  preflight passed=%d\n', audit.preflight.passed);
fprintf('  cases=%d stopTime=%.4g\n', numel(audit.caseDefinitions), ...
    audit.stopTime);

if audit.preflight.passed
    for idx = 1:numel(audit.caseDefinitions)
        result = runControlCase(model, modelFile, ...
            audit.caseDefinitions(idx), audit.stopTime);
        if ~result.simCompleted && contains(result.errorId, "ZeroCrossings")
            fprintf('  RETRY %s at 8 s after zero-crossing failure\n', ...
                result.caseId);
            result = runControlCase(model, modelFile, ...
                audit.caseDefinitions(idx), 8);
            result.retryFromDefault = true;
        end
        audit.caseResults(idx) = result;
    end
end

audit.responseTable = struct2table(audit.caseResults);
audit.relationChecks = checkRelations(audit.caseResults);
audit.generated = audit.preflight.passed && all([audit.caseResults.simCompleted]);
audit.passed = audit.generated && audit.relationChecks.allCritical;
assignin('base', 'routeA_a9_8_fcu_bop_control_audit', audit);
dispAudit(audit);

function result = runPreflight(model, mw, paths)
result = struct('passed', false, 'layerOk', false, ...
    'externalCaseDisabled', false, 'fcuExists', false, ...
    'egrValveControlled', false, 'errorId', "", 'errorMessage', "");
try
    layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
    externalEnabled = logical(getWorkspaceValue(mw, ...
        'routeA_external_case_enabled', true));
    result.layerOk = layer == "platform_default";
    result.externalCaseDisabled = ~externalEnabled;
    result.fcuExists = getSimulinkBlockHandle(paths.fcu) ~= -1;
    result.egrValveControlled = string(get_param(paths.egrValve, ...
        'const_area')) == "false";
    result.passed = result.layerOk && result.externalCaseDisabled && ...
        result.fcuExists && result.egrValveControlled;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function defs = buildCaseDefinitions(mw)
pipeArea = getWorkspaceValue(mw, 'cegr_pipe_area', 0.0019634954);
closedArea = getWorkspaceValue(mw, 'cegr_valve_area_closed', 1e-10);
defs = repmat(emptyCaseDefinition(), 15, 1);
idx = 0;
for mdot = [0.036 0.045 0.054]
    idx = idx + 1;
    defs(idx) = caseDef("target_mdot", sprintf('mdot_%.3f', mdot), ...
        1, mdot, 2.5, 0.5, 2, 0.02, closedArea, 50.96);
end
for oer = [2.0 2.5 3.0]
    idx = idx + 1;
    defs(idx) = caseDef("target_oer", sprintf('oer_%.1f', oer), ...
        2, 0.045, oer, 0.5, 2, 0.02, closedArea, 50.96);
end
for ratio = [0.005 0.02 0.10]
    idx = idx + 1;
    defs(idx) = caseDef("target_egr_ratio", sprintf('egr_ratio_%.3f', ratio), ...
        1, 0.045, 2.5, 0.5, 1, ratio, 2e-3 * pipeArea, 50.96);
end
for frac = [1e-6 5e-4 2e-3 1e-2 2e-2]
    idx = idx + 1;
    defs(idx) = caseDef("direct_area", sprintf('direct_area_%.4g', frac), ...
        1, 0.045, 2.5, 0.5, 2, 0.02, frac * pipeArea, 50.96);
end
idx = idx + 1;
defs(idx) = caseDef("nominal", "nominal_50p96kW", ...
    1, 0.045, 2.5, 0.5, 1, 0.02, 2e-3 * pipeArea, 50.96);
end

function c = emptyCaseDefinition()
c = struct('group', "", 'caseId', "", 'airMode', NaN, ...
    'targetMdot', NaN, 'targetOer', NaN, 'directCmd', NaN, ...
    'egrMode', NaN, 'targetEgrRatio', NaN, 'directArea', NaN, ...
    'targetPowerKW', NaN);
end

function c = caseDef(group, caseId, airMode, targetMdot, targetOer, ...
    directCmd, egrMode, targetEgrRatio, directArea, targetPowerKW)
c = emptyCaseDefinition();
c.group = string(group);
c.caseId = string(caseId);
c.airMode = airMode;
c.targetMdot = targetMdot;
c.targetOer = targetOer;
c.directCmd = directCmd;
c.egrMode = egrMode;
c.targetEgrRatio = targetEgrRatio;
c.directArea = directArea;
c.targetPowerKW = targetPowerKW;
end

function defs = filterCaseDefinitions(defs, caseFilter)
caseFilter = string(caseFilter);
caseFilter = caseFilter(strlength(caseFilter) > 0);
if isempty(caseFilter)
    return;
end
keep = false(size(defs));
for idx = 1:numel(defs)
    keep(idx) = any(defs(idx).caseId == caseFilter) || ...
        any(defs(idx).group == caseFilter);
end
defs = defs(keep);
end

function result = runControlCase(model, modelFile, c, stopTime)
result = emptyCaseResult();
result.group = c.group;
result.caseId = c.caseId;
result.airMode = c.airMode;
result.egrMode = c.egrMode;
result.targetMdot = c.targetMdot;
result.targetOer = c.targetOer;
result.targetEgrRatio = c.targetEgrRatio;
result.directArea = c.directArea;
result.targetPowerKW = c.targetPowerKW;
result.stopTime = stopTime;

fprintf('\nA9.8 case: %-22s group=%s\n', result.caseId, result.group);
try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    paths = routeA_block_paths(model);
    markAuditSignals(model, paths);
    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', sprintf('%.16g', stopTime), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'all');
    simIn = simIn.setVariable('drive_cycle_time', [0; 5; stopTime], ...
        'Workspace', model);
    simIn = simIn.setVariable('drive_cycle_power', ...
        [0; c.targetPowerKW; c.targetPowerKW], 'Workspace', model);
    simIn = simIn.setVariable('routeA_air_control_mode_id', ...
        c.airMode, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_mdot_comp_inlet', ...
        c.targetMdot, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_oer', ...
        c.targetOer, 'Workspace', model);
    simIn = simIn.setVariable('routeA_compressor_cmd_direct', ...
        c.directCmd, 'Workspace', model);
    simIn = simIn.setVariable('routeA_egr_control_mode_id', ...
        c.egrMode, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_egr_ratio_comp_in', ...
        c.targetEgrRatio, 'Workspace', model);
    simIn = simIn.setVariable('routeA_egr_valve_area_direct', ...
        c.directArea, 'Workspace', model);
    simIn = simIn.setVariable('routeA_stack_temperature_set_C', ...
        80, 'Workspace', model);
    simIn = simIn.setBlockParameter(paths.stackTemperature, ...
        'Value', 'routeA_stack_temperature_set_C');
    simOut = sim(simIn);
    result.simCompleted = true;
    result = collectResult(simOut, result, model);
    result = evaluateResult(result);
    fprintf('  %s cmd=%.4g rpm=%.4g mdot=%.4g egrArea=%.4g egr=%.4g\n', ...
        passFailText(result.passed), result.compressorCmd, ...
        result.compressorRpmCmd, result.compInletMdotKgS, ...
        result.egrValveAreaCmd, result.egrRatioCompIn);
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    fprintf('  FAIL %s: %s\n', result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function result = emptyCaseResult()
result = struct('group', "", 'caseId', "", 'passed', false, ...
    'simCompleted', false, 'errorId', "", 'errorMessage', "", ...
    'airMode', NaN, 'egrMode', NaN, 'targetMdot', NaN, ...
    'targetOer', NaN, 'targetEgrRatio', NaN, 'directArea', NaN, ...
    'targetPowerKW', NaN, 'actualPowerKW', NaN, 'stopTime', NaN, ...
    'retryFromDefault', false, ...
    'compressorCmd', NaN, 'compressorRpmCmd', NaN, ...
    'airControlError', NaN, 'airMdotSet', NaN, ...
    'compInletMdotKgS', NaN, 'egrValveAreaCmd', NaN, ...
    'egrValveCmdLimited', NaN, 'egrControlError', NaN, ...
    'egrRatioCompIn', NaN, 'o2CompInlet', NaN, ...
    'h2oCompInlet', NaN, 'pOutletPa', NaN, ...
    'pCompInletPa', NaN, 'kpiFiniteOk', false);
end

function result = collectResult(simOut, result, model)
logsout = simOut.logsout;
result.compressorCmd = scalarLastOrNaN(logsout, "routeA_compressor_cmd");
if ~isfinite(result.compressorCmd)
    result.compressorCmd = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_compressor_cmd_ts");
end
result.compressorRpmCmd = scalarLastOrNaN(logsout, "routeA_compressor_rpm_cmd");
if ~isfinite(result.compressorRpmCmd)
    result.compressorRpmCmd = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_compressor_rpm_cmd_ts");
end
result.airControlError = scalarLastOrNaN(logsout, "routeA_air_control_error");
if ~isfinite(result.airControlError)
    result.airControlError = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_air_control_error_ts");
end
result.airMdotSet = scalarLastOrNaN(logsout, "routeA_air_mdot_set");
if ~isfinite(result.airMdotSet)
    result.airMdotSet = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_air_mdot_set_ts");
end
result.compInletMdotKgS = scalarLastOrNaN(logsout, "routeA_mdot_comp_inlet");
result.egrValveAreaCmd = scalarLastOrNaN(logsout, "routeA_egr_valve_area_cmd");
if ~isfinite(result.egrValveAreaCmd)
    result.egrValveAreaCmd = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_egr_valve_area_cmd_ts");
end
result.egrValveCmdLimited = scalarLastOrNaN(logsout, ...
    "routeA_egr_valve_cmd_limited");
if ~isfinite(result.egrValveCmdLimited)
    result.egrValveCmdLimited = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_egr_valve_cmd_limited_ts");
end
result.egrControlError = scalarLastOrNaN(logsout, "routeA_egr_control_error");
if ~isfinite(result.egrControlError)
    result.egrControlError = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_egr_control_error_ts");
end
result.egrRatioCompIn = scalarLastOrNaN(logsout, "routeA_egr_ratio_comp_in");
if ~isfinite(result.egrRatioCompIn)
    result.egrRatioCompIn = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_egr_ratio_comp_in_ts");
end
yiComp = vectorLastOrNaN(logsout, "routeA_yi_comp_inlet", 4);
result.o2CompInlet = yiComp(2);
result.h2oCompInlet = yiComp(4);
result.pOutletPa = scalarLastOrNaN(logsout, "routeA_p_outlet");
result.pCompInletPa = scalarLastOrNaN(logsout, "routeA_p_comp_inlet");
result.actualPowerKW = collectSimscapePower(simOut, model);
end

function result = evaluateResult(result)
finiteList = [result.compressorCmd, result.compressorRpmCmd, ...
    result.compInletMdotKgS, result.egrValveAreaCmd, ...
    result.egrValveCmdLimited, result.egrRatioCompIn, ...
    result.o2CompInlet, result.h2oCompInlet, result.pOutletPa, ...
    result.pCompInletPa];
result.kpiFiniteOk = all(isfinite(finiteList));
result.passed = result.simCompleted && result.kpiFiniteOk;
end

function checks = checkRelations(results)
checks = struct();
checks.targetMdot = relationCheck("target_mdot_to_compressor", ...
    isIncreasing(results, "target_mdot", 'targetMdot') && ...
    isIncreasing(results, "target_mdot", 'compressorCmd') && ...
    isIncreasing(results, "target_mdot", 'compressorRpmCmd') && ...
    isIncreasing(results, "target_mdot", 'compInletMdotKgS'), ...
    "target mdot up should increase compressor command, rpm, and measured mdot");
checks.targetOer = relationCheck("target_oer_to_mdot", ...
    isIncreasing(results, "target_oer", 'targetOer') && ...
    isIncreasing(results, "target_oer", 'compInletMdotKgS'), ...
    "target OER mode should preserve OER-to-flow direction");
checks.targetEgr = relationCheck("target_egr_to_valve_and_ratio", ...
    isIncreasing(results, "target_egr_ratio", 'targetEgrRatio') && ...
    isIncreasing(results, "target_egr_ratio", 'egrValveAreaCmd') && ...
    isIncreasing(results, "target_egr_ratio", 'egrRatioCompIn'), ...
    "target EGR ratio up should increase valve area and measured EGR ratio");
checks.directArea = relationCheck("direct_area_to_ratio", ...
    isIncreasing(results, "direct_area", 'directArea') && ...
    isIncreasing(results, "direct_area", 'egrRatioCompIn'), ...
    "direct area open-loop regression should remain monotonic");
nominal = results(strcmp({results.group}, 'nominal'));
checks.nominal = relationCheck("nominal_finite", ...
    ~isempty(nominal) && nominal(1).passed && isfinite(nominal(1).actualPowerKW), ...
    "nominal 50.96 kW combined case should complete with finite KPIs");
checks.allCritical = checks.targetMdot.passed && checks.targetOer.passed && ...
    checks.targetEgr.passed && checks.directArea.passed && checks.nominal.passed;
end

function check = relationCheck(name, passed, note)
check = struct('name', string(name), 'passed', logical(passed), ...
    'note', string(note));
end

function tf = isIncreasing(results, group, fieldName)
subset = results(strcmp({results.group}, group));
values = [subset.(fieldName)];
tf = numel(values) >= 2 && all(isfinite(values)) && ...
    all(diff(values) > 0);
end

function powerKW = collectSimscapePower(simOut, model)
powerKW = NaN;
try
    simlog = simOut.get(['simlog_' model]);
    mea = routeA_simscape_log_mea(simlog);
    powerKW = mea.power_elec.series.values('kW');
    powerKW = powerKW(end);
catch
end
end

function markAuditSignals(model, paths)
nameLineFromBlockOut(paths.compressorFlowConverter, ...
    'routeA_mdot_comp_inlet');
nameLineFromBlockOut(paths.compressorCommandSwitch, ...
    'routeA_compressor_cmd');
nameLineFromBlockOut(paths.compressorRpmCommand, ...
    'routeA_compressor_rpm_cmd');
nameLineFromBlockOut(paths.airControlError, ...
    'routeA_air_control_error');
nameLineFromBlockOut(paths.airMdotSetSwitch, ...
    'routeA_air_mdot_set');
nameLineFromBlockOutPort(paths.fcu, 1, ...
    'routeA_egr_valve_area_cmd');
nameLineFromBlockOutPort(paths.fcu, 2, ...
    'routeA_egr_valve_cmd_limited');
nameLineFromBlockOutPort(paths.fcu, 3, ...
    'routeA_egr_control_error');
nameLineFromBlockOutPort(paths.fcu, 4, ...
    'routeA_egr_ratio_comp_in');
end

function nameLineFromBlockOut(blockPath, signalName)
nameLineFromBlockOutPort(blockPath, 1, signalName);
end

function nameLineFromBlockOutPort(blockPath, portNumber, signalName)
if getSimulinkBlockHandle(blockPath) == -1
    return;
end
ph = get_param(blockPath, 'PortHandles');
if numel(ph.Outport) < portNumber
    return;
end
lineHandle = get_param(ph.Outport(portNumber), 'Line');
if lineHandle ~= -1
    set_param(lineHandle, 'Name', signalName);
    try
        set_param(lineHandle, 'DataLogging', 'on');
    catch
    end
    try
        set_param(lineHandle, 'DataLoggingNameMode', 'Custom', ...
            'DataLoggingName', signalName);
    catch
    end
    try
        set_param(lineHandle, 'TestPoint', 'on');
    catch
    end
end
end

function value = scalarLastOrNaN(logsout, signalName)
value = lastLoggedValueOrNaN(logsout, signalName);
if isempty(value)
    value = NaN;
else
    value = value(1);
end
end

function value = vectorLastOrNaN(logsout, signalName, n)
value = lastLoggedValueOrNaN(logsout, signalName);
if isempty(value)
    value = NaN(1, n);
elseif numel(value) < n
    value = [value(:).' NaN(1, n - numel(value))];
else
    value = value(1:n);
end
end

function value = scalarLastFromSimOutOrNaN(simOut, variableName)
value = NaN;
try
    signal = simOut.get(char(variableName));
catch
    return;
end
if isempty(signal)
    return;
end
try
    data = signal.Data;
    value = data(end);
catch
    try
        value = signal(end);
    catch
        value = NaN;
    end
end
end

function value = lastLoggedValueOrNaN(logsout, signalName)
value = NaN;
signalElement = findLoggedElement(logsout, signalName);
if isempty(signalElement)
    return;
end
signal = signalElement.Values;
data = signal.Data;
nTime = numel(signal.Time);
if isvector(data)
    value = data(end);
elseif size(data, 1) == nTime
    value = squeeze(data(end, :));
elseif size(data, ndims(data)) == nTime
    reshaped = reshape(data, [], nTime);
    value = reshaped(:, end).';
else
    value = squeeze(data(end, :));
end
value = value(:).';
end

function signalElement = findLoggedElement(logsout, signalName)
signalElement = [];
for idx = 1:logsout.numElements
    candidate = logsout.get(idx);
    if string(candidate.Name) == signalName
        signalElement = candidate;
        return;
    end
end
end

function value = getWorkspaceValue(modelWorkspace, name, fallback)
value = fallback;
try
    value = modelWorkspace.getVariable(name);
catch
end
end

function value = getBaseWorkspaceValue(name, fallback)
value = fallback;
try
    if evalin('base', sprintf('exist(''%s'', ''var'')', name))
        value = evalin('base', name);
    end
catch
    value = fallback;
end
end

function txt = firstLine(txt)
parts = splitlines(txt);
txt = parts(1);
end

function txt = passFailText(tf)
if tf
    txt = "PASS";
else
    txt = "FAIL";
end
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
end

function refreshModelWorkspace(model)
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
end
end

function restoreFolderAndModel(oldDir, model, modelFile)
cd(oldDir);
if bdIsLoaded(model)
    close_system(model, 0);
end
if exist(modelFile, 'file')
    load_system(modelFile);
end
end

function dispAudit(audit)
fprintf('\nA9.8 result\n');
fprintf('  generated=%d passed=%d cases=%d/%d\n', audit.generated, ...
    audit.passed, nnz([audit.caseResults.simCompleted]), ...
    numel(audit.caseResults));
names = fieldnames(audit.relationChecks);
for idx = 1:numel(names)
    item = audit.relationChecks.(names{idx});
    if isstruct(item) && isfield(item, 'passed')
        fprintf('  %-30s passed=%d\n', item.name, item.passed);
    end
end
end
