%% Route A A6 cEGR coupling diagnostics
% This script isolates the A6 initialization failure by adding the cEGR
% coupling back in layers. All topology changes are temporary in memory.
% The model is reloaded from disk before each probe and is never saved.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a6_diag_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

if bdIsLoaded(model) && strcmp(get_param(model, 'Dirty'), 'on')
    error('RouteA:A6Diag:DirtyModel', ...
        ['Model %s has unsaved changes. Save or discard them in MATLAB ', ...
        'before running this diagnostic script.'], model);
end

probeDefs = defineProbes();
probeFilter = getProbeFilter();
if probeFilter ~= ""
    keepProbe = [probeDefs.name] == probeFilter | ...
        [probeDefs.mode] == probeFilter;
    if ~any(keepProbe)
        error('RouteA:A6Diag:UnknownProbeFilter', ...
            'No probe matches routeAProbeFilter=%s.', probeFilter);
    end
    probeDefs = probeDefs(keepProbe);
end
results = repmat(emptyProbeResult(), numel(probeDefs), 1);

for k = 1:numel(probeDefs)
    results(k) = runProbe(model, modelFile, probeDefs(k));
end

assignin('base', 'routeA_a6_coupling_diagnostics', results);
dispProbeResults(results);

function probeFilter = getProbeFilter()
probeFilter = "";
if evalin('base', 'exist(''routeAProbeFilter'', ''var'')')
    probeFilter = string(evalin('base', 'routeAProbeFilter'));
end
envProbe = string(getenv('ROUTEA_A6_PROBE'));
if probeFilter == "" && envProbe ~= ""
    probeFilter = envProbe;
end
end

function probeDefs = defineProbes()
probeDefs(1).name = "P0_official_no_egr";
probeDefs(1).mode = "official_no_egr";
probeDefs(1).description = "Official inlet and outlet topology restored.";

probeDefs(2).name = "P1_keep_mixer_no_egr";
probeDefs(2).mode = "keep_mixer_no_egr";
probeDefs(2).description = "Keep CompressorInletMixer, bypass outlet/EGR.";

probeDefs(3).name = "P2_outlet_chamber_capped";
probeDefs(3).mode = "outlet_chamber_capped";
probeDefs(3).description = "Keep outlet chamber A-B path; cap chamber C and cEGR inlet.";

probeDefs(4).name = "P2a_outlet_chamber_two_port";
probeDefs(4).mode = "outlet_chamber_two_port";
probeDefs(4).description = "Keep outlet chamber A-B path; set chamber to two ports.";

probeDefs(5).name = "P2b_outlet_chamber_no_cond";
probeDefs(5).mode = "outlet_chamber_no_cond";
probeDefs(5).description = "Keep three-port outlet chamber capped; disable chamber condensation.";

probeDefs(6).name = "P2c_outlet_two_port_no_cond";
probeDefs(6).mode = "outlet_two_port_no_cond";
probeDefs(6).description = "Set outlet chamber to two ports and disable condensation.";

probeDefs(7).name = "P2d_outlet_with_resistance";
probeDefs(7).mode = "outlet_with_resistance";
probeDefs(7).description = "Insert Flow Resistance between cathode channel chamber and outlet chamber.";

probeDefs(8).name = "P3_mass_sensor_capped";
probeDefs(8).mode = "mass_sensor_capped";
probeDefs(8).description = "Add EGR mass sensor, cap sensor outlet and cEGR inlet.";

probeDefs(9).name = "P4_valve_capped";
probeDefs(9).mode = "valve_capped";
probeDefs(9).description = "Add near-closed EGR valve, cap valve outlet and cEGR inlet.";

probeDefs(10).name = "P5_pipe_capped";
probeDefs(10).mode = "pipe_capped";
probeDefs(10).description = "Add EGR pipe inventory, cap pipe outlet and cEGR inlet.";

probeDefs(11).name = "P6_full_closed_loop";
probeDefs(11).mode = "full_closed_loop";
probeDefs(11).description = "Current Route A closed-valve topology.";

probeDefs(12).name = "P6r_full_loop_with_resistance";
probeDefs(12).mode = "full_loop_with_resistance";
probeDefs(12).description = "Current closed loop plus outlet chamber inlet flow resistance.";
end

function result = emptyProbeResult()
result = struct( ...
    'probeName', "", ...
    'mode', "", ...
    'description', "", ...
    'passed', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
    'dirtyAfterProbe', "", ...
    'notes', "");
end

function result = runProbe(model, modelFile, probeDef)
result = emptyProbeResult();
result.probeName = probeDef.name;
result.mode = probeDef.mode;
result.description = probeDef.description;

fprintf('\nRoute A A6 coupling probe: %s\n', probeDef.name);
fprintf('  %s\n', probeDef.description);

try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    paths = routeA_block_paths(model);
    applyProbeTopology(model, paths, probeDef.mode);
    setClosedValveArea(paths);

    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', '0.1', ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'SimscapeLogType', 'none');

    sim(simIn);
    result.passed = true;
    result.dirtyAfterProbe = string(get_param(model, 'Dirty'));
    fprintf('  PASS StopTime=0.1\n');
catch ME
    result.passed = false;
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
    if bdIsLoaded(model)
        result.dirtyAfterProbe = string(get_param(model, 'Dirty'));
    end
    fprintf('  FAIL StopTime=0.1\n');
    fprintf('    %s\n', ME.identifier);
    fprintf('    %s\n', result.errorMessage);
end

resetModelFromDisk(model, modelFile);
end

function applyProbeTopology(model, paths, mode)
switch mode
    case "official_no_egr"
        applyOfficialNoEGRBypass(model, paths);
    case "keep_mixer_no_egr"
        applyOutletAndEGRBypassKeepMixer(model, paths);
    case "outlet_chamber_capped"
        applyOutletChamberCapped(model, paths);
    case "outlet_chamber_two_port"
        applyOutletChamberTwoPort(model, paths);
    case "outlet_chamber_no_cond"
        applyOutletChamberCapped(model, paths);
        disableOutletChamberCondensation(paths);
    case "outlet_two_port_no_cond"
        applyOutletChamberTwoPort(model, paths);
        disableOutletChamberCondensation(paths);
    case "outlet_with_resistance"
        applyOutletChamberWithResistance(model, paths);
    case "mass_sensor_capped"
        applyMassSensorCapped(model, paths);
    case "valve_capped"
        applyValveCapped(model, paths);
    case "pipe_capped"
        applyPipeCapped(model, paths);
    case "full_closed_loop"
        % Use the model as saved, only force closed-valve area.
    case "full_loop_with_resistance"
        applyOutletResistanceOnly(model, paths);
    otherwise
        error('RouteA:A6Diag:UnknownProbe', 'Unknown probe mode: %s', mode);
end
end

function applyOutletResistanceOnly(model, paths)
resPath = [model '/RouteAProbeOutletResistance'];
if getSimulinkBlockHandle(resPath) ~= -1
    delete_block(resPath);
end

cathodeGas = paths.cathodeGas;
outletChamber = paths.outletChamber;
deleteLineAtBlockPort(cathodeGas, 'LConn', 2);
deleteLineAtBlockPort(outletChamber, 'LConn', 3);

add_block('FuelCell_lib/elements/Flow Resistance (FC)', resPath, ...
    'MakeNameUnique', 'off', ...
    'Position', [1000 850 1070 910], ...
    'area', 'cegr_pipe_area');

phGas = get_param(cathodeGas, 'PortHandles');
phOutlet = get_param(outletChamber, 'PortHandles');
phRes = get_param(resPath, 'PortHandles');
add_line(model, phGas.LConn(2), phRes.LConn(1), 'autorouting', 'on');
add_line(model, phRes.RConn(1), phOutlet.LConn(3), 'autorouting', 'on');
end

function disableOutletChamberCondensation(paths)
set_param(paths.outletChamber, ...
    'cond_spec', 'FuelCell.enum.ChamberCondSpec.Disabled');
end

function refreshModelWorkspace(model)
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
end
end

function setClosedValveArea(paths)
if getSimulinkBlockHandle(paths.egrValve) ~= -1
    set_param(paths.egrValve, ...
        'restriction_area', 'cegr_valve_area_closed');
end
end

function applyOfficialNoEGRBypass(model, paths)
commentBlocks(routeAOutletAndEGRBlocks(paths));
commentBlocks(oxygenMixerBlocks(paths));
restoreOfficialOxygenSourceInlet(paths);
restoreOfficialCathodeOutlet(model, paths);
end

function applyOutletAndEGRBypassKeepMixer(model, paths)
commentBlocks(routeAOutletAndEGRBlocks(paths));
restoreOfficialCathodeOutlet(model, paths);
end

function applyOutletChamberCapped(model, paths)
commentBlocks(egrBranchBlocks(paths));
deleteLineAtBlockPort(paths.outletChamber, 'LConn', 5);
deleteLineAtBlockPort(paths.oxygen, 'LConn', 2);
addCapToBlockPort(model, paths.outletChamber, 'LConn', 5, ...
    'RouteAProbeCap_OutletC', [1280 905 1330 955]);
addCapToBlockPort(model, paths.oxygen, 'LConn', 2, ...
    'RouteAProbeCap_CompInC', [1540 560 1590 610]);
end

function applyOutletChamberTwoPort(model, paths)
commentBlocks(egrBranchBlocks(paths));
deleteLineAtBlockPort(paths.outletChamber, 'LConn', 5);
deleteLineAtBlockPort(paths.oxygen, 'LConn', 2);
set_param(paths.outletChamber, ...
    'num_ports', 'foundation.enum.num_ports.two');
addCapToBlockPort(model, paths.oxygen, 'LConn', 2, ...
    'RouteAProbeCap_CompInC', [1540 560 1590 610]);
end

function applyOutletChamberWithResistance(model, paths)
applyOutletChamberCapped(model, paths);
resPath = [model '/RouteAProbeOutletResistance'];
if getSimulinkBlockHandle(resPath) ~= -1
    delete_block(resPath);
end

cathodeGas = paths.cathodeGas;
outletChamber = paths.outletChamber;
deleteLineAtBlockPort(cathodeGas, 'LConn', 2);
deleteLineAtBlockPort(outletChamber, 'LConn', 3);

add_block('FuelCell_lib/elements/Flow Resistance (FC)', resPath, ...
    'MakeNameUnique', 'off', ...
    'Position', [1000 850 1070 910], ...
    'area', 'cegr_pipe_area');

phGas = get_param(cathodeGas, 'PortHandles');
phOutlet = get_param(outletChamber, 'PortHandles');
phRes = get_param(resPath, 'PortHandles');
add_line(model, phGas.LConn(2), phRes.LConn(1), 'autorouting', 'on');
add_line(model, phRes.RConn(1), phOutlet.LConn(3), 'autorouting', 'on');
end

function applyMassSensorCapped(model, paths)
commentBlocks(downstreamOfMassSensorBlocks(paths));
deleteLineAtBlockPort(paths.egrMassFlowSensor, 'RConn', 4);
deleteLineAtBlockPort(paths.oxygen, 'LConn', 2);
addCapToBlockPort(model, paths.egrMassFlowSensor, 'RConn', 4, ...
    'RouteAProbeCap_MassSensorB', [1500 585 1550 635]);
addCapToBlockPort(model, paths.oxygen, 'LConn', 2, ...
    'RouteAProbeCap_CompInC', [1540 560 1590 610]);
end

function applyValveCapped(model, paths)
commentBlocks(downstreamOfValveBlocks(paths));
deleteLineAtBlockPort(paths.egrValve, 'RConn', 1);
deleteLineAtBlockPort(paths.oxygen, 'LConn', 2);
addCapToBlockPort(model, paths.egrValve, 'RConn', 1, ...
    'RouteAProbeCap_ValveB', [1500 900 1550 950]);
addCapToBlockPort(model, paths.oxygen, 'LConn', 2, ...
    'RouteAProbeCap_CompInC', [1540 560 1590 610]);
end

function applyPipeCapped(model, paths)
deleteLineAtBlockPort(paths.egrPipe, 'RConn', 1);
deleteLineAtBlockPort(paths.oxygen, 'LConn', 2);
addCapToBlockPort(model, paths.egrPipe, 'RConn', 1, ...
    'RouteAProbeCap_PipeB', [1510 280 1560 330]);
addCapToBlockPort(model, paths.oxygen, 'LConn', 2, ...
    'RouteAProbeCap_CompInC', [1540 560 1590 610]);
end

function blocks = oxygenMixerBlocks(paths)
oxygen = paths.oxygen;
blocks = { ...
    paths.compressorInletMixer, ...
    paths.compressorInletMixerInsulator, ...
    paths.compressorInletPressureConverter, ...
    paths.compressorInletTemperatureConverter, ...
    paths.compressorInletCompositionConverter, ...
    paths.compressorInletDiagnostics};
end

function blocks = routeAOutletAndEGRBlocks(paths)
blocks = [ ...
    {paths.outletChamber, paths.outletResistance, ...
    paths.exhaustMassFlowSensor, paths.exhaustMassFlowConverter, ...
    paths.exhaustMdotWorkspace, paths.exhaustDiagnostics, ...
    paths.outletChamberInsulator, paths.outletPConverter, ...
    paths.outletTConverter, paths.outletYiConverter, ...
    paths.outletTemperatureDiagnostics, paths.outletCompositionDiagnostics}, ...
    egrBranchBlocks(paths)];
end

function blocks = egrBranchBlocks(paths)
blocks = { ...
    paths.egrMassFlowSensor, paths.egrMassFlowConverter, ...
    paths.egrDiagnostics, paths.egrValve, paths.egrValveUpSensor, ...
    paths.egrValveUpReference, paths.egrValveUpPConverter, ...
    paths.egrValveDownSensor, paths.egrValveDownReference, ...
    paths.egrValveDownPConverter, paths.pressureChainDiagnostics, ...
    paths.egrPipe, [paths.cathodeAir '/EGRPipeInsulator']};
end

function blocks = downstreamOfMassSensorBlocks(paths)
blocks = {paths.egrValve, paths.egrValveUpSensor, ...
    paths.egrValveUpReference, paths.egrValveUpPConverter, ...
    paths.egrValveDownSensor, paths.egrValveDownReference, ...
    paths.egrValveDownPConverter, paths.pressureChainDiagnostics, ...
    paths.egrPipe, [paths.cathodeAir '/EGRPipeInsulator']};
end

function blocks = downstreamOfValveBlocks(paths)
blocks = {paths.egrValveDownSensor, paths.egrValveDownReference, ...
    paths.egrValveDownPConverter, paths.pressureChainDiagnostics, ...
    paths.egrPipe, [paths.cathodeAir '/EGRPipeInsulator']};
end

function commentBlocks(~, blocks)
for k = 1:numel(blocks)
    if getSimulinkBlockHandle(blocks{k}) ~= -1
        set_param(blocks{k}, 'Commented', 'on');
    end
end
end

function restoreOfficialOxygenSourceInlet(paths)
oxygen = paths.oxygen;
airIntake = paths.airIntake;
mixer = paths.compressorInletMixer;
compressor = paths.compressor;
compressorMap = [oxygen '/Compressor Map'];

phMixer = get_param(mixer, 'PortHandles');
phCompressor = get_param(compressor, 'PortHandles');
phMap = get_param(compressorMap, 'PortHandles');
lineHandles = [];

for portIdx = [3 4 5]
    lineHandles = appendLineAtPort(lineHandles, phMixer.LConn(portIdx));
end

lineHandles = appendLineAtPort(lineHandles, phCompressor.LConn(2));
lineHandles = appendLineAtPort(lineHandles, phMap.RConn(1));
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
    lineHandles = appendLineAtPort(lineHandles, portHandle);
end
if getSimulinkBlockHandle(exhaustSensor) ~= -1
    phExhaustSensor = get_param(exhaustSensor, 'PortHandles');
    for portHandle = [phExhaustSensor.LConn(1), phExhaustSensor.RConn(1), phExhaustSensor.RConn(4)]
        lineHandles = appendLineAtPort(lineHandles, portHandle);
    end
end
if getSimulinkBlockHandle(exhaustConverter) ~= -1
    phExhaustConverter = get_param(exhaustConverter, 'PortHandles');
    if ~isempty(phExhaustConverter.Outport)
        lineHandles = appendLineAtPort(lineHandles, phExhaustConverter.Outport(1));
    end
end

deleteLines(lineHandles);

phGas = get_param(cathodeGas, 'PortHandles');
phExhaust = get_param(cathodeExhaust, 'PortHandles');
add_line(model, phGas.LConn(2), phExhaust.LConn(1), 'autorouting', 'on');
end

function addCapToBlockPort(model, blockPath, portGroup, portIndex, capName, position)
parentPath = fileparts(blockPath);
capPath = [parentPath '/' capName];
if getSimulinkBlockHandle(capPath) ~= -1
    delete_block(capPath);
end

add_block('FuelCell_lib/elements/Cap (FC)', capPath, ...
    'MakeNameUnique', 'off', 'Position', position);

phBlock = get_param(blockPath, 'PortHandles');
phCap = get_param(capPath, 'PortHandles');
targetPort = phBlock.(portGroup)(portIndex);
capPort = firstPhysicalPort(phCap);
add_line(parentPath, targetPort, capPort, 'autorouting', 'on');
end

function port = firstPhysicalPort(portHandles)
if isfield(portHandles, 'LConn') && ~isempty(portHandles.LConn)
    port = portHandles.LConn(1);
elseif isfield(portHandles, 'RConn') && ~isempty(portHandles.RConn)
    port = portHandles.RConn(1);
else
    error('RouteA:A6Diag:NoPhysicalPort', ...
        'The temporary cap block has no physical connection port.');
end
end

function deleteLineAtBlockPort(blockPath, portGroup, portIndex)
if getSimulinkBlockHandle(blockPath) == -1
    return;
end
ph = get_param(blockPath, 'PortHandles');
portHandle = ph.(portGroup)(portIndex);
lineHandle = get_param(portHandle, 'Line');
if lineHandle ~= -1
    deleteLines(lineHandle);
end
end

function lineHandles = appendLineAtPort(lineHandles, portHandle)
lineHandle = get_param(portHandle, 'Line');
if lineHandle ~= -1
    lineHandles(end + 1) = lineHandle; %#ok<AGROW>
end
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

function txt = firstLine(txt)
parts = splitlines(txt);
txt = parts(1);
end

function dispProbeResults(results)
fprintf('\nRoute A A6 coupling diagnostic summary\n');
fprintf('%-26s %-22s %-6s %-34s %s\n', ...
    'probe', 'mode', 'pass', 'error_id', 'message');
for k = 1:numel(results)
    r = results(k);
    fprintf('%-26s %-22s %-6s %-34s %s\n', ...
        r.probeName, r.mode, string(r.passed), r.errorId, r.errorMessage);
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
