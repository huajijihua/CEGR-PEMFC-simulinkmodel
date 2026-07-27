function summary = run_routeA_stage1_high_cegr_valve_area_sensitivity( ...
    cegrValveMaxAreas_m2)
% Study high-load cEGR valve-area capacity with compatible temporary states.
%
% Each case assigns one explicit cegr_valve_max_area value. A reusable normal-operation
% precondition is generated under that compiled parameter configuration, then
% the high-load target is applied from the resulting temporary operating point.
% The formal platform_default state file and model file are never overwritten.

if nargin < 1 || isempty(cegrValveMaxAreas_m2)
    cegrValveMaxAreas_m2 = [ ...
        9.81747704245e-5, 1.96349540849e-4, ...
        4.90873852123e-4, 9.81747704245e-4];
end
validateattributes(cegrValveMaxAreas_m2, {'numeric'}, ...
    {'vector', 'real', 'positive', 'finite'});

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
baseCfg = studyConfig(model);
results = repmat(emptyResult(), numel(cegrValveMaxAreas_m2), 1);
for idx = 1:numel(cegrValveMaxAreas_m2)
    results(idx) = runAreaValue( ...
        model, modelFile, baseCfg, cegrValveMaxAreas_m2(idx));
end

summary = struct();
summary.timestamp = string(datetime('now', 'Format', ...
    'yyyy-MM-dd HH:mm:ss'));
summary.model = string(model);
summary.studyKind = "parameter-consistent high-load cEGR capacity sensitivity";
summary.parameterName = "cegr_valve_max_area";
summary.cegrValveMaxAreas_m2 = cegrValveMaxAreas_m2(:).';
summary.currentDensity_A_cm2 = baseCfg.currentDensity_A_cm2;
summary.targetCurrentA = baseCfg.targetCurrentA;
summary.airControlBasis = ...
    "target_total_compressor_mdot_from_fresh_air_equivalent_oer";
summary.targetAirEquivalentOer = baseCfg.targetAirEquivalentOer;
summary.targetRatio = baseCfg.targetRatio;
summary.researchDuration_s = baseCfg.researchDuration_s;
summary.tailLogicalWindow_s = baseCfg.tailLogicalWindow_s;
summary.preconditionDefinition = ...
    ['temporary j=0.1 A/cm^2, fresh-air-equivalent OER=3, ', ...
    'zero-cEGR, phase-aligned normal state'];
summary.results = results;
summary.summaryTable = buildSummaryTable(results);
summary.allSimulationsCompleted = builtin('all', [results.simCompleted]);
summary.allPreconditionsPassed = builtin('all', [results.preconditionPassed]);
assignin('base', 'routeA_stage1_high_cegr_valve_area_sensitivity', summary);
assignin('base', 'routeA_stage1_high_cegr_valve_area_sensitivity_table', ...
    summary.summaryTable);
displaySummary(summary);
clear cleanup;
end

function cfg = studyConfig(model)
mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
parameterLayer = string(mw.getVariable('routeA_parameter_layer'));
externalCaseEnabled = logical(mw.getVariable( ...
    'routeA_external_case_enabled'));
if parameterLayer ~= "platform_default" || externalCaseEnabled
    error('RouteA:HighValveSensitivityParameterBoundary', ...
        'The sensitivity requires platform_default with external_case disabled.');
end
stackArea = mw.getVariable('stack_area');
stackCells = mw.getVariable('stack_num_cells');
validateattributes(stackArea, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(stackCells, {'numeric'}, {'scalar', 'positive', 'finite'});

cfg = struct();
cfg.currentDensity_A_cm2 = 1.2;
cfg.targetCurrentA = cfg.currentDensity_A_cm2 * stackArea;
cfg.targetAirEquivalentOer = 2;
cfg.targetRatio = 0.30;
cfg.stackCells = stackCells;
cfg.researchDuration_s = 600;
cfg.tailLogicalWindow_s = [540, 600];
cfg.commandStepOffset_s = 0.5;
cfg.currentTrackingTolerance_A = 5e-3;
cfg.faradayConstant_C_mol = 96485.33212;
cfg.molarMass_kg_mol = [0.0280134, 0.0319988, 0.00201588, 0.01801528];
cfg.purgeDropSlope_1_s = -0.02;
cfg.gas = struct( ...
    'n2Index', 1, 'o2Index', 2, 'h2oIndex', 4, ...
    'absoluteResidualTolerance_kg_s', 5e-4, ...
    'relativeResidualTolerance', 0.05);
end

function result = runAreaValue(model, modelFile, cfg, cegrValveMaxArea_m2)
result = emptyResult();
result.cegrValveMaxArea_m2 = cegrValveMaxArea_m2;
parameterValues = struct('cegr_valve_max_area', cegrValveMaxArea_m2);
try
    [initialState, initialMetadata, preconditionAudit] = ...
        routeA_prepare_parameter_consistent_initial_state( ...
        model, modelFile, parameterValues, struct());
    result.precondition = preconditionAudit;
    result.initialState = initialMetadata;
    result.preconditionPassed = true;
    result = runHighCase(model, cfg, initialState, initialMetadata, result);
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = string(ME.message);
    if ~isempty(ME.stack)
        result.errorLocation = string(ME.stack(1).name) + ":" + ...
            string(ME.stack(1).line);
    end
end
end

function result = runHighCase(model, cfg, initialState, initialMetadata, result)
mw = get_param(model, 'ModelWorkspace');
effectiveMaxArea = mw.getVariable('cegr_valve_max_area');
if abs(effectiveMaxArea - result.cegrValveMaxArea_m2) > ...
        1e-12 * max(1, abs(result.cegrValveMaxArea_m2))
    error('RouteA:HighValveSensitivityValueLost', ...
        'The intended cEGR valve maximum area is no longer active.');
end

researchStartTime_s = initialMetadata.snapshotTimeS;
commandStepTime_s = researchStartTime_s + cfg.commandStepOffset_s;
stopTime_s = researchStartTime_s + cfg.researchDuration_s;
tailWindow_s = researchStartTime_s + cfg.tailLogicalWindow_s;
routeA_apply_constant_current_step(model, initialMetadata.targetCurrentA, ...
    cfg.targetCurrentA, commandStepTime_s);
routeA_mark_observability_signals(model);

in = Simulink.SimulationInput(model);
in = in.setInitialState(initialState);
in = in.setModelParameter( ...
    'StopTime', sprintf('%.16g', stopTime_s), ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all');
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_target_oer', cfg.targetAirEquivalentOer, ...
    'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 1, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in', ...
    cfg.targetRatio, 'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
    [researchStartTime_s, 0; ...
    commandStepTime_s - 1e-3, 0; ...
    commandStepTime_s, cfg.targetRatio; ...
    stopTime_s, cfg.targetRatio], 'Workspace', model);

out = sim(in);
result = collectResult(out, model, cfg, tailWindow_s, ...
    researchStartTime_s + 1, stopTime_s, result);
end

function result = collectResult( ...
    out, model, cfg, tailWindow_s, currentStart_s, stopTime_s, result)
logsout = out.logsout;
ratio = loggedTimeseries(logsout, 'routeA_egr_ratio_comp_in');
area = loggedTimeseries(logsout, 'routeA_egr_valve_area_cmd');
pUp = loggedTimeseries(logsout, 'routeA_p_egr_valve_up');
pDown = loggedTimeseries(logsout, 'routeA_p_egr_valve_down');
egrMdot = magnitudeTimeseries(loggedTimeseries(logsout, 'routeA_egr_mdot'));
compMdot = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_mdot_comp_inlet'));
compCmd = loggedTimeseries(logsout, 'routeA_compressor_cmd');
compRpm = loggedTimeseries(logsout, 'routeA_compressor_rpm');
stackCurrent = loggedTimeseries(logsout, 'routeA_stack_current_A');
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
lambda = inletOxygenStoich(speciesMdot, stackCurrent, cfg.stackCells, ...
    cfg.faradayConstant_C_mol);

areaFraction = timeseries(area.Data(:) / result.cegrValveMaxArea_m2, ...
    area.Time);
pDownAtUp = interp1(pDown.Time, pDown.Data(:), pUp.Time, ...
    'linear', 'extrap');
pressureDelta = timeseries((pUp.Data(:) - pDownAtUp) * 1e-6, pUp.Time);

tail = struct();
tail.egrRatio = windowStats(ratio, tailWindow_s);
tail.egrMdot_kg_s = windowStats(egrMdot, tailWindow_s);
tail.egrValveAreaFraction = windowStats(areaFraction, tailWindow_s);
tail.egrValveDeltaP_MPa = windowStats(pressureDelta, tailWindow_s);
tail.compressorMdot_kg_s = windowStats(compMdot, tailWindow_s);
tail.compressorCommand = windowStats(compCmd, tailWindow_s);
tail.compressorRpm = windowStats(compRpm, tailWindow_s);
tail.stackCurrent_A = windowStats(stackCurrent, tailWindow_s);
tail.lambdaCaIn = windowStats(lambda, tailWindow_s);

gasCfg = cfg;
gasCfg.tailWindow_s = tailWindow_s;
gasClosure = routeA_stage1_cathode_gas_closure_from_outputs(out, model, gasCfg);
purge = purgeStats(out, model, cfg, tailWindow_s);
currentValues = windowData(stackCurrent, [currentStart_s, stopTime_s]);

result.simCompleted = true;
result.tailWindow_s = tailWindow_s;
result.tail = tail;
result.actualRatio = tail.egrRatio.mean;
result.targetError = result.actualRatio - cfg.targetRatio;
result.currentTrackingMaxError_A = max(abs(currentValues - cfg.targetCurrentA));
result.valveAreaFractionMax = tail.egrValveAreaFraction.maximum;
result.valveDeltaP_MPa = tail.egrValveDeltaP_MPa.mean;
result.lambdaTailMean = tail.lambdaCaIn.mean;
result.lambdaTailMin = tail.lambdaCaIn.minimum;
result.gasClosure = gasClosure;
result.gasClosurePassed = gasClosure.passed;
result.purge = purge;
result.tailPurgeFree = purge.tailEventCount == 0;
result.finiteTail = tailFinite(tail);
result.currentPassed = result.currentTrackingMaxError_A <= ...
    cfg.currentTrackingTolerance_A;
result.areaSaturated = result.valveAreaFractionMax >= 1 - 1e-6;
result.trackingPassed = abs(result.targetError) <= ...
    max(0.002, 0.10 * cfg.targetRatio);
result.passed = result.preconditionPassed && result.simCompleted && ...
    result.finiteTail && result.currentPassed && result.gasClosurePassed && ...
    result.tailPurgeFree && result.trackingPassed;
end

function tableOut = buildSummaryTable(results)
count = numel(results);
cegrValveMaxArea = NaN(count, 1);
snapshotTime = NaN(count, 1);
actualRatio = NaN(count, 1);
targetError = NaN(count, 1);
areaFractionMax = NaN(count, 1);
deltaP = NaN(count, 1);
lambdaTailMean = NaN(count, 1);
currentError = NaN(count, 1);
preconditionPassed = false(count, 1);
gasClosurePassed = false(count, 1);
simCompleted = false(count, 1);
passed = false(count, 1);
errorId = strings(count, 1);
for idx = 1:count
    item = results(idx);
    cegrValveMaxArea(idx) = item.cegrValveMaxArea_m2;
    if isstruct(item.initialState) && isfield(item.initialState, 'snapshotTimeS')
        snapshotTime(idx) = item.initialState.snapshotTimeS;
    end
    actualRatio(idx) = item.actualRatio;
    targetError(idx) = item.targetError;
    areaFractionMax(idx) = item.valveAreaFractionMax;
    deltaP(idx) = item.valveDeltaP_MPa;
    lambdaTailMean(idx) = item.lambdaTailMean;
    currentError(idx) = item.currentTrackingMaxError_A;
    preconditionPassed(idx) = item.preconditionPassed;
    gasClosurePassed(idx) = item.gasClosurePassed;
    simCompleted(idx) = item.simCompleted;
    passed(idx) = item.passed;
    errorId(idx) = item.errorId;
end
tableOut = table(cegrValveMaxArea, snapshotTime, actualRatio, ...
    targetError, areaFractionMax, deltaP, lambdaTailMean, currentError, ...
    preconditionPassed, gasClosurePassed, simCompleted, passed, errorId, ...
    'VariableNames', {'cegrValveMaxArea_m2', ...
    'temporaryStateTime_s', 'actualRatio', 'targetError', ...
    'areaFractionMax', 'valveDeltaP_MPa', 'lambdaTailMean', ...
    'currentTrackingMaxError_A', 'preconditionPassed', ...
    'gasClosurePassed', 'simCompleted', 'passed', 'errorId'});
end

function displaySummary(summary)
fprintf('\nRoute A parameter-consistent high-load valve-area sensitivity\n');
fprintf(['  I=%.6g A | air-equivalent OER=%.6g | cEGR target=%.3f | ', ...
    'target duration=%.0f s\n'], summary.targetCurrentA, ...
    summary.targetAirEquivalentOer, summary.targetRatio, ...
    summary.researchDuration_s);
disp(summary.summaryTable);
end

function result = emptyResult()
result = struct('cegrValveMaxArea_m2', NaN, ...
    'initialState', struct(), 'precondition', struct(), ...
    'preconditionPassed', false, 'simCompleted', false, 'errorId', "", ...
    'errorMessage', "", 'errorLocation', "", 'tailWindow_s', NaN(1, 2), ...
    'tail', struct(), 'actualRatio', NaN, 'targetError', NaN, ...
    'currentTrackingMaxError_A', NaN, 'valveAreaFractionMax', NaN, ...
    'valveDeltaP_MPa', NaN, 'lambdaTailMean', NaN, ...
    'lambdaTailMin', NaN, 'gasClosure', struct(), ...
    'gasClosurePassed', false, 'purge', struct(), 'tailPurgeFree', false, ...
    'finiteTail', false, 'currentPassed', false, 'areaSaturated', false, ...
    'trackingPassed', false, 'passed', false);
end

function purge = purgeStats(out, model, cfg, tailWindow_s)
simlog = out.get(get_param(model, 'SimscapeLogName'));
mea = routeA_simscape_log_mea(simlog);
time = mea.x_i_anode.series.time;
anode = seriesMatrix(mea.x_i_anode.series.values('1'), time, ...
    'anode composition');
slope = diff(anode(:, 1)) ./ diff(time(:));
candidate = find(slope < cfg.purgeDropSlope_1_s);
if isempty(candidate)
    eventTimes = zeros(0, 1);
else
    eventIndices = candidate([true; diff(candidate) > 1]) + 1;
    eventTimes = time(eventIndices);
end
tailEvents = eventTimes(eventTimes >= tailWindow_s(1) & ...
    eventTimes < tailWindow_s(2));
purge = struct('eventTimesModel_s', eventTimes(:).', ...
    'tailEventTimesModel_s', tailEvents(:).', ...
    'tailEventCount', numel(tailEvents));
end

function lambda = inletOxygenStoich(speciesMdot, stackCurrent, stackCells, F)
species = abs(seriesMatrix(speciesMdot.Data, speciesMdot.Time, ...
    'cathode inlet species mass flow'));
current = interp1(stackCurrent.Time, stackCurrent.Data(:), ...
    speciesMdot.Time, 'linear', 'extrap');
o2SupplyMolS = species(:, 2) / 0.0319988;
o2ConsumptionMolS = stackCells * abs(current) / (4 * F);
lambda = timeseries(o2SupplyMolS ./ o2ConsumptionMolS, speciesMdot.Time);
end

function stats = windowStats(signal, window)
values = windowData(signal, window);
finiteValues = values(isfinite(values));
stats = struct('mean', NaN, 'std', NaN, 'span', Inf, ...
    'minimum', NaN, 'maximum', NaN, 'sampleCount', numel(values), ...
    'nonfiniteCount', sum(~isfinite(values)));
if ~isempty(finiteValues)
    stats.mean = mean(finiteValues);
    stats.std = std(finiteValues);
    stats.span = max(finiteValues) - min(finiteValues);
    stats.minimum = min(finiteValues);
    stats.maximum = max(finiteValues);
end
end

function values = windowData(signal, window)
mask = signal.Time >= window(1) & signal.Time < window(2);
values = signal.Data(mask);
values = values(:);
if isempty(values)
    error('RouteA:HighValveSensitivityEmptyWindow', ...
        'No signal samples were found in the requested time window.');
end
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:HighValveSensitivityMissingSignal', ...
        'The required logged signal is unavailable: %s.', name);
end
signal = element.Values;
end

function signal = magnitudeTimeseries(signal)
signal = timeseries(abs(signal.Data), signal.Time);
end

function data = seriesMatrix(data, time, signalName)
data = squeeze(data);
if isvector(data)
    if isscalar(time)
        data = reshape(data, 1, []);
    else
        data = data(:);
    end
end
if size(data, 1) ~= numel(time)
    data = data.';
end
if size(data, 1) ~= numel(time)
    error('RouteA:HighValveSensitivitySeriesShape', ...
        'Unexpected signal shape for %s.', signalName);
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
