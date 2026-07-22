% Route A Stage 1 normal-operation constant-current cEGR ratio matrix.
%
% This matrix keeps the cEGR topology enabled and starts every case from
% the same saved platform_default Simulink operating point.  It therefore
% compares time-aligned tail statistics instead of treating an anode-purge
% periodic system as an absolutely static operating point.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
routeA_matrix_cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));

cfg = matrixConfig(modelDir);
[cases, caseOutputs] = runMatrixCase(model, modelFile, modelDir, cfg, ...
    cfg.targetRatios(1));
for idx = 2:numel(cfg.targetRatios)
    [cases(idx), caseOutputs(idx)] = runMatrixCase(model, modelFile, modelDir, cfg, ...
        cfg.targetRatios(idx));
end

matrix = summarizeMatrix(cases, cfg);
matrix.waterLedger = routeA_stage1_water_ledger_from_outputs( ...
    caseOutputs, waterLedgerConfig(cfg, model));
matrix.waterLedgerPassed = matrix.waterLedger.auditPassed;
matrix.passed = matrix.allCasesPassed && matrix.waterLedgerPassed;
assignin('base', 'routeA_stage1_cegr_ratio_matrix', matrix);
assignin('base', 'routeA_stage1_water_ledger', matrix.waterLedger);
displayMatrix(matrix);
clear caseOutputs;
clear routeA_matrix_cleanup;

function cfg = matrixConfig(modelDir)
initialStateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
loaded = load(initialStateFile, 'routeA_initial_metadata_current');
if ~isfield(loaded, 'routeA_initial_metadata_current')
    error('RouteA:InvalidPlatformDefaultInitialState', ...
        'The platform_default Current initial-state metadata is unavailable.');
end

metadata = loaded.routeA_initial_metadata_current;
requiredFields = {'snapshotTimeS', 'targetCurrentA', ...
    'currentDensity_A_cm2', 'purgePeriodS', 'cegrTopologyEnabled', ...
    'cegrValveModeId', 'egrReferenceKind'};
if ~builtin('all', isfield(metadata, requiredFields))
    error('RouteA:InvalidPlatformDefaultInitialStateMetadata', ...
        'The platform_default initial-state metadata is incomplete.');
end
if ~metadata.cegrTopologyEnabled
    error('RouteA:InitialStateTopologyMismatch', ...
        'The saved state must retain the CEGR-enabled topology.');
end
if metadata.cegrValveModeId ~= 1 || ...
        string(metadata.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:InitialStateModeMismatch', ...
        'The matrix requires a mode-1 zero-target formal initial state.');
end

cfg = struct();
cfg.initialStateMetadata = metadata;
cfg.initialStateFile = initialStateFile;
cfg.researchStartTime_s = metadata.snapshotTimeS;
cfg.researchDuration_s = 600;
cfg.modelStopTime_s = cfg.researchStartTime_s + cfg.researchDuration_s;
cfg.tailLogicalWindow_s = [540, 600];
cfg.tailWindow_s = cfg.researchStartTime_s + cfg.tailLogicalWindow_s;
cfg.targetCurrentA = metadata.targetCurrentA;
cfg.targetAirEquivalentOer = 3;
cfg.targetRatios = [0, 0.10, 0.30];
cfg.currentTrackingTolerance_A = 5e-3;
cfg.lambdaLowerBound = 1;
cfg.stackCells = 400;
cfg.molarMass_kg_mol = [0.0280134, 0.0319988, 0.00201588, 0.01801528];
cfg.tailSpan = struct( ...
    'egrRatio', 0.002, ...
    'egrMdot_kg_s', 5e-4, ...
    'freshAirApprox_kg_s', 5e-4, ...
    'inletTotalMdot_kg_s', 5e-4, ...
    'stackCurrent_A', 0.5, ...
    'stackVoltage_V', 0.5, ...
    'stackPower_kW', 0.05, ...
    'stackTemperature_C', 0.5, ...
    'compressorMdot_kg_s', 5e-4, ...
    'compressorTemperature_K', 0.5, ...
    'rhCaIn', 0.02, ...
    'rhCaOut', 0.02, ...
    'waterSeparator', 5e-5, ...
    'lambdaCaIn', 0.02, ...
    'inletO2MassFraction', 0.002);
end

function [result, caseOutput] = runMatrixCase(model, modelFile, modelDir, cfg, targetRatio)
resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
routeA_apply_constant_current_step(model, ...
    cfg.initialStateMetadata.targetCurrentA, cfg.targetCurrentA);

in = Simulink.SimulationInput(model);
[in, initialStateMetadata] = routeA_attach_platform_default_initial_state( ...
    in, model, modelDir, cfg.initialStateFile, 'Current');
routeA_mark_observability_signals(model);
in = in.setModelParameter( ...
    'StopTime', sprintf('%.16g', cfg.modelStopTime_s), ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all');
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_target_oer', cfg.targetAirEquivalentOer, ...
    'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 0, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in', targetRatio, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
    [cfg.researchStartTime_s, targetRatio; ...
    cfg.modelStopTime_s, targetRatio], 'Workspace', model);

out = sim(in);
result = collectCaseResult(out, model, cfg, targetRatio);
result.initialState = initialStateMetadata;
result.modeId = 1;
caseOutput = struct('targetRatio', targetRatio, 'out', out, ...
    'initialState', initialStateMetadata, 'modeId', 1, ...
    'targetAirEquivalentOer', cfg.targetAirEquivalentOer);
end

function result = collectCaseResult(out, model, cfg, targetRatio)
logsout = out.logsout;
ratio = loggedTimeseries(logsout, 'routeA_egr_ratio_comp_in');
area = loggedTimeseries(logsout, 'routeA_egr_valve_area_cmd');
pUp = loggedTimeseries(logsout, 'routeA_p_egr_valve_up');
pDown = loggedTimeseries(logsout, 'routeA_p_egr_valve_down');
compMdot = magnitudeTimeseries( ...
    loggedTimeseries(logsout, 'routeA_mdot_comp_inlet'));
compP = loggedTimeseries(logsout, 'routeA_p_comp_inlet');
compT = loggedTimeseries(logsout, 'routeA_T_comp_inlet');
compCmd = loggedTimeseries(logsout, 'routeA_compressor_cmd');
compRpm = loggedTimeseries(logsout, 'routeA_compressor_rpm');
egrMdot = magnitudeTimeseries(loggedTimeseries(logsout, 'routeA_egr_mdot'));
stackCurrent = loggedTimeseries(logsout, 'routeA_stack_current_A');
stackVoltage = loggedTimeseries(logsout, 'routeA_stack_voltage_V');
stackPower = timeseries( ...
    stackCurrent.Data .* stackVoltage.Data * 1e-3, stackCurrent.Time);
stackTemperature = loggedTimeseries(logsout, 'routeA_stack_temperature_C');
rhIn = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_in', 'routeA_RH_ca_in_ts'), 'routeA_RH_ca_in');
rhOut = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_out', 'routeA_RH_ca_out_ts'), 'routeA_RH_ca_out');
waterSeparator = outputTimeseries(out, logsout, 'routeA_m_water_sep', ...
    'routeA_m_water_sep_ts');

speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
[~, speciesTotal, speciesMassFraction] = inletSpeciesMetrics(speciesMdot);
inletTotalMdot = timeseries(speciesTotal, speciesMdot.Time);
inletO2MassFraction = timeseries(speciesMassFraction(:, 2), ...
    speciesMdot.Time);
lambdaCaIn = inletOxygenStoich(speciesMdot, stackCurrent, cfg.stackCells);

egrAtCompressorTime = interp1(egrMdot.Time, egrMdot.Data, ...
    compMdot.Time, 'linear', 'extrap');
freshAirApprox = timeseries(compMdot.Data - egrAtCompressorTime, ...
    compMdot.Time);
pressureDeltaMPa = timeseries((pUp.Data - pDown.Data) * 1e-6, ...
    pUp.Time);
mw = get_param(model, 'ModelWorkspace');
maxValveArea = mw.getVariable('cegr_valve_max_area');
areaFraction = timeseries(area.Data / maxValveArea, area.Time);

tail = struct();
tail.egrRatio = windowStats(ratio, cfg.tailWindow_s);
tail.egrMdot_kg_s = windowStats(egrMdot, cfg.tailWindow_s);
tail.freshAirApprox_kg_s = windowStats(freshAirApprox, cfg.tailWindow_s);
tail.inletTotalMdot_kg_s = windowStats(inletTotalMdot, cfg.tailWindow_s);
tail.stackCurrent_A = windowStats(stackCurrent, cfg.tailWindow_s);
tail.stackVoltage_V = windowStats(stackVoltage, cfg.tailWindow_s);
tail.stackPower_kW = windowStats(stackPower, cfg.tailWindow_s);
tail.stackTemperature_C = windowStats(stackTemperature, cfg.tailWindow_s);
tail.compressorMdot_kg_s = windowStats(compMdot, cfg.tailWindow_s);
tail.compressorPressure_Pa = windowStats(compP, cfg.tailWindow_s);
tail.compressorTemperature_K = windowStats(compT, cfg.tailWindow_s);
tail.compressorCommand = windowStats(compCmd, cfg.tailWindow_s);
tail.compressorRpm = windowStats(compRpm, cfg.tailWindow_s);
tail.egrValveDeltaP_MPa = windowStats(pressureDeltaMPa, cfg.tailWindow_s);
tail.egrValveAreaFraction = windowStats(areaFraction, cfg.tailWindow_s);
tail.rhCaIn = windowStats(rhIn, cfg.tailWindow_s);
tail.rhCaOut = windowStats(rhOut, cfg.tailWindow_s);
tail.waterSeparator = windowStats(waterSeparator, cfg.tailWindow_s);
tail.lambdaCaIn = windowStats(lambdaCaIn, cfg.tailWindow_s);
tail.inletO2MassFraction = windowStats(inletO2MassFraction, ...
    cfg.tailWindow_s);

operationalWindow = [cfg.researchStartTime_s, cfg.modelStopTime_s];
currentError = max(abs(windowData(stackCurrent, operationalWindow) - ...
    cfg.targetCurrentA));
lambdaOperational = windowData(lambdaCaIn, operationalWindow);
result = struct();
result.targetRatio = targetRatio;
result.modeId = 1;
result.researchStartModelTime_s = cfg.researchStartTime_s;
result.researchDuration_s = cfg.researchDuration_s;
result.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
result.tailModelWindow_s = cfg.tailWindow_s;
result.tail = tail;
result.tailMeans = tailMeans(tail);
result.actualRatio = tail.egrRatio.mean;
result.targetError = result.actualRatio - targetRatio;
result.targetTolerance = targetTolerance(targetRatio);
result.currentTrackingMaxError_A = currentError;
result.lambdaOperationalMin = min(lambdaOperational);
result.finiteTail = tailFinite(tail);
result.trackingPassed = abs(result.targetError) <= result.targetTolerance;
result.currentPassed = currentError <= cfg.currentTrackingTolerance_A;
result.lambdaPassed = result.lambdaOperationalMin > cfg.lambdaLowerBound;
result.pressureDirectionPassed = targetRatio == 0 || ...
    tail.egrValveDeltaP_MPa.mean > 0;
result.areaPassed = tail.egrValveAreaFraction.minimum >= 0 && ...
    tail.egrValveAreaFraction.maximum < 1 - 1e-6;
result.tailStable = tailStabilityPassed(tail, cfg);
result.passed = result.finiteTail && result.trackingPassed && ...
    result.currentPassed && result.lambdaPassed && ...
    result.pressureDirectionPassed && result.areaPassed && ...
    result.tailStable;
end

function matrix = summarizeMatrix(cases, cfg)
matrix = struct();
matrix.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
matrix.model = string(cfg.initialStateMetadata.model);
matrix.initialState = cfg.initialStateMetadata;
matrix.targetRatios = cfg.targetRatios;
matrix.modeId = 1;
matrix.researchDuration_s = cfg.researchDuration_s;
matrix.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
matrix.tailDefinition = 'mean/std/span over [540,600) s after saved operating point';
matrix.referenceDefinition = ...
    'same mode-1 initial operating point, same topology, zero-target near-zero cEGR';
matrix.cases = cases;
referenceMeans = cases(1).tailMeans;
for idx = 1:numel(cases)
    matrix.cases(idx).deltaToReference = meanDelta( ...
        cases(idx).tailMeans, referenceMeans);
end
matrix.allCasesPassed = builtin('all', [matrix.cases.passed]);
matrix.passed = matrix.allCasesPassed;
end

function cfg = waterLedgerConfig(matrixCfg, model)
cfg = struct();
cfg.model = model;
cfg.initialStateMetadata = matrixCfg.initialStateMetadata;
cfg.researchStartTime_s = matrixCfg.researchStartTime_s;
cfg.researchDuration_s = matrixCfg.researchDuration_s;
cfg.modelStopTime_s = matrixCfg.modelStopTime_s;
cfg.tailLogicalWindow_s = matrixCfg.tailLogicalWindow_s;
cfg.tailWindow_s = matrixCfg.tailWindow_s;
cfg.targetCurrentA = matrixCfg.targetCurrentA;
cfg.currentTrackingTolerance_A = matrixCfg.currentTrackingTolerance_A;
cfg.targetAirEquivalentOer = matrixCfg.targetAirEquivalentOer;
cfg.targetRatios = [0, 0.30];
cfg.meaClosureTolerance_kg_s = 1e-6;
cfg.localGasBalanceAbsTolerance_kg = 1e-6;
cfg.localGasBalanceRelativeTolerance = 1e-3;
cfg.systemGasBalanceAbsTolerance_kg = 5e-6;
cfg.systemGasBalanceRelativeTolerance = 5e-5;
cfg.species = struct('n2', 1, 'o2', 2, 'h2', 3, 'h2o', 4);
end

function displayMatrix(matrix)
cases = matrix.cases;
summary = table( ...
    [cases.targetRatio].', ...
    [cases.actualRatio].', ...
    [cases.targetError].', ...
    arrayfun(@(c) c.tailMeans.stackVoltage_V, cases).', ...
    arrayfun(@(c) c.deltaToReference.stackVoltage_V, cases).', ...
    arrayfun(@(c) c.tailMeans.stackPower_kW, cases).', ...
    arrayfun(@(c) c.deltaToReference.stackPower_kW, cases).', ...
    arrayfun(@(c) c.tailMeans.stackTemperature_C, cases).', ...
    arrayfun(@(c) c.tailMeans.lambdaCaIn, cases).', ...
    arrayfun(@(c) c.tailMeans.inletO2MassFraction, cases).', ...
    [cases.passed].', ...
    'VariableNames', {'targetRatio','actualRatio','targetError', ...
    'voltage_V','deltaVoltage_V','power_kW','deltaPower_kW', ...
    'stackTemperature_C','lambdaCaIn','inletO2MassFraction','passed'});
fprintf('\nRoute A Stage 1 constant-current cEGR ratio matrix\n');
fprintf('  initial phase: %s | t0=%.6f s | I=%.6g A | tail=[%.0f,%.0f) s\n', ...
    matrix.initialState.normalOperationPhase, ...
    matrix.initialState.snapshotTimeS, ...
    matrix.initialState.targetCurrentA, ...
    matrix.tailLogicalWindow_s(1), matrix.tailLogicalWindow_s(2));
disp(summary);
for idx = 1:numel(cases)
    value = cases(idx);
    fprintf(['  target=%.2f: stable=%d tracking=%d current=%d lambda=%d ', ...
        'pressure=%d area=%d finite=%d | V span/std=%.6g/%.6g V\n'], ...
        value.targetRatio, value.tailStable, value.trackingPassed, ...
        value.currentPassed, value.lambdaPassed, ...
        value.pressureDirectionPassed, value.areaPassed, value.finiteTail, ...
        value.tail.stackVoltage_V.span, value.tail.stackVoltage_V.std);
end
fprintf('  water-ledger passed=%d | matrix passed=%d\n', ...
    matrix.waterLedgerPassed, matrix.passed);
end

function passed = tailStabilityPassed(tail, cfg)
passed = tail.egrRatio.span <= cfg.tailSpan.egrRatio && ...
    tail.egrMdot_kg_s.span <= cfg.tailSpan.egrMdot_kg_s && ...
    tail.freshAirApprox_kg_s.span <= cfg.tailSpan.freshAirApprox_kg_s && ...
    tail.inletTotalMdot_kg_s.span <= cfg.tailSpan.inletTotalMdot_kg_s && ...
    tail.stackCurrent_A.span <= cfg.tailSpan.stackCurrent_A && ...
    tail.stackVoltage_V.span <= cfg.tailSpan.stackVoltage_V && ...
    tail.stackPower_kW.span <= cfg.tailSpan.stackPower_kW && ...
    tail.stackTemperature_C.span <= cfg.tailSpan.stackTemperature_C && ...
    tail.compressorMdot_kg_s.span <= cfg.tailSpan.compressorMdot_kg_s && ...
    tail.compressorTemperature_K.span <= cfg.tailSpan.compressorTemperature_K && ...
    tail.rhCaIn.span <= cfg.tailSpan.rhCaIn && ...
    tail.rhCaOut.span <= cfg.tailSpan.rhCaOut && ...
    tail.waterSeparator.span <= cfg.tailSpan.waterSeparator && ...
    tail.lambdaCaIn.span <= cfg.tailSpan.lambdaCaIn && ...
    tail.inletO2MassFraction.span <= cfg.tailSpan.inletO2MassFraction;
end

function tolerance = targetTolerance(targetRatio)
if targetRatio == 0
    tolerance = 1e-4;
else
    tolerance = max(0.002, 0.10 * targetRatio);
end
end

function means = tailMeans(tail)
names = fieldnames(tail);
means = struct();
for idx = 1:numel(names)
    name = names{idx};
    means.(name) = tail.(name).mean;
end
end

function delta = meanDelta(later, earlier)
names = fieldnames(later);
delta = struct();
for idx = 1:numel(names)
    name = names{idx};
    delta.(name) = later.(name) - earlier.(name);
end
end

function passed = tailFinite(tail)
names = fieldnames(tail);
passed = true;
for idx = 1:numel(names)
    if tail.(names{idx}).nonfiniteCount ~= 0
        passed = false;
        return;
    end
end
end

function stats = windowStats(signal, window)
values = windowData(signal, window);
finiteValues = values(isfinite(values));
stats = struct();
stats.start_s = window(1);
stats.end_s = window(2);
stats.sampleCount = numel(values);
stats.nonfiniteCount = sum(~isfinite(values));
if isempty(finiteValues)
    stats.mean = NaN;
    stats.std = NaN;
    stats.span = Inf;
    stats.minimum = NaN;
    stats.maximum = NaN;
    return;
end
stats.mean = mean(finiteValues);
stats.std = std(finiteValues);
stats.span = max(finiteValues) - min(finiteValues);
stats.minimum = min(finiteValues);
stats.maximum = max(finiteValues);
end

function values = windowData(signal, window)
mask = signal.Time >= window(1) & signal.Time < window(2);
values = signal.Data(mask);
values = values(:);
if isempty(values)
    error('RouteA:Stage1MatrixEmptyWindow', ...
        'No samples were found in the requested statistics window.');
end
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:Stage1MatrixMissingLoggedSignal', ...
        'The required logged signal is unavailable: %s.', name);
end
signal = element.Values;
end

function signal = outputTimeseries(out, logsout, logName, outputName)
if datasetHasElement(logsout, logName)
    element = logsout.get(logName);
    if ~isempty(element) && ~isempty(element.Values)
        signal = element.Values;
        return;
    end
end
signal = out.get(outputName);
end

function present = datasetHasElement(dataset, name)
present = false;
try
    names = dataset.getElementNames;
    present = any(strcmp(names, name));
catch
end
end

function signal = magnitudeTimeseries(signal)
signal = timeseries(abs(signal.Data), signal.Time);
end

function rh = waterRelativeHumidity(signal, signalName)
data = compositionMatrix(signal, signalName);
if size(data, 2) < 4
    error('RouteA:Stage1MatrixRelativeHumidityShape', ...
        'The water relative-humidity component is unavailable: %s.', ...
        signalName);
end
rh = timeseries(data(:, 4), signal.Time);
end

function lambda = inletOxygenStoich(speciesMdot, stackCurrent, stackCells)
species = compositionMatrix(speciesMdot, 'routeA_mdot_species_ca_in');
if size(species, 2) < 2
    error('RouteA:Stage1MatrixSpeciesFlowShape', ...
        'The cathode inlet species-flow signal has fewer than two components.');
end
current = stackCurrent.Data(:);
currentAtSpeciesTime = interp1(stackCurrent.Time, current, ...
    speciesMdot.Time, 'linear', 'extrap');
o2SupplyMolS = abs(species(:, 2)) / 0.0319988;
o2ConsumptionMolS = stackCells * abs(currentAtSpeciesTime) / ...
    (4 * 96485.33212);
lambda = timeseries(o2SupplyMolS ./ o2ConsumptionMolS, speciesMdot.Time);
end

function [species, total, massFraction] = inletSpeciesMetrics(speciesMdot)
species = abs(compositionMatrix(speciesMdot, 'routeA_mdot_species_ca_in'));
total = sum(species, 2);
massFraction = species ./ total;
end

function data = compositionMatrix(signal, signalName)
data = squeeze(signal.Data);
if isvector(data)
    if isscalar(signal.Time)
        data = reshape(data, 1, []);
    else
        data = data(:);
    end
end
if size(data, 1) ~= numel(signal.Time)
    data = data.';
end
if size(data, 1) ~= numel(signal.Time)
    error('RouteA:Stage1MatrixCompositionShape', ...
        'Unexpected signal shape for %s.', signalName);
end
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
end

function refreshModelWorkspace(model)
mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
end
