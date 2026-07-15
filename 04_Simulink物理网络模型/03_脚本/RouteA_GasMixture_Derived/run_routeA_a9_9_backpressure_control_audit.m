% Route A A9.9 cathode backpressure control interface audit.
% Verifies that target cathode outlet pressure is exposed as a model
% workspace setpoint and drives the existing pressure relief valve.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a9_9_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');
paths = routeA_block_paths(model);

audit = struct();
audit.model = model;
audit.phase = "A9.9";
audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.scope = "cathode outlet pressure/backpressure setpoint audit";
audit.preflight = runPreflight(model, mw, paths);
audit.caseDefinitions = buildCaseDefinitions();
audit.caseResults = repmat(emptyCaseResult(), numel(audit.caseDefinitions), 1);
audit.stopTime = 10;

fprintf('\nRoute A A9.9 backpressure control audit\n');
fprintf('  model=%s\n', model);
fprintf('  preflight passed=%d\n', audit.preflight.passed);

if audit.preflight.passed
    for idx = 1:numel(audit.caseDefinitions)
        audit.caseResults(idx) = runPressureCase(model, modelFile, ...
            audit.caseDefinitions(idx), audit.stopTime);
    end
end

audit.responseTable = struct2table(audit.caseResults);
audit.relationChecks = checkRelations(audit.caseResults);
audit.generated = audit.preflight.passed && all([audit.caseResults.simCompleted]);
audit.passed = audit.generated && audit.relationChecks.allCritical;
assignin('base', 'routeA_a9_9_backpressure_control_audit', audit);
dispAudit(audit);

function result = runPreflight(model, mw, paths)
result = struct('passed', false, 'layerOk', false, ...
    'externalCaseDisabled', false, 'pressureTargetVariable', false, ...
    'stackPressureBlockUsesTarget', false, 'errorId', "", 'errorMessage', "");
try
    layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
    externalEnabled = logical(getWorkspaceValue(mw, ...
        'routeA_external_case_enabled', true));
    result.layerOk = layer == "platform_default";
    result.externalCaseDisabled = ~externalEnabled;
    result.pressureTargetVariable = isfinite(getWorkspaceValue(mw, ...
        'routeA_target_p_ca_out_MPa', NaN));
    value = string(get_param([paths.cathodeExhaustBlock '/Stack Pressure'], ...
        'Value'));
    result.stackPressureBlockUsesTarget = contains(value, ...
        "routeA_target_p_ca_out_MPa");
    result.passed = result.layerOk && result.externalCaseDisabled && ...
        result.pressureTargetVariable && result.stackPressureBlockUsesTarget;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function defs = buildCaseDefinitions()
targets = [0.145 0.161325 0.180]; % [MPa] absolute cathode outlet pressure targets
defs = repmat(emptyCaseDefinition(), numel(targets), 1);
for idx = 1:numel(targets)
    defs(idx).caseId = sprintf('p_ca_out_%.3fMPa', targets(idx));
    defs(idx).targetPCaOutMPa = targets(idx);
    defs(idx).targetMdot = 0.045;
    defs(idx).targetPowerKW = 50.96;
    defs(idx).targetEgrRatio = 0.02;
end
end

function c = emptyCaseDefinition()
c = struct('caseId', "", 'targetPCaOutMPa', NaN, ...
    'targetMdot', NaN, 'targetPowerKW', NaN, 'targetEgrRatio', NaN);
end

function result = runPressureCase(model, modelFile, c, stopTime)
result = emptyCaseResult();
result.caseId = string(c.caseId);
result.targetPCaOutMPa = c.targetPCaOutMPa;
result.targetMdot = c.targetMdot;
result.targetPowerKW = c.targetPowerKW;
result.targetEgrRatio = c.targetEgrRatio;
result.stopTime = stopTime;

fprintf('\nA9.9 case: %-18s target=%.4g MPa\n', ...
    result.caseId, result.targetPCaOutMPa);
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
    simIn = simIn.setVariable('drive_cycle_time', [0; 4; stopTime], ...
        'Workspace', model);
    simIn = simIn.setVariable('drive_cycle_power', ...
        [0; c.targetPowerKW; c.targetPowerKW], 'Workspace', model);
    simIn = simIn.setVariable('routeA_air_control_mode_id', ...
        1, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_mdot_comp_inlet', ...
        c.targetMdot, 'Workspace', model);
    simIn = simIn.setVariable('routeA_egr_control_mode_id', ...
        1, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_egr_ratio_comp_in', ...
        c.targetEgrRatio, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_p_ca_out_MPa', ...
        c.targetPCaOutMPa, 'Workspace', model);
    simOut = sim(simIn);
    result.simCompleted = true;
    result = collectResult(simOut, result, model);
    result = evaluateResult(result);
    fprintf('  %s pOut=%.4g MPa error=%.4g MPa mdot=%.4g\n', ...
        passFailText(result.passed), result.pOutletMPa, ...
        result.pressureErrorMPa, result.compInletMdotKgS);
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    fprintf('  FAIL %s: %s\n', result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function result = emptyCaseResult()
result = struct('caseId', "", 'passed', false, 'simCompleted', false, ...
    'errorId', "", 'errorMessage', "", 'targetPCaOutMPa', NaN, ...
    'targetMdot', NaN, 'targetPowerKW', NaN, 'targetEgrRatio', NaN, ...
    'stopTime', NaN, 'pOutletMPa', NaN, 'pCompInletMPa', NaN, ...
    'pressureErrorMPa', NaN, 'compInletMdotKgS', NaN, ...
    'actualPowerKW', NaN, 'kpiFiniteOk', false);
end

function result = collectResult(simOut, result, model)
logsout = simOut.logsout;
result.pOutletMPa = scalarLastOrNaN(logsout, "routeA_p_outlet") / 1e6;
result.pCompInletMPa = scalarLastOrNaN(logsout, "routeA_p_comp_inlet") / 1e6;
result.compInletMdotKgS = scalarLastOrNaN(logsout, "routeA_mdot_comp_inlet");
result.actualPowerKW = collectSimscapePower(simOut, model);
result.pressureErrorMPa = result.pOutletMPa - result.targetPCaOutMPa;
end

function result = evaluateResult(result)
result.kpiFiniteOk = all(isfinite([result.pOutletMPa, ...
    result.pCompInletMPa, result.compInletMdotKgS, result.actualPowerKW, ...
    result.pressureErrorMPa]));
result.passed = result.simCompleted && result.kpiFiniteOk && ...
    abs(result.pressureErrorMPa) <= 0.01;
end

function checks = checkRelations(results)
checks = struct();
targets = [results.targetPCaOutMPa];
pOut = [results.pOutletMPa];
checks.pressureTarget = relationCheck("target_pressure_to_p_out", ...
    numel(results) >= 3 && all(isfinite([targets pOut])) && ...
    all(diff(targets) > 0) && all(diff(pOut) > 0), ...
    "target cathode outlet pressure up should increase measured outlet pressure");
checks.finite = relationCheck("finite_all_cases", ...
    all([results.passed]), ...
    "all pressure target cases should complete with finite KPIs and tolerance");
checks.allCritical = checks.pressureTarget.passed && checks.finite.passed;
end

function check = relationCheck(name, passed, note)
check = struct('name', string(name), 'passed', logical(passed), ...
    'note', string(note));
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
nameLineFromBlockOut(paths.outletPConverter, 'routeA_p_outlet');
nameLineFromBlockOut(paths.compressorInletPressureConverter, ...
    'routeA_p_comp_inlet');
nameLineFromBlockOut(paths.compressorFlowConverter, ...
    'routeA_mdot_comp_inlet');
end

function nameLineFromBlockOut(blockPath, signalName)
if getSimulinkBlockHandle(blockPath) == -1
    return;
end
ph = get_param(blockPath, 'PortHandles');
if isempty(ph.Outport)
    return;
end
lineHandle = get_param(ph.Outport(1), 'Line');
if lineHandle ~= -1
    set_param(lineHandle, 'Name', signalName);
    try
        set_param(lineHandle, 'DataLogging', 'on');
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

function value = lastLoggedValueOrNaN(logsout, signalName)
value = NaN;
for idx = 1:logsout.numElements
    candidate = logsout.get(idx);
    if string(candidate.Name) == signalName
        signal = candidate.Values;
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
fprintf('\nA9.9 result\n');
fprintf('  generated=%d passed=%d cases=%d/%d\n', audit.generated, ...
    audit.passed, nnz([audit.caseResults.simCompleted]), ...
    numel(audit.caseResults));
fprintf('  target_pressure passed=%d finite=%d\n', ...
    audit.relationChecks.pressureTarget.passed, ...
    audit.relationChecks.finite.passed);
end
