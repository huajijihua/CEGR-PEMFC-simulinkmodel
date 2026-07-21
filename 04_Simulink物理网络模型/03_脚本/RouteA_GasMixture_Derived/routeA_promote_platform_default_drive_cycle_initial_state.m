function metadata = routeA_promote_platform_default_drive_cycle_initial_state(modelDir)
% Add a validated Drive cycle operating point to the formal state file.

if nargin < 1 || strlength(string(modelDir)) == 0
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
        'RouteA_GasMixture_Derived');
end
candidateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_candidate_mode1_drive_cycle.mat');
formalFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
nextFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_next.mat');
backupFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_pre_promotion_backup.mat');

if ~isfile(candidateFile) || ~isfile(formalFile)
    error('RouteA:DriveCycleInitialStatePromotionInput', ...
        'Both formal Step state and Drive cycle candidate are required.');
end
if isfile(nextFile) || isfile(backupFile)
    error('RouteA:DriveCycleInitialStatePromotionRecoveryRequired', ...
        'Resolve an existing promotion recovery file before continuing.');
end

stepLoaded = load(formalFile, 'routeA_initial_state', ...
    'routeA_initial_metadata');
driveLoaded = load(candidateFile, 'routeA_initial_state', ...
    'routeA_initial_metadata');
validateState(stepLoaded, "Step");
validateState(driveLoaded, "Drive cycle");
stepMetadata = stepLoaded.routeA_initial_metadata;
driveMetadata = driveLoaded.routeA_initial_metadata;
if abs(stepMetadata.cegrValveMaxArea_m2 - ...
        driveMetadata.cegrValveMaxArea_m2) > ...
        1e-12 * max(1, abs(stepMetadata.cegrValveMaxArea_m2))
    error('RouteA:DriveCycleInitialStatePromotionParameterMismatch', ...
        'The Step and Drive cycle initial states use different valve areas.');
end

routeA_initial_state = stepLoaded.routeA_initial_state;
routeA_initial_metadata = stepMetadata;
routeA_initial_metadata.loadInputType = "Step";
routeA_initial_metadata.availableLoadInputTypes = ["Step", "Drive cycle"];
routeA_initial_state_drive_cycle = driveLoaded.routeA_initial_state;
routeA_initial_metadata_drive_cycle = driveMetadata;
routeA_initial_metadata_drive_cycle.availableLoadInputTypes = ...
    routeA_initial_metadata.availableLoadInputTypes;
save(nextFile, 'routeA_initial_state', 'routeA_initial_metadata', ...
    'routeA_initial_state_drive_cycle', ...
    'routeA_initial_metadata_drive_cycle', '-v7.3');

roundTrip = load(nextFile, 'routeA_initial_state', ...
    'routeA_initial_state_drive_cycle');
if ~isa(roundTrip.routeA_initial_state, ...
        'Simulink.op.ModelOperatingPoint') || ...
        ~isa(roundTrip.routeA_initial_state_drive_cycle, ...
        'Simulink.op.ModelOperatingPoint')
    error('RouteA:DriveCycleInitialStatePromotionWrite', ...
        'The composed formal state file did not round-trip correctly.');
end

[movedFormal, formalMessage] = movefile(formalFile, backupFile, 'f');
if ~movedFormal
    delete(nextFile);
    error('RouteA:DriveCycleInitialStatePromotionBackup', ...
        'Could not stage the existing formal state: %s.', formalMessage);
end
[movedNext, nextMessage] = movefile(nextFile, formalFile, 'f');
if ~movedNext
    movefile(backupFile, formalFile, 'f');
    error('RouteA:DriveCycleInitialStatePromotionMove', ...
        'Could not promote the composed formal state: %s.', nextMessage);
end
delete(backupFile);
delete(candidateFile);

metadata = routeA_initial_metadata;
assignin('base', 'routeA_platform_default_initial_metadata', metadata);
fprintf('Added the Drive cycle operating point to: %s\n', formalFile);
end

function validateState(loaded, expectedLoadInputType)
required = {'routeA_initial_state', 'routeA_initial_metadata'};
if ~builtin('all', isfield(loaded, required)) || ...
        ~isa(loaded.routeA_initial_state, 'Simulink.op.ModelOperatingPoint')
    error('RouteA:DriveCycleInitialStatePromotionState', ...
        'A required operating point is unavailable or invalid.');
end
metadata = loaded.routeA_initial_metadata;
requiredMetadata = {'cegrTopologyEnabled', 'cegrValveModeId', ...
    'egrReferenceKind', 'cegrValveMaxArea_m2'};
if ~builtin('all', isfield(metadata, requiredMetadata)) || ...
        ~metadata.cegrTopologyEnabled || metadata.cegrValveModeId ~= 1 || ...
        string(metadata.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:DriveCycleInitialStatePromotionMode', ...
        'An operating point is not a validated mode-1 zero-cEGR state.');
end
if expectedLoadInputType == "Drive cycle" && ...
        (~isfield(metadata, 'loadInputType') || ...
        string(metadata.loadInputType) ~= "Drive cycle")
    error('RouteA:DriveCycleInitialStatePromotionLoadVariant', ...
        'The candidate is not a Drive cycle operating point.');
end
end
