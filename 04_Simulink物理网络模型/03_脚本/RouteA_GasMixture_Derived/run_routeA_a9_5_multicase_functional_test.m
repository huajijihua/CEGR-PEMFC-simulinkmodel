% Route A A9.5 multicase functional steady-state test.
% This script validates the A9 platform baseline over 3 load points x
% 3 cEGR valve settings. It does not save or structurally edit the model.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a9_5_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');
paths = routeA_block_paths(model);

audit = struct();
audit.model = model;
audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.phase = "A9.5";
audit.scope = "platform_default functional multicase test";
audit.note = "No structural edit; no external_case; no stoich/inlet control interface added.";
audit.preflight = runPreflight(model, mw, paths);
audit.caseDefinitions = buildCaseDefinitions(mw);
audit.caseFilter = getBaseStringArray('routeA_a9_5_case_filter');
if ~isempty(audit.caseFilter)
    audit.caseDefinitions = filterCaseDefinitions(audit.caseDefinitions, ...
        audit.caseFilter);
end
audit.isFullMatrix = isempty(audit.caseFilter) && ...
    numel(audit.caseDefinitions) == 9;
audit.caseDefinitionsOk = ~isempty(audit.caseDefinitions);
audit.results = repmat(emptyCaseResult(), numel(audit.caseDefinitions), 1);

fprintf('\nRoute A A9.5 multicase functional test\n');
fprintf('  model=%s\n', model);
fprintf('  timestamp=%s\n', audit.timestamp);
fprintf('  preflight passed=%d\n', audit.preflight.passed);

if audit.preflight.passed && audit.caseDefinitionsOk
    for idx = 1:numel(audit.caseDefinitions)
        c = audit.caseDefinitions(idx);
        result = runFunctionalCase(model, modelFile, c, 30);
        if result.simCompleted && ~result.steadyOk
            fprintf('  RETRY %s at 60 s: power_drift=%.4g egr_drift=%.4g\n', ...
                result.caseId, result.powerDriftFrac, result.egrRatioDriftAbs);
            result = runFunctionalCase(model, modelFile, c, 60);
            result.retryFrom30s = true;
        end
        audit.results(idx) = result;
    end
elseif ~audit.preflight.passed
    fprintf('  SKIP cases because preflight failed: %s %s\n', ...
        audit.preflight.errorId, audit.preflight.errorMessage);
else
    fprintf('  SKIP cases because no case definitions matched the filter\n');
end

audit.trend = checkTrendAcceptance(audit.results, audit.isFullMatrix);
audit.summaryTable = resultsToTable(audit.results);
audit.passed = audit.preflight.passed && audit.caseDefinitionsOk && ...
    all([audit.results.passed]) && ...
    (~audit.isFullMatrix || audit.trend.passed);
audit.saveSummaryCsv = getBaseFlag('routeA_a9_5_save_summary_csv', false);

if audit.saveSummaryCsv
    outDir = fullfile(pwd, 'RouteA_A9_5_results');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    stamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    audit.summaryCsv = fullfile(outDir, ...
        ['routeA_a9_5_summary_' char(stamp) '.csv']);
    writetable(audit.summaryTable, audit.summaryCsv);
else
    audit.summaryCsv = "";
end

assignin('base', 'routeA_a9_5_multicase_functional_test', audit);
dispAudit(audit);

function result = runPreflight(model, mw, paths)
result = struct( ...
    'passed', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
    'layerOk', false, ...
    'externalCaseDisabled', false, ...
    'anodeTubeOk', false, ...
    'cathodeSeparatorOk', false, ...
    'cegrMaxFractionOk', false, ...
    'signalsAvailable', false);
try
    layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
    externalEnabled = logical(getWorkspaceValue(mw, ...
        'routeA_external_case_enabled', true));
    anodeTubeD = getWorkspaceValue(mw, 'anode_tube_D', NaN);
    cathSepMdot = getWorkspaceValue(mw, ...
        'cathode_separator_mdot_nominal', NaN);
    cegrMaxFrac = getWorkspaceValue(mw, ...
        'cegr_valve_area_frac_max', NaN);
    result.layerOk = layer == "platform_default";
    result.externalCaseDisabled = ~externalEnabled;
    result.anodeTubeOk = near(anodeTubeD, 0.02, 1e-9);
    result.cathodeSeparatorOk = near(cathSepMdot, 0.10, 1e-9);
    result.cegrMaxFractionOk = near(cegrMaxFrac, 0.02, 1e-12);
    result.signalsAvailable = requiredBlocksPresent(model, paths);
    result.passed = result.layerOk && result.externalCaseDisabled && ...
        result.anodeTubeOk && result.cathodeSeparatorOk && ...
        result.cegrMaxFractionOk && result.signalsAvailable;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function defs = buildCaseDefinitions(mw)
stackNumCells = getWorkspaceValue(mw, 'stack_num_cells', 400);
stackAreaCm2 = getWorkspaceValue(mw, 'stack_area', 280);
loads = [ ...
    loadDef("low", 0.2, 0.78); ...
    loadDef("nominal", 0.7, 0.65); ...
    loadDef("high", 1.2, 0.58)];
egrs = [ ...
    egrDef("no_egr", "cegr_valve_area_closed", 1e-6); ...
    egrDef("low_egr", "cegr_valve_area_low", 5e-4); ...
    egrDef("mid_egr", "2e-3*cegr_pipe_area", 2e-3)];
defs = repmat(emptyCaseDefinition(), numel(loads) * numel(egrs), 1);
idx = 0;
for egrIdx = 1:numel(egrs)
    for loadIdx = 1:numel(loads)
        idx = idx + 1;
        c = emptyCaseDefinition();
        c.caseId = sprintf('%s_%s_load', egrs(egrIdx).label, ...
            loads(loadIdx).label);
        c.loadLabel = loads(loadIdx).label;
        c.egrLabel = egrs(egrIdx).label;
        c.currentDensityAcm2 = loads(loadIdx).currentDensityAcm2;
        c.referenceCellVoltageV = loads(loadIdx).cellVoltageV;
        c.targetCurrentA = c.currentDensityAcm2 * stackAreaCm2;
        c.targetPowerKW = c.targetCurrentA * stackNumCells * ...
            c.referenceCellVoltageV / 1000;
        c.restrictionArea = egrs(egrIdx).restrictionArea;
        c.areaFraction = egrs(egrIdx).areaFraction;
        c.humidifierGain = 1;
        defs(idx) = c;
    end
end
end

function defs = filterCaseDefinitions(defs, caseFilter)
keep = false(size(defs));
for idx = 1:numel(defs)
    keep(idx) = any(string(defs(idx).caseId) == caseFilter);
end
defs = defs(keep);
end

function c = emptyCaseDefinition()
c = struct( ...
    'caseId', "", ...
    'loadLabel', "", ...
    'egrLabel', "", ...
    'currentDensityAcm2', NaN, ...
    'referenceCellVoltageV', NaN, ...
    'targetCurrentA', NaN, ...
    'targetPowerKW', NaN, ...
    'restrictionArea', "", ...
    'areaFraction', NaN, ...
    'humidifierGain', 1);
end

function d = loadDef(label, currentDensityAcm2, cellVoltageV)
d = struct('label', string(label), ...
    'currentDensityAcm2', currentDensityAcm2, ...
    'cellVoltageV', cellVoltageV);
end

function d = egrDef(label, restrictionArea, areaFraction)
d = struct('label', string(label), ...
    'restrictionArea', string(restrictionArea), ...
    'areaFraction', areaFraction);
end

function result = runFunctionalCase(model, modelFile, c, stopTime)
result = emptyCaseResult();
result.caseId = string(c.caseId);
result.loadLabel = string(c.loadLabel);
result.egrLabel = string(c.egrLabel);
result.stopTime = stopTime;
result.targetPowerKW = c.targetPowerKW;
result.targetCurrentA = c.targetCurrentA;
result.targetCurrentDensityAcm2 = c.currentDensityAcm2;
result.referenceCellVoltageV = c.referenceCellVoltageV;
result.restrictionArea = string(c.restrictionArea);
result.areaFraction = c.areaFraction;
result.humidifierGain = c.humidifierGain;

fprintf('\nRoute A A9.5 case: %s stop=%g s target=%.4g kW area=%s\n', ...
    result.caseId, stopTime, result.targetPowerKW, result.restrictionArea);
try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    paths = routeA_block_paths(model);
    markAuditSignals(paths);
    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', sprintf('%.16g', stopTime), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'all');
    simIn = simIn.setVariable('drive_cycle_time', ...
        [0; 5; stopTime], 'Workspace', model);
    simIn = simIn.setVariable('drive_cycle_power', ...
        [0; c.targetPowerKW; c.targetPowerKW], 'Workspace', model);
    simIn = simIn.setVariable('routeA_cathode_humidifier_gain', ...
        c.humidifierGain);
    simIn = simIn.setBlockParameter(paths.egrValve, ...
        'restriction_area', char(c.restrictionArea));
    simOut = sim(simIn);
    result.simCompleted = true;
    result = collectCaseResult(simOut, result, model);
    result = evaluateCase(result, simOut, model);
    result.passed = result.simCompleted && result.steadyOk && ...
        result.powerTrackingOk && result.pressureChainOk && ...
        result.kpiFiniteOk && result.kpiNonnegativeOk && ...
        result.egrLevelOk;
    fprintf('  %s power=%.4g kW err=%.3g egr=%.4g split=%.4g steady=%d passed=%d\n', ...
        passFailText(result.passed), result.actualPowerKW, ...
        result.powerTrackingErrorFrac, result.egrRatioCompIn, ...
        result.egrSplitRatioOut, result.steadyOk, result.passed);
catch ME
    result.simCompleted = false;
    result.passed = false;
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    fprintf('  FAIL %s: %s\n', result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function result = emptyCaseResult()
result = struct( ...
    'caseId', "", ...
    'loadLabel', "", ...
    'egrLabel', "", ...
    'stopTime', NaN, ...
    'retryFrom30s', false, ...
    'passed', false, ...
    'simCompleted', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
    'targetPowerKW', NaN, ...
    'targetCurrentA', NaN, ...
    'targetCurrentDensityAcm2', NaN, ...
    'referenceCellVoltageV', NaN, ...
    'restrictionArea', "", ...
    'areaFraction', NaN, ...
    'humidifierGain', NaN, ...
    'actualPowerKW', NaN, ...
    'powerDissipatedKW', NaN, ...
    'powerTrackingErrorFrac', NaN, ...
    'powerTrackingOk', false, ...
    'powerDriftFrac', NaN, ...
    'egrRatioDriftAbs', NaN, ...
    'steadyOk', false, ...
    'egrMdot', NaN, ...
    'exhaustMdot', NaN, ...
    'compInletMdot', NaN, ...
    'egrRatioCompIn', NaN, ...
    'egrSplitRatioOut', NaN, ...
    'pOutlet', NaN, ...
    'pEgrValveUp', NaN, ...
    'pEgrValveDown', NaN, ...
    'pCompInlet', NaN, ...
    'rhCaIn', NaN, ...
    'rhCaOut', NaN, ...
    'mWaterSep', NaN, ...
    'pressureChainOk', false, ...
    'kpiFiniteOk', false, ...
    'kpiNonnegativeOk', false, ...
    'egrLevelOk', false);
end

function result = collectCaseResult(simOut, result, model)
logsout = simOut.logsout;
result.egrMdot = scalarLastOrNaN(logsout, "routeA_cegr_mdot");
result.exhaustMdot = scalarLastOrNaN(logsout, "routeA_exhaust_mdot");
if ~isfinite(result.exhaustMdot)
    result.exhaustMdot = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_exhaust_mdot_ts");
end
result.compInletMdot = scalarLastOrNaN(logsout, "routeA_mdot_comp_inlet");
result.egrRatioCompIn = safeDivide(result.egrMdot, result.compInletMdot);
outletTotalMdot = max(result.egrMdot, 0) + max(result.exhaustMdot, 0);
result.egrSplitRatioOut = safeDivide(max(result.egrMdot, 0), outletTotalMdot);
result.pOutlet = scalarLastOrNaN(logsout, "routeA_p_outlet");
result.pEgrValveUp = scalarLastOrNaN(logsout, "routeA_p_egr_valve_up");
result.pEgrValveDown = scalarLastOrNaN(logsout, "routeA_p_egr_valve_down");
result.pCompInlet = scalarLastOrNaN(logsout, "routeA_p_comp_inlet");
result.rhCaIn = scalarLastOrNaN(logsout, "routeA_RH_ca_in");
if ~isfinite(result.rhCaIn)
    result.rhCaIn = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_RH_ca_in_ts");
end
result.rhCaOut = scalarLastOrNaN(logsout, "routeA_RH_ca_out");
if ~isfinite(result.rhCaOut)
    result.rhCaOut = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_RH_ca_out_ts");
end
result.mWaterSep = scalarLastOrNaN(logsout, "routeA_m_water_sep");
if ~isfinite(result.mWaterSep)
    result.mWaterSep = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_m_water_sep_ts");
end
[result.actualPowerKW, result.powerDissipatedKW] = ...
    collectSimscapePower(simOut, model);
end

function result = evaluateCase(result, simOut, model)
result.pressureChainOk = checkPressureChain(result);
result.kpiFiniteOk = all(isfinite([result.actualPowerKW, ...
    result.egrRatioCompIn, result.egrSplitRatioOut, result.rhCaIn, ...
    result.rhCaOut, result.mWaterSep, result.targetPowerKW]));
result.kpiNonnegativeOk = all([result.egrRatioCompIn, ...
    result.egrSplitRatioOut, result.rhCaIn, result.rhCaOut, ...
    result.mWaterSep, result.targetPowerKW] >= 0);
result.powerTrackingErrorFrac = abs(result.actualPowerKW - ...
    result.targetPowerKW) / max(abs(result.targetPowerKW), 1);
result.powerTrackingOk = isfinite(result.powerTrackingErrorFrac) && ...
    result.powerTrackingErrorFrac <= 0.05;
result.egrLevelOk = result.egrLabel ~= "no_egr" || ...
    result.egrRatioCompIn < 1e-3;

[tPower, powerKW] = collectSimscapePowerSeries(simOut, model);
[tRatio, egrRatio] = collectEgrRatioSeries(simOut.logsout);
result.powerDriftFrac = windowDrift(tPower, powerKW, ...
    result.stopTime, result.targetPowerKW);
result.egrRatioDriftAbs = windowDrift(tRatio, egrRatio, ...
    result.stopTime, 1);
result.steadyOk = isfinite(result.powerDriftFrac) && ...
    result.powerDriftFrac <= 0.02 && ...
    isfinite(result.egrRatioDriftAbs) && ...
    result.egrRatioDriftAbs <= 0.005;
end

function trend = checkTrendAcceptance(results, requireFullMatrix)
trend = struct( ...
    'passed', false, ...
    'required', requireFullMatrix, ...
    'noEgrCloseOk', false, ...
    'egrMonotonicOk', false, ...
    'powerMonotonicOk', false, ...
    'advisoryWarnings', strings(0, 1));
if ~requireFullMatrix
    trend.passed = true;
    trend.advisoryWarnings(end + 1, 1) = "trend_check_skipped_for_filtered_run";
    return;
end
if isempty(results) || ~all([results.simCompleted])
    trend.advisoryWarnings(end + 1, 1) = "not_all_cases_completed";
    return;
end
trend.noEgrCloseOk = all([results(strcmp({results.egrLabel}, 'no_egr')).egrRatioCompIn] < 1e-3);
loads = ["low", "nominal", "high"];
egrs = ["no_egr", "low_egr", "mid_egr"];
egrOk = true;
for loadIdx = 1:numel(loads)
    vals = nan(1, numel(egrs));
    for egrIdx = 1:numel(egrs)
        vals(egrIdx) = pickMetric(results, loads(loadIdx), egrs(egrIdx), ...
            'egrRatioCompIn');
    end
    egrOk = egrOk && all(isfinite(vals)) && all(diff(vals) > 0);
end
trend.egrMonotonicOk = egrOk;

powerOk = true;
heatWarn = false;
for egrIdx = 1:numel(egrs)
    powers = nan(1, numel(loads));
    heats = nan(1, numel(loads));
    for loadIdx = 1:numel(loads)
        powers(loadIdx) = pickMetric(results, loads(loadIdx), egrs(egrIdx), ...
            'actualPowerKW');
        heats(loadIdx) = pickMetric(results, loads(loadIdx), egrs(egrIdx), ...
            'powerDissipatedKW');
    end
    powerOk = powerOk && all(isfinite(powers)) && all(diff(powers) > 0);
    if all(isfinite(heats)) && any(diff(heats) < 0)
        heatWarn = true;
    end
end
trend.powerMonotonicOk = powerOk;
if heatWarn
    trend.advisoryWarnings(end + 1, 1) = "heat_not_monotonic_for_some_egr_level";
end
trend.passed = trend.noEgrCloseOk && trend.egrMonotonicOk && ...
    trend.powerMonotonicOk;
end

function value = pickMetric(results, loadLabel, egrLabel, fieldName)
value = NaN;
for idx = 1:numel(results)
    if string(results(idx).loadLabel) == loadLabel && ...
            string(results(idx).egrLabel) == egrLabel
        value = results(idx).(fieldName);
        return;
    end
end
end

function tbl = resultsToTable(results)
if isempty(results)
    tbl = table();
else
    tbl = struct2table(results);
end
end

function [powerKW, heatKW] = collectSimscapePower(simOut, model)
powerKW = NaN;
heatKW = NaN;
try
    simlog = simOut.get(['simlog_' model]);
    mea = routeA_simscape_log_mea(simlog);
    powerData = mea.power_elec.series.values('kW');
    powerKW = powerData(end);
catch
end
try
    simlog = simOut.get(['simlog_' model]);
    mea = routeA_simscape_log_mea(simlog);
    heatData = mea.power_dissipated.series.values('kW');
    heatKW = heatData(end);
catch
end
end

function [timeS, powerKW] = collectSimscapePowerSeries(simOut, model)
timeS = [];
powerKW = [];
try
    simlog = simOut.get(['simlog_' model]);
    mea = routeA_simscape_log_mea(simlog);
    series = mea.power_elec.series;
    timeS = series.time;
    powerKW = series.values('kW');
    timeS = double(timeS(:));
    powerKW = double(powerKW(:));
catch
end
end

function [timeS, ratio] = collectEgrRatioSeries(logsout)
[tEgr, egr] = loggedSeries(logsout, "routeA_cegr_mdot");
[tComp, comp] = loggedSeries(logsout, "routeA_mdot_comp_inlet");
timeS = [];
ratio = [];
if isempty(tEgr) || isempty(tComp)
    return;
end
try
    compAtEgrTime = interp1(tComp, comp, tEgr, 'linear', 'extrap');
    valid = abs(compAtEgrTime) > eps;
    timeS = tEgr(valid);
    ratio = egr(valid) ./ compAtEgrTime(valid);
catch
    timeS = [];
    ratio = [];
end
end

function [timeS, data] = loggedSeries(logsout, signalName)
timeS = [];
data = [];
signalElement = findLoggedElement(logsout, signalName);
if isempty(signalElement)
    return;
end
try
    values = signalElement.Values;
    timeS = double(values.Time(:));
    raw = values.Data;
    if isvector(raw)
        data = double(raw(:));
    elseif size(raw, 1) == numel(timeS)
        data = double(reshape(raw(:, 1), [], 1));
    elseif size(raw, ndims(raw)) == numel(timeS)
        reshaped = reshape(raw, [], numel(timeS));
        data = double(reshaped(1, :).');
    else
        data = double(raw(:));
        data = data(1:min(numel(data), numel(timeS)));
        timeS = timeS(1:numel(data));
    end
catch
    timeS = [];
    data = [];
end
end

function drift = windowDrift(timeS, values, stopTime, scale)
drift = NaN;
if isempty(timeS) || isempty(values)
    return;
end
lastMask = timeS >= stopTime - 5 & timeS <= stopTime;
prevMask = timeS >= stopTime - 10 & timeS < stopTime - 5;
if ~any(lastMask) || ~any(prevMask)
    return;
end
lastMean = mean(values(lastMask), 'omitnan');
prevMean = mean(values(prevMask), 'omitnan');
if ~isfinite(lastMean) || ~isfinite(prevMean)
    return;
end
drift = abs(lastMean - prevMean) / max(abs(scale), 1);
end

function value = scalarLastOrNaN(logsout, signalName)
value = lastLoggedValueOrNaN(logsout, signalName);
if isempty(value)
    value = NaN;
else
    value = value(1);
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

function ok = checkPressureChain(result)
tol = 10;
ok = isfinite(result.pOutlet) && isfinite(result.pEgrValveUp) && ...
    isfinite(result.pEgrValveDown) && isfinite(result.pCompInlet) && ...
    result.pOutlet + tol >= result.pEgrValveUp && ...
    result.pEgrValveUp + tol >= result.pEgrValveDown && ...
    result.pEgrValveDown + tol >= result.pCompInlet;
end

function ok = requiredBlocksPresent(~, paths)
blocks = { ...
    paths.egrValve, paths.compressorFlowConverter, ...
    paths.exhaustMassFlowConverter, paths.cathodeHumidifierConverter, ...
    paths.outletRHConverter, paths.separatorObserver};
ok = true;
for idx = 1:numel(blocks)
    ok = ok && getSimulinkBlockHandle(blocks{idx}) ~= -1;
end
end

function markAuditSignals(paths)
nameLineFromBlockOut(paths.compressorFlowConverter, ...
    'routeA_mdot_comp_inlet');
nameLineFromBlockOut(paths.exhaustMassFlowConverter, ...
    'routeA_exhaust_mdot');
nameLineFromBlockOut(paths.cathodeHumidifierConverter, ...
    'routeA_RH_ca_in');
nameLineFromBlockOut(paths.outletRHConverter, ...
    'routeA_RH_ca_out');
nameLineFromBlockOut(paths.separatorObserver, ...
    'routeA_m_water_sep');
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
end
end

function value = getWorkspaceValue(modelWorkspace, name, fallback)
value = fallback;
try
    value = modelWorkspace.getVariable(name);
catch
end
end

function tf = near(value, target, tol)
tf = isfinite(value) && abs(value - target) <= tol;
end

function out = safeDivide(num, den)
if isfinite(num) && isfinite(den) && abs(den) > eps
    out = num / den;
else
    out = NaN;
end
end

function tf = getBaseFlag(name, defaultValue)
tf = defaultValue;
try
    if evalin('base', sprintf('exist(''%s'', ''var'')', name))
        tf = logical(evalin('base', name));
    end
catch
    tf = defaultValue;
end
end

function values = getBaseStringArray(name)
values = strings(0, 1);
try
    if evalin('base', sprintf('exist(''%s'', ''var'')', name))
        raw = evalin('base', name);
        if ischar(raw)
            values = string(raw);
        else
            values = string(raw(:));
        end
    end
catch
    values = strings(0, 1);
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
fprintf('\nA9.5 result\n');
fprintf('  passed=%d cases=%d/%d trend=%d\n', audit.passed, ...
    nnz([audit.results.passed]), numel(audit.results), ...
    audit.trend.passed);
if audit.trend.required
    fprintf('  no_egr_close=%d egr_monotonic=%d power_monotonic=%d\n', ...
        audit.trend.noEgrCloseOk, audit.trend.egrMonotonicOk, ...
        audit.trend.powerMonotonicOk);
else
    fprintf('  trend_check=skipped_for_filtered_run\n');
end
if strlength(audit.summaryCsv) > 0
    fprintf('  summary_csv=%s\n', audit.summaryCsv);
end
fprintf('\nCase summary\n');
for idx = 1:numel(audit.results)
    r = audit.results(idx);
    fprintf('  %-22s passed=%d stop=%g power=%.4g kW egr=%.4g split=%.4g steady=%d err=%.3g\n', ...
        r.caseId, r.passed, r.stopTime, r.actualPowerKW, ...
        r.egrRatioCompIn, r.egrSplitRatioOut, r.steadyOk, ...
        r.powerTrackingErrorFrac);
end
if ~isempty(audit.trend.advisoryWarnings)
    fprintf('\nAdvisory warnings\n');
    for idx = 1:numel(audit.trend.advisoryWarnings)
        fprintf('  %s\n', audit.trend.advisoryWarnings(idx));
    end
end
end
