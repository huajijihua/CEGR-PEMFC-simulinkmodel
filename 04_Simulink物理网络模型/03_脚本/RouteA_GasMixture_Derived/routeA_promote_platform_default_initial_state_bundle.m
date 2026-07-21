function metadata = routeA_promote_platform_default_initial_state_bundle(modelDir)
% Atomically replace all Electrical Load operating-point variants together.
%
% A structural change below Electrical Load invalidates every saved
% ModelOperatingPoint, including inactive load branches. This promoter only
% accepts three freshly generated mode-1 candidates and never combines one
% new state with older Step or Drive cycle states.

if nargin < 1 || strlength(string(modelDir)) == 0
    scriptDir = fileparts(mfilename('fullpath'));
    modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
        'RouteA_GasMixture_Derived');
end
modelDir = char(modelDir);

files = struct();
files.step = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_candidate_mode1.mat');
files.drive = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_candidate_mode1_drive_cycle.mat');
files.voltage = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_candidate_mode1_voltage.mat');
files.formal = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
files.next = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_next.mat');
files.backup = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state_pre_promotion_backup.mat');

requiredFiles = {files.step, files.drive, files.voltage};
if ~builtin('all', cellfun(@isfile, requiredFiles))
    error('RouteA:InitialStateBundlePromotionInput', ...
        'Fresh Step, Drive cycle, and Voltage candidates are all required.');
end
if isfile(files.next) || isfile(files.backup)
    error('RouteA:InitialStateBundlePromotionRecoveryRequired', ...
        'Resolve an existing initial-state promotion recovery file first.');
end

step = loadCandidate(files.step, "Step");
drive = loadCandidate(files.drive, "Drive cycle");
voltage = loadCandidate(files.voltage, "Voltage");
validateCommonMetadata(step.metadata, drive.metadata, voltage.metadata);
promotionTime = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

routeA_initial_state = step.state;
routeA_initial_metadata = step.metadata;
routeA_initial_metadata.loadInputType = "Step";
routeA_initial_metadata.availableLoadInputTypes = ...
    ["Step", "Drive cycle", "Voltage"];
routeA_initial_metadata.temporary = false;
routeA_initial_metadata.promotedAt = promotionTime;
routeA_initial_state_drive_cycle = drive.state;
routeA_initial_metadata_drive_cycle = drive.metadata;
routeA_initial_metadata_drive_cycle.availableLoadInputTypes = ...
    routeA_initial_metadata.availableLoadInputTypes;
routeA_initial_metadata_drive_cycle.temporary = false;
routeA_initial_metadata_drive_cycle.promotedAt = promotionTime;
routeA_initial_state_voltage = voltage.state;
routeA_initial_metadata_voltage = voltage.metadata;
routeA_initial_metadata_voltage.availableLoadInputTypes = ...
    routeA_initial_metadata.availableLoadInputTypes;
routeA_initial_metadata_voltage.temporary = false;
routeA_initial_metadata_voltage.promotedAt = promotionTime;

save(files.next, 'routeA_initial_state', 'routeA_initial_metadata', ...
    'routeA_initial_state_drive_cycle', ...
    'routeA_initial_metadata_drive_cycle', ...
    'routeA_initial_state_voltage', ...
    'routeA_initial_metadata_voltage', '-v7.3');
validateBundleRoundTrip(files.next);

hadFormal = isfile(files.formal);
if hadFormal
    [movedFormal, formalMessage] = movefile(files.formal, files.backup, 'f');
    if ~movedFormal
        delete(files.next);
        error('RouteA:InitialStateBundlePromotionBackup', ...
            'Could not stage the existing formal file: %s.', formalMessage);
    end
end
[movedNext, nextMessage] = movefile(files.next, files.formal, 'f');
if ~movedNext
    if hadFormal && isfile(files.backup)
        movefile(files.backup, files.formal, 'f');
    end
    error('RouteA:InitialStateBundlePromotionMove', ...
        'Could not promote the initial-state bundle: %s.', nextMessage);
end
if hadFormal && isfile(files.backup)
    delete(files.backup);
end
delete(files.step);
delete(files.drive);
delete(files.voltage);

metadata = routeA_initial_metadata;
assignin('base', 'routeA_platform_default_initial_metadata', metadata);
fprintf('Promoted Route A Step, Drive cycle, and Voltage initial states: %s\n', ...
    files.formal);
end

function candidate = loadCandidate(file, expectedLoadInputType)
loaded = load(file, 'routeA_initial_state', 'routeA_initial_metadata');
if ~isfield(loaded, 'routeA_initial_state') || ...
        ~isfield(loaded, 'routeA_initial_metadata') || ...
        ~isa(loaded.routeA_initial_state, 'Simulink.op.ModelOperatingPoint')
    error('RouteA:InitialStateBundlePromotionState', ...
        'Candidate %s does not contain a valid ModelOperatingPoint.', file);
end
metadata = loaded.routeA_initial_metadata;
required = {'model', 'loadInputType', 'snapshotTimeS', ...
    'cegrTopologyEnabled', 'cegrValveModeId', 'egrReferenceKind', ...
    'cegrValveMaxArea_m2'};
if ~builtin('all', isfield(metadata, required)) || ...
        string(metadata.loadInputType) ~= expectedLoadInputType || ...
        ~metadata.cegrTopologyEnabled || metadata.cegrValveModeId ~= 1 || ...
        string(metadata.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:InitialStateBundlePromotionMetadata', ...
        'Candidate %s is not the required %s mode-1 zero-cEGR state.', ...
        file, expectedLoadInputType);
end
candidate = struct('state', loaded.routeA_initial_state, ...
    'metadata', metadata);
end

function validateCommonMetadata(step, drive, voltage)
models = [string(step.model), string(drive.model), string(voltage.model)];
if ~builtin('all', models == models(1))
    error('RouteA:InitialStateBundlePromotionModel', ...
        'The three initial-state candidates belong to different models.');
end
areas = [step.cegrValveMaxArea_m2, drive.cegrValveMaxArea_m2, ...
    voltage.cegrValveMaxArea_m2];
if max(abs(areas - areas(1))) > 1e-12 * max(1, abs(areas(1)))
    error('RouteA:InitialStateBundlePromotionParameter', ...
        'The three initial-state candidates use different cEGR valve areas.');
end
end

function validateBundleRoundTrip(file)
loaded = load(file, 'routeA_initial_state', ...
    'routeA_initial_state_drive_cycle', 'routeA_initial_state_voltage', ...
    'routeA_initial_metadata', 'routeA_initial_metadata_drive_cycle', ...
    'routeA_initial_metadata_voltage');
if ~isa(loaded.routeA_initial_state, 'Simulink.op.ModelOperatingPoint') || ...
        ~isa(loaded.routeA_initial_state_drive_cycle, ...
        'Simulink.op.ModelOperatingPoint') || ...
        ~isa(loaded.routeA_initial_state_voltage, ...
        'Simulink.op.ModelOperatingPoint')
    error('RouteA:InitialStateBundlePromotionWrite', ...
        'The composed initial-state bundle did not round-trip correctly.');
end
expected = ["Step", "Drive cycle", "Voltage"];
actual = [string(loaded.routeA_initial_metadata.loadInputType), ...
    string(loaded.routeA_initial_metadata_drive_cycle.loadInputType), ...
    string(loaded.routeA_initial_metadata_voltage.loadInputType)];
if ~builtin('all', actual == expected)
    error('RouteA:InitialStateBundlePromotionMode', ...
        'The composed bundle does not preserve the three load variants.');
end
metadata = {loaded.routeA_initial_metadata, ...
    loaded.routeA_initial_metadata_drive_cycle, ...
    loaded.routeA_initial_metadata_voltage};
isFormal = cellfun(@(item) isfield(item, 'temporary') && ...
    ~item.temporary, metadata);
if ~builtin('all', isFormal)
    error('RouteA:InitialStateBundlePromotionFormalMetadata', ...
        'The promoted bundle still contains a temporary initial state.');
end
end
