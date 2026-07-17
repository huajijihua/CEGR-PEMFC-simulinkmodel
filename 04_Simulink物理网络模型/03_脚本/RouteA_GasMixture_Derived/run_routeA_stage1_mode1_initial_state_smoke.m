function summary = run_routeA_stage1_mode1_initial_state_smoke(initialStateFile)
% Verify that one mode-1 candidate or promoted state serves zero and positive cEGR.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
if nargin < 1 || strlength(string(initialStateFile)) == 0
    initialStateFile = fullfile(modelDir, ...
        'RouteA_platform_default_initial_state.mat');
end
initialStateFile = char(initialStateFile);
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
loaded = load(initialStateFile, 'routeA_initial_metadata');
metadata = loaded.routeA_initial_metadata;
cfg = struct();
cfg.initialStateFile = initialStateFile;
cfg.initialStateMetadata = metadata;
cfg.researchStartTime_s = metadata.snapshotTimeS;
cfg.stopTime_s = cfg.researchStartTime_s + 30;
cfg.targetCurrentA = metadata.targetCurrentA;
cfg.targetOer = 3;
cfg.zeroTargetTolerance = 1e-4;
cfg.positiveResponseLowerBound = 0.01;
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
summary.cases = cases;
summary.passed = builtin('all', [cases.passed]);
assignin('base', 'routeA_stage1_mode1_candidate_smoke', summary);
fprintf(['Route A mode-1 initial-state smoke: zero=%d positive=%d ', ...
    'overall=%d\n'], cases(1).passed, cases(2).passed, summary.passed);
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
routeA_apply_constant_current_step(model, ...
    cfg.initialStateMetadata.targetCurrentA, cfg.targetCurrentA);

in = Simulink.SimulationInput(model);
[in, ~] = routeA_attach_platform_default_initial_state( ...
    in, model, modelDir, cfg.initialStateFile);
routeA_mark_observability_signals(model);
in = in.setModelParameter( ...
    'StopTime', sprintf('%.16g', cfg.stopTime_s), ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all');
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_target_oer', cfg.targetOer, 'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 0, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in', targetRatio, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
    [cfg.researchStartTime_s, targetRatio; cfg.stopTime_s, targetRatio], ...
    'Workspace', model);

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
