%% Route A A6.5 cEGR topology and valve-area audit
% This script performs a compact read-back and low/mid EGR valve-area scan.
% It prints evidence only and does not export figures, CSV files, or model
% copies. Optional 120 s scan can be enabled with:
%   routeA_run_extended_scan = true;

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a65_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

if bdIsLoaded(model) && strcmp(get_param(model, 'Dirty'), 'on')
    error('RouteA:A65:DirtyModel', ...
        ['Model %s has unsaved changes. Save or discard them before ', ...
        'running A6.5 audit.'], model);
end

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
paths = routeA_block_paths(model);
topology = verifyRouteATopology(model, paths);
dispTopology(topology);

areaFractions = [1e-6, 5e-4, 1e-3, 2e-3, 5e-3];
results30 = runAreaScan(model, modelFile, areaFractions, "30");
extendedResults = repmat(emptyAuditResult(), 0, 1);
if all([results30.passed]) && getOptionalFlag('routeA_run_extended_scan', false)
    extendedResults = runAreaScan(model, modelFile, areaFractions, "120");
end

scanAssessment = assessAreaScan(results30);
assignin('base', 'routeA_a6_5_topology', topology);
assignin('base', 'routeA_a6_5_results30', results30);
assignin('base', 'routeA_a6_5_extended_results', extendedResults);
assignin('base', 'routeA_a6_5_scan_assessment', scanAssessment);

dispResults(results30, "Route A A6.5 30 s valve-area scan");
if ~isempty(extendedResults)
    dispResults(extendedResults, "Route A A6.5 120 s valve-area scan");
end
dispAssessment(scanAssessment);

function topology = verifyRouteATopology(model, paths)
requiredBlocks = [ ...
    "CathodeOutletResistance", ...
    "CathodeOutletChamber", ...
    "ExhaustMassFlowSensor", ...
    "Exhaust_mdot_ToWorkspace", ...
    "EGRMassFlowSensor", ...
    "EGRValveRestriction", ...
    "EGRPipe", ...
    "Oxygen Source"];

topology = struct();
topology.model = string(model);
topology.requiredBlocks = requiredBlocks;
topology.blockPresent = false(size(requiredBlocks));
topology.referenceBlocks = strings(size(requiredBlocks));
requiredPaths = {paths.outletResistance, paths.outletChamber, ...
    paths.exhaustMassFlowSensor, paths.exhaustMdotWorkspace, ...
    paths.egrMassFlowSensor, paths.egrValve, paths.egrPipe, paths.oxygen};
for k = 1:numel(requiredBlocks)
    path = requiredPaths{k};
    topology.blockPresent(k) = getSimulinkBlockHandle(path) ~= -1;
    if topology.blockPresent(k)
        try
            topology.referenceBlocks(k) = string(get_param(path, 'ReferenceBlock'));
        catch
            topology.referenceBlocks(k) = "";
        end
    end
end

topology.cathodeOutletResistanceRef = getRef(paths.outletResistance);
topology.exhaustSensorRef = getRef(paths.exhaustMassFlowSensor);
topology.savedConnectionsOk = hasRequiredConnection(paths);
topology.rhStatus = "not_available_direct_signal";
topology.condensedStatus = "not_available_direct_signal";
topology.passed = all(topology.blockPresent) && topology.savedConnectionsOk && ...
    contains(topology.cathodeOutletResistanceRef, 'Flow Resistance') && ...
    contains(topology.exhaustSensorRef, 'Mass Flow Rate');
end

function tf = hasRequiredConnection(paths)
tf = false;
try
    chamber = paths.outletChamber;
    resistance = paths.outletResistance;
    exhaustSensor = paths.exhaustMassFlowSensor;
    egrSensor = paths.egrMassFlowSensor;
    egrValve = paths.egrValve;
    egrPipe = paths.egrPipe;
    oxygen = paths.oxygen;
    phChamber = get_param(chamber, 'PortHandles');
    phResistance = get_param(resistance, 'PortHandles');
    phExhaustSensor = get_param(exhaustSensor, 'PortHandles');
    phEgrSensor = get_param(egrSensor, 'PortHandles');
    phEgrValve = get_param(egrValve, 'PortHandles');
    phEgrPipe = get_param(egrPipe, 'PortHandles');
    phOxygen = get_param(oxygen, 'PortHandles');
    tf = allPortsConnected([ ...
        phResistance.RConn(1), phChamber.LConn(3), ...
        phChamber.LConn(4), phExhaustSensor.LConn(1), ...
        phChamber.LConn(5), phEgrSensor.LConn(1), ...
        phEgrSensor.RConn(4), phEgrValve.LConn(1), ...
        phEgrValve.RConn(1), phEgrPipe.LConn(1), ...
        phEgrPipe.RConn(1), phOxygen.LConn(2)]);
catch
    tf = false;
end
end

function tf = allPortsConnected(portHandles)
tf = true;
for k = 1:numel(portHandles)
    tf = tf && get_param(portHandles(k), 'Line') ~= -1;
end
end

function ref = getRef(path)
ref = "";
if getSimulinkBlockHandle(path) ~= -1
    ref = string(get_param(path, 'ReferenceBlock'));
end
end

function results = runAreaScan(model, modelFile, areaFractions, stopTime)
results = repmat(emptyAuditResult(), numel(areaFractions), 1);
for k = 1:numel(areaFractions)
    results(k) = runAreaCase(model, modelFile, areaFractions(k), stopTime);
    if ~results(k).passed
        break;
    end
end
end

function result = emptyAuditResult()
result = struct( ...
    'areaFraction', NaN, ...
    'stopTime', "", ...
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
    'yO2Outlet', NaN, ...
    'yH2OOutlet', NaN, ...
    'yO2CompInlet', NaN, ...
    'yH2OCompInlet', NaN, ...
    'pressureChainOk', false);
end

function result = runAreaCase(model, modelFile, areaFraction, stopTime)
result = emptyAuditResult();
result.areaFraction = areaFraction;
result.stopTime = stopTime;
fprintf('\nRoute A A6.5 area scan: frac=%.6g StopTime=%s\n', areaFraction, stopTime);
try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    paths = routeA_block_paths(model);
    markAuditSignals(model, paths);
    egrValvePath = paths.egrValve;
    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', char(stopTime), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'none');
    simIn = simIn.setBlockParameter(egrValvePath, ...
        'restriction_area', sprintf('%.16g*cegr_pipe_area', areaFraction));
    simOut = sim(simIn);
    result.passed = true;
    result = collectAuditResult(simOut, result);
    result.pressureChainOk = checkPressureChain(result);
    fprintf('  PASS ratio=%.5g split=%.5g yO2_in=%.5g\n', ...
        result.egrRatioCompIn, result.egrSplitRatioOut, result.yO2CompInlet);
catch ME
    result.passed = false;
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    fprintf('  FAIL %s: %s\n', result.errorId, result.errorMessage);
end
resetModelFromDisk(model, modelFile);
end

function markAuditSignals(~, paths)
nameLineFromBlockOut(paths.compressorFlowConverter, ...
    'routeA_mdot_comp_inlet');
nameLineFromBlockOut(paths.exhaustMassFlowConverter, ...
    'routeA_exhaust_mdot');
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

function result = collectAuditResult(simOut, result)
logsout = simOut.logsout;
result.egrMdot = scalarLastOrNaN(logsout, "routeA_cegr_mdot");
result.exhaustMdot = scalarLastOrNaN(logsout, "routeA_exhaust_mdot");
if ~isfinite(result.exhaustMdot)
    result.exhaustMdot = scalarLastFromSimOutOrNaN(simOut, "routeA_exhaust_mdot_ts");
end
result.compInletMdot = scalarLastOrNaN(logsout, "routeA_mdot_comp_inlet");
result.egrRatioCompIn = safeDivide(result.egrMdot, result.compInletMdot);
outletTotalMdot = max(result.egrMdot, 0) + max(result.exhaustMdot, 0);
result.egrSplitRatioOut = safeDivide(max(result.egrMdot, 0), outletTotalMdot);

result.pOutlet = scalarLastOrNaN(logsout, "routeA_p_outlet");
result.pEgrValveUp = scalarLastOrNaN(logsout, "routeA_p_egr_valve_up");
result.pEgrValveDown = scalarLastOrNaN(logsout, "routeA_p_egr_valve_down");
result.pCompInlet = scalarLastOrNaN(logsout, "routeA_p_comp_inlet");

outletYi = lastLoggedValueOrNaN(logsout, "routeA_yi_outlet");
inletYi = lastLoggedValueOrNaN(logsout, "routeA_yi_comp_inlet");
result.yO2Outlet = pickSpecies(outletYi, 2);
result.yH2OOutlet = pickSpecies(outletYi, 4);
result.yO2CompInlet = pickSpecies(inletYi, 2);
result.yH2OCompInlet = pickSpecies(inletYi, 4);
end

function ok = checkPressureChain(result)
tol = 10; % Pa tolerance for equal-node sensor noise
ok = isfinite(result.pOutlet) && isfinite(result.pEgrValveUp) && ...
    isfinite(result.pEgrValveDown) && isfinite(result.pCompInlet) && ...
    result.pOutlet + tol >= result.pEgrValveUp && ...
    result.pEgrValveUp + tol >= result.pEgrValveDown && ...
    result.pEgrValveDown + tol >= result.pCompInlet;
end

function assessment = assessAreaScan(results)
passed = [results.passed];
valid = results(passed);
assessment = struct();
assessment.all30sPassed = all(passed);
assessment.firstFailAreaFraction = NaN;
if ~all(passed)
    idx = find(~passed, 1, 'first');
    assessment.firstFailAreaFraction = results(idx).areaFraction;
end
assessment.egrMdotMonotonic = false;
assessment.compInletO2NonIncreasing = false;
assessment.pressureChainAllOk = false;
if ~isempty(valid)
    mdot = [valid.egrMdot];
    yO2 = [valid.yO2CompInlet];
    assessment.egrMdotMonotonic = all(diff(mdot) >= -1e-8);
    assessment.compInletO2NonIncreasing = all(diff(yO2) <= 1e-6);
    assessment.pressureChainAllOk = all([valid.pressureChainOk]);
end
assessment.passed = assessment.all30sPassed && assessment.egrMdotMonotonic && ...
    assessment.compInletO2NonIncreasing && assessment.pressureChainAllOk;
end

function dispTopology(topology)
fprintf('\nRoute A A6.5 topology read-back\n');
for k = 1:numel(topology.requiredBlocks)
    fprintf('  %-28s present=%d ref=%s\n', topology.requiredBlocks(k), ...
        topology.blockPresent(k), topology.referenceBlocks(k));
end
fprintf('  saved_connections_ok=%d\n', topology.savedConnectionsOk);
fprintf('  RH=%s condensed=%s\n', topology.rhStatus, topology.condensedStatus);
fprintf('  topology_passed=%d\n', topology.passed);
end

function dispResults(results, titleText)
fprintf('\n%s\n', titleText);
fprintf(['%-10s %-6s %-8s %11s %11s %11s %11s %11s ', ...
    '%11s %11s %11s %11s %10s %10s %s\n'], ...
    'areaFrac', 'pass', 'stop', 'mdot_egr', 'mdot_exh', 'mdot_comp', ...
    'ratio_in', 'split_out', 'p_out', 'p_up', 'p_down', 'p_comp', ...
    'yO2_out', 'yO2_in', 'error');
for k = 1:numel(results)
    r = results(k);
    fprintf(['%-10.4g %-6s %-8s %11.4g %11.4g %11.4g %11.4g %11.4g ', ...
        '%11.4g %11.4g %11.4g %11.4g %10.4g %10.4g %s\n'], ...
        r.areaFraction, string(r.passed), r.stopTime, r.egrMdot, ...
        r.exhaustMdot, r.compInletMdot, r.egrRatioCompIn, ...
        r.egrSplitRatioOut, r.pOutlet, r.pEgrValveUp, r.pEgrValveDown, ...
        r.pCompInlet, r.yO2Outlet, r.yO2CompInlet, r.errorId);
end
end

function dispAssessment(assessment)
fprintf('\nRoute A A6.5 scan assessment\n');
fprintf('  all30sPassed=%d\n', assessment.all30sPassed);
fprintf('  egrMdotMonotonic=%d\n', assessment.egrMdotMonotonic);
fprintf('  compInletO2NonIncreasing=%d\n', assessment.compInletO2NonIncreasing);
fprintf('  pressureChainAllOk=%d\n', assessment.pressureChainAllOk);
fprintf('  passed=%d\n', assessment.passed);
if isfinite(assessment.firstFailAreaFraction)
    fprintf('  firstFailAreaFraction=%.6g\n', assessment.firstFailAreaFraction);
end
end

function refreshModelWorkspace(model)
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
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

function value = pickSpecies(vectorValue, speciesIndex)
if numel(vectorValue) >= speciesIndex
    value = vectorValue(speciesIndex);
else
    value = NaN;
end
end

function out = safeDivide(num, den)
if isfinite(num) && isfinite(den) && abs(den) > eps
    out = num / den;
else
    out = NaN;
end
end

function flag = getOptionalFlag(name, defaultValue)
flag = defaultValue;
if evalin('base', sprintf('exist(''%s'', ''var'')', name))
    flag = logical(evalin('base', name));
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

function restoreFolderAndModel(oldDir, model, modelFile)
cd(oldDir);
if bdIsLoaded(model)
    close_system(model, 0);
end
if exist(modelFile, 'file')
    load_system(modelFile);
end
end
