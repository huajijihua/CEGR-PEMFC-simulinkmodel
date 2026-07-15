%% Route A A7 platform structure and parameter-layer audit
% This is the Route A A7 main entry. It performs read-back checks only:
% no model save, no external bench data load, no figures, and no exports.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_a7_platform_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model));

if bdIsLoaded(model) && strcmp(get_param(model, 'Dirty'), 'on')
    error('RouteA:A7:DirtyModel', ...
        ['Model %s has unsaved changes. Save or discard them before ', ...
        'running the A7 platform audit.'], model);
end

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
paths = routeA_block_paths(model);

audit = struct();
audit.model = string(model);
audit.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
audit.parameterIsolation = auditParameterIsolation(model, modelDir);
audit.externalCaseGuard = auditExternalCaseGuard(model);
audit.structure = auditPlatformStructure(model, paths);
audit.parameterMatching = auditParameterMatching(model);
audit.a8Readiness = assessA8Readiness(audit);
audit.passed = audit.parameterIsolation.passed && ...
    audit.externalCaseGuard.passed && ...
    audit.structure.platformMinimumPassed && ...
    audit.parameterMatching.passed;

assignin('base', 'routeA_a7_platform_audit', audit);
dispAudit(audit);

function result = auditParameterIsolation(model, modelDir)
mw = get_param(model, 'ModelWorkspace');
result = struct();
result.layer = string(getWorkspaceValue(mw, 'routeA_parameter_layer', ""));
result.externalCaseEnabled = logical(getWorkspaceValue(mw, ...
    'routeA_external_case_enabled', true));
parameterFile = fullfile(modelDir, 'PEMFuelCellSystemWithACustomLibraryParameters.m');
txt = string(fileread(parameterFile));
result.parameterFile = string(parameterFile);
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

function result = auditPlatformStructure(model, paths)
result = struct();
requiredTopBlocks = [ ...
    "Membrane Electrode Assembly", ...
    "Oxygen Source", ...
    "Cathode Humidifier", ...
    "Cathode Gas Channels", ...
    "Cathode Exhaust", ...
    "Anode Humidifier", ...
    "Anode Gas Channels", ...
    "Hydrogen Source", ...
    "Recirculation", ...
    "Cooling System", ...
    "Heat Dissipation", ...
    "Measurements", ...
    "CathodeOutletResistance", ...
    "CathodeOutletChamber", ...
    "EGRMassFlowSensor", ...
    "EGRValveRestriction", ...
    "EGRPipe", ...
    "ExhaustMassFlowSensor"];
result.requiredTopBlocks = requiredTopBlocks;
result.requiredTopBlockPresent = false(size(requiredTopBlocks));
requiredPaths = { ...
    [paths.stack '/Membrane Electrode Assembly'], paths.oxygen, ...
    paths.cathodeHumidifier, paths.cathodeGas, paths.cathodeExhaustBlock, ...
    paths.anodeHumidifier, paths.anodeGas, paths.hydrogenSource, ...
    paths.recirculation, paths.coolingSystem, paths.heatDissipation, ...
    paths.measurements, paths.outletResistance, paths.outletChamber, ...
    paths.egrMassFlowSensor, paths.egrValve, paths.egrPipe, ...
    paths.exhaustMassFlowSensor};
for k = 1:numel(requiredTopBlocks)
    result.requiredTopBlockPresent(k) = ...
        getSimulinkBlockHandle(requiredPaths{k}) ~= -1;
end

oxygenBlocks = [ ...
    "Air Intake", ...
    "CompressorInletMixer", ...
    "Compressor", ...
    "Compressor Map", ...
    "PS-Simulink Converter"];
oxygenPath = paths.oxygen;
result.oxygenBlocks = oxygenBlocks;
result.oxygenBlockPresent = false(size(oxygenBlocks));
for k = 1:numel(oxygenBlocks)
    result.oxygenBlockPresent(k) = ...
        ~isempty(findBlocksByName(oxygenPath, oxygenBlocks(k), 1));
end

result.requiredConnectionsOk = hasRequiredCegrConnections(paths);
result.humidifierPresent = result.requiredTopBlockPresent( ...
    requiredTopBlocks == "Cathode Humidifier");
result.coolingPresent = result.requiredTopBlockPresent( ...
    requiredTopBlocks == "Cooling System");
result.explicitIntercoolerPresent = hasAnyNamedBlock(model, ...
    ["Intercooler", "Aftercooler", "ChargeAirCooler"]);
result.explicitSeparatorPresent = hasAnyNamedBlock(model, ...
    ["Separator", "WaterSeparator", "Condensate", "Condensation"]);
result.explicitHumidifierBypassPresent = hasAnyNamedBlock(model, ...
    ["HumidifierBypass", "CathodeHumidifierBypass", "Bypass"]);
result.rhDirectSignalPresent = hasAnySignal(model, ...
    ["routeA_RH_ca_in", "routeA_RH_ca_out"]);
result.condensedDirectSignalPresent = hasAnySignal(model, ...
    ["routeA_m_condensed", "routeA_m_water_sep"]);
result.platformMinimumPassed = all(result.requiredTopBlockPresent) && ...
    all(result.oxygenBlockPresent) && result.requiredConnectionsOk;
result.a8Gaps = strings(0, 1);
if ~result.explicitIntercoolerPresent
    result.a8Gaps(end + 1, 1) = "explicit_intercooler_or_aftercooler_L2_interface";
end
if ~result.explicitSeparatorPresent
    result.a8Gaps(end + 1, 1) = "explicit_water_separator_or_condensation_interface";
end
if ~result.explicitHumidifierBypassPresent
    result.a8Gaps(end + 1, 1) = "configurable_cathode_humidifier_bypass";
end
if ~result.rhDirectSignalPresent
    result.a8Gaps(end + 1, 1) = "direct_RH_KPI_signals";
end
if ~result.condensedDirectSignalPresent
    result.a8Gaps(end + 1, 1) = "direct_condensed_or_separated_water_KPI";
end
end

function result = auditParameterMatching(model)
mw = get_param(model, 'ModelWorkspace');
stackNumCells = getWorkspaceValue(mw, 'stack_num_cells', NaN);
stackAreaCm2 = getWorkspaceValue(mw, 'stack_area', NaN);
stackIL = getWorkspaceValue(mw, 'stack_iL', NaN);
compMdotMap = getWorkspaceValue(mw, 'comp_mdot_corr_TLU', NaN);
cegrPipeArea = getWorkspaceValue(mw, 'cegr_pipe_area', NaN);
cegrLowFrac = getWorkspaceValue(mw, 'cegr_valve_area_frac_low', NaN);
cegrMaxArea = getWorkspaceValue(mw, 'cegr_valve_max_area', NaN);
cegrPipeLength = getWorkspaceValue(mw, 'cegr_pipe_length', NaN);
compMixerVL = getWorkspaceValue(mw, 'comp_inlet_mixer_V', NaN);
outletChamberVL = getWorkspaceValue(mw, 'cathode_outlet_chamber_V', NaN);
cegrPipeD = getWorkspaceValue(mw, 'cegr_pipe_D', NaN);
coolantTubeD = getWorkspaceValue(mw, 'coolant_tube_D', NaN);
radiatorPrimary = getWorkspaceValue(mw, 'radiator_air_area_primary', NaN);
radiatorFins = getWorkspaceValue(mw, 'radiator_air_area_fins', NaN);

designCurrentDensity = 0.7; % [A/cm2], platform-level nominal point
designCellVoltage = 0.65; % [V], platform-level nominal point
limitCellVoltage = 0.55; % [V], rough high-current bound
airStoich = 2.0; % [-], sizing sanity only
faraday = 96485.33212; % [C/mol]
mO2 = 0.031998; % [kg/mol]
o2MassFractionAir = 0.232; % [-]

designCurrentA = stackAreaCm2 * designCurrentDensity;
limitCurrentA = stackAreaCm2 * stackIL;
designPowerW = stackNumCells * designCurrentA * designCellVoltage;
limitPowerW = stackNumCells * limitCurrentA * limitCellVoltage;
designO2KgS = stackNumCells * designCurrentA * mO2 / (4 * faraday);
designAirKgS = airStoich * designO2KgS / o2MassFractionAir;
maxCompMdotKgS = max(compMdotMap, [], 'all');
cegrLowArea = cegrPipeArea * cegrLowFrac;
cegrPipeVolumeL = cegrPipeArea * cegrPipeLength * 1000;
totalRadiatorAirArea = radiatorPrimary + radiatorFins;

result = struct();
result.stackNumCells = stackNumCells;
result.stackAreaCm2 = stackAreaCm2;
result.nominalDesignCurrentA = designCurrentA;
result.nominalDesignPowerW = designPowerW;
result.roughLimitPowerW = limitPowerW;
result.designAirDemandKgSAtLambda2 = designAirKgS;
result.maxCompressorMapMdotKgS = maxCompMdotKgS;
result.compressorAirDemandMargin = safeDivide(maxCompMdotKgS, designAirKgS);
result.cegrPipeDiameterM = cegrPipeD;
result.cegrPipeAreaM2 = cegrPipeArea;
result.cegrPipeVolumeL = cegrPipeVolumeL;
result.cegrLowValveAreaM2 = cegrLowArea;
result.cegrLowValveToPipeArea = safeDivide(cegrLowArea, cegrPipeArea);
result.cegrMaxValveToPipeArea = safeDivide(cegrMaxArea, cegrPipeArea);
result.compInletMixerVolumeL = compMixerVL;
result.cathodeOutletChamberVolumeL = outletChamberVL;
result.coolantTubeDiameterM = coolantTubeD;
result.radiatorAirAreaM2 = totalRadiatorAirArea;
result.compressorEnoughForNominal = result.compressorAirDemandMargin > 2;
result.cegrLowValveSmallButNonzero = result.cegrLowValveToPipeArea > 0 && ...
    result.cegrLowValveToPipeArea < 0.01;
result.cegrMaxValveNotLargerThanPipe = result.cegrMaxValveToPipeArea <= 1;
result.inventoryVolumesPositive = all([compMixerVL, outletChamberVL, ...
    cegrPipeVolumeL] > 0);
result.coolingGeometryPositive = coolantTubeD > 0 && totalRadiatorAirArea > 0;
result.passed = result.compressorEnoughForNominal && ...
    result.cegrLowValveSmallButNonzero && ...
    result.cegrMaxValveNotLargerThanPipe && ...
    result.inventoryVolumesPositive && result.coolingGeometryPositive;
end

function readiness = assessA8Readiness(audit)
readiness = struct();
readiness.a7CanClose = audit.parameterIsolation.passed && ...
    audit.externalCaseGuard.passed && ...
    audit.structure.platformMinimumPassed && ...
    audit.parameterMatching.passed;
readiness.mustEnterA8BeforeBenchOrVehicleConfig = ...
    ~isempty(audit.structure.a8Gaps);
readiness.nextPhase = "A8";
if ~readiness.a7CanClose
    readiness.nextPhase = "A7_fix";
end
readiness.gaps = audit.structure.a8Gaps;
end

function dispAudit(audit)
fprintf('\nRoute A A7 platform audit\n');
fprintf('  model=%s\n', audit.model);
fprintf('  timestamp=%s\n', audit.timestamp);
fprintf('\nParameter isolation\n');
fprintf('  layer=%s layer_ok=%d external_case_enabled=%d default_data_load=%d passed=%d\n', ...
    audit.parameterIsolation.layer, audit.parameterIsolation.layerOk, ...
    audit.parameterIsolation.externalCaseEnabled, ...
    audit.parameterIsolation.defaultScriptReadsTables, ...
    audit.parameterIsolation.passed);
fprintf('  external_case_guard=%d error_id=%s\n', ...
    audit.externalCaseGuard.passed, audit.externalCaseGuard.errorId);
fprintf('\nStructure sufficiency\n');
fprintf('  top_blocks_present=%d/%d oxygen_blocks_present=%d/%d connections_ok=%d minimum_passed=%d\n', ...
    nnz(audit.structure.requiredTopBlockPresent), ...
    numel(audit.structure.requiredTopBlockPresent), ...
    nnz(audit.structure.oxygenBlockPresent), ...
    numel(audit.structure.oxygenBlockPresent), ...
    audit.structure.requiredConnectionsOk, ...
    audit.structure.platformMinimumPassed);
fprintf('  a8_gaps=%s\n', strjoin(audit.structure.a8Gaps.', ', '));
fprintf('\nCoarse parameter matching\n');
fprintf('  nominal_power_kW=%.3g rough_limit_power_kW=%.3g design_air_kg_s=%.4g comp_max_kg_s=%.4g margin=%.3g\n', ...
    audit.parameterMatching.nominalDesignPowerW / 1000, ...
    audit.parameterMatching.roughLimitPowerW / 1000, ...
    audit.parameterMatching.designAirDemandKgSAtLambda2, ...
    audit.parameterMatching.maxCompressorMapMdotKgS, ...
    audit.parameterMatching.compressorAirDemandMargin);
fprintf('  cegr_pipe_D_m=%.4g pipe_volume_L=%.4g low_valve_to_pipe=%.4g max_valve_to_pipe=%.4g\n', ...
    audit.parameterMatching.cegrPipeDiameterM, ...
    audit.parameterMatching.cegrPipeVolumeL, ...
    audit.parameterMatching.cegrLowValveToPipeArea, ...
    audit.parameterMatching.cegrMaxValveToPipeArea);
fprintf('  mixer_V_L=%.4g outlet_chamber_V_L=%.4g radiator_air_area_m2=%.4g passed=%d\n', ...
    audit.parameterMatching.compInletMixerVolumeL, ...
    audit.parameterMatching.cathodeOutletChamberVolumeL, ...
    audit.parameterMatching.radiatorAirAreaM2, ...
    audit.parameterMatching.passed);
fprintf('\nA7 result\n');
fprintf('  passed=%d a7_can_close=%d next_phase=%s must_enter_a8_before_variants=%d\n', ...
    audit.passed, audit.a8Readiness.a7CanClose, ...
    audit.a8Readiness.nextPhase, ...
    audit.a8Readiness.mustEnterA8BeforeBenchOrVehicleConfig);
end

function value = getWorkspaceValue(modelWorkspace, name, fallback)
value = fallback;
try
    value = modelWorkspace.getVariable(name);
catch
end
end

function blocks = findBlocksByName(scope, name, maxDepth)
blocks = find_system(scope, 'SearchDepth', maxDepth, ...
    'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
    'MatchFilter', @Simulink.match.allVariants, 'Name', char(name));
end

function tf = hasAnyNamedBlock(model, names)
tf = false;
for k = 1:numel(names)
    matches = find_system(model, 'LookUnderMasks', 'all', ...
        'FollowLinks', 'on', 'MatchFilter', @Simulink.match.allVariants, ...
        'Regexp', 'on', 'Name', char(names(k)));
    if ~isempty(matches)
        tf = true;
        return;
    end
end
end

function tf = hasAnySignal(model, names)
tf = false;
lineHandles = find_system(model, 'FindAll', 'on', 'Type', 'line');
for k = 1:numel(lineHandles)
    lineName = string(get_param(lineHandles(k), 'Name'));
    if any(lineName == names)
        tf = true;
        return;
    end
end
end

function tf = hasRequiredCegrConnections(paths)
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
    connected = allPortsConnected([ ...
        phResistance.RConn(1), phChamber.LConn(3), ...
        phChamber.LConn(4), phExhaustSensor.LConn(1), ...
        phChamber.LConn(5), phEgrSensor.LConn(1), ...
        phEgrSensor.RConn(4), phEgrValve.LConn(1), ...
        phEgrValve.RConn(1), phEgrPipe.LConn(1), ...
        phEgrPipe.RConn(1), phOxygen.LConn(2)]);
catch
    connected = false;
end
tf = connected;
end

function tf = allPortsConnected(portHandles)
tf = true;
for k = 1:numel(portHandles)
    tf = tf && get_param(portHandles(k), 'Line') ~= -1;
end
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

function restoreFolderAndModel(oldDir, model)
cd(oldDir);
if bdIsLoaded(model)
    close_system(model, 0);
end
end
