function [initialState, metadata, audit] = ...
    routeA_prepare_parameter_consistent_initial_state( ...
    model, modelFile, parameterOverrides, userCfg)
% Create a temporary, parameter-compatible Route A normal-operation state.
%
% This helper is for studies that change compile-time physical parameters.
% It applies the overrides before model update, then follows the established
% low-load, zero-cEGR periodic conditioning protocol. Mode 2 uses a
% fresh-air-equivalent OER to set total compressor flow; actual lambda_ca_in
% remains an audited result. If userCfg.maxStep_s is supplied, conditioning
% shares the caller's runtime time base. The state remains in memory and must
% not replace the formal platform_default initial-state file.

if nargin < 4 || isempty(userCfg)
    userCfg = struct();
end
cfg = preconditionConfig(userCfg);
validateOverrides(parameterOverrides);

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');
appliedOverrides = applyOverrides(mw, parameterOverrides);
mw.assignin('routeA_cegr_enabled', true);
mw.assignin('routeA_cegr_valve_mode_id', 1);
set_param(model, 'SimulationCommand', 'update');

stackAreaCm2 = mw.getVariable('stack_area');
stackIL = mw.getVariable('stack_iL');
validateattributes(stackAreaCm2, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(stackIL, {'numeric'}, {'scalar', 'positive', 'finite'});
targetCurrentA = cfg.currentDensity_A_cm2 * stackAreaCm2;
initialCurrentA = 1e-6 * stackIL * stackAreaCm2;
configureLowLoadStep(model, initialCurrentA, targetCurrentA, ...
    cfg.loadStepTime_s);

outCheckpoint = runCondition(model, cfg, cfg.checkpointStopTime_s, []);
checkpointState = outCheckpoint.get(cfg.finalStateName);
validateOperatingPoint(checkpointState, 'checkpoint');

outProbe = runCondition(model, cfg, cfg.probeStopTime_s, checkpointState);
periodic = assessPeriodicState(outProbe, model, cfg);
if ~periodic.passed
    error('RouteA:ParameterPreconditionNotPeriodic', ...
        ['The parameter-specific normal-operation precondition did not ', ...
        'reach the required repeated purge phase.']);
end

outFinal = runCondition(model, cfg, periodic.phaseStopTime_s, ...
    checkpointState);
initialState = outFinal.get(cfg.finalStateName);
validateOperatingPoint(initialState, 'final');
egrRatio = lastScalar(loggedTimeseries(outFinal.logsout, ...
    'routeA_egr_ratio_comp_in'));
if ~isfinite(egrRatio) || abs(egrRatio) > cfg.maxEgrRatio
    error('RouteA:ParameterPreconditionEgr', ...
        'The temporary normal-operation state is not zero-cEGR compatible.');
end

metadata = struct();
metadata.schema = 'RouteA_parameter_consistent_initial_state_v01';
metadata.model = string(model);
metadata.generatedAt = string(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
metadata.temporary = true;
metadata.parameterOverrides = appliedOverrides;
metadata.currentDensity_A_cm2 = cfg.currentDensity_A_cm2;
metadata.targetCurrentA = targetCurrentA;
metadata.airControlBasis = ...
    "target_total_compressor_mdot_from_fresh_air_equivalent_oer";
metadata.targetAirEquivalentOer = cfg.targetOer;
metadata.targetOer = cfg.targetOer; % Legacy metadata field for compatibility.
metadata.solverMaxStep_s = cfg.maxStep_s;
metadata.egrTargetRatio = 0;
metadata.cegrTopologyEnabled = true;
metadata.cegrValveModeId = 1;
metadata.egrReferenceKind = "mode1_zero_target_near_zero";
metadata.snapshotTimeS = periodic.phaseStopTime_s;
metadata.normalOperationPhase = 'post_anode_purge_100_s';
metadata.purgePeriodS = periodic.period_s;
metadata.periodicVerification = periodic;
metadata.stateClass = string(class(initialState));

audit = struct();
audit.periodic = periodic;
audit.zeroEgrRatio = egrRatio;
audit.checkpointStateClass = string(class(checkpointState));
audit.finalStateClass = string(class(initialState));
audit.appliedOverrides = appliedOverrides;
clear outCheckpoint outProbe outFinal checkpointState;
end

function cfg = preconditionConfig(userCfg)
cfg = struct();
cfg.currentDensity_A_cm2 = 0.1;
cfg.targetOer = 3; % Fresh-air-equivalent OER for total compressor-flow mode.
cfg.loadStepTime_s = 0.5;
cfg.maxStep_s = [];
cfg.checkpointStopTime_s = 3600;
cfg.probeStopTime_s = 5200;
cfg.postPurgeOffset_s = 100;
cfg.finalStateName = 'routeA_parameter_precondition_operating_point';
cfg.purgeDropSlope_1_s = -0.02;
cfg.maxEgrRatio = 1e-5;
cfg.maxPeriodicDelta = struct( ...
    'stackVoltage_V', 0.05, ...
    'anodeN2MassFraction', 0.002, ...
    'cathodeO2MassFraction', 1e-4, ...
    'cathodeWaterMassFraction', 1e-4, ...
    'ohmicResistance_Ohm_cm2', 1e-6, ...
    'stackTemperature_C', 0.01);

if ~isstruct(userCfg) || numel(userCfg) ~= 1
    error('RouteA:ParameterPreconditionConfig', ...
        'The precondition configuration must be a scalar struct.');
end
names = fieldnames(userCfg);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(cfg, name)
        error('RouteA:ParameterPreconditionConfigField', ...
            'Unsupported precondition configuration field: %s.', name);
    end
    cfg.(name) = userCfg.(name);
end
validateattributes(cfg.currentDensity_A_cm2, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.targetOer, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(cfg.loadStepTime_s, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
if ~isempty(cfg.maxStep_s)
    validateattributes(cfg.maxStep_s, {'numeric'}, ...
        {'scalar', 'positive', 'finite'});
end
validateattributes(cfg.checkpointStopTime_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.probeStopTime_s, {'numeric'}, ...
    {'scalar', '>', cfg.checkpointStopTime_s, 'finite'});
end

function validateOverrides(overrides)
if ~isstruct(overrides) || numel(overrides) ~= 1
    error('RouteA:ParameterPreconditionOverrides', ...
        'Parameter overrides must be a scalar struct.');
end
names = fieldnames(overrides);
if isempty(names)
    error('RouteA:ParameterPreconditionNoOverrides', ...
        'At least one physical parameter override is required.');
end
for idx = 1:numel(names)
    if ~isvarname(names{idx})
        error('RouteA:ParameterPreconditionOverrideName', ...
            'Invalid model-workspace variable name: %s.', names{idx});
    end
end
end

function applied = applyOverrides(mw, overrides)
names = fieldnames(overrides);
applied = struct();
for idx = 1:numel(names)
    name = names{idx};
    try
        mw.getVariable(name);
    catch
        error('RouteA:ParameterPreconditionUnknownOverride', ...
            'The model workspace does not define: %s.', name);
    end
    value = overrides.(name);
    if isnumeric(value) && any(~isfinite(value(:)))
        error('RouteA:ParameterPreconditionNonfiniteOverride', ...
            'Override %s contains a nonfinite value.', name);
    end
    mw.assignin(name, value);
    applied.(name) = value;
end
end

function configureLowLoadStep(model, initialCurrentA, targetCurrentA, stepTime_s)
loadPath = Simulink.ID.getFullName([model ':368']);
stepPath = Simulink.ID.getFullName([model ':878']);
set_param(loadPath, 'input_type', 'Step');
set_param(stepPath, ...
    'Time', sprintf('%.16g', stepTime_s), ...
    'Before', sprintf('%.16g', initialCurrentA), ...
    'After', sprintf('%.16g', targetCurrentA));
end

function out = runCondition(model, cfg, stopTime_s, initialState)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    'StopTime', sprintf('%.16g', stopTime_s), ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all', ...
    'SaveFinalState', 'on', ...
    'FinalStateName', cfg.finalStateName, ...
    'SaveOperatingPoint', 'on');
if ~isempty(cfg.maxStep_s)
    in = in.setModelParameter('MaxStep', sprintf('%.16g', cfg.maxStep_s));
end
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_target_oer', cfg.targetOer, ...
    'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 1, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in', 0, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
    [0, 0; stopTime_s, 0], 'Workspace', model);
if ~isempty(initialState)
    in = in.setInitialState(initialState);
end
out = sim(in);
end

function periodic = assessPeriodicState(out, model, cfg)
simlog = out.get(get_param(model, 'SimscapeLogName'));
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
if isempty(candidate)
    error('RouteA:ParameterPreconditionPurge', ...
        'The probe run did not contain a detectable anode purge event.');
end
eventIndices = candidate([true; diff(candidate) > 1]) + 1;
eventTimes = time(eventIndices);
if numel(eventTimes) < 2
    error('RouteA:ParameterPreconditionPurgeCycle', ...
        'The probe run did not contain two purge events.');
end
phaseTimes = eventTimes(end - 1:end) + cfg.postPurgeOffset_s;
if phaseTimes(end) >= time(end)
    error('RouteA:ParameterPreconditionPhaseWindow', ...
        'The probe run ends before the selected post-purge phase.');
end

periodic = struct();
periodic.eventTimes_s = eventTimes(:).';
periodic.period_s = eventTimes(end) - eventTimes(end - 1);
periodic.phaseOffset_s = cfg.postPurgeOffset_s;
periodic.phaseTimes_s = phaseTimes;
periodic.phaseStopTime_s = phaseTimes(end);
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
    error('RouteA:ParameterPreconditionSignalShape', ...
        'Unexpected signal shape for %s.', signalName);
end
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:ParameterPreconditionMissingSignal', ...
        'The required logged signal is unavailable: %s.', name);
end
signal = element.Values;
end

function value = lastScalar(signal)
data = signal.Data;
if ~isscalar(data(1))
    data = squeeze(data);
end
if ~isvector(data)
    error('RouteA:ParameterPreconditionScalarSignal', ...
        'A scalar signal was required for the precondition audit.');
end
value = data(end);
end

function validateOperatingPoint(value, label)
if ~isa(value, 'Simulink.op.ModelOperatingPoint')
    error('RouteA:ParameterPreconditionStateClass', ...
        'The %s precondition state is not a ModelOperatingPoint.', label);
end
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
open_system(model);
drawnow;
end

function refreshModelWorkspace(model)
mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
end
