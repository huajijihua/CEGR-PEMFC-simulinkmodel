function summary = run_routeA_stage1_mode1_initial_state_smoke( ...
    initialStateFile, loadInputType)
% Verify one load-variant state with zero and positive cEGR commands.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
if nargin < 1 || strlength(string(initialStateFile)) == 0
    initialStateFile = fullfile(modelDir, ...
        'RouteA_platform_default_initial_state.mat');
end
if nargin < 2 || strlength(string(loadInputType)) == 0
    loadInputType = "Current";
end
initialStateFile = char(initialStateFile);
loadInputType = string(loadInputType);
if ~isscalar(loadInputType) || ...
        ~any(loadInputType == ["Current", "Power", "Voltage"])
    error('RouteA:InitialStateSmokeLoadInputType', ...
        'loadInputType must be Current, Power, or Voltage.');
end
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));

if ~isfile(initialStateFile)
    error('RouteA:MissingInitialStateCandidate', ...
        'The requested mode-1 initial-state file does not exist.');
end
metadata = loadVariantMetadata(initialStateFile, loadInputType);
cfg = struct();
cfg.initialStateFile = initialStateFile;
cfg.initialStateMetadata = metadata;
cfg.loadInputType = loadInputType;
cfg.researchStartTime_s = metadata.snapshotTimeS;
cfg.stopTime_s = cfg.researchStartTime_s + 30;
cfg.targetAirEquivalentOer = 3;
cfg.zeroTargetTolerance = 1e-4;
cfg.positiveResponseLowerBound = 0.01;
if loadInputType == "Current"
    requireMetadataField(metadata, 'targetCurrentA', loadInputType);
    cfg.targetCurrentA = metadata.targetCurrentA;
elseif loadInputType == "Power"
    requireMetadataField(metadata, 'targetPower_kW', loadInputType);
    cfg.targetPower_kW = metadata.targetPower_kW;
else
    requireMetadataField(metadata, 'targetVoltage_V', loadInputType);
    cfg.targetVoltage_V = metadata.targetVoltage_V;
end
targets = [0, 0.10];

cases = repmat(emptyResult(), numel(targets), 1);
for idx = 1:numel(targets)
    cases(idx) = runCase(model, modelFile, modelDir, cfg, targets(idx));
end
summary = struct();
summary.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
summary.model = string(model);
summary.initialStateFile = string(initialStateFile);
summary.initialState = metadata;
summary.loadInputType = loadInputType;
summary.cases = cases;
summary.passed = builtin('all', [cases.passed]);
assignin('base', 'routeA_stage1_mode1_candidate_smoke', summary);
fprintf(['Route A %s mode-1 initial-state smoke: zero=%d positive=%d ', ...
    'overall=%d\n'], loadInputType, cases(1).passed, cases(2).passed, ...
    summary.passed);
if ~summary.passed
    error('RouteA:Mode1CandidateSmokeFailed', ...
        'The mode-1 candidate did not pass its compatibility smoke.');
end
clear cleanup;
end

function result = emptyResult()
result = struct('targetRatio', NaN, 'actualRatio', NaN, ...
    'egrMdot_kg_s', NaN, 'valveDeltaP_MPa', NaN, ...
    'valveAreaFraction', NaN, 'finite', false, 'responsePassed', false, ...
    'passed', false);
end

function result = runCase(model, modelFile, modelDir, cfg, targetRatio)
resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
if cfg.loadInputType == "Current"
    routeA_apply_constant_current_step(model, ...
        cfg.initialStateMetadata.targetCurrentA, cfg.targetCurrentA);
end

in = Simulink.SimulationInput(model);
[in, ~] = routeA_attach_platform_default_initial_state( ...
    in, model, modelDir, cfg.initialStateFile, cfg.loadInputType);
routeA_mark_observability_signals(model);
in = in.setModelParameter( ...
    'StopTime', sprintf('%.16g', cfg.stopTime_s), ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all');
if isfield(cfg.initialStateMetadata, 'solverMaxStep_s') && ...
        ~isempty(cfg.initialStateMetadata.solverMaxStep_s)
    in = in.setModelParameter('MaxStep', sprintf('%.16g', ...
        cfg.initialStateMetadata.solverMaxStep_s));
end
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
    [cfg.researchStartTime_s, targetRatio; cfg.stopTime_s, targetRatio], ...
    'Workspace', model);
if cfg.loadInputType == "Current"
    in = in.setVariable('drive_cycle_time', ...
        [cfg.researchStartTime_s; cfg.researchStartTime_s + 0.5; ...
        cfg.stopTime_s], 'Workspace', model);
    in = in.setVariable('drive_cycle_current', ...
        [cfg.initialStateMetadata.targetCurrentA; ...
        cfg.initialStateMetadata.targetCurrentA; cfg.targetCurrentA], ...
        'Workspace', model);
elseif cfg.loadInputType == "Power"
    in = in.setVariable('drive_cycle_time', ...
        [cfg.researchStartTime_s; cfg.researchStartTime_s + 0.5; ...
        cfg.stopTime_s], 'Workspace', model);
    in = in.setVariable('drive_cycle_power', ...
        [cfg.targetPower_kW; cfg.targetPower_kW; cfg.targetPower_kW], ...
        'Workspace', model);
elseif cfg.loadInputType == "Voltage"
    in = in.setVariable('drive_cycle_time', ...
        [cfg.researchStartTime_s; cfg.researchStartTime_s + 0.5; ...
        cfg.stopTime_s], 'Workspace', model);
    in = in.setVariable('drive_cycle_voltage', ...
        [cfg.targetVoltage_V; cfg.targetVoltage_V; cfg.targetVoltage_V], ...
        'Workspace', model);
end

out = sim(in);
ratio = out.logsout.get('routeA_egr_ratio_comp_in').Values;
mdot = out.logsout.get('routeA_egr_mdot').Values;
pUp = out.logsout.get('routeA_p_egr_valve_up').Values;
pDown = out.logsout.get('routeA_p_egr_valve_down').Values;
area = out.logsout.get('routeA_egr_valve_area_cmd').Values;
mw = get_param(model, 'ModelWorkspace');
maxArea = mw.getVariable('cegr_valve_max_area');

result = emptyResult();
result.targetRatio = targetRatio;
result.actualRatio = ratio.Data(end);
result.egrMdot_kg_s = abs(mdot.Data(end));
result.valveDeltaP_MPa = (pUp.Data(end) - pDown.Data(end)) * 1e-6;
result.valveAreaFraction = area.Data(end) / maxArea;
result.finite = builtin('all', isfinite([ratio.Data(:); mdot.Data(:); ...
    pUp.Data(:); pDown.Data(:); area.Data(:)]));
if targetRatio == 0
    result.responsePassed = abs(result.actualRatio) <= ...
        cfg.zeroTargetTolerance;
else
    result.responsePassed = result.actualRatio >= ...
        cfg.positiveResponseLowerBound && result.egrMdot_kg_s > 0 && ...
        result.valveDeltaP_MPa > 0 && result.valveAreaFraction > 0;
end
result.passed = result.finite && result.responsePassed;
end

function requireMetadataField(metadata, fieldName, loadInputType)
if ~isfield(metadata, fieldName)
    error('RouteA:InitialStateSmokeMetadata', ...
        'The %s initial state does not record %s.', loadInputType, fieldName);
end
validateattributes(metadata.(fieldName), {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
end

function metadata = loadVariantMetadata(initialStateFile, loadInputType)
if loadInputType == "Current"
    metadataField = 'routeA_initial_metadata_current';
elseif loadInputType == "Power"
    metadataField = 'routeA_initial_metadata_power';
else
    metadataField = 'routeA_initial_metadata_voltage';
end

loaded = load(initialStateFile);
if isfield(loaded, metadataField)
    metadata = loaded.(metadataField);
elseif isfield(loaded, 'routeA_initial_metadata') && ...
        isfield(loaded.routeA_initial_metadata, 'loadInputType') && ...
        string(loaded.routeA_initial_metadata.loadInputType) == loadInputType
    % Candidate generators use the generic pair before atomic promotion.
    metadata = loaded.routeA_initial_metadata;
else
    error('RouteA:InitialStateSmokeMetadata', ...
        'The requested %s initial state does not provide matching metadata.', ...
        loadInputType);
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
