% Route A A9.7 actuator-to-boundary sensitivity audit.
% Read-only first pass: perturb existing setpoints/parameters with
% SimulationInput, collect summary KPIs, and do not save the model.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a9_7_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');

audit = struct();
audit.model = model;
audit.phase = "A9.7";
audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.scope = "read-only actuator-to-boundary sensitivity audit";
audit.generated = false;
audit.preflight = runPreflight(mw);
audit.controlChain = buildControlChainSummary();
audit.caseDefinitions = buildCaseDefinitions();
audit.caseResults = repmat(emptyCaseResult(), numel(audit.caseDefinitions), 1);

fprintf('\nRoute A A9.7 actuator-boundary sensitivity audit\n');
fprintf('  model=%s\n', model);
fprintf('  timestamp=%s\n', audit.timestamp);
fprintf('  preflight passed=%d\n', audit.preflight.passed);

if audit.preflight.passed
    for idx = 1:numel(audit.caseDefinitions)
        c = audit.caseDefinitions(idx);
        result = runSensitivityCase(model, modelFile, c, 30);
        if result.simCompleted && ~result.coolingAdvisory && ~result.steadyOk
            fprintf('  RETRY %s at 60 s: power_drift=%.4g egr_drift=%.4g\n', ...
                result.caseId, result.powerDriftFrac, result.egrRatioDriftAbs);
            result = runSensitivityCase(model, modelFile, c, 60);
            result.retryFrom30s = true;
        end
        audit.caseResults(idx) = result;
    end
end

audit.responseTable = struct2table(audit.caseResults);
audit.relationChecks = checkRelations(audit.caseResults);
audit.interfaceGaps = buildInterfaceGaps();
audit.generated = audit.preflight.passed && all([audit.caseResults.simCompleted]);
audit.passed = audit.generated && audit.relationChecks.allCritical;
assignin('base', 'routeA_a9_7_actuator_boundary_sensitivity_audit', audit);
dispAudit(audit);

function result = runPreflight(mw)
result = struct('passed', false, 'layerOk', false, ...
    'externalCaseDisabled', false, 'errorId', "", 'errorMessage', "");
try
    layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
    externalEnabled = logical(getWorkspaceValue(mw, ...
        'routeA_external_case_enabled', true));
    result.layerOk = layer == "platform_default";
    result.externalCaseDisabled = ~externalEnabled;
    result.passed = result.layerOk && result.externalCaseDisabled;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end
end

function chain = buildControlChainSummary()
actuator = [
    "electrical_load_current_source"
    "compressor_oer_pi_to_mdot_source"
    "cegr_valve_restriction_area"
    "cathode_humidifier_gain"
    "coolant_pump_temperature_pi"
    ];
currentInput = [
    "drive_cycle_power"
    "Oxygen Excess Ratio constant"
    "EGRValveRestriction.restriction_area"
    "routeA_cathode_humidifier_gain"
    "Cooling System/Stack Temperature"
    ];
currentOutput = [
    "current command through P/V"
    "PI output 0..1, max rpm, compressor map, mdot source"
    "solved cEGR mdot and pressure-flow response"
    "humidifier/bypass gain and RH response"
    "PI output 0..1 and TL pump flow source"
    ];
openGap = [
    "direct current-density command not exposed"
    "direct rpm command not exposed"
    "target EGR-ratio controller not implemented"
    "detailed water injection command not audited"
    "thermal steady response exceeds first-pass short run"
    ];
chain = table(actuator, currentInput, currentOutput, openGap);
end

function defs = buildCaseDefinitions()
defs = repmat(emptyCaseDefinition(), 17, 1);
idx = 0;
for p = [17.47 50.96 77.95]
    idx = idx + 1;
    defs(idx) = caseDef("power", sprintf('power_%.0fkW', p), p, ...
        p, "cegr_valve_area_closed", 1, 2.5, 80, false);
end
for oer = [2.0 2.5 3.0]
    idx = idx + 1;
    defs(idx) = caseDef("oer", sprintf('oer_%.1f', oer), oer, ...
        50.96, "cegr_valve_area_closed", 1, oer, 80, false);
end
for frac = [1e-6 5e-4 2e-3 1e-2 2e-2]
    idx = idx + 1;
    expr = sprintf('%.16g*cegr_pipe_area', frac);
    defs(idx) = caseDef("cegr_valve", sprintf('cegr_area_%.4g', frac), ...
        frac, 50.96, string(expr), 1, 2.5, 80, false);
end
for gain = [0 0.5 1]
    idx = idx + 1;
    defs(idx) = caseDef("humidifier", sprintf('humid_gain_%.1f', gain), ...
        gain, 50.96, "2e-3*cegr_pipe_area", gain, 2.5, 80, false);
end
for tSet = [70 80 90]
    idx = idx + 1;
    defs(idx) = caseDef("cooling", sprintf('cooling_Tset_%.0fC', tSet), ...
        tSet, 50.96, "cegr_valve_area_closed", 1, 2.5, tSet, true);
end
end

function c = emptyCaseDefinition()
c = struct('group', "", 'caseId', "", 'commandValue', NaN, ...
    'targetPowerKW', NaN, 'restrictionArea', "", ...
    'humidifierGain', NaN, 'oerSetpoint', NaN, ...
    'stackTempSetC', NaN, 'coolingAdvisory', false);
end

function c = caseDef(group, caseId, commandValue, targetPowerKW, ...
    restrictionArea, humidifierGain, oerSetpoint, stackTempSetC, ...
    coolingAdvisory)
c = emptyCaseDefinition();
c.group = string(group);
c.caseId = string(caseId);
c.commandValue = commandValue;
c.targetPowerKW = targetPowerKW;
c.restrictionArea = string(restrictionArea);
c.humidifierGain = humidifierGain;
c.oerSetpoint = oerSetpoint;
c.stackTempSetC = stackTempSetC;
c.coolingAdvisory = coolingAdvisory;
end

function result = runSensitivityCase(model, modelFile, c, stopTime)
result = emptyCaseResult();
result.group = c.group;
result.caseId = c.caseId;
result.commandValue = c.commandValue;
result.targetPowerKW = c.targetPowerKW;
result.restrictionArea = c.restrictionArea;
result.humidifierGain = c.humidifierGain;
result.oerSetpoint = c.oerSetpoint;
result.stackTempSetC = c.stackTempSetC;
result.coolingAdvisory = c.coolingAdvisory;
result.stopTime = stopTime;

fprintf('\nA9.7 case: %-22s group=%s cmd=%.4g target=%.4g kW\n', ...
    result.caseId, result.group, result.commandValue, result.targetPowerKW);
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
    simIn = simIn.setVariable('drive_cycle_time', [0; 5; stopTime], ...
        'Workspace', model);
    simIn = simIn.setVariable('drive_cycle_power', ...
        [0; c.targetPowerKW; c.targetPowerKW], 'Workspace', model);
    simIn = simIn.setVariable('routeA_cathode_humidifier_gain', ...
        c.humidifierGain, 'Workspace', model);
    simIn = simIn.setVariable('routeA_air_control_mode_id', ...
        2, 'Workspace', model);
    simIn = simIn.setVariable('routeA_egr_control_mode_id', ...
        2, 'Workspace', model);
    simIn = simIn.setVariable('routeA_egr_valve_area_direct', ...
        evalModelExpression(model, c.restrictionArea), 'Workspace', model);
    simIn = simIn.setBlockParameter( ...
        paths.oerSetpoint, ...
        'Value', sprintf('%.16g', c.oerSetpoint));
    simIn = simIn.setBlockParameter( ...
        paths.stackTemperature, ...
        'Value', sprintf('%.16g', c.stackTempSetC));
    simOut = sim(simIn);
    result.simCompleted = true;
    result = collectResult(simOut, result, model);
    result = evaluateResult(result, simOut, model);
    result.passed = result.simCompleted && result.kpiFiniteOk && ...
        result.powerTrackingOk && (result.coolingAdvisory || result.steadyOk);
    fprintf('  %s power=%.4g mdot=%.4g egr=%.4g O2in=%.4g RHin=%.4g steady=%d\n', ...
        passFailText(result.passed), result.actualPowerKW, ...
        result.compInletMdotKgS, result.egrRatioCompIn, ...
        result.o2CompInlet, result.rhCaIn, result.steadyOk);
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    fprintf('  FAIL %s: %s\n', result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function result = emptyCaseResult()
result = struct( ...
    'group', "", 'caseId', "", 'commandValue', NaN, ...
    'passed', false, 'simCompleted', false, 'errorId', "", ...
    'errorMessage', "", 'targetPowerKW', NaN, 'actualPowerKW', NaN, ...
    'stackHeatKW', NaN, 'powerTrackingErrorFrac', NaN, ...
    'powerTrackingOk', false, 'restrictionArea', "", ...
    'humidifierGain', NaN, 'oerSetpoint', NaN, 'stackTempSetC', NaN, ...
    'coolingAdvisory', false, 'stopTime', NaN, 'retryFrom30s', false, ...
    'compInletMdotKgS', NaN, 'egrMdotKgS', NaN, ...
    'exhaustMdotKgS', NaN, 'egrRatioCompIn', NaN, ...
    'egrSplitRatioOut', NaN, 'pOutletPa', NaN, 'pCompInletPa', NaN, ...
    'pEgrValveUpPa', NaN, 'pEgrValveDownPa', NaN, ...
    'tOutletK', NaN, 'tCompInletK', NaN, 'o2CompInlet', NaN, ...
    'h2oCompInlet', NaN, 'o2Outlet', NaN, 'h2oOutlet', NaN, ...
    'rhCaIn', NaN, 'rhCaOut', NaN, 'mWaterSep', NaN, ...
    'powerDriftFrac', NaN, 'powerDriftFallback', false, ...
    'egrRatioDriftAbs', NaN, ...
    'steadyOk', false, 'kpiFiniteOk', false);
end

function result = collectResult(simOut, result, model)
logsout = simOut.logsout;
result.pOutletPa = scalarLastOrNaN(logsout, "routeA_p_outlet");
result.tOutletK = scalarLastOrNaN(logsout, "routeA_T_outlet");
yiOut = vectorLastOrNaN(logsout, "routeA_yi_outlet", 4);
result.o2Outlet = yiOut(2);
result.h2oOutlet = yiOut(4);
result.pCompInletPa = scalarLastOrNaN(logsout, "routeA_p_comp_inlet");
result.tCompInletK = scalarLastOrNaN(logsout, "routeA_T_comp_inlet");
yiComp = vectorLastOrNaN(logsout, "routeA_yi_comp_inlet", 4);
result.o2CompInlet = yiComp(2);
result.h2oCompInlet = yiComp(4);
result.pEgrValveUpPa = scalarLastOrNaN(logsout, "routeA_p_egr_valve_up");
result.pEgrValveDownPa = scalarLastOrNaN(logsout, "routeA_p_egr_valve_down");
result.egrMdotKgS = scalarLastOrNaN(logsout, "routeA_cegr_mdot");
result.compInletMdotKgS = scalarLastOrNaN(logsout, ...
    "routeA_mdot_comp_inlet");
result.exhaustMdotKgS = scalarLastOrNaN(logsout, "routeA_exhaust_mdot");
if ~isfinite(result.exhaustMdotKgS)
    result.exhaustMdotKgS = scalarLastFromSimOutOrNaN(simOut, ...
        "routeA_exhaust_mdot_ts");
end
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
result.egrRatioCompIn = safeDivide(result.egrMdotKgS, ...
    result.compInletMdotKgS);
result.egrSplitRatioOut = safeDivide(max(result.egrMdotKgS, 0), ...
    max(result.egrMdotKgS, 0) + max(result.exhaustMdotKgS, 0));
[result.actualPowerKW, result.stackHeatKW] = collectSimscapePower(simOut, model);
end

function result = evaluateResult(result, simOut, model)
result.powerTrackingErrorFrac = abs(result.actualPowerKW - ...
    result.targetPowerKW) / max(abs(result.targetPowerKW), 1);
result.powerTrackingOk = isfinite(result.powerTrackingErrorFrac) && ...
    result.powerTrackingErrorFrac <= 0.05;
result.kpiFiniteOk = all(isfinite([result.actualPowerKW, ...
    result.compInletMdotKgS, result.egrRatioCompIn, result.rhCaIn, ...
    result.rhCaOut, result.mWaterSep, result.o2CompInlet, ...
    result.h2oCompInlet, result.o2Outlet, result.h2oOutlet]));
[tPower, powerKW] = collectSimscapePowerSeries(simOut, model);
[tRatio, egrRatio] = collectEgrRatioSeries(simOut.logsout);
result.powerDriftFrac = windowDrift(tPower, powerKW, ...
    result.stopTime, result.targetPowerKW);
result.egrRatioDriftAbs = windowDrift(tRatio, egrRatio, ...
    result.stopTime, 1);
if ~isfinite(result.powerDriftFrac) && result.powerTrackingOk
    result.powerDriftFrac = 0;
    result.powerDriftFallback = true;
end
result.steadyOk = isfinite(result.powerDriftFrac) && ...
    result.powerDriftFrac <= 0.02 && ...
    isfinite(result.egrRatioDriftAbs) && ...
    result.egrRatioDriftAbs <= 0.005;
end

function checks = checkRelations(results)
checks = struct();
checks.power = relationCheck("power_demand", ...
    isIncreasing(results, "power", 'actualPowerKW') && ...
    isIncreasing(results, "power", 'compInletMdotKgS') && ...
    isIncreasing(results, "power", 'stackHeatKW'), ...
    "power demand up should increase power, cathode flow, and heat");
checks.oer = relationCheck("oer_to_mdot", ...
    isIncreasing(results, "oer", 'compInletMdotKgS'), ...
    "OER setpoint up should increase compressor inlet mdot");
checks.cegr = relationCheck("valve_area_to_egr_and_o2", ...
    isIncreasing(results, "cegr_valve", 'egrRatioCompIn') && ...
    isDecreasing(results, "cegr_valve", 'o2CompInlet') && ...
    isIncreasing(results, "cegr_valve", 'h2oCompInlet'), ...
    "cEGR valve area up should increase EGR and H2O while lowering O2");
checks.humidifier = relationCheck("humidifier_gain_to_rh", ...
    isIncreasing(results, "humidifier", 'rhCaIn'), ...
    "humidifier gain up should increase cathode inlet RH");
checks.cooling = relationCheck("cooling_tset_observable", ...
    all([results(strcmp({results.group}, 'cooling')).simCompleted]), ...
    "cooling scan is advisory; thermal steady is not a first-pass hard gate");
checks.allCritical = checks.power.passed && checks.oer.passed && ...
    checks.cegr.passed && checks.humidifier.passed;
end

function c = relationCheck(name, passed, note)
c = struct('name', string(name), 'passed', logical(passed), ...
    'note', string(note));
end

function tf = isIncreasing(results, groupName, fieldName)
vals = groupValues(results, groupName, fieldName);
tf = numel(vals) >= 2 && all(isfinite(vals)) && all(diff(vals) > 0);
end

function tf = isDecreasing(results, groupName, fieldName)
vals = groupValues(results, groupName, fieldName);
tf = numel(vals) >= 2 && all(isfinite(vals)) && all(diff(vals) < 0);
end

function vals = groupValues(results, groupName, fieldName)
mask = string({results.group}) == string(groupName);
subset = results(mask);
[~, order] = sort([subset.commandValue]);
subset = subset(order);
vals = arrayfun(@(r) r.(fieldName), subset);
end

function gaps = buildInterfaceGaps()
gap = [
    "direct_rpm_command"
    "target_egr_ratio_controller"
    "backpressure_or_cathode_pressure_controller"
    "cathode_mdot_or_stoich_target"
    "cathode_stack_inlet_pT_KPI"
    ];
currentStatus = [
    "Compressor path uses OER PI output to max rpm/map and mdot source"
    "Only valve area is set; target EGR ratio is not closed-loop"
    "No stable independent backpressure actuator was used in A9.7 scan"
    "No direct cathode mdot or stoich input exposed"
    "Compressor inlet and outlet p/T exist, stack inlet p/T remains not unified"
    ];
nextAction = [
    "A9.8 decide whether to add direct rpm/cmd wrapper"
    "A9.8 implement valve-area search for target EGR levels"
    "A9.8 identify or add pressure actuator before pressure-flow decoupling"
    "A9.8 define O2 sufficiency and stoich postprocessing"
    "Add minimal read-back KPI before controller tuning"
    ];
gaps = table(gap, currentStatus, nextAction);
end

function [powerKW, heatKW] = collectSimscapePower(simOut, model)
powerKW = NaN;
heatKW = NaN;
try
    simlog = simOut.get(['simlog_' model]);
    mea = routeA_simscape_log_mea(simlog);
    powerKW = mea.power_elec.series.values('kW');
    powerKW = powerKW(end);
catch
end
try
    simlog = simOut.get(['simlog_' model]);
    mea = routeA_simscape_log_mea(simlog);
    heatKW = mea.power_dissipated.series.values('kW');
    heatKW = heatKW(end);
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
    timeS = double(series.time(:));
    powerKW = double(series.values('kW'));
    powerKW = powerKW(:);
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

function value = evalModelExpression(model, expr)
modelWorkspace = get_param(model, 'ModelWorkspace');
value = modelWorkspace.evalin(char(expr));
end

function out = safeDivide(num, den)
if isfinite(num) && isfinite(den) && abs(den) > eps
    out = num / den;
else
    out = NaN;
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
fprintf('\nA9.7 result\n');
fprintf('  generated=%d passed=%d cases=%d/%d critical_relations=%d\n', ...
    audit.generated, audit.passed, nnz([audit.caseResults.simCompleted]), ...
    numel(audit.caseResults), audit.relationChecks.allCritical);
groups = unique(string({audit.caseResults.group}), 'stable');
for g = groups
    subset = audit.caseResults(strcmp({audit.caseResults.group}, char(g)));
    fprintf('  group=%s cases=%d completed=%d\n', g, numel(subset), ...
        nnz([subset.simCompleted]));
end
fprintf('  relation power=%d oer=%d cegr=%d humidifier=%d cooling=%d\n', ...
    audit.relationChecks.power.passed, audit.relationChecks.oer.passed, ...
    audit.relationChecks.cegr.passed, ...
    audit.relationChecks.humidifier.passed, ...
    audit.relationChecks.cooling.passed);
end
