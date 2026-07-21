function metadata = routeA_generate_platform_default_drive_cycle_initial_state()
% Generate a candidate normal-operation state for the Drive cycle branch.
%
% ModelOperatingPoint carries a checksum of the Electrical Load branch. The
% formal Step state therefore cannot initialize the Drive cycle branch even
% when its physical source condition is the same. This generator preserves
% that source condition by using the Step-state power as the low-load
% Drive-cycle command, then applies the standard mode-1 zero-cEGR periodic
% conditioning protocol.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
formalFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
candidateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_candidate_mode1_drive_cycle.mat');
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));

if ~isfile(formalFile)
    error('RouteA:MissingStepInitialState', ...
        'The formal Step initial state is required: %s.', formalFile);
end
loaded = load(formalFile, 'routeA_initial_metadata');
if ~isfield(loaded, 'routeA_initial_metadata')
    error('RouteA:InvalidStepInitialState', ...
        'The formal Step initial-state metadata is unavailable.');
end
source = loaded.routeA_initial_metadata;
required = {'model', 'physicalSummary', 'snapshotTimeS', ...
    'cegrTopologyEnabled', 'cegrValveModeId', 'egrReferenceKind', ...
    'cegrValveMaxArea_m2'};
if ~builtin('all', isfield(source, required)) || ...
        ~isfield(source.physicalSummary, 'stackPower_kW')
    error('RouteA:InvalidStepInitialStateMetadata', ...
        'The formal Step initial-state metadata is incomplete.');
end
if string(source.model) ~= string(model) || ...
        ~source.cegrTopologyEnabled || source.cegrValveModeId ~= 1 || ...
        string(source.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:StepInitialStateMode', ...
        'The formal Step state is not the required mode-1 zero-cEGR state.');
end
sourcePower_kW = source.physicalSummary.stackPower_kW;
validateattributes(sourcePower_kW, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});

preconditionCfg = struct( ...
    'loadInputType', "Drive cycle", ...
    'targetPower_kW', sourcePower_kW, ...
    'maxStep_s', 5);
[routeA_initial_state, metadata, audit] = ...
    routeA_prepare_parameter_consistent_initial_state( ...
    model, modelFile, struct(), preconditionCfg);
if ~audit.periodic.passed
    error('RouteA:DriveCycleInitialStatePeriodic', ...
        'The Drive cycle candidate did not pass periodic verification.');
end
if abs(metadata.cegrValveMaxArea_m2 - source.cegrValveMaxArea_m2) > ...
        1e-12 * max(1, abs(source.cegrValveMaxArea_m2))
    error('RouteA:DriveCycleInitialStateParameterMismatch', ...
        'The Drive cycle candidate does not match the formal valve area.');
end

metadata.schema = 'RouteA_platform_default_initial_state_v04_mode1';
metadata.candidateSource = ...
    "routeA_generate_platform_default_drive_cycle_initial_state";
metadata.loadInputType = "Drive cycle";
metadata.sourceStepSnapshotTimeS = source.snapshotTimeS;
metadata.sourceStepPower_kW = sourcePower_kW;
metadata.stateClass = string(class(routeA_initial_state));
routeA_initial_metadata = metadata;
save(candidateFile, 'routeA_initial_state', ...
    'routeA_initial_metadata', '-v7.3');
assignin('base', 'routeA_platform_default_drive_cycle_candidate_metadata', ...
    routeA_initial_metadata);
fprintf(['Saved Route A mode-1 Drive cycle initial-state candidate: %s ', ...
    '(P_source=%.4g kW)\n'], candidateFile, sourcePower_kW);

clear cleanup;
end
