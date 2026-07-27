function [initialState, metadata, audit] = ...
    routeA_prepare_parameter_consistent_initial_state( ...
    model, modelFile, parameterValues, userCfg)
% Create a temporary, parameter-compatible Route A normal-operation state.
%
% This helper is for studies that change compile-time physical parameters or
% select a load branch that requires a matching operating-point checksum. It
% applies the requested parameter values before model update, then follows the established
% smooth-load, zero-cEGR periodic conditioning protocol. Mode 2 uses a
% fresh-air-equivalent OER to set total compressor flow; actual lambda_ca_in
% remains an audited result. The initial run uses a smooth near-zero-to-target
% load ramp so the saved state is a physical hot-start state rather than an
% abrupt target-load step. If userCfg.maxStep_s is supplied, conditioning
% shares the caller's runtime time base. The state remains in memory and must
% not replace the formal platform_default initial-state file.

if nargin < 4 || isempty(userCfg)
    userCfg = struct();
end
cfg = preconditionConfig(userCfg);
validateParameterValues(parameterValues);

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
mw = get_param(model, 'ModelWorkspace');
appliedParameterValues = applyParameterValues(mw, parameterValues);
mw.assignin('routeA_cegr_enabled', cfg.cegrEnabled);
mw.assignin('routeA_cegr_valve_mode_id', cfg.cegrValveModeId);

stackAreaCm2 = mw.getVariable('stack_area');
stackIL = mw.getVariable('stack_iL');
cegrValveMaxArea_m2 = mw.getVariable('cegr_valve_max_area');
validateattributes(stackAreaCm2, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(stackIL, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(cegrValveMaxArea_m2, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
targetCurrentA = cfg.currentDensity_A_cm2 * stackAreaCm2;
initialCurrentA = 1e-6 * stackIL * stackAreaCm2;
cfg.targetCurrentA = targetCurrentA;
cfg.initialCurrentA = initialCurrentA;
paths = routeA_block_paths(model);
cfg.loadPath = paths.electricalLoad;
configureLowLoadCommand(model, cfg, initialCurrentA, targetCurrentA);
set_param(model, 'SimulationCommand', 'update');

outCheckpoint = runCondition(model, cfg, cfg.checkpointStopTime_s, []);
checkpointState = outCheckpoint.get(cfg.finalStateName);
validateOperatingPoint(checkpointState, 'checkpoint');

outProbe = runCondition(model, cfg, cfg.probeStopTime_s, checkpointState);
periodic = assessPeriodicState(outProbe, model, cfg);
if ~periodic.passed
    assignin('base', 'routeA_parameter_precondition_periodic_diagnostic', periodic);
    assignin('base', 'routeA_parameter_precondition_periodic_limits', ...
        cfg.relativeVariationLimit);
    error('RouteA:ParameterPreconditionNotPeriodic', ...
        ['The parameter-specific normal-operation precondition did not ', ...
        'reach the required repeated post-purge quiet state. ', ...
        'maxRelativeChange=%.6g.'], periodic.maximumRelativeChange);
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
summary = physicalSummary(outFinal);
commandProfileBaseline = v10CommandBaseline(mw, cfg);

metadata = struct();
metadata.schema = 'RouteA_parameter_consistent_initial_state_v10';
metadata.model = string(model);
metadata.generatedAt = string(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
metadata.temporary = true;
metadata.parameterValues = appliedParameterValues;
metadata.currentDensity_A_cm2 = cfg.currentDensity_A_cm2;
metadata.targetCurrentA = targetCurrentA;
metadata.airControlBasis = ...
    "target_total_compressor_mdot_from_fresh_air_equivalent_oer";
metadata.targetAirEquivalentOer = cfg.targetAirEquivalentOer;
metadata.solverMaxStep_s = cfg.maxStep_s;
metadata.loadInputType = cfg.loadInputType;
metadata.commandTargetPower_kW = cfg.targetPower_kW;
metadata.commandTargetVoltage_V = cfg.targetVoltage_V;
metadata.initializationCondition = initializationCondition(mw, cfg);
metadata.commandProfileSchema = "RouteA_Command_Profile_v10";
metadata.commandProfileFields = mw.getVariable('routeA_command_profile_fields');
metadata.commandProfileBaseline = commandProfileBaseline;
metadata.baselineElectricalCommand = baselineElectricalCommand(cfg, summary);
metadata.sourceConditionerState = sourceConditionerState(mw);
metadata.modelVersion = modelVersion(modelFile);
metadata.preconditioning = struct( ...
    'kind', "smooth_load_ramp", ...
    'rampStartTime_s', cfg.loadRampStartTime_s, ...
    'rampDuration_s', cfg.loadRampDuration_s, ...
    'voltageNoLoadMargin_V', cfg.voltageNoLoadMargin_V, ...
    'purpose', "physical_hot_start_preconditioning");
metadata.egrTargetRatio = cfg.egrTargetRatio;
metadata.cegrTopologyEnabled = cfg.cegrEnabled;
metadata.cegrValveModeId = cfg.cegrValveModeId;
metadata.egrControlModeId = cfg.egrControlModeId;
if ~cfg.cegrEnabled
    metadata.egrReferenceKind = "topology_disabled";
elseif cfg.cegrValveModeId == 1
    metadata.egrReferenceKind = "mode1_zero_target_near_zero";
else
    metadata.egrReferenceKind = "mode0_closed";
end
metadata.cegrValveMaxArea_m2 = cegrValveMaxArea_m2;
metadata.egrPipeCondensationEnabled = cfg.egrPipeCondensationEnabled;
metadata.egrPipeInitialPressure_MPa = cfg.egrPipeInitialPressure_MPa;
metadata.egrPipeInitialTemperature_C = cfg.egrPipeInitialTemperature_C;
metadata.egrPipeInitialMassFractions = cfg.egrPipeInitialMassFractions;
metadata.egrPipeInitialMoleFractions = cfg.egrPipeInitialMoleFractions;
metadata.anodeExhaustPipeInitialPressure_MPa = ...
    cfg.anodeExhaustPipeInitialPressure_MPa;
metadata.anodeExhaustPipeInitialTemperature_C = ...
    cfg.anodeExhaustPipeInitialTemperature_C;
metadata.anodeExhaustPipeInitialMoleFractions = ...
    cfg.anodeExhaustPipeInitialMoleFractions;
metadata.snapshotTimeS = initialState.snapshotTime;
metadata.normalOperationPhase = 'post_anode_purge_quiet_window_end';
metadata.purgePeriodS = periodic.period_s;
metadata.periodicVerification = periodic;
metadata.physicalSummary = summary;
metadata.targetPower_kW = summary.stackPower_kW;
metadata.targetVoltage_V = summary.stackVoltage_V;
metadata.solver = struct('name', "VariableStepAuto", ...
    'relativeTolerance', 1e-3, 'absoluteTolerance', 1e-3, ...
    'maxStep_s', cfg.maxStep_s, 'initialConditionStartTime_s', 0);
metadata.stateClass = string(class(initialState));

audit = struct();
audit.periodic = periodic;
audit.zeroEgrRatio = egrRatio;
audit.checkpointStateClass = string(class(checkpointState));
audit.finalStateClass = string(class(initialState));
audit.appliedParameterValues = appliedParameterValues;
audit.physicalSummary = summary;
clear outCheckpoint outProbe outFinal checkpointState;
end

function cfg = preconditionConfig(userCfg)
cfg = struct();
cfg.currentDensity_A_cm2 = 0.1;
cfg.targetAirEquivalentOer = 3; % Fresh-air-equivalent OER for total compressor-flow mode.
cfg.loadInputType = "Current";
cfg.targetCurrentA = NaN;
cfg.targetPower_kW = NaN;
cfg.targetVoltage_V = NaN;
cfg.cegrValveModeId = 1;
cfg.cegrEnabled = true;
cfg.egrControlModeId = 1;
cfg.egrPipeCondensationEnabled = true;
cfg.egrPipeInitialPressure_MPa = [];
cfg.egrPipeInitialTemperature_C = [];
cfg.egrPipeInitialMassFractions = [];
cfg.egrPipeInitialMoleFractions = [];
cfg.anodeExhaustPipeInitialPressure_MPa = [];
cfg.anodeExhaustPipeInitialTemperature_C = [];
cfg.anodeExhaustPipeInitialMoleFractions = [];
cfg.egrTargetRatio = 0;
cfg.loadRampStartTime_s = 0.5;
cfg.loadRampDuration_s = 120;
cfg.voltageNoLoadMargin_V = 20;
cfg.solver = "VariableStepAuto";
cfg.relativeTolerance = 1e-3;
cfg.absoluteTolerance = 1e-3;
cfg.maxStep_s = 5;
cfg.checkpointStopTime_s = 3600;
% Keep parameter- and branch-specific conditioning on the same multi-cycle
% observation window used by the migrated Current formal-state generator.
cfg.probeStopTime_s = 10000;
cfg.postPurgeOffset_s = 100;
cfg.postPurgeQuietWindow_s = 60;
cfg.purgeEventMergeGap_s = 5;
cfg.finalStateName = 'routeA_parameter_precondition_operating_point';
cfg.purgeDropSlope_1_s = -0.02;
cfg.maxEgrRatio = 1e-5;
cfg.relativeVariationLimit = 0.005;

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
validateattributes(cfg.targetAirEquivalentOer, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.cegrValveModeId, {'numeric'}, ...
    {'scalar', 'integer', '>=', 0, '<=', 1});
validateattributes(cfg.cegrEnabled, {'logical', 'numeric'}, {'scalar'});
cfg.cegrEnabled = logical(cfg.cegrEnabled);
validateattributes(cfg.egrControlModeId, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 2});
validateattributes(cfg.egrPipeCondensationEnabled, {'logical', 'numeric'}, ...
    {'scalar'});
cfg.egrPipeCondensationEnabled = logical(cfg.egrPipeCondensationEnabled);
if ~isempty(cfg.egrPipeInitialPressure_MPa)
    validateattributes(cfg.egrPipeInitialPressure_MPa, {'numeric'}, ...
        {'scalar', 'positive', 'finite'});
end
if ~isempty(cfg.egrPipeInitialTemperature_C)
    validateattributes(cfg.egrPipeInitialTemperature_C, {'numeric'}, ...
        {'scalar', 'finite'});
end
if ~isempty(cfg.egrPipeInitialMassFractions)
    validateattributes(cfg.egrPipeInitialMassFractions, {'numeric'}, ...
        {'vector', 'finite', 'nonnegative'});
    cfg.egrPipeInitialMassFractions = reshape( ...
        cfg.egrPipeInitialMassFractions, [], 1);
    if numel(cfg.egrPipeInitialMassFractions) ~= 4 || ...
            abs(sum(cfg.egrPipeInitialMassFractions) - 1) > 1e-9
        error('RouteA:ParameterPreconditionEgrPipeComposition', ...
            'egrPipeInitialMassFractions must be a four-species unit vector.');
    end
end
if ~isempty(cfg.egrPipeInitialMoleFractions)
    validateattributes(cfg.egrPipeInitialMoleFractions, {'numeric'}, ...
        {'vector', 'finite', 'nonnegative'});
    cfg.egrPipeInitialMoleFractions = reshape( ...
        cfg.egrPipeInitialMoleFractions, [], 1);
    if numel(cfg.egrPipeInitialMoleFractions) ~= 4 || ...
            abs(sum(cfg.egrPipeInitialMoleFractions) - 1) > 1e-9
        error('RouteA:ParameterPreconditionEgrPipeComposition', ...
            'egrPipeInitialMoleFractions must be a four-species unit vector.');
    end
end
if ~isempty(cfg.anodeExhaustPipeInitialPressure_MPa)
    validateattributes(cfg.anodeExhaustPipeInitialPressure_MPa, ...
        {'numeric'}, {'scalar', 'positive', 'finite'});
end
if ~isempty(cfg.anodeExhaustPipeInitialTemperature_C)
    validateattributes(cfg.anodeExhaustPipeInitialTemperature_C, ...
        {'numeric'}, {'scalar', 'finite'});
end
if ~isempty(cfg.anodeExhaustPipeInitialMoleFractions)
    validateattributes(cfg.anodeExhaustPipeInitialMoleFractions, ...
        {'numeric'}, {'vector', 'finite', 'nonnegative'});
    cfg.anodeExhaustPipeInitialMoleFractions = reshape( ...
        cfg.anodeExhaustPipeInitialMoleFractions, [], 1);
    if numel(cfg.anodeExhaustPipeInitialMoleFractions) ~= 4 || ...
            abs(sum(cfg.anodeExhaustPipeInitialMoleFractions) - 1) > 1e-9
        error('RouteA:ParameterPreconditionAnodeExhaustComposition', ...
            ['anodeExhaustPipeInitialMoleFractions must be a four-', ...
            'species unit vector.']);
    end
end
validateattributes(cfg.egrTargetRatio, {'numeric'}, ...
    {'scalar', 'finite', '>=', 0, '<=', 1});
cfg.loadInputType = string(cfg.loadInputType);
if ~isscalar(cfg.loadInputType) || ...
        ~any(cfg.loadInputType == ["Current", "Power", "Voltage"])
    error('RouteA:ParameterPreconditionLoadInputType', ...
        'loadInputType must be Current, Power, or Voltage.');
end
if cfg.loadInputType == "Current"
    % The Current target is derived from currentDensity_A_cm2 after the
    % active model workspace supplies stack_area.
elseif cfg.loadInputType == "Power"
    validateattributes(cfg.targetPower_kW, {'numeric'}, ...
        {'scalar', 'positive', 'finite'});
elseif cfg.loadInputType == "Voltage"
    validateattributes(cfg.targetVoltage_V, {'numeric'}, ...
        {'scalar', 'positive', 'finite'});
end
validateattributes(cfg.loadRampStartTime_s, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
validateattributes(cfg.loadRampDuration_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.voltageNoLoadMargin_V, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
if cfg.loadRampStartTime_s + cfg.loadRampDuration_s >= ...
        cfg.checkpointStopTime_s
    error('RouteA:ParameterPreconditionRampWindow', ...
        'The preconditioning ramp must finish before the checkpoint.');
end
cfg.solver = string(cfg.solver);
if ~isscalar(cfg.solver) || cfg.solver ~= "VariableStepAuto"
    error('RouteA:ParameterPreconditionSolver', ...
        'Route A currently supports the VariableStepAuto solver only.');
end
validateattributes(cfg.relativeTolerance, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.absoluteTolerance, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.maxStep_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.checkpointStopTime_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.probeStopTime_s, {'numeric'}, ...
    {'scalar', '>', cfg.checkpointStopTime_s, 'finite'});
validateattributes(cfg.postPurgeOffset_s, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
validateattributes(cfg.postPurgeQuietWindow_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.relativeVariationLimit, {'numeric'}, ...
    {'scalar', 'positive', 'finite', '<=', 1});
end

function validateParameterValues(parameterValues)
if ~isstruct(parameterValues) || numel(parameterValues) ~= 1
    error('RouteA:ParameterPreconditionValues', ...
        'Parameter values must be a scalar struct.');
end
names = fieldnames(parameterValues);
for idx = 1:numel(names)
    if ~isvarname(names{idx})
        error('RouteA:ParameterPreconditionValueName', ...
            'Invalid model-workspace variable name: %s.', names{idx});
    end
end
end

function applied = applyParameterValues(mw, parameterValues)
names = fieldnames(parameterValues);
applied = struct();
for idx = 1:numel(names)
    name = names{idx};
    try
        mw.getVariable(name);
    catch
        error('RouteA:ParameterPreconditionUnknownValue', ...
            'The model workspace does not define: %s.', name);
    end
    value = parameterValues.(name);
    if isnumeric(value) && any(~isfinite(value(:)))
        error('RouteA:ParameterPreconditionNonfiniteValue', ...
            'Parameter value %s contains a nonfinite value.', name);
    end
    mw.assignin(name, value);
    applied.(name) = value;
end
end

function configureLowLoadCommand(model, cfg, initialCurrentA, targetCurrentA)
loadPath = cfg.loadPath;
paths = routeA_block_paths(model);
mw = get_param(model, 'ModelWorkspace');
profileTime = [0; cfg.loadRampStartTime_s; ...
        cfg.loadRampStartTime_s + cfg.loadRampDuration_s; ...
        cfg.checkpointStopTime_s];
if cfg.loadInputType == "Current"
    set_param(loadPath, 'input_type', 'Current');
    set_param([paths.currentDemand '/Current Demand'], 'VariableName', ...
        '[drive_cycle_time, drive_cycle_current]');
    profileValue = [initialCurrentA; initialCurrentA; ...
        targetCurrentA; targetCurrentA];
    mw.assignin('drive_cycle_current', profileValue);
elseif cfg.loadInputType == "Power"
    set_param(loadPath, 'input_type', 'Power');
    profileValue = [0; 0; cfg.targetPower_kW; cfg.targetPower_kW];
    mw.assignin('drive_cycle_power', profileValue);
else
    set_param(loadPath, 'input_type', 'Voltage');
    profileValue = [cfg.targetVoltage_V + cfg.voltageNoLoadMargin_V; ...
        cfg.targetVoltage_V + cfg.voltageNoLoadMargin_V; ...
        cfg.targetVoltage_V; cfg.targetVoltage_V];
    mw.assignin('drive_cycle_voltage', profileValue);
end
mw.assignin('drive_cycle_time', profileTime);
end

function out = runCondition(model, cfg, stopTime_s, initialState)
in = Simulink.SimulationInput(model);
    in = in.setModelParameter( ...
        'StartTime', '0', ...
        'StopTime', sprintf('%.16g', stopTime_s), ...
    'Solver', char(cfg.solver), ...
    'SolverType', 'Variable-step', ...
    'RelTol', sprintf('%.16g', cfg.relativeTolerance), ...
    'AbsTol', sprintf('%.16g', cfg.absoluteTolerance), ...
    'MaxStep', sprintf('%.16g', cfg.maxStep_s), ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all', ...
    'SaveFinalState', 'on', ...
    'FinalStateName', cfg.finalStateName, ...
    'SaveOperatingPoint', 'on');
in = in.setBlockParameter(cfg.loadPath, 'input_type', ...
    char(cfg.loadInputType));
in = in.setVariable('routeA_cegr_enabled', cfg.cegrEnabled, ...
    'Workspace', model);
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', cfg.egrControlModeId, ...
    'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', cfg.cegrValveModeId, ...
    'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 1, ...
    'Workspace', model);
if cfg.egrPipeCondensationEnabled
    egrPipeIsCond = '[0; 0; 0; 1]';
else
    egrPipeIsCond = '[0; 0; 0; 0]';
end
egrPipePath = [model '/Cathode_Air_cEGR_BOP/EGRPipe'];
in = in.setBlockParameter(egrPipePath, 'isCond', egrPipeIsCond);
if ~isempty(cfg.egrPipeInitialPressure_MPa)
    in = in.setBlockParameter(egrPipePath, 'p0', ...
        sprintf('%.16g', cfg.egrPipeInitialPressure_MPa));
end
if ~isempty(cfg.egrPipeInitialTemperature_C)
    in = in.setBlockParameter(egrPipePath, 'T0', ...
        sprintf('%.16g', cfg.egrPipeInitialTemperature_C));
end
if ~isempty(cfg.egrPipeInitialMassFractions)
    in = in.setBlockParameter(egrPipePath, 'x0', ...
        mat2str(cfg.egrPipeInitialMassFractions, 16));
end
if ~isempty(cfg.egrPipeInitialMoleFractions)
    in = in.setBlockParameter(egrPipePath, 'y0', ...
        mat2str(cfg.egrPipeInitialMoleFractions, 16));
end
anodeExhaustPipePath = [model '/Anode_Hydrogen_BOP/Anode Exhaust/Pipe (FC)'];
if ~isempty(cfg.anodeExhaustPipeInitialPressure_MPa)
    in = in.setBlockParameter(anodeExhaustPipePath, 'p0', ...
        sprintf('%.16g', cfg.anodeExhaustPipeInitialPressure_MPa));
end
if ~isempty(cfg.anodeExhaustPipeInitialTemperature_C)
    in = in.setBlockParameter(anodeExhaustPipePath, 'T0', ...
        sprintf('%.16g', cfg.anodeExhaustPipeInitialTemperature_C));
end
if ~isempty(cfg.anodeExhaustPipeInitialMoleFractions)
    in = in.setBlockParameter(anodeExhaustPipePath, 'y0', ...
        mat2str(cfg.anodeExhaustPipeInitialMoleFractions, 16));
end
if isempty(initialState)
    modelStartTime_s = 0;
    rampEndTime_s = cfg.loadRampStartTime_s + cfg.loadRampDuration_s;
    if rampEndTime_s >= stopTime_s
        error('RouteA:ParameterPreconditionRampStopTime', ...
            'The preconditioning ramp must finish before StopTime.');
    end
    profileTime_s = [0; cfg.loadRampStartTime_s; rampEndTime_s; stopTime_s];
    if cfg.loadInputType == "Current"
        profileValue = [cfg.initialCurrentA; cfg.initialCurrentA; ...
            cfg.targetCurrentA; cfg.targetCurrentA];
    elseif cfg.loadInputType == "Power"
        profileValue = [0; 0; cfg.targetPower_kW; cfg.targetPower_kW];
    else
        profileValue = [cfg.targetVoltage_V + cfg.voltageNoLoadMargin_V; ...
            cfg.targetVoltage_V + cfg.voltageNoLoadMargin_V; ...
            cfg.targetVoltage_V; cfg.targetVoltage_V];
    end
else
    modelStartTime_s = initialState.snapshotTime;
    validateattributes(modelStartTime_s, {'numeric'}, ...
        {'scalar', 'real', 'finite'});
    if stopTime_s <= modelStartTime_s
        error('RouteA:ParameterPreconditionStopTime', ...
            'StopTime must be greater than the initial-state snapshot time.');
    end
    profileTime_s = [modelStartTime_s; stopTime_s];
    if cfg.loadInputType == "Current"
        profileValue = [cfg.targetCurrentA; cfg.targetCurrentA];
    elseif cfg.loadInputType == "Power"
        profileValue = [cfg.targetPower_kW; cfg.targetPower_kW];
    else
        profileValue = [cfg.targetVoltage_V; cfg.targetVoltage_V];
    end
end
commandProfileBaseline = v10CommandBaseline( ...
    get_param(model, 'ModelWorkspace'), cfg);
in = in.setVariable('routeA_command_profile', ...
    [modelStartTime_s, commandProfileBaseline; ...
    stopTime_s, commandProfileBaseline], 'Workspace', model);
in = in.setVariable('drive_cycle_time', profileTime_s, ...
    'Workspace', model);
if cfg.loadInputType == "Current"
    in = in.setVariable('drive_cycle_current', profileValue, ...
        'Workspace', model);
elseif cfg.loadInputType == "Power"
    in = in.setVariable('drive_cycle_power', profileValue, ...
        'Workspace', model);
else
    in = in.setVariable('drive_cycle_voltage', profileValue, ...
        'Workspace', model);
end
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
 eventStart = [true; diff(time(candidate)) > cfg.purgeEventMergeGap_s];
 eventIndices = candidate(eventStart) + 1;
eventTimes = time(eventIndices);
if numel(eventTimes) < 2
    error('RouteA:ParameterPreconditionPurgeCycle', ...
        'The probe run did not contain two purge events.');
end
validEvent = eventTimes + cfg.postPurgeOffset_s + ...
    cfg.postPurgeQuietWindow_s <= time(end);
validEventTimes = eventTimes(validEvent);
if numel(validEventTimes) < 2
    error('RouteA:ParameterPreconditionPhaseWindow', ...
        ['The probe run does not contain two purge events with complete ', ...
        'post-purge quiet windows.']);
end
selectedEventTimes = validEventTimes(end - 1:end);
quietWindows = [selectedEventTimes + cfg.postPurgeOffset_s, ...
    selectedEventTimes + cfg.postPurgeOffset_s + ...
    cfg.postPurgeQuietWindow_s];

periodic = struct();
periodic.eventTimes_s = eventTimes(:).';
periodic.selectedEventTimes_s = selectedEventTimes(:).';
periodic.period_s = selectedEventTimes(2) - selectedEventTimes(1);
periodic.phaseOffset_s = cfg.postPurgeOffset_s;
periodic.quietWindowDuration_s = cfg.postPurgeQuietWindow_s;
periodic.quietWindows_s = quietWindows;
periodic.phaseStopTime_s = quietWindows(2, 2);
periodic.relativeVariationLimit = cfg.relativeVariationLimit;
periodic.steadyStateCriterion = ...
    "phase_aligned_cross_cycle_quiet_window_mean";
signals = struct( ...
    'stackVoltage_V', voltage, ...
    'anodeN2MassFraction', anodeN2, ...
    'cathodeO2MassFraction', cathode(:, 2), ...
    'cathodeWaterMassFraction', cathode(:, 4), ...
    'ohmicResistance_Ohm_cm2', ohmicResistance, ...
    'stackTemperature_C', stackTemperature);
periodic.metrics = struct();
periodic.passed = true;
periodic.maximumRelativeChange = 0;
periodic.maximumWithinWindowRelativeChange = 0;
names = fieldnames(signals);
for idx = 1:numel(names)
    name = names{idx};
    scale = periodicMetricScale(name);
    first = quietWindowStats(time, signals.(name), quietWindows(1, :), ...
        scale);
    second = quietWindowStats(time, signals.(name), quietWindows(2, :), ...
        scale);
    crossCycleRelativeChange = abs(second.mean - first.mean) / ...
        max([abs(first.mean), abs(second.mean), scale]);
    metric = struct('firstCycle', first, 'secondCycle', second, ...
        'crossCycleRelativeChange', crossCycleRelativeChange, ...
        'passed', false);
    % The anode inventory evolves between purges. Stability is therefore
    % assessed at the same purge phase across consecutive cycles.
    metric.passed = first.finite && second.finite && ...
        crossCycleRelativeChange <= cfg.relativeVariationLimit;
    periodic.metrics.(name) = metric;
    periodic.passed = periodic.passed && metric.passed;
    periodic.maximumRelativeChange = max( ...
        periodic.maximumRelativeChange, crossCycleRelativeChange);
    periodic.maximumWithinWindowRelativeChange = max( ...
        [periodic.maximumWithinWindowRelativeChange, ...
        first.withinWindowRelativeChange, second.withinWindowRelativeChange]);
end
eventInQuietWindow = false;
for idx = 1:size(quietWindows, 1)
    eventInQuietWindow = eventInQuietWindow || any(eventTimes > ...
        quietWindows(idx, 1) & eventTimes < quietWindows(idx, 2));
end
periodic.quietWindowPurgeFree = ~eventInQuietWindow;
periodic.passed = periodic.passed && periodic.quietWindowPurgeFree;
end

function stats = quietWindowStats(time, data, window, scale)
time = time(:);
data = data(:);
if numel(time) ~= numel(data)
    error('RouteA:ParameterPreconditionWindowShape', ...
        'Quiet-window time and data dimensions are inconsistent.');
end
inside = time >= window(1) & time < window(2);
sampleTime = unique([window(1); time(inside); window(2)]);
sample = interp1(time, data, sampleTime, 'linear', 'extrap');
finite = all(isfinite(sample)) && any(inside);
stats = struct('mean', NaN, 'withinWindowRelativeChange', Inf, ...
    'sampleCount', sum(inside), 'finite', finite);
if ~finite
    return;
end
stats.mean = trapz(sampleTime, sample) / diff(window);
midpoint = mean(window);
firstMean = timeWeightedMean(time, data, [window(1), midpoint]);
secondMean = timeWeightedMean(time, data, [midpoint, window(2)]);
stats.withinWindowRelativeChange = abs(secondMean - firstMean) / ...
    max([abs(firstMean), abs(secondMean), scale]);
end

function meanValue = timeWeightedMean(time, data, window)
time = time(:);
data = data(:);
inside = time >= window(1) & time < window(2);
sampleTime = unique([window(1); time(inside); window(2)]);
sample = interp1(time, data, sampleTime, 'linear', 'extrap');
meanValue = trapz(sampleTime, sample) / diff(window);
end

function scale = periodicMetricScale(name)
switch string(name)
    case {"stackVoltage_V", "stackTemperature_C"}
        scale = 1;
    case {"anodeN2MassFraction", "cathodeO2MassFraction", ...
            "cathodeWaterMassFraction"}
        scale = 1e-4;
    case "ohmicResistance_Ohm_cm2"
        scale = 1e-6;
    otherwise
        error('RouteA:ParameterPreconditionMetric', ...
            'No quiet-window scale is defined for %s.', name);
end
end

function condition = initializationCondition(mw, cfg)
condition = struct( ...
    'electricalInputType', cfg.loadInputType, ...
    'currentDensity_A_cm2', cfg.currentDensity_A_cm2, ...
    'currentA', cfg.targetCurrentA, ...
    'targetPowerCommand_kW', cfg.targetPower_kW, ...
    'targetVoltageCommand_V', cfg.targetVoltage_V, ...
    'airControlModeId', mw.getVariable('routeA_air_control_mode_id'), ...
    'targetAirEquivalentOer', cfg.targetAirEquivalentOer, ...
    'cathodeSourcePressure_MPa_abs', mw.getVariable('env_p'), ...
    'cathodeSourceTemperature_C', mw.getVariable('env_T'), ...
    'cathodeSourceO2MoleFraction', mw.getVariable('env_yO2'), ...
    'cathodeSourceWaterMoleFraction', mw.getVariable('env_yH20'), ...
    'cathodeOutletPressure_MPa_abs', ...
        mw.getVariable('routeA_target_p_ca_out_MPa'), ...
    'cathodeHumidifierRelativeHumidity', ...
        mw.getVariable('routeA_cathode_rh_setpoint'), ...
    'stackTemperatureSet_C', ...
        mw.getVariable('routeA_stack_temperature_set_C'), ...
    'anodeTankPressure_MPa_abs', mw.getVariable('tank_p'), ...
    'anodeSourceTemperature_C', mw.getVariable('tank_T'), ...
    'anodeHydrogenMoleFraction', mw.getVariable('tank_yH2'), ...
    'anodeInletPressure_MPa_abs', ...
        mw.getVariable('routeA_anode_inlet_pressure_MPa_abs'), ...
    'anodeHumidifierRelativeHumidity', ...
        mw.getVariable('routeA_anode_rh_setpoint'), ...
    'anodeRecirculationBaseCommand', ...
        mw.getVariable('routeA_anode_recirculation_base_command'), ...
    'anodeRecirculationCurrentGain_A_inv', ...
        mw.getVariable('routeA_anode_recirculation_current_gain_A_inv'), ...
    'anodePurgeEnabled', mw.getVariable('routeA_anode_purge_enable'), ...
    'anodePurgeOnN2MoleFraction', ...
        mw.getVariable('routeA_anode_purge_on_n2_mole_fraction'), ...
    'anodePurgeOffN2MoleFraction', ...
        mw.getVariable('routeA_anode_purge_off_n2_mole_fraction'), ...
    'cegrTargetRatio', cfg.egrTargetRatio, ...
    'solverStartTime_s', 0, ...
    'postPurgeOffset_s', cfg.postPurgeOffset_s, ...
    'postPurgeQuietWindow_s', cfg.postPurgeQuietWindow_s);
end

function baseline = v10CommandBaseline(mw, cfg)
baseline = mw.getVariable('routeA_command_profile_baseline');
baseline = reshape(double(baseline), 1, []);
if numel(baseline) ~= 22 || any(~isfinite(baseline))
    error('RouteA:ParameterPreconditionCommandProfile', ...
        'The model workspace has no valid 22-column v10 command baseline.');
end
% The conditioning cEGR target and its complete physical source/BoP command
% state are supplied through the common runtime path.
baseline(6) = cfg.targetAirEquivalentOer;
baseline(11) = cfg.egrTargetRatio;
end

function command = baselineElectricalCommand(cfg, summary)
command = struct('current', summary.stackCurrent_A, ...
    'power', summary.stackPower_kW, 'voltage', summary.stackVoltage_V);
switch cfg.loadInputType
    case "Current"
        command.current = cfg.targetCurrentA;
    case "Power"
        command.power = cfg.targetPower_kW;
    case "Voltage"
        command.voltage = cfg.targetVoltage_V;
end
values = [command.current, command.power, command.voltage];
if any(~isfinite(values))
    error('RouteA:ParameterPreconditionElectricalBaseline', ...
        'The v10 initial state has a non-finite electrical baseline command.');
end
end

function state = sourceConditionerState(mw)
state = struct();
state.schema = "RouteA_Source_Conditioner_v10";
state.cathode = struct( ...
    'blockName', "Cathode_Source_Conditioner", ...
    'species', ["N2", "O2", "H2O"], ...
    'chamberVolume_L', mw.getVariable( ...
        'routeA_cathode_source_conditioner_volume_L'), ...
    'nominalFlow_kg_s', mw.getVariable( ...
        'routeA_cathode_source_conditioner_nominal_flow_kg_s'));
state.anode = struct( ...
    'blockName', "Anode_Source_Conditioner", ...
    'species', ["H2", "N2"], ...
    'chamberVolume_L', mw.getVariable( ...
        'routeA_anode_source_conditioner_volume_L'), ...
    'nominalFlow_kg_s', mw.getVariable( ...
        'routeA_anode_source_conditioner_nominal_flow_kg_s'));
end

function version = modelVersion(modelFile)
info = dir(modelFile);
if numel(info) ~= 1
    error('RouteA:ParameterPreconditionModelVersion', ...
        'Could not resolve the Route A model file for v10 metadata.');
end
version = struct('fileName', string(info.name), ...
    'bytes', info.bytes, 'modified', string(info.date));
end

function summary = physicalSummary(out)
logsout = out.logsout;
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
summary.stackVoltage_V = lastScalar(loggedTimeseries(logsout, ...
    'routeA_stack_voltage_V'));
summary.stackPower_kW = lastScalar( ...
    routeA_stack_electrical_power_timeseries(logsout));
summary.stackTemperature_C = lastScalar(loggedTimeseries(logsout, ...
    'routeA_stack_temperature_C'));
summary.cathodeOutletPressure_Pa = lastScalar(loggedTimeseries(logsout, ...
    'routeA_p_outlet'));
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

function rh = waterRelativeHumidity(signal)
data = seriesMatrix(signal.Data, signal.Time, 'relative humidity');
if size(data, 2) < 4
    error('RouteA:ParameterPreconditionHumidityShape', ...
        'Relative-humidity signal does not contain the water component.');
end
rh = timeseries(data(:, 4), signal.Time);
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
