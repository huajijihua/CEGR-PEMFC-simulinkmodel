%% Route A A6 staged smoke run for compressor-inlet cathode cEGR
% A6 is gated deliberately:
%   1. no_egr_isolated     : temporarily restore official no-EGR inlet/outlet
%                            topology in memory; do not save the model.
%   2. no_egr_closed_valve : use the Route A cEGR topology with the valve
%                            near closed.
%   3. low_egr             : use the Route A cEGR topology with low valve area.
%
% The script stops at the first failing gate. It prints compact evidence and
% does not export figures, CSV files, or model copies.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a6_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

if bdIsLoaded(model) && strcmp(get_param(model, 'Dirty'), 'on')
    error('RouteA:A6:DirtyModel', ...
        ['Model %s has unsaved changes. Save or discard them in MATLAB ', ...
        'before running this staged smoke script.'], model);
end

caseDefs = defineCases();
results = repmat(emptyResult(), numel(caseDefs), 1);

for k = 1:numel(caseDefs)
    results(k) = runCase(model, modelFile, caseDefs(k));
    if ~results(k).passed
        break;
    end
end

assignin('base', 'routeA_smoke_results', results);
dispResults(results);

function caseDefs = defineCases()
caseDefs(1).name = "no_egr_isolated";
caseDefs(1).mode = "official_no_egr_bypass";
caseDefs(1).restrictionArea = "";
caseDefs(1).stopTimes = ["0.1", "5", "30"];

caseDefs(2).name = "no_egr_closed_valve";
caseDefs(2).mode = "routeA_valve_area";
caseDefs(2).restrictionArea = "cegr_valve_area_closed";
caseDefs(2).stopTimes = ["0.1", "5", "30"];

caseDefs(3).name = "low_egr";
caseDefs(3).mode = "routeA_valve_area";
caseDefs(3).restrictionArea = "cegr_valve_area_low";
caseDefs(3).stopTimes = ["0.1", "5", "30"];
end

function result = emptyResult()
result = struct( ...
    'caseName', "", ...
    'mode', "", ...
    'restrictionArea', "", ...
    'passed', false, ...
    'stopTimePassed', "", ...
    'failedStopTime', "", ...
    'errorId', "", ...
    'errorMessage', "", ...
    'cegrMdot', NaN, ...
    'compInletMdot', NaN, ...
    'egrRatioCompIn', NaN, ...
    'pOutlet', NaN, ...
    'pEgrValveUp', NaN, ...
    'pEgrValveDown', NaN, ...
    'pCompInlet', NaN, ...
    'yO2Outlet', NaN, ...
    'yO2CompInlet', NaN);
end

function result = runCase(model, modelFile, caseDef)
result = emptyResult();
result.caseName = caseDef.name;
result.mode = caseDef.mode;
result.restrictionArea = caseDef.restrictionArea;

fprintf('\nRoute A A6 gate: %s\n', caseDef.name);

for n = 1:numel(caseDef.stopTimes)
    stopTime = caseDef.stopTimes(n);
    try
        resetModelFromDisk(model, modelFile);
        refreshModelWorkspace(model);
        paths = routeA_block_paths(model);
        if caseDef.mode == "official_no_egr_bypass"
            applyOfficialNoEGRBypass(model, paths);
        end
        markSmokeSignals(paths);

        simIn = Simulink.SimulationInput(model);
        simIn = simIn.setModelParameter( ...
            'StopTime', char(stopTime), ...
            'SignalLogging', 'on', ...
            'SignalLoggingName', 'logsout', ...
            'SimscapeLogType', 'none');

        if caseDef.mode == "routeA_valve_area"
            egrValvePath = paths.egrValve;
            simIn = simIn.setBlockParameter(egrValvePath, ...
                'restriction_area', caseDef.restrictionArea);
        end

        simOut = sim(simIn);
        result.passed = true;
        result.stopTimePassed = stopTime;
        result = collectResult(simOut, result);
        fprintf('  PASS StopTime=%s\n', stopTime);
    catch ME
        result.passed = false;
        result.failedStopTime = stopTime;
        result.errorId = string(ME.identifier);
        result.errorMessage = string(ME.message);
        fprintf('  FAIL StopTime=%s\n', stopTime);
        fprintf('    %s\n', ME.identifier);
        fprintf('    %s\n', ME.message);
        resetModelFromDisk(model, modelFile);
        return;
    end
end

resetModelFromDisk(model, modelFile);
end

function refreshModelWorkspace(model)
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
end
end

function applyOfficialNoEGRBypass(model, paths)
oxygen = paths.oxygen;
commentBlocks = { ...
    paths.compressorInletMixer, ...
    paths.compressorInletMixerInsulator, ...
    paths.compressorInletPressureConverter, ...
    paths.compressorInletTemperatureConverter, ...
    paths.compressorInletCompositionConverter, ...
    paths.compressorInletDiagnostics, ...
    paths.outletChamber, ...
    paths.outletResistance, ...
    paths.exhaustMassFlowSensor, ...
    paths.exhaustMassFlowConverter, ...
    paths.exhaustMdotWorkspace, ...
    paths.exhaustDiagnostics, ...
    paths.outletChamberInsulator, ...
    paths.outletPConverter, ...
    paths.outletTConverter, ...
    paths.outletYiConverter, ...
    paths.outletTemperatureDiagnostics, ...
    paths.outletCompositionDiagnostics, ...
    paths.egrMassFlowSensor, ...
    paths.egrMassFlowConverter, ...
    paths.egrDiagnostics, ...
    paths.egrValve, ...
    paths.egrValveUpSensor, ...
    paths.egrValveUpReference, ...
    paths.egrValveUpPConverter, ...
    paths.egrValveDownSensor, ...
    paths.egrValveDownReference, ...
    paths.egrValveDownPConverter, ...
    paths.pressureChainDiagnostics, ...
    paths.egrPipe, ...
    [paths.cathodeAir '/EGRPipeInsulator']};

for k = 1:numel(commentBlocks)
    if getSimulinkBlockHandle(commentBlocks{k}) ~= -1
        set_param(commentBlocks{k}, 'Commented', 'on');
    end
end

restoreOfficialOxygenSourceInlet(paths);
restoreOfficialCathodeOutlet(model, paths);
end

function restoreOfficialOxygenSourceInlet(paths)
oxygen = paths.oxygen;
airIntake = paths.airIntake;
mixer = paths.compressorInletMixer;
compressor = paths.compressor;
compressorMap = [paths.oxygen '/Compressor Map'];

phMixer = get_param(mixer, 'PortHandles');
phCompressor = get_param(compressor, 'PortHandles');
phMap = get_param(compressorMap, 'PortHandles');
lineHandles = [];

for portIdx = [3 4 5]
    lineHandle = get_param(phMixer.LConn(portIdx), 'Line');
    if lineHandle ~= -1
        lineHandles(end + 1) = lineHandle; %#ok<AGROW>
    end
end

for portHandle = [phCompressor.LConn(2), phMap.RConn(1)]
    lineHandle = get_param(portHandle, 'Line');
    if lineHandle ~= -1
        lineHandles(end + 1) = lineHandle; %#ok<AGROW>
    end
end

deleteLines(lineHandles);

phAir = get_param(airIntake, 'PortHandles');
phCompressor = get_param(compressor, 'PortHandles');
phMap = get_param(compressorMap, 'PortHandles');
add_line(oxygen, phAir.LConn(1), phCompressor.LConn(2), 'autorouting', 'on');
add_line(oxygen, phAir.LConn(1), phMap.RConn(1), 'autorouting', 'on');
end

function restoreOfficialCathodeOutlet(model, paths)
cathodeGas = paths.cathodeGas;
cathodeExhaust = paths.cathodeExhaustBlock;
outletChamber = paths.outletChamber;
exhaustSensor = paths.exhaustMassFlowSensor;
exhaustConverter = paths.exhaustMassFlowConverter;

phGas = get_param(cathodeGas, 'PortHandles');
phExhaust = get_param(cathodeExhaust, 'PortHandles');
phOutlet = get_param(outletChamber, 'PortHandles');
lineHandles = [];

for portHandle = [phGas.LConn(2), phExhaust.LConn(1), ...
        phOutlet.LConn(3), phOutlet.LConn(4), phOutlet.LConn(5)]
    lineHandle = get_param(portHandle, 'Line');
    if lineHandle ~= -1
        lineHandles(end + 1) = lineHandle; %#ok<AGROW>
    end
end
if getSimulinkBlockHandle(exhaustSensor) ~= -1
    phExhaustSensor = get_param(exhaustSensor, 'PortHandles');
    for portHandle = [phExhaustSensor.LConn(1), phExhaustSensor.RConn(1), phExhaustSensor.RConn(4)]
        lineHandle = get_param(portHandle, 'Line');
        if lineHandle ~= -1
            lineHandles(end + 1) = lineHandle; %#ok<AGROW>
        end
    end
end
if getSimulinkBlockHandle(exhaustConverter) ~= -1
    phExhaustConverter = get_param(exhaustConverter, 'PortHandles');
    if ~isempty(phExhaustConverter.Outport)
        lineHandle = get_param(phExhaustConverter.Outport(1), 'Line');
        if lineHandle ~= -1
            lineHandles(end + 1) = lineHandle; %#ok<AGROW>
        end
    end
end

deleteLines(lineHandles);

phGas = get_param(cathodeGas, 'PortHandles');
phExhaust = get_param(cathodeExhaust, 'PortHandles');
add_line(model, phGas.LConn(2), phExhaust.LConn(1), 'autorouting', 'on');
end

function deleteLines(lineHandles)
lineHandles = unique(lineHandles);
for k = 1:numel(lineHandles)
    try
        delete_line(lineHandles(k));
    catch
    end
end
end

function markSmokeSignals(paths)
compressorFlowConverter = paths.compressorFlowConverter;
if getSimulinkBlockHandle(compressorFlowConverter) ~= -1
    portHandles = get_param(compressorFlowConverter, 'PortHandles');
    lineHandle = get_param(portHandles.Outport(1), 'Line');
    if lineHandle ~= -1
        set_param(lineHandle, 'Name', 'routeA_mdot_comp_inlet');
    end
end
end

function result = collectResult(simOut, result)
try
    logsout = simOut.logsout;
catch
    return;
end

result.cegrMdot = scalarLastOrNaN(logsout, "routeA_cegr_mdot");
result.compInletMdot = scalarLastOrNaN(logsout, "routeA_mdot_comp_inlet");
if isfinite(result.cegrMdot) && isfinite(result.compInletMdot) && ...
        abs(result.compInletMdot) > eps
    result.egrRatioCompIn = result.cegrMdot / result.compInletMdot;
end

result.pOutlet = scalarLastOrNaN(logsout, "routeA_p_outlet");
result.pEgrValveUp = scalarLastOrNaN(logsout, "routeA_p_egr_valve_up");
result.pEgrValveDown = scalarLastOrNaN(logsout, "routeA_p_egr_valve_down");
result.pCompInlet = scalarLastOrNaN(logsout, "routeA_p_comp_inlet");

outletYi = lastLoggedValueOrNaN(logsout, "routeA_yi_outlet");
inletYi = lastLoggedValueOrNaN(logsout, "routeA_yi_comp_inlet");
result.yO2Outlet = pickSpecies(outletYi, 2);
result.yO2CompInlet = pickSpecies(inletYi, 2);
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

function dispResults(results)
fprintf('\nRoute A A6 staged smoke summary\n');
fprintf(['%-20s %-24s %-6s %-8s %-8s %11s %11s %11s ', ...
    '%11s %11s %10s %10s %s\n'], ...
    'case', 'mode_or_area', 'pass', 'ok_to', 'fail_at', ...
    'mdot_egr', 'mdot_comp', 'egr_ratio', 'p_out', ...
    'p_comp_in', 'yO2_out', 'yO2_in', 'error');

for k = 1:numel(results)
    r = results(k);
    if r.caseName == ""
        continue;
    end
    modeOrArea = r.mode;
    if r.restrictionArea ~= ""
        modeOrArea = r.restrictionArea;
    end
    fprintf(['%-20s %-24s %-6s %-8s %-8s %11.4g %11.4g %11.4g ', ...
        '%11.4g %11.4g %10.4g %10.4g %s\n'], ...
        r.caseName, modeOrArea, string(r.passed), r.stopTimePassed, ...
        r.failedStopTime, r.cegrMdot, r.compInletMdot, ...
        r.egrRatioCompIn, r.pOutlet, r.pCompInlet, r.yO2Outlet, ...
        r.yO2CompInlet, r.errorId);
end
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
