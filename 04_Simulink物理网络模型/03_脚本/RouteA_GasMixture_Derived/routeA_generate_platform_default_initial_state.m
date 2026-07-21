function metadata = routeA_generate_platform_default_initial_state()
% Generate a mode-1 candidate Route A platform_default operating point.
%
% The candidate is generated at j = 0.1 A/cm^2 with the cEGR topology
% enabled, the Local Restriction Variant selected, and a zero cEGR target.
% It is deliberately written to a temporary candidate file. Promotion to the
% sole formal platform_default file is handled only after full regression.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
initialStateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_candidate_mode1.mat');
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
routeA_initial_state_cleanup = onCleanup(@() ...
    routeA_restore_model_and_folder(model, modelFile, oldDir));

cfg = initializationConfig();
resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');
mw.assignin('routeA_cegr_enabled', true);
mw.assignin('routeA_cegr_valve_mode_id', 1);
stackAreaCm2 = mw.getVariable('stack_area');
cegrValveMaxArea_m2 = mw.getVariable('cegr_valve_max_area');
validateattributes(cegrValveMaxArea_m2, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
cfg.targetCurrentA = cfg.currentDensity_A_cm2 * stackAreaCm2;
cfg.initialCurrentA = 1e-6 * mw.getVariable('stack_iL') * stackAreaCm2;
cfg.loadPath = Simulink.ID.getFullName([model ':368']);
cfg.stepPath = Simulink.ID.getFullName([model ':878']);
set_param(cfg.loadPath, 'input_type', 'Step');
set_param(cfg.stepPath, ...
    'Time', sprintf('%.16g', cfg.loadStepTimeS), ...
    'Before', sprintf('%.16g', cfg.initialCurrentA), ...
    'After', sprintf('%.16g', cfg.targetCurrentA));
set_param(model, 'SimulationCommand', 'update');
routeA_mark_observability_signals(model);

outCheckpoint = runCondition(model, cfg, cfg.checkpointStopTimeS, []);
checkpointState = outCheckpoint.get(cfg.finalStateName);
outProbe = runCondition(model, cfg, cfg.probeStopTimeS, checkpointState);
periodic = assessPeriodicState(outProbe, model, cfg);
displayPeriodicState(periodic, cfg);
if ~periodic.passed
    error('RouteA:PeriodicOperatingStateNotConverged', ...
        ['The mode-1 zero-target j=0.1 A/cm^2 purge cycle has not ', ...
        'converged. The formal initial-state file was not changed.']);
end

outFinal = runCondition(model, cfg, periodic.phaseStopTimeS, ...
    checkpointState);
routeA_initial_state = outFinal.get(cfg.finalStateName);
if isempty(routeA_initial_state)
    error('RouteA:MissingInitialOperatingPoint', ...
        'Simulation did not return the final operating point.');
end
summary = physicalSummary(outFinal, model);
if abs(summary.egrRatio) > cfg.maxEgrRatio
    error('RouteA:InitialStateHasRecirculation', ...
        ['The selected mode-1 normal-operation state exceeds the ', ...
        'zero-target near-zero cEGR gate.']);
end

routeA_initial_metadata = struct();
routeA_initial_metadata.schema = ...
    'RouteA_platform_default_initial_state_v03_mode1';
routeA_initial_metadata.model = string(model);
routeA_initial_metadata.generatedAt = ...
    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
routeA_initial_metadata.cegrTopologyEnabled = true;
routeA_initial_metadata.cegrValveModeId = 1;
routeA_initial_metadata.egrReferenceKind = ...
    "mode1_zero_target_near_zero";
routeA_initial_metadata.candidateSource = ...
    "routeA_generate_platform_default_initial_state";
routeA_initial_metadata.egrTargetRatio = 0;
routeA_initial_metadata.currentDensity_A_cm2 = cfg.currentDensity_A_cm2;
routeA_initial_metadata.targetCurrentA = cfg.targetCurrentA;
routeA_initial_metadata.cegrValveMaxArea_m2 = cegrValveMaxArea_m2;
routeA_initial_metadata.airControlBasis = ...
    "target_total_compressor_mdot_from_fresh_air_equivalent_oer";
routeA_initial_metadata.targetAirEquivalentOer = cfg.targetAirEquivalentOer;
routeA_initial_metadata.normalOperationPhase = ...
    'post_anode_purge_100_s';
routeA_initial_metadata.purgePeriodS = periodic.periodS;
routeA_initial_metadata.snapshotTimeS = periodic.phaseStopTimeS;
routeA_initial_metadata.periodicVerification = periodic;
routeA_initial_metadata.physicalSummary = summary;
routeA_initial_metadata.stateClass = string(class(routeA_initial_state));
save(initialStateFile, 'routeA_initial_state', ...
    'routeA_initial_metadata', '-v7.3');
assignin('base', 'routeA_platform_default_initial_metadata', ...
    routeA_initial_metadata);
metadata = routeA_initial_metadata;
fprintf('Saved Route A mode-1 candidate initial state: %s\n', ...
    initialStateFile);
clear outCheckpoint outProbe outFinal;
clear routeA_initial_state_cleanup;
end

function cfg = initializationConfig()
cfg = struct();
cfg.currentDensity_A_cm2 = 0.1;
cfg.targetAirEquivalentOer = 3; % Fresh-air-equivalent OER for mode-2 total-flow control.
cfg.loadStepTimeS = 0.5;
cfg.checkpointStopTimeS = 3600;
cfg.probeStopTimeS = 5200;
cfg.postPurgeOffsetS = 100;
cfg.finalStateName = 'routeA_platform_default_operating_point';
cfg.purgeDropSlope_1_s = -0.02;
cfg.maxEgrRatio = 1e-5;
cfg.maxPeriodicDelta = struct( ...
    'stackVoltage_V', 0.05, ...
    'anodeN2MassFraction', 0.002, ...
    'cathodeO2MassFraction', 1e-4, ...
    'cathodeWaterMassFraction', 1e-4, ...
    'ohmicResistance_Ohm_cm2', 1e-6, ...
    'stackTemperature_C', 0.01);
end

function out = runCondition(model, cfg, stopTimeS, initialState)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    'StopTime', sprintf('%.16g', stopTimeS), ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all', ...
    'SaveFinalState', 'on', ...
    'FinalStateName', cfg.finalStateName, ...
    'SaveOperatingPoint', 'on');
in = in.setBlockParameter(cfg.loadPath, 'input_type', 'Step');
in = in.setBlockParameter(cfg.stepPath, 'Time', ...
    sprintf('%.16g', cfg.loadStepTimeS));
in = in.setBlockParameter(cfg.stepPath, 'Before', ...
    sprintf('%.16g', cfg.initialCurrentA));
in = in.setBlockParameter(cfg.stepPath, 'After', ...
    sprintf('%.16g', cfg.targetCurrentA));
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_target_oer', cfg.targetAirEquivalentOer, ...
    'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, ...
    'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in', 0, ...
    'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 1, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
    [0, 0; stopTimeS, 0], 'Workspace', model);
if ~isempty(initialState)
    in = in.setInitialState(initialState);
end
out = sim(in);
end

function periodic = assessPeriodicState(out, model, cfg)
simlog = out.get(['simlog_' model]);
mea = routeA_simscape_log_mea(simlog);
time = mea.Vstack.series.time;
voltage = mea.Vstack.series.values('V');
anode = seriesMatrix(mea.x_i_anode.series.values('1'), time, ...
    'anode composition');
cathode = seriesMatrix(mea.x_i_cathode.series.values('1'), time, ...
    'cathode composition');
ohmicResistance = mea.Rohm.series.values('Ohm*cm^2');
stackTemperature = mea.T_stack.series.values('degC');
anodeN2 = anode(:, 1);
slope = diff(anodeN2) ./ diff(time);
candidate = find(slope < cfg.purgeDropSlope_1_s);
eventIndices = candidate([true; diff(candidate) > 1]) + 1;
eventTimes = time(eventIndices);
if numel(eventTimes) < 2
    error('RouteA:MissingPurgeCycle', ...
        'The preconditioning run did not contain two purge events.');
end
periodS = eventTimes(end) - eventTimes(end - 1);
phaseTimes = eventTimes(end - 1:end) + cfg.postPurgeOffsetS;
if phaseTimes(end) >= time(end)
    error('RouteA:InsufficientPurgePhaseWindow', ...
        'The probe run ends before the selected post-purge phase.');
end
periodic = struct();
periodic.eventTimesS = eventTimes;
periodic.periodS = periodS;
periodic.phaseOffsetS = cfg.postPurgeOffsetS;
periodic.phaseTimesS = phaseTimes;
periodic.phaseStopTimeS = phaseTimes(end);
periodic.stackVoltage_V = diff(interp1(time, voltage, phaseTimes));
periodic.anodeN2MassFraction = diff(interp1(time, anodeN2, phaseTimes));
periodic.cathodeO2MassFraction = diff(interp1(time, cathode(:, 2), ...
    phaseTimes));
periodic.cathodeWaterMassFraction = diff(interp1(time, cathode(:, 4), ...
    phaseTimes));
periodic.ohmicResistance_Ohm_cm2 = diff(interp1(time, ohmicResistance, ...
    phaseTimes));
periodic.stackTemperature_C = diff(interp1(time, stackTemperature, ...
    phaseTimes));
periodic.passed = abs(periodic.stackVoltage_V) <= ...
    cfg.maxPeriodicDelta.stackVoltage_V && ...
    abs(periodic.anodeN2MassFraction) <= ...
        cfg.maxPeriodicDelta.anodeN2MassFraction && ...
    abs(periodic.cathodeO2MassFraction) <= ...
        cfg.maxPeriodicDelta.cathodeO2MassFraction && ...
    abs(periodic.cathodeWaterMassFraction) <= ...
        cfg.maxPeriodicDelta.cathodeWaterMassFraction && ...
    abs(periodic.ohmicResistance_Ohm_cm2) <= ...
        cfg.maxPeriodicDelta.ohmicResistance_Ohm_cm2 && ...
    abs(periodic.stackTemperature_C) <= ...
        cfg.maxPeriodicDelta.stackTemperature_C;
end

function summary = physicalSummary(out, model)
logsout = out.logsout;
simlog = out.get(['simlog_' model]);
mea = routeA_simscape_log_mea(simlog);
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
species = abs(seriesMatrix(speciesMdot.Data, speciesMdot.Time, ...
    'inlet species mass flow'));
inletMassFraction = species(end, :) / sum(species(end, :));
outletYi = loggedTimeseries(logsout, 'routeA_yi_outlet');
outletMoleFraction = seriesMatrix(outletYi.Data, outletYi.Time, ...
    'outlet composition');
rhIn = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_in', 'routeA_RH_ca_in_ts'));
rhOut = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_out', 'routeA_RH_ca_out_ts'));
summary = struct();
summary.stackCurrent_A = lastScalar(loggedTimeseries(logsout, ...
    'routeA_stack_current_A'));
summary.stackVoltage_V = mea.Vstack.series.values('V');
summary.stackVoltage_V = summary.stackVoltage_V(end);
summary.stackPower_kW = mea.power_elec.series.values('kW');
summary.stackPower_kW = summary.stackPower_kW(end);
summary.stackTemperature_C = mea.T_stack.series.values('degC');
summary.stackTemperature_C = summary.stackTemperature_C(end);
summary.compressorMdot_kg_s = lastScalar(loggedTimeseries(logsout, ...
    'routeA_mdot_comp_inlet'));
summary.compressorPressure_Pa = lastScalar(loggedTimeseries(logsout, ...
    'routeA_p_comp_inlet'));
summary.compressorTemperature_K = lastScalar(loggedTimeseries(logsout, ...
    'routeA_T_comp_inlet'));
summary.inletO2MassFraction = inletMassFraction(2);
summary.outletO2MoleFraction = outletMoleFraction(end, 2);
summary.inletWaterRelativeHumidity = lastScalar(rhIn);
summary.outletWaterRelativeHumidity = lastScalar(rhOut);
summary.egrRatio = lastScalar(loggedTimeseries(logsout, ...
    'routeA_egr_ratio_comp_in'));
summary.egrMdot_kg_s = abs(lastScalar(loggedTimeseries(logsout, ...
    'routeA_egr_mdot')));
summary.exhaustMdot_kg_s = abs(lastScalar(outputTimeseries(out, logsout, ...
    'routeA_exhaust_mdot', 'routeA_exhaust_mdot_ts')));
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
    error('RouteA:UnexpectedSignalShape', ...
        'Unexpected signal shape for %s.', signalName);
end
end

function value = lastScalar(signal)
data = signal.Data;
if ~isscalar(data(1))
    data = squeeze(data);
end
if ~isvector(data)
    error('RouteA:ExpectedScalarSignal', ...
        'A scalar signal was required for the physical summary.');
end
value = data(end);
end

function rh = waterRelativeHumidity(signal)
data = seriesMatrix(signal.Data, signal.Time, 'relative humidity');
if size(data, 2) < 4
    error('RouteA:UnexpectedHumidityShape', ...
        'Relative-humidity signal does not contain the water component.');
end
rh = timeseries(data(:, 4), signal.Time);
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:MissingLoggedSignal', ...
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
    present = any(strcmp(dataset.getElementNames, name));
catch
end
end

function displayPeriodicState(periodic, cfg)
fprintf(['Route A periodic initialization: j=%.6g A/cm^2, ', ...
    'purge period=%.6g s, selected phase=%.6g s after purge\n'], ...
    cfg.currentDensity_A_cm2, periodic.periodS, periodic.phaseOffsetS);
fprintf(['  phase deltas: dV=%.6g V dN2=%.6g dO2=%.6g ', ...
    'dH2O=%.6g dRohm=%.6g dT=%.6g C passed=%d\n'], ...
    periodic.stackVoltage_V, periodic.anodeN2MassFraction, ...
    periodic.cathodeO2MassFraction, periodic.cathodeWaterMassFraction, ...
    periodic.ohmicResistance_Ohm_cm2, periodic.stackTemperature_C, ...
    periodic.passed);
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
