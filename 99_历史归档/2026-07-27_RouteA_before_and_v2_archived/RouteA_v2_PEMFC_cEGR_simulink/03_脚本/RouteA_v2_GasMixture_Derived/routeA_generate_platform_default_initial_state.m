function metadata = routeA_generate_platform_default_initial_state(userCfg)
% Generate one Route A platform-default initial-state candidate.
%
% The electrical load branch is selected by userCfg.loadInputType:
% Current, Power, or Voltage. A no-argument call remains the compatible
% Current candidate entry point. Power and Voltage candidates are conditioned
% from the validated Current source candidate.

if nargin < 1 || isempty(userCfg)
    userCfg = struct();
end
if ~isstruct(userCfg) || ~isscalar(userCfg)
    error('RouteA:InitialStateConfig', ...
        'userCfg must be a scalar struct.');
end

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_v2_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01';
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));

cfg = defaultInitialStateConfig();
cfg = mergeKnownFields(cfg, userCfg);
cfg.loadInputType = canonicalLoadInputType(cfg.loadInputType);

source = struct();
if cfg.loadInputType ~= "Current"
    source = loadCurrentSource(cfg.sourceInitialStateFile, modelDir, model);
    if cfg.loadInputType == "Power"
        if isnan(cfg.targetPower_kW)
            cfg.targetPower_kW = source.physicalSummary.stackPower_kW;
        end
    else
        if isnan(cfg.targetVoltage_V)
            cfg.targetVoltage_V = source.physicalSummary.stackVoltage_V;
        end
    end
end

candidateSuffix = lower(char(cfg.loadInputType));
candidateFile = fullfile(modelDir, sprintf( ...
    'RouteA_v2_platform_default_initial_state_candidate_mode1_%s.mat', ...
    candidateSuffix));
prepareCfg = rmfield(cfg, 'sourceInitialStateFile');
[routeA_initial_state, metadata, audit] = ...
    routeA_prepare_parameter_consistent_initial_state( ...
    model, modelFile, struct(), prepareCfg);

if ~audit.periodic.passed
    error('RouteA:InitialStateQuietWindow', ...
        'The %s candidate did not pass the post-purge quiet-window gate.', ...
        cfg.loadInputType);
end
if cfg.loadInputType ~= "Current"
    assertSourceCompatibility(source, metadata, cfg.loadInputType);
end

metadata.schema = sprintf( ...
    'RouteA_v2_platform_default_initial_state_v10_mode1_%s', ...
    candidateSuffix);
metadata.candidateSource = ...
    "routeA_generate_platform_default_initial_state";
metadata.loadInputType = cfg.loadInputType;
metadata.targetCurrentA = metadata.physicalSummary.stackCurrent_A;
metadata.stateClass = string(class(routeA_initial_state));
if cfg.loadInputType == "Power"
    metadata.sourceCurrentSnapshotTimeS = source.snapshotTimeS;
    metadata.sourceCurrentPower_kW = source.physicalSummary.stackPower_kW;
    metadata.sourceCurrentStateSchema = source.schema;
elseif cfg.loadInputType == "Voltage"
    metadata.sourceCurrentSnapshotTimeS = source.snapshotTimeS;
    metadata.sourceCurrentVoltage_V = source.physicalSummary.stackVoltage_V;
    metadata.sourceCurrentStateSchema = source.schema;
end

routeA_initial_metadata = metadata;
save(candidateFile, 'routeA_initial_state', ...
    'routeA_initial_metadata', '-v7.3');
assignCandidateMetadata(cfg.loadInputType, routeA_initial_metadata);
fprintf('Saved Route A %s initial-state candidate: %s\n', ...
    cfg.loadInputType, candidateFile);
clear cleanup;
end

function cfg = defaultInitialStateConfig()
cfg = struct( ...
    'currentDensity_A_cm2', 0.1, ...
    'targetAirEquivalentOer', 3, ...
    'loadInputType', "Current", ...
    'targetPower_kW', NaN, ...
    'targetVoltage_V', NaN, ...
    'sourceInitialStateFile', "", ...
    'loadRampStartTime_s', 0.5, ...
    'loadRampDuration_s', 120, ...
    'solver', "VariableStepAuto", ...
    'relativeTolerance', 1e-3, ...
    'absoluteTolerance', 1e-3, ...
    'maxStep_s', 5, ...
    'checkpointStopTime_s', 3600, ...
    'probeStopTime_s', 10000, ...
    'postPurgeOffset_s', 100, ...
    'postPurgeQuietWindow_s', 60, ...
    'relativeVariationLimit', 0.005);
end

function result = mergeKnownFields(defaults, user)
result = defaults;
names = fieldnames(user);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(result, name)
        error('RouteA:InitialStateConfigField', ...
            'Unsupported initial-state field: %s.', name);
    end
    result.(name) = user.(name);
end
end

function type = canonicalLoadInputType(value)
value = lower(string(value));
if ~isscalar(value)
    error('RouteA:InitialStateLoadInputType', ...
        'loadInputType must be Current, Power, or Voltage.');
end
switch value
    case "current"
        type = "Current";
    case "power"
        type = "Power";
    case "voltage"
        type = "Voltage";
    otherwise
        error('RouteA:InitialStateLoadInputType', ...
            'loadInputType must be Current, Power, or Voltage.');
end
end

function source = loadCurrentSource(configuredFile, modelDir, model)
if strlength(string(configuredFile)) == 0
    candidateFile = fullfile(modelDir, ...
        'RouteA_v2_platform_default_initial_state_candidate_mode1_current.mat');
    bundleFile = fullfile(modelDir, ...
        'RouteA_v2_platform_default_initial_state.mat');
    if isfile(candidateFile)
        configuredFile = candidateFile;
    else
        configuredFile = bundleFile;
    end
end
sourceFile = char(configuredFile);
if ~isfile(sourceFile)
    error('RouteA:InitialStateCurrentSourceMissing', ...
        'The Current source initial-state file does not exist: %s.', ...
        sourceFile);
end
loaded = load(sourceFile);
if isfield(loaded, 'routeA_initial_metadata')
    source = loaded.routeA_initial_metadata;
elseif isfield(loaded, 'routeA_initial_metadata_current')
    source = loaded.routeA_initial_metadata_current;
else
    error('RouteA:InitialStateCurrentSourceMetadata', ...
        'The Current source file has no recognized metadata variable: %s.', ...
        sourceFile);
end
if ~isstruct(source) || ~isscalar(source)
    error('RouteA:InitialStateCurrentSourceMetadata', ...
        'The Current source metadata must be a scalar struct: %s.', ...
        sourceFile);
end
required = {'schema', 'model', 'snapshotTimeS', 'physicalSummary', ...
    'cegrTopologyEnabled', 'cegrValveModeId', 'egrReferenceKind', ...
    'cegrValveMaxArea_m2', 'loadInputType', ...
    'commandProfileSchema', 'commandProfileFields', ...
    'commandProfileBaseline', 'baselineElectricalCommand', ...
    'sourceConditionerState', 'modelVersion'};
for idx = 1:numel(required)
    if ~isfield(source, required{idx})
        error('RouteA:InitialStateCurrentSourceMetadata', ...
            'Current source metadata is missing field %s.', required{idx});
    end
end
if string(source.model) ~= string(model)
    error('RouteA:InitialStateCurrentSourceModel', ...
        'Current source model does not match the Route A model.');
end
if ~contains(string(source.schema), '_v10_')
    error('RouteA:InitialStateCurrentSourceSchema', ...
        'Power/Voltage conditioning requires a v10 Current source candidate.');
end
if string(source.loadInputType) ~= "Current"
    error('RouteA:InitialStateCurrentSourceType', ...
        'Power/Voltage conditioning requires a Current source candidate.');
end
if ~source.cegrTopologyEnabled || source.cegrValveModeId ~= 1 || ...
        string(source.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:InitialStateCurrentSourceCEGR', ...
        'Current source must use the mode-1 zero-target cEGR reference state.');
end
if ~isfield(source.physicalSummary, 'stackPower_kW') || ...
        ~isfield(source.physicalSummary, 'stackVoltage_V')
    error('RouteA:InitialStateCurrentSourceSummary', ...
        'Current source physicalSummary lacks power or voltage.');
end
end

function assertSourceCompatibility(source, metadata, loadInputType)
if source.cegrValveMaxArea_m2 ~= metadata.cegrValveMaxArea_m2
    error('RouteA:InitialStateSourceValveArea', ...
        '%s candidate valve area differs from the Current source.', ...
        loadInputType);
end
if metadata.cegrValveModeId ~= source.cegrValveModeId || ...
        ~metadata.cegrTopologyEnabled
    error('RouteA:InitialStateSourceCEGR', ...
        '%s candidate did not retain the Current source cEGR topology.', ...
        loadInputType);
end
if ~isequal(metadata.sourceConditionerState, source.sourceConditionerState)
    error('RouteA:InitialStateSourceConditioner', ...
        '%s candidate source-conditioner topology or parameters differ from Current.', ...
        loadInputType);
end
end

function assignCandidateMetadata(type, metadata)
switch type
    case "Current"
        variableName = 'routeA_platform_default_current_candidate_metadata';
    case "Power"
        variableName = 'routeA_platform_default_power_candidate_metadata';
    case "Voltage"
        variableName = 'routeA_platform_default_voltage_candidate_metadata';
end
assignin('base', variableName, metadata);
end
