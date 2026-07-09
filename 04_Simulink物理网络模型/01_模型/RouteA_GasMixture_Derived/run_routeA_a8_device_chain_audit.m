%% Route A A8 device-chain completion audit
% Read-back and smoke-test entry for the A8 platform equipment-chain gaps:
% intercooler L2 interface, separator/condensation interface, configurable
% cathode humidifier bypass, direct RH KPI, and separated-water KPI.
%
% No external bench data, no figures, no CSV/XLSX, and no model copies.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = [model '.slx'];
scriptDir = fileparts(mfilename('fullpath'));
oldDir = pwd;
routeA_a8_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));
cd(scriptDir);

if bdIsLoaded(model) && strcmp(get_param(model, 'Dirty'), 'on')
    error('RouteA:A8:DirtyModel', ...
        ['Model %s has unsaved changes. Save or discard them before ', ...
        'running the A8 device-chain audit.'], model);
end

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);

audit = struct();
audit.model = string(model);
audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.parameterIsolation = auditParameterIsolation(model, scriptDir);
audit.externalCaseGuard = auditExternalCaseGuard(model);
audit.structure = auditA8Structure(model);
audit.parameters = auditA8Parameters(model);

cases = [ ...
    smokeCase("no_egr_closed_valve", 1e-6, 1), ...
    smokeCase("low_egr_humidifier_on", 5e-4, 1), ...
    smokeCase("low_egr_humidifier_bypass", 5e-4, 0)];
audit.smoke = runSmokeCases(model, modelFile, cases);
audit.smokePassed = all([audit.smoke.passed]) && ...
    all([audit.smoke.pressureChainOk]) && ...
    all([audit.smoke.kpiFiniteOk]) && ...
    all([audit.smoke.kpiNonnegativeOk]);
audit.passed = audit.parameterIsolation.passed && ...
    audit.externalCaseGuard.passed && ...
    audit.structure.passed && ...
    audit.parameters.passed && ...
    audit.smokePassed;

assignin('base', 'routeA_a8_device_chain_audit', audit);
dispAudit(audit);

function c = smokeCase(name, areaFraction, humidifierGain)
c = struct();
c.name = string(name);
c.areaFraction = areaFraction;
c.humidifierGain = humidifierGain;
c.stopTime = "30";
end

function result = auditParameterIsolation(model, scriptDir)
mw = get_param(model, 'ModelWorkspace');
parameterFile = fullfile(scriptDir, 'PEMFuelCellSystemWithACustomLibraryParameters.m');
txt = string(fileread(parameterFile));
result = struct();
result.layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
result.externalCaseEnabled = logical(getWorkspaceValue(mw, ...
    'routeA_external_case_enabled', true));
result.defaultScriptReadsTables = contains(txt, "readtable(") || ...
    contains(txt, ".csv") || contains(txt, ".xlsx") || contains(txt, ".xls");
result.layerOk = result.layer == "platform_default";
result.externalCaseFlagOk = ~result.externalCaseEnabled;
result.noDefaultFileDataLoad = ~result.defaultScriptReadsTables;
result.passed = result.layerOk && result.externalCaseFlagOk && ...
    result.noDefaultFileDataLoad;
end

function result = auditExternalCaseGuard(model)
result = struct();
result.disabledByDefault = false;
result.errorId = "";
result.errorMessage = "";
try
    run('run_routeA_a7_bench_sanity.m');
    result.errorId = "NO_ERROR";
    result.errorMessage = "external_case script did not reject default run";
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    result.disabledByDefault = result.errorId == "RouteA:ExternalCase:Disabled";
end
resetModelFromDisk(model, [model '.slx']);
refreshModelWorkspace(model);
result.passed = result.disabledByDefault;
end

function result = auditA8Structure(model)
result = struct();
result.requiredBlocks = [ ...
    "Intercooler_L2_Interface", ...
    "IntercoolerOutletPTSensor", ...
    "IntercoolerOutletHumiditySensor", ...
    "CathodeWaterSeparator_FC", ...
    "AnodeWaterSeparator_FC", ...
    "SeparatorOrCondensation", ...
    "OutletHumiditySensor", ...
    "CathodeHumidifierBypass", ...
    "WaterSep_ToWorkspace", ...
    "RH_ca_in_ToWorkspace", ...
    "RH_ca_out_ToWorkspace"];
result.blockPresent = false(size(result.requiredBlocks));
for k = 1:numel(result.requiredBlocks)
    result.blockPresent(k) = hasAnyNamedBlock(model, result.requiredBlocks(k));
end

result.requiredSignals = [ ...
    "routeA_p_ca_pre_humidifier", ...
    "routeA_T_ca_pre_humidifier", ...
    "routeA_yi_ca_pre_humidifier", ...
    "routeA_RH_ca_in", ...
    "routeA_RH_ca_out", ...
    "routeA_m_water_sep"];
result.signalPresent = false(size(result.requiredSignals));
for k = 1:numel(result.requiredSignals)
    result.signalPresent(k) = hasAnySignal(model, result.requiredSignals(k));
end

result.cegrConnectionsOk = hasRequiredCegrConnections(model);
result.waterSeparatorConnectionsOk = hasWaterSeparatorConnections(model);
result.intercoolerConnectionsOk = hasIntercoolerConnections(model);
result.humidifierBypassConnectionOk = hasHumidifierBypassConnection(model);
result.passed = all(result.blockPresent) && all(result.signalPresent) && ...
    result.cegrConnectionsOk && result.waterSeparatorConnectionsOk && ...
    result.intercoolerConnectionsOk && result.humidifierBypassConnectionOk;
end

function result = auditA8Parameters(model)
mw = get_param(model, 'ModelWorkspace');
paramNames = [ ...
    "intercooler_length", ...
    "intercooler_area", ...
    "intercooler_Dh", ...
    "intercooler_cond_tau", ...
    "separator_condensation_enabled", ...
    "separator_l2_efficiency", ...
    "cathode_separator_D", ...
    "cathode_separator_length", ...
    "cathode_separator_area", ...
    "cathode_separator_dp_nominal", ...
    "cathode_separator_mdot_nominal", ...
    "anode_separator_D", ...
    "anode_separator_length", ...
    "anode_separator_area", ...
    "anode_separator_dp_nominal", ...
    "anode_separator_mdot_nominal", ...
    "routeA_cathode_humidifier_enabled", ...
    "routeA_cathode_humidifier_gain"];
result = struct();
result.paramNames = paramNames;
result.present = false(size(paramNames));
result.values = cell(size(paramNames));
for k = 1:numel(paramNames)
    try
        result.values{k} = mw.getVariable(char(paramNames(k)));
        result.present(k) = true;
    catch
    end
end
result.separatorSource = string(getWorkspaceValue(mw, ...
    'separator_l2_source', ""));
result.separatorSourceOk = result.separatorSource == ...
    "l2_saturation_excess_estimator";
result.passed = all(result.present) && result.separatorSourceOk;
end

function results = runSmokeCases(model, modelFile, cases)
results = repmat(emptySmokeResult(), numel(cases), 1);
for k = 1:numel(cases)
    results(k) = runSmokeCase(model, modelFile, cases(k));
    if ~results(k).passed
        break;
    end
end
end

function result = emptySmokeResult()
result = struct( ...
    'name', "", ...
    'areaFraction', NaN, ...
    'humidifierGain', NaN, ...
    'passed', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
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
    'kpiNonnegativeOk', false);
end

function result = runSmokeCase(model, modelFile, c)
result = emptySmokeResult();
result.name = c.name;
result.areaFraction = c.areaFraction;
result.humidifierGain = c.humidifierGain;
fprintf('\nRoute A A8 smoke: %s area_frac=%.6g humidifier_gain=%.3g\n', ...
    c.name, c.areaFraction, c.humidifierGain);
try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    markAuditSignals(model);
    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', char(c.stopTime), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'none');
    simIn = simIn.setBlockParameter([model '/EGRValveRestriction'], ...
        'restriction_area', sprintf('%.16g*cegr_pipe_area', c.areaFraction));
    simIn = simIn.setVariable('routeA_cathode_humidifier_gain', ...
        c.humidifierGain);
    simOut = sim(simIn);
    result.passed = true;
    result = collectSmokeResult(simOut, result);
    result.pressureChainOk = checkPressureChain(result);
    result.kpiFiniteOk = all(isfinite([result.rhCaIn, result.rhCaOut, ...
        result.mWaterSep, result.egrRatioCompIn, result.egrSplitRatioOut]));
    result.kpiNonnegativeOk = all([result.rhCaIn, result.rhCaOut, ...
        result.mWaterSep] >= 0);
    fprintf('  PASS egr_ratio=%.5g split=%.5g RH_in=%.5g RH_out=%.5g water=%.5g\n', ...
        result.egrRatioCompIn, result.egrSplitRatioOut, result.rhCaIn, ...
        result.rhCaOut, result.mWaterSep);
catch ME
    result.passed = false;
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    fprintf('  FAIL %s: %s\n', result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function markAuditSignals(model)
nameLineFromBlockOut([model '/Oxygen Source/PS-Simulink Converter'], ...
    'routeA_mdot_comp_inlet');
nameLineFromBlockOut([model '/Exhaust_mdot_Converter'], ...
    'routeA_exhaust_mdot');
nameLineFromBlockOut([model '/Cathode Humidifier/PS-Simulink Converter2'], ...
    'routeA_RH_ca_in');
nameLineFromBlockOut([model '/OutletRH_Converter'], ...
    'routeA_RH_ca_out');
nameLineFromBlockOut([model '/SeparatorOrCondensation'], ...
    'routeA_m_water_sep');
end

function result = collectSmokeResult(simOut, result)
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
end

function ok = checkPressureChain(result)
tol = 10; % Same tolerance convention as A6.5 audit.
ok = isfinite(result.pOutlet) && isfinite(result.pEgrValveUp) && ...
    isfinite(result.pEgrValveDown) && isfinite(result.pCompInlet) && ...
    result.pOutlet + tol >= result.pEgrValveUp && ...
    result.pEgrValveUp + tol >= result.pEgrValveDown && ...
    result.pEgrValveDown + tol >= result.pCompInlet;
end

function tf = hasIntercoolerConnections(model)
tf = false;
try
    pipe = [model '/Oxygen Source/Intercooler_L2_Interface'];
    compVolume = [model '/Oxygen Source/Compressor Volume'];
    massSensor = [model '/Oxygen Source/Mass Flow Rate Sensor (FC)'];
    phPipe = get_param(pipe, 'PortHandles');
    phComp = get_param(compVolume, 'PortHandles');
    phSensor = get_param(massSensor, 'PortHandles');
    tf = allPortsConnected([phComp.LConn(3), phPipe.LConn(1), ...
        phPipe.RConn(1), phSensor.LConn(1)]);
catch
end
end

function tf = hasHumidifierBypassConnection(model)
tf = false;
try
    bypass = [model '/Cathode Humidifier/CathodeHumidifierBypass'];
    ph = get_param(bypass, 'PortHandles');
    tf = allPortsConnected([ph.Inport(1), ph.Outport(1)]);
catch
end
end

function tf = hasRequiredCegrConnections(model)
tf = false;
try
    chamber = [model '/CathodeOutletChamber'];
    resistance = [model '/CathodeOutletResistance'];
    exhaustSensor = [model '/ExhaustMassFlowSensor'];
    egrSensor = [model '/EGRMassFlowSensor'];
    cathodeSeparator = [model '/CathodeWaterSeparator_FC'];
    egrValve = [model '/EGRValveRestriction'];
    egrPipe = [model '/EGRPipe'];
    oxygen = [model '/Oxygen Source'];
    phChamber = get_param(chamber, 'PortHandles');
    phResistance = get_param(resistance, 'PortHandles');
    phExhaustSensor = get_param(exhaustSensor, 'PortHandles');
    phEgrSensor = get_param(egrSensor, 'PortHandles');
    phCathodeSeparator = get_param(cathodeSeparator, 'PortHandles');
    phEgrValve = get_param(egrValve, 'PortHandles');
    phEgrPipe = get_param(egrPipe, 'PortHandles');
    phOxygen = get_param(oxygen, 'PortHandles');
    tf = allPortsConnected([ ...
        phResistance.RConn(1), phChamber.LConn(3), ...
        phChamber.LConn(4), phExhaustSensor.LConn(1), ...
        phChamber.LConn(5), phEgrSensor.LConn(1), ...
        phEgrSensor.RConn(4), phCathodeSeparator.LConn(1), ...
        phCathodeSeparator.RConn(1), phEgrValve.LConn(1), ...
        phEgrValve.RConn(1), phEgrPipe.LConn(1), ...
        phEgrPipe.RConn(1), phOxygen.LConn(2)]);
catch
end
end

function tf = hasWaterSeparatorConnections(model)
tf = false;
try
    cathodeSeparator = [model '/CathodeWaterSeparator_FC'];
    anodeSeparator = [model '/AnodeWaterSeparator_FC'];
    anodeGas = [model '/Anode Gas Channels'];
    recirculation = [model '/Recirculation'];
    phCathodeSeparator = get_param(cathodeSeparator, 'PortHandles');
    phAnodeSeparator = get_param(anodeSeparator, 'PortHandles');
    phAnodeGas = get_param(anodeGas, 'PortHandles');
    phRecirculation = get_param(recirculation, 'PortHandles');
    cathodeOk = allPortsConnected([ ...
        phCathodeSeparator.LConn(1), ...
        phCathodeSeparator.RConn(1)]);
    anodeOk = allPortsConnected([ ...
        phAnodeGas.LConn(2), ...
        phAnodeSeparator.LConn(1), ...
        phAnodeSeparator.RConn(1), ...
        phRecirculation.RConn(2)]);
    allowedRefs = ["FuelCell_lib/elements/Pipe (FC)", ...
        "FuelCell_lib/elements/Flow Resistance (FC)"];
    cathodeRefOk = any(strcmp(get_param(cathodeSeparator, ...
        'ReferenceBlock'), allowedRefs));
    anodeRefOk = any(strcmp(get_param(anodeSeparator, ...
        'ReferenceBlock'), allowedRefs));
    tf = cathodeOk && anodeOk && cathodeRefOk && anodeRefOk;
catch
end
end

function tf = allPortsConnected(portHandles)
tf = true;
for k = 1:numel(portHandles)
    tf = tf && get_param(portHandles(k), 'Line') ~= -1;
end
end

function tf = hasAnyNamedBlock(model, name)
tf = ~isempty(find_system(model, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'MatchFilter', @Simulink.match.allVariants, ...
    'Regexp', 'on', 'Name', char(name)));
end

function tf = hasAnySignal(model, name)
tf = false;
lineHandles = find_system(model, 'FindAll', 'on', 'Type', 'line');
for k = 1:numel(lineHandles)
    if string(get_param(lineHandles(k), 'Name')) == name
        tf = true;
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

function out = safeDivide(num, den)
if isfinite(num) && isfinite(den) && abs(den) > eps
    out = num / den;
else
    out = NaN;
end
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

function txt = firstLine(txt)
parts = splitlines(txt);
txt = parts(1);
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
fprintf('\nRoute A A8 device-chain audit\n');
fprintf('  model=%s\n', audit.model);
fprintf('  timestamp=%s\n', audit.timestamp);
fprintf('\nParameter isolation\n');
fprintf('  layer=%s external_case_enabled=%d default_data_load=%d passed=%d\n', ...
    audit.parameterIsolation.layer, ...
    audit.parameterIsolation.externalCaseEnabled, ...
    audit.parameterIsolation.defaultScriptReadsTables, ...
    audit.parameterIsolation.passed);
fprintf('  external_case_guard=%d error_id=%s\n', ...
    audit.externalCaseGuard.passed, audit.externalCaseGuard.errorId);
fprintf('\nA8 structure\n');
fprintf('  blocks_present=%d/%d signals_present=%d/%d cegr=%d water_sep=%d intercooler=%d bypass=%d passed=%d\n', ...
    nnz(audit.structure.blockPresent), numel(audit.structure.blockPresent), ...
    nnz(audit.structure.signalPresent), numel(audit.structure.signalPresent), ...
    audit.structure.cegrConnectionsOk, audit.structure.waterSeparatorConnectionsOk, ...
    audit.structure.intercoolerConnectionsOk, ...
    audit.structure.humidifierBypassConnectionOk, audit.structure.passed);
fprintf('  separator_source=%s params_passed=%d\n', ...
    audit.parameters.separatorSource, audit.parameters.passed);
fprintf('\nSmoke\n');
for k = 1:numel(audit.smoke)
    r = audit.smoke(k);
    fprintf('  %s passed=%d pressure=%d kpiFinite=%d kpiNonnegative=%d ratio=%.5g split=%.5g RH_in=%.5g RH_out=%.5g water=%.5g\n', ...
        r.name, r.passed, r.pressureChainOk, r.kpiFiniteOk, ...
        r.kpiNonnegativeOk, r.egrRatioCompIn, r.egrSplitRatioOut, ...
        r.rhCaIn, r.rhCaOut, r.mWaterSep);
    if ~r.passed
        fprintf('    error=%s %s\n', r.errorId, r.errorMessage);
    end
end
fprintf('\nA8 result\n');
fprintf('  passed=%d smoke_passed=%d\n', audit.passed, audit.smokePassed);
end
