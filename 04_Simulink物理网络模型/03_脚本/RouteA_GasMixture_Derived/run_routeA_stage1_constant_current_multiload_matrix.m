function matrix = run_routeA_stage1_constant_current_multiload_matrix(studyCfg)
% Route A Stage 1 normal-operation constant-current multi-load matrix.
%
% This runner is the Stage 1 main evidence for low/nominal/high load. Every
% case uses one common mode-1 operating point (the saved formal state, or a
% temporary parameter-consistent state when a compile-time override is used),
% a fixed 600 s logical
% study, a common [540,600) s tail window, and a runtime MaxStep of 5 s.
% These are study-protocol settings applied through SimulationInput; they do
% not modify the saved model, platform_default parameters, or controller
% semantics. Air mode 2 holds total compressor flow from a fresh-air-
% equivalent OER command; it does not hold actual lambda_ca_in constant after
% cEGR changes composition.
%
% studyCfg optionally accepts valveAreaFactor (default 2), runPreflight
% (default true), and protocol overrides. The valve factor is a temporary
% study configuration only: it is applied to the model workspace during each
% run and never writes the formal parameter layer, saved platform operating
% point, or model file.

if nargin < 1 || isempty(studyCfg)
    studyCfg = struct();
end

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
routeA_multiload_cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));
resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
cfg = matrixConfig(model, modelDir, studyCfg);
cfg = prepareStudyInitialState(model, modelFile, cfg);
[cases, caseOutputs, execution] = runAllCases(model, modelFile, modelDir, cfg);
if execution.matrixComplete
    [cases, loadGroups] = finalizeLoadGroups(cases, cfg);
    [waterLedger, waterLedgerPassed] = runSharedWaterLedger( ...
        caseOutputs, cfg, model);
else
    [cases, loadGroups] = classifyIncompleteMatrix(cases, cfg, execution);
    waterLedger = skippedWaterLedger(execution);
    waterLedgerPassed = false;
end

matrix = summarizeMatrix(cases, loadGroups, waterLedger, ...
    waterLedgerPassed, cfg, execution);
assignin('base', 'routeA_stage1_constant_current_multiload_matrix', matrix);
assignin('base', 'routeA_stage1_constant_current_multiload_summary', ...
    matrix.summaryTable);
assignin('base', 'routeA_stage1_constant_current_multiload_water_ledger', ...
    matrix.waterLedger);
displayMatrix(matrix);

% SimulationOutput objects are retained only for the shared water audit.
clear caseOutputs;
clear routeA_multiload_cleanup;
end

function cfg = matrixConfig(model, modelDir, studyCfg)
studyCfg = normalizeStudyConfig(studyCfg);
initialStateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
loaded = load(initialStateFile, 'routeA_initial_metadata');
if ~isfield(loaded, 'routeA_initial_metadata')
    error('RouteA:MultiLoadInitialState', ...
        'The platform_default initial-state metadata is unavailable.');
end
metadata = loaded.routeA_initial_metadata;
requiredMetadata = {'snapshotTimeS', 'targetCurrentA', ...
    'currentDensity_A_cm2', 'purgePeriodS', 'cegrTopologyEnabled', ...
    'cegrValveModeId', 'egrReferenceKind'};
if ~builtin('all', isfield(metadata, requiredMetadata))
    error('RouteA:MultiLoadInitialStateMetadata', ...
        'The platform_default initial-state metadata is incomplete.');
end
if ~metadata.cegrTopologyEnabled || metadata.cegrValveModeId ~= 1 || ...
        string(metadata.egrReferenceKind) ~= "mode1_zero_target_near_zero"
    error('RouteA:MultiLoadInitialStateMode', ...
        'The multi-load matrix requires the formal mode-1 zero-target state.');
end

mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
parameterLayer = string(mw.getVariable('routeA_parameter_layer'));
externalCaseEnabled = logical(mw.getVariable('routeA_external_case_enabled'));
if parameterLayer ~= "platform_default" || externalCaseEnabled
    error('RouteA:MultiLoadParameterBoundary', ...
        ['The Stage 1 matrix requires platform_default with ', ...
        'external_case disabled.']);
end
stackAreaCm2 = mw.getVariable('stack_area');
stackCells = mw.getVariable('stack_num_cells');
maxValveArea = mw.getVariable('cegr_valve_max_area');
rpmTable = mw.getVariable('comp_rpm_TLU');
validateattributes(stackAreaCm2, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(stackCells, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(maxValveArea, {'numeric'}, {'scalar', 'positive', 'finite'});
validateattributes(rpmTable, {'numeric'}, {'vector', 'nonempty', 'finite'});

cfg = struct();
cfg.model = string(model);
cfg.initialStateFile = initialStateFile;
cfg.initialStateMetadata = metadata;
cfg.formalInitialStateMetadata = metadata;
cfg.initialState = [];
cfg.initialStateKind = "formal_platform_default";
cfg.preconditionAudit = struct();
cfg.parameterLayer = parameterLayer;
cfg.externalCaseEnabled = externalCaseEnabled;
cfg.airControlBasis = ...
    "target_total_compressor_mdot_from_fresh_air_equivalent_oer";
cfg.stackAreaCm2 = stackAreaCm2;
cfg.stackCells = stackCells;
cfg.valveAreaFactor = studyCfg.valveAreaFactor;
cfg.parameterOverrides = struct();
if abs(cfg.valveAreaFactor - 1) > eps
    cfg.baseValveMaxArea_m2 = maxValveArea;
    cfg.requestedValveMaxArea_m2 = maxValveArea * cfg.valveAreaFactor;
    cfg.parameterOverrides.cegr_valve_max_area = ...
        cfg.requestedValveMaxArea_m2;
else
    cfg.baseValveMaxArea_m2 = maxValveArea;
    cfg.requestedValveMaxArea_m2 = maxValveArea;
end
if abs(cfg.valveAreaFactor - 1) > eps
    cfg.parameterOverrides.cegr_valve_max_area = ...
        cfg.requestedValveMaxArea_m2;
end
cfg.maxValveArea_m2 = cfg.requestedValveMaxArea_m2;
cfg.compressorRpmLookupBounds = [min(rpmTable), max(rpmTable)];
cfg.researchDuration_s = studyCfg.researchDuration_s;
cfg.tailLogicalWindow_s = studyCfg.tailLogicalWindow_s;
cfg.studyMaxStep_s = studyCfg.studyMaxStep_s;
cfg.commandStepTime_s = 0.5;
cfg.currentTrackingStartOffset_s = 1.0;
cfg.targetRatios = [0, 0.10, 0.30];
cfg.commandStepOffset_s = 0.5;
cfg.currentTrackingTolerance_A = 5e-3;
cfg.lambdaLowerBound = 1;
cfg.powerSpanAbsoluteTolerance_kW = ...
    studyCfg.powerSpanAbsoluteTolerance_kW;
cfg.powerSpanRelativeTolerance = ...
    studyCfg.powerSpanRelativeTolerance;
cfg.airMdotTrackingRelativeTolerance = 0.02;
cfg.airMdotTrackingAbsoluteTolerance_kg_s = 5e-4;
cfg.runPreflight = studyCfg.runPreflight;
cfg.preflightCaseIds = ["high_cegr_0p30", "nominal_cegr_0p30"];
cfg.caseIds = studyCfg.caseIds;
cfg.purgeDropSlope_1_s = -0.02;
cfg.faradayConstant_C_mol = 96485.33212;
cfg.molarMass_kg_mol = [0.0280134, 0.0319988, 0.00201588, 0.01801528];
cfg.gas = struct( ...
    'n2Index', 1, ...
    'o2Index', 2, ...
    'h2oIndex', 4, ...
    'absoluteResidualTolerance_kg_s', 5e-4, ...
    'relativeResidualTolerance', 0.05);
cfg.tailSpan = struct( ...
    'egrRatio', 0.002, ...
    'egrMdot_kg_s', 5e-4, ...
    'freshAirApprox_kg_s', 5e-4, ...
    'inletTotalMdot_kg_s', 5e-4, ...
    'stackCurrent_A', 0.5, ...
    'stackVoltage_V', 0.5, ...
    'stackPower_kW', cfg.powerSpanAbsoluteTolerance_kW, ...
    'stackTemperature_C', 0.5, ...
    'compressorMdot_kg_s', 5e-4, ...
    'compressorMdotSet_kg_s', 5e-4, ...
    'compressorMdotTrackingError_kg_s', 5e-4, ...
    'airControlError_kg_s', 5e-4, ...
    'compressorTemperature_K', 0.5, ...
    'rhCaIn', 0.02, ...
    'rhCaOut', 0.02, ...
    'waterSeparator', 5e-5, ...
    'lambdaCaIn', 0.02, ...
    'inletO2MassFraction', 0.002);
cfg.loads = [ ...
    loadDefinition("low", 0.2, 4, cfg.stackAreaCm2); ...
    loadDefinition("nominal", 0.7, 3, cfg.stackAreaCm2); ...
    loadDefinition("high", 1.2, 2, cfg.stackAreaCm2)];
cfg = assignRuntimeWindows(cfg, metadata);
end

function studyCfg = normalizeStudyConfig(studyCfg)
if ~isstruct(studyCfg) || numel(studyCfg) ~= 1
    error('RouteA:MultiLoadStudyConfig', ...
        'The study configuration must be a scalar struct.');
end
defaults = struct( ...
    'valveAreaFactor', 2, ...
    'runPreflight', true, ...
    'researchDuration_s', 600, ...
    'tailLogicalWindow_s', [540, 600], ...
    'studyMaxStep_s', 5, ...
    'powerSpanAbsoluteTolerance_kW', 0.05, ...
    'powerSpanRelativeTolerance', 0.005, ...
    'caseIds', strings(1, 0));
names = fieldnames(studyCfg);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(defaults, name)
        error('RouteA:MultiLoadStudyConfigField', ...
            'Unsupported study configuration field: %s.', name);
    end
    defaults.(name) = studyCfg.(name);
end
validateattributes(defaults.valveAreaFactor, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite'});
validateattributes(defaults.runPreflight, {'logical', 'numeric'}, ...
    {'scalar'});
validateattributes(defaults.researchDuration_s, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite'});
validateattributes(defaults.tailLogicalWindow_s, {'numeric'}, ...
    {'vector', 'numel', 2, 'real', 'nonnegative', 'finite'});
defaults.tailLogicalWindow_s = defaults.tailLogicalWindow_s(:).';
if defaults.tailLogicalWindow_s(2) <= defaults.tailLogicalWindow_s(1) || ...
        defaults.tailLogicalWindow_s(2) > defaults.researchDuration_s
    error('RouteA:MultiLoadTailWindow', ...
        'The logical tail window must be increasing and within the study duration.');
end
validateattributes(defaults.studyMaxStep_s, {'numeric'}, ...
    {'scalar', 'real', 'positive', 'finite'});
validateattributes(defaults.powerSpanAbsoluteTolerance_kW, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative', 'finite'});
validateattributes(defaults.powerSpanRelativeTolerance, {'numeric'}, ...
    {'scalar', 'real', 'nonnegative', 'finite'});
if ~(isstring(defaults.caseIds) || ischar(defaults.caseIds) || ...
        iscellstr(defaults.caseIds))
    error('RouteA:MultiLoadCaseIds', ...
        'caseIds must be a string, character vector, or cell array of text.');
end
defaults.caseIds = string(defaults.caseIds);
defaults.caseIds = defaults.caseIds(:).';
defaults.caseIds = defaults.caseIds(strlength(defaults.caseIds) > 0);
defaults.caseIds = unique(defaults.caseIds, 'stable');
defaults.runPreflight = logical(defaults.runPreflight);
studyCfg = defaults;
end

function cfg = assignRuntimeWindows(cfg, metadata)
cfg.researchStartTime_s = metadata.snapshotTimeS;
cfg.modelStopTime_s = cfg.researchStartTime_s + cfg.researchDuration_s;
cfg.tailWindow_s = cfg.researchStartTime_s + cfg.tailLogicalWindow_s;
cfg.currentTrackingWindow_s = [ ...
    cfg.researchStartTime_s + cfg.currentTrackingStartOffset_s, ...
    cfg.modelStopTime_s];
cfg.lambdaTransitionDiagnosticWindow_s = [ ...
    cfg.currentTrackingWindow_s(1), cfg.tailWindow_s(1)];
end

function cfg = prepareStudyInitialState(model, modelFile, cfg)
if isempty(fieldnames(cfg.parameterOverrides))
    cfg.initialStateKind = "formal_platform_default";
    return;
end
[initialState, metadata, audit] = ...
    routeA_prepare_parameter_consistent_initial_state( ...
    model, modelFile, cfg.parameterOverrides, ...
    struct('maxStep_s', cfg.studyMaxStep_s));
if ~isa(initialState, 'Simulink.op.ModelOperatingPoint')
    error('RouteA:MultiLoadTemporaryStateClass', ...
        'The parameter-consistent initial state is not a ModelOperatingPoint.');
end
cfg.initialState = initialState;
cfg.initialStateMetadata = metadata;
cfg.initialStateKind = "temporary_parameter_consistent";
cfg.preconditionAudit = audit;
cfg = assignRuntimeWindows(cfg, metadata);
end

function load = loadDefinition( ...
    id, currentDensity_A_cm2, targetAirEquivalentOer, stackAreaCm2)
load = struct( ...
    'id', string(id), ...
    'currentDensity_A_cm2', currentDensity_A_cm2, ...
    'targetCurrentA', currentDensity_A_cm2 * stackAreaCm2, ...
    'targetAirEquivalentOer', targetAirEquivalentOer, ...
    'targetOer', targetAirEquivalentOer); % Legacy field for helper compatibility.
end

function [cases, caseOutputs, execution] = runAllCases( ...
    model, modelFile, modelDir, cfg)
caseCount = numel(cfg.loads) * numel(cfg.targetRatios);
cases = repmat(emptyCaseResult(), caseCount, 1);
caseOutputs = repmat(emptyCaseOutput(), caseCount, 1);
index = 0;
for loadIdx = 1:numel(cfg.loads)
    load = cfg.loads(loadIdx);
    for ratioIdx = 1:numel(cfg.targetRatios)
        index = index + 1;
        targetRatio = cfg.targetRatios(ratioIdx);
        [cases(index), caseOutputs(index)] = initializeMatrixCase( ...
            cfg, load, targetRatio);
    end
end

allCaseIds = string({cases.caseId});
if isempty(cfg.caseIds)
    selectedIndices = 1:caseCount;
else
    selectedIndices = zeros(1, numel(cfg.caseIds));
    for idx = 1:numel(cfg.caseIds)
        matches = find(allCaseIds == cfg.caseIds(idx));
        if numel(matches) ~= 1
            error('RouteA:MultiLoadCaseSelection', ...
                'Requested case is unavailable: %s.', cfg.caseIds(idx));
        end
        selectedIndices(idx) = matches;
    end
end
if cfg.runPreflight
    preflightIndices = zeros(1, numel(cfg.preflightCaseIds));
    for idx = 1:numel(cfg.preflightCaseIds)
        matches = find(allCaseIds == cfg.preflightCaseIds(idx));
        if numel(matches) ~= 1
            error('RouteA:MultiLoadPreflightCase', ...
                'Required preflight case is unavailable: %s.', ...
                cfg.preflightCaseIds(idx));
        end
        preflightIndices(idx) = matches;
        if ~ismember(matches, selectedIndices)
            error('RouteA:MultiLoadPreflightSelection', ...
                'The requested case set omits required preflight case: %s.', ...
                cfg.preflightCaseIds(idx));
        end
    end
else
    preflightIndices = zeros(1, 0);
end
runOrder = [preflightIndices, setdiff(selectedIndices, preflightIndices, ...
    'stable')];
execution = struct( ...
    'preflightEnabled', cfg.runPreflight, ...
    'preflightCaseIds', cfg.preflightCaseIds, ...
    'requestedCaseIds', allCaseIds(selectedIndices), ...
    'executedCaseIds', strings(1, 0), ...
    'preflightPassed', ~cfg.runPreflight, ...
    'scopeComplete', false, ...
    'matrixComplete', false, ...
    'halted', false, ...
    'haltReason', "");
for runIdx = 1:numel(runOrder)
    caseIndex = runOrder(runIdx);
    load = cfg.loads(find(string({cfg.loads.id}) == cases(caseIndex).loadId, 1));
    [cases(caseIndex), caseOutputs(caseIndex)] = runMatrixCase( ...
        model, modelFile, modelDir, cfg, load, cases(caseIndex).targetRatio);
    execution.executedCaseIds(end + 1) = cases(caseIndex).caseId;
    if cfg.runPreflight && runIdx <= numel(preflightIndices) && ...
            ~cases(caseIndex).localPassed
        execution.halted = true;
        execution.haltReason = "preflight_failed:" + ...
            cases(caseIndex).caseId + ":" + cases(caseIndex).failureCategory;
        for pendingIdx = setdiff(selectedIndices, runOrder(1:runIdx), 'stable')
            cases(pendingIdx).failureCategory = "preflight_blocked";
        end
        return;
    end
    if cfg.runPreflight && runIdx == numel(preflightIndices)
        execution.preflightPassed = true;
    end
end
execution.scopeComplete = builtin('all', [cases(selectedIndices).simCompleted]);
execution.matrixComplete = numel(selectedIndices) == caseCount && ...
    execution.scopeComplete;
if ~execution.scopeComplete
    execution.halted = true;
    execution.haltReason = "simulation_incomplete";
elseif ~execution.matrixComplete
    execution.haltReason = "partial_matrix_scope";
end
end

function [result, caseOutput] = runMatrixCase( ...
    model, modelFile, modelDir, cfg, load, targetRatio)
[base, caseOutput] = initializeMatrixCase(cfg, load, targetRatio);

try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    applyStudyParameterOverrides(model, cfg);
    commandStepTime_s = cfg.researchStartTime_s + cfg.commandStepOffset_s;
    routeA_apply_constant_current_step(model, ...
        cfg.initialStateMetadata.targetCurrentA, load.targetCurrentA, ...
        commandStepTime_s);
    in = Simulink.SimulationInput(model);
    if cfg.initialStateKind == "temporary_parameter_consistent"
        in = in.setInitialState(cfg.initialState);
        initialStateMetadata = cfg.initialStateMetadata;
    else
        [in, initialStateMetadata] = routeA_attach_platform_default_initial_state( ...
            in, model, modelDir, cfg.initialStateFile);
    end
    routeA_mark_observability_signals(model);
    in = in.setModelParameter( ...
        'StopTime', sprintf('%.16g', cfg.modelStopTime_s), ...
        'MaxStep', sprintf('%.16g', cfg.studyMaxStep_s), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'all');
    in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
    in = in.setVariable('routeA_target_oer', ...
        load.targetAirEquivalentOer, ...
        'Workspace', model);
    in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
    in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
    in = in.setVariable('routeA_egr_target_input_mode_id', 1, ...
        'Workspace', model);
    in = in.setVariable('routeA_target_egr_ratio_comp_in', targetRatio, ...
        'Workspace', model);
    in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
        [cfg.researchStartTime_s, 0; ...
        commandStepTime_s - 1e-3, 0; ...
        commandStepTime_s, targetRatio; ...
        cfg.modelStopTime_s, targetRatio], 'Workspace', model);

    out = sim(in);
    result = collectCaseResult(out, model, cfg, base);
    result.initialState = initialStateMetadata;
    caseOutput.out = out;
    caseOutput.initialState = initialStateMetadata;
catch ME
    result = base;
    result.errorId = string(ME.identifier);
    result.errorMessage = string(ME.message);
    if ~isempty(ME.stack)
        result.errorLocation = string(ME.stack(1).name) + ":" + ...
            string(ME.stack(1).line);
    end
    result.failureCategory = "simulation_or_collection_error";
end
end

function [base, caseOutput] = initializeMatrixCase(cfg, load, targetRatio)
base = emptyCaseResult();
base.caseId = caseId(load.id, targetRatio);
base.loadId = load.id;
base.currentDensity_A_cm2 = load.currentDensity_A_cm2;
base.targetCurrentA = load.targetCurrentA;
base.targetAirEquivalentOer = load.targetAirEquivalentOer;
base.targetOer = load.targetOer;
base.targetRatio = targetRatio;
base.modeId = 1;
base.initialStateKind = cfg.initialStateKind;
base.valveAreaFactor = cfg.valveAreaFactor;
base.requestedValveMaxArea_m2 = cfg.requestedValveMaxArea_m2;
base.researchStartModelTime_s = cfg.researchStartTime_s;
base.researchDuration_s = cfg.researchDuration_s;
base.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
base.tailModelWindow_s = cfg.tailWindow_s;
base.currentTrackingWindow_s = cfg.currentTrackingWindow_s;
base.lambdaTransitionDiagnosticWindow_s = ...
    cfg.lambdaTransitionDiagnosticWindow_s;
caseOutput = emptyCaseOutput();
caseOutput.caseId = base.caseId;
caseOutput.loadId = load.id;
caseOutput.currentDensity_A_cm2 = load.currentDensity_A_cm2;
caseOutput.targetCurrentA = load.targetCurrentA;
caseOutput.targetAirEquivalentOer = load.targetAirEquivalentOer;
caseOutput.targetOer = load.targetOer;
caseOutput.targetRatio = targetRatio;
caseOutput.modeId = 1;
end

function applyStudyParameterOverrides(model, cfg)
if isempty(fieldnames(cfg.parameterOverrides))
    return;
end
mw = get_param(model, 'ModelWorkspace');
names = fieldnames(cfg.parameterOverrides);
for idx = 1:numel(names)
    name = names{idx};
    try
        mw.getVariable(name);
    catch
        error('RouteA:MultiLoadUnknownOverride', ...
            'The model workspace does not define: %s.', name);
    end
    mw.assignin(name, cfg.parameterOverrides.(name));
end
set_param(model, 'SimulationCommand', 'update');
effectiveArea = mw.getVariable('cegr_valve_max_area');
if abs(effectiveArea - cfg.requestedValveMaxArea_m2) > ...
        1e-12 * max(1, abs(cfg.requestedValveMaxArea_m2))
    error('RouteA:MultiLoadOverrideLost', ...
        'The requested cegr_valve_max_area override is not active.');
end
end

function result = collectCaseResult(out, model, cfg, result)
logsout = out.logsout;
ratio = loggedTimeseries(logsout, 'routeA_egr_ratio_comp_in');
area = loggedTimeseries(logsout, 'routeA_egr_valve_area_cmd');
pUp = loggedTimeseries(logsout, 'routeA_p_egr_valve_up');
pDown = loggedTimeseries(logsout, 'routeA_p_egr_valve_down');
compMdot = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_mdot_comp_inlet'));
compP = loggedTimeseries(logsout, 'routeA_p_comp_inlet');
compT = loggedTimeseries(logsout, 'routeA_T_comp_inlet');
compCmd = loggedTimeseries(logsout, 'routeA_compressor_cmd');
compRpm = loggedTimeseries(logsout, 'routeA_compressor_rpm');
airMdotSet = magnitudeTimeseries(loggedTimeseries(logsout, ...
    'routeA_air_mdot_set'));
airControlError = loggedTimeseries(logsout, 'routeA_air_control_error');
egrMdot = magnitudeTimeseries(loggedTimeseries(logsout, 'routeA_egr_mdot'));
stackCurrent = loggedTimeseries(logsout, 'routeA_stack_current_A');
stackVoltage = loggedTimeseries(logsout, 'routeA_stack_voltage_V');
stackPower = timeseries( ...
    stackCurrent.Data .* stackVoltage.Data * 1e-3, stackCurrent.Time);
stackTemperature = loggedTimeseries(logsout, 'routeA_stack_temperature_C');
rhIn = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_in', 'routeA_RH_ca_in_ts'), 'routeA_RH_ca_in');
rhOut = waterRelativeHumidity(outputTimeseries(out, logsout, ...
    'routeA_RH_ca_out', 'routeA_RH_ca_out_ts'), 'routeA_RH_ca_out');
waterSeparator = outputTimeseries(out, logsout, 'routeA_m_water_sep', ...
    'routeA_m_water_sep_ts');
speciesMdot = out.get('routeA_mdot_species_ca_in_ts');
[~, speciesTotal, speciesMassFraction] = inletSpeciesMetrics(speciesMdot);
inletTotalMdot = timeseries(speciesTotal, speciesMdot.Time);
inletO2MassFraction = timeseries(speciesMassFraction(:, 2), ...
    speciesMdot.Time);
lambdaCaIn = inletOxygenStoich(speciesMdot, stackCurrent, cfg.stackCells);
egrAtCompressorTime = interpolate(egrMdot.Time, egrMdot.Data, ...
    compMdot.Time);
freshAirApprox = timeseries(compMdot.Data - egrAtCompressorTime, ...
    compMdot.Time);
airMdotSetAtCompressorTime = interpolate(airMdotSet.Time, ...
    airMdotSet.Data, compMdot.Time);
compressorMdotTrackingError = timeseries(compMdot.Data - ...
    airMdotSetAtCompressorTime, compMdot.Time);
pressureDeltaMPa = timeseries((pUp.Data - pDown.Data) * 1e-6, ...
    pUp.Time);
areaFraction = timeseries(area.Data / cfg.maxValveArea_m2, area.Time);

tail = struct();
tail.egrRatio = windowStats(ratio, cfg.tailWindow_s);
tail.egrMdot_kg_s = windowStats(egrMdot, cfg.tailWindow_s);
tail.freshAirApprox_kg_s = windowStats(freshAirApprox, cfg.tailWindow_s);
tail.inletTotalMdot_kg_s = windowStats(inletTotalMdot, cfg.tailWindow_s);
tail.stackCurrent_A = windowStats(stackCurrent, cfg.tailWindow_s);
tail.stackVoltage_V = windowStats(stackVoltage, cfg.tailWindow_s);
tail.stackPower_kW = windowStats(stackPower, cfg.tailWindow_s);
tail.stackTemperature_C = windowStats(stackTemperature, cfg.tailWindow_s);
tail.compressorMdot_kg_s = windowStats(compMdot, cfg.tailWindow_s);
tail.compressorMdotSet_kg_s = windowStats(airMdotSet, cfg.tailWindow_s);
tail.compressorMdotTrackingError_kg_s = windowStats( ...
    compressorMdotTrackingError, cfg.tailWindow_s);
tail.airControlError_kg_s = windowStats(airControlError, cfg.tailWindow_s);
tail.compressorPressure_Pa = windowStats(compP, cfg.tailWindow_s);
tail.compressorTemperature_K = windowStats(compT, cfg.tailWindow_s);
tail.compressorCommand = windowStats(compCmd, cfg.tailWindow_s);
tail.compressorRpm = windowStats(compRpm, cfg.tailWindow_s);
tail.egrValveDeltaP_MPa = windowStats(pressureDeltaMPa, cfg.tailWindow_s);
tail.egrValveAreaFraction = windowStats(areaFraction, cfg.tailWindow_s);
tail.rhCaIn = windowStats(rhIn, cfg.tailWindow_s);
tail.rhCaOut = windowStats(rhOut, cfg.tailWindow_s);
tail.waterSeparator = windowStats(waterSeparator, cfg.tailWindow_s);
tail.lambdaCaIn = windowStats(lambdaCaIn, cfg.tailWindow_s);
tail.inletO2MassFraction = windowStats(inletO2MassFraction, ...
    cfg.tailWindow_s);

currentData = windowData(stackCurrent, cfg.currentTrackingWindow_s);
lambdaTransition = windowData(lambdaCaIn, ...
    cfg.lambdaTransitionDiagnosticWindow_s);
compressorMdotTrackingData = windowData(compressorMdotTrackingError, ...
    cfg.tailWindow_s);
gasClosure = routeA_stage1_cathode_gas_closure_from_outputs(out, model, cfg);
purge = purgeStats(out, model, cfg);

result.simCompleted = true;
result.tail = tail;
result.tailMeans = tailMeans(tail);
result.actualRatio = tail.egrRatio.mean;
result.targetError = result.actualRatio - result.targetRatio;
result.targetTolerance = targetTolerance(result.targetRatio);
result.currentTrackingMaxError_A = max(abs(currentData - result.targetCurrentA));
result.compressorMdotTrackingMaxAbsError_kg_s = ...
    max(abs(compressorMdotTrackingData));
result.compressorMdotTrackingTolerance_kg_s = max( ...
    cfg.airMdotTrackingRelativeTolerance * ...
    abs(tail.compressorMdotSet_kg_s.mean), ...
    cfg.airMdotTrackingAbsoluteTolerance_kg_s);
result.tailPowerSpanTolerance_kW = tailPowerSpanTolerance(tail, cfg);
result.tailPowerSpanPassed = tail.stackPower_kW.span <= ...
    result.tailPowerSpanTolerance_kW;
result.lambdaTailMin = tail.lambdaCaIn.minimum;
result.lambdaTransitionMin = finiteMinimum(lambdaTransition);
result.lambdaOperationalMin = result.lambdaTailMin; % Legacy field: tail only.
result.finiteTail = tailFinite(tail);
result.trackingPassed = abs(result.targetError) <= result.targetTolerance;
result.currentPassed = result.currentTrackingMaxError_A <= ...
    cfg.currentTrackingTolerance_A;
result.compressorMdotTrackingPassed = ...
    result.compressorMdotTrackingMaxAbsError_kg_s <= ...
    result.compressorMdotTrackingTolerance_kg_s;
result.lambdaPassed = tail.lambdaCaIn.nonfiniteCount == 0 && ...
    result.lambdaTailMin > cfg.lambdaLowerBound;
result.pressureDirectionPassed = result.targetRatio == 0 || ...
    tail.egrValveDeltaP_MPa.mean > 0;
result.areaPassed = tail.egrValveAreaFraction.minimum >= 0 && ...
    tail.egrValveAreaFraction.maximum < 1 - 1e-6;
result.compressorRpmLookupPassed = ...
    tail.compressorRpm.minimum >= cfg.compressorRpmLookupBounds(1) - 1e-9 && ...
    tail.compressorRpm.maximum <= cfg.compressorRpmLookupBounds(2) + 1e-9;
result.tailStable = tailStabilityPassed(tail, cfg);
result.purge = purge;
result.tailPurgeFree = purge.tailEventCount == 0;
result.gasClosure = gasClosure;
result.gasClosurePassed = gasClosure.passed;
result.localPassed = result.finiteTail && result.trackingPassed && ...
    result.currentPassed && result.compressorMdotTrackingPassed && ...
    result.lambdaPassed && ...
    result.pressureDirectionPassed && result.areaPassed && ...
    result.compressorRpmLookupPassed && result.tailStable && ...
    result.tailPurgeFree && result.gasClosurePassed;
result.failureCategory = localFailureCategory(result);
end

function [cases, groups] = finalizeLoadGroups(cases, cfg)
groups = repmat(emptyLoadGroup(), numel(cfg.loads), 1);
caseLoadIds = string({cases.loadId});
for loadIdx = 1:numel(cfg.loads)
    load = cfg.loads(loadIdx);
    indices = find(caseLoadIds == load.id);
    targetRatios = [cases(indices).targetRatio];
    refRelativeIndex = find(abs(targetRatios) < eps, 1);
    referenceAvailable = ~isempty(refRelativeIndex) && ...
        cases(indices(refRelativeIndex)).simCompleted;
    tailWindowPassed = builtin('all', [cases(indices).tailPurgeFree]);
    compressorMdotMeans = NaN(1, numel(indices));
    compressorMdotSetMeans = NaN(1, numel(indices));
    for localIdx = 1:numel(indices)
        compressorMdotMeans(localIdx) = tailMean(cases(indices(localIdx)), ...
            'compressorMdot_kg_s');
        compressorMdotSetMeans(localIdx) = tailMean( ...
            cases(indices(localIdx)), 'compressorMdotSet_kg_s');
    end
    flowSetpointMean_kg_s = mean(compressorMdotSetMeans);
    flowInvarianceTolerance_kg_s = max( ...
        cfg.airMdotTrackingRelativeTolerance * abs(flowSetpointMean_kg_s), ...
        cfg.airMdotTrackingAbsoluteTolerance_kg_s);
    flowSetpointSpan_kg_s = spanOrInf(compressorMdotSetMeans);
    flowActualSpan_kg_s = spanOrInf(compressorMdotMeans);
    flowInvariancePassed = builtin('all', isfinite(compressorMdotMeans)) && ...
        builtin('all', isfinite(compressorMdotSetMeans)) && ...
        flowSetpointSpan_kg_s <= flowInvarianceTolerance_kg_s && ...
        flowActualSpan_kg_s <= flowInvarianceTolerance_kg_s;
    for idx = indices
        cases(idx).referenceAvailable = referenceAvailable;
        cases(idx).sameTailWindowPassed = tailWindowPassed;
        cases(idx).sameTotalCompressorFlowPassed = flowInvariancePassed;
        cases(idx).totalCompressorFlowInvarianceTolerance_kg_s = ...
            flowInvarianceTolerance_kg_s;
        cases(idx).comparabilityPassed = referenceAvailable && ...
            tailWindowPassed && flowInvariancePassed;
        if referenceAvailable
            referenceMeans = cases(indices(refRelativeIndex)).tailMeans;
            if ~isempty(fieldnames(referenceMeans)) && ...
                    ~isempty(fieldnames(cases(idx).tailMeans))
                cases(idx).deltaToReference = meanDelta( ...
                    cases(idx).tailMeans, referenceMeans);
            end
        end
        cases(idx).passed = cases(idx).localPassed && ...
            cases(idx).comparabilityPassed;
        if ~cases(idx).referenceAvailable
            cases(idx).failureCategory = appendFailureCategory( ...
                cases(idx).failureCategory, "zero_target_reference_missing");
        end
        if ~cases(idx).sameTailWindowPassed
            cases(idx).failureCategory = appendFailureCategory( ...
                cases(idx).failureCategory, "tail_timing_unclosed");
        end
        if ~cases(idx).sameTotalCompressorFlowPassed
            cases(idx).failureCategory = appendFailureCategory( ...
                cases(idx).failureCategory, ...
                "same_load_total_compressor_flow_unclosed");
        end
    end
    groups(loadIdx) = struct( ...
        'loadId', load.id, ...
        'currentDensity_A_cm2', load.currentDensity_A_cm2, ...
        'targetCurrentA', load.targetCurrentA, ...
        'targetAirEquivalentOer', load.targetAirEquivalentOer, ...
        'targetOer', load.targetOer, ...
        'caseIndices', indices, ...
        'referenceAvailable', referenceAvailable, ...
        'sharedTailWindow_s', cfg.tailWindow_s, ...
        'sharedTailWindowPassed', tailWindowPassed, ...
        'compressorMdotMeans_kg_s', compressorMdotMeans, ...
        'compressorMdotSetMeans_kg_s', compressorMdotSetMeans, ...
        'totalCompressorFlowSetpointMean_kg_s', flowSetpointMean_kg_s, ...
        'totalCompressorFlowSetpointSpan_kg_s', flowSetpointSpan_kg_s, ...
        'totalCompressorFlowActualSpan_kg_s', flowActualSpan_kg_s, ...
        'totalCompressorFlowInvarianceTolerance_kg_s', ...
            flowInvarianceTolerance_kg_s, ...
        'totalCompressorFlowInvariancePassed', flowInvariancePassed, ...
        'allLocalCasesPassed', builtin('all', [cases(indices).localPassed]), ...
        'passed', builtin('all', [cases(indices).passed]), ...
        'incompleteReason', "");
end
end

function [cases, groups] = classifyIncompleteMatrix(cases, cfg, execution)
groups = repmat(emptyLoadGroup(), numel(cfg.loads), 1);
caseLoadIds = string({cases.loadId});
for loadIdx = 1:numel(cfg.loads)
    load = cfg.loads(loadIdx);
    indices = find(caseLoadIds == load.id);
    for idx = indices
        if ~cases(idx).simCompleted && strlength(cases(idx).failureCategory) == 0
            if execution.scopeComplete && ~execution.matrixComplete
                cases(idx).failureCategory = "not_requested";
            else
                cases(idx).failureCategory = "preflight_blocked";
            end
        end
        cases(idx).passed = false;
    end
    groups(loadIdx) = struct( ...
        'loadId', load.id, ...
        'currentDensity_A_cm2', load.currentDensity_A_cm2, ...
        'targetCurrentA', load.targetCurrentA, ...
        'targetAirEquivalentOer', load.targetAirEquivalentOer, ...
        'targetOer', load.targetOer, ...
        'caseIndices', indices, ...
        'referenceAvailable', false, ...
        'sharedTailWindow_s', cfg.tailWindow_s, ...
        'sharedTailWindowPassed', false, ...
        'compressorMdotMeans_kg_s', NaN(1, numel(indices)), ...
        'compressorMdotSetMeans_kg_s', NaN(1, numel(indices)), ...
        'totalCompressorFlowSetpointMean_kg_s', NaN, ...
        'totalCompressorFlowSetpointSpan_kg_s', Inf, ...
        'totalCompressorFlowActualSpan_kg_s', Inf, ...
        'totalCompressorFlowInvarianceTolerance_kg_s', NaN, ...
        'totalCompressorFlowInvariancePassed', false, ...
        'allLocalCasesPassed', false, ...
        'passed', false, ...
        'incompleteReason', execution.haltReason);
end
end

function ledger = skippedWaterLedger(execution)
ledger = struct( ...
    'attempted', false, ...
    'auditPassed', false, ...
    'skipReason', "matrix_incomplete:" + execution.haltReason, ...
    'cases', struct([]));
end

function [ledger, passed] = runSharedWaterLedger(caseOutputs, cfg, model)
available = true;
reason = "";
loadIds = string({cfg.loads.id});
for loadIdx = 1:numel(loadIds)
    for targetRatio = [0, 0.30]
        matches = find(string({caseOutputs.loadId}) == loadIds(loadIdx) & ...
            abs([caseOutputs.targetRatio] - targetRatio) < eps);
        if numel(matches) ~= 1 || ...
                ~isa(caseOutputs(matches).out, 'Simulink.SimulationOutput')
            available = false;
            reason = sprintf('Missing usable SimulationOutput for %s / %.2f.', ...
                loadIds(loadIdx), targetRatio);
        end
    end
end
if ~available
    ledger = struct( ...
        'attempted', false, ...
        'auditPassed', false, ...
        'skipReason', string(reason), ...
        'cases', struct([]));
    passed = false;
    return;
end

waterCfg = struct();
waterCfg.model = model;
waterCfg.initialStateMetadata = cfg.initialStateMetadata;
waterCfg.targetRatios = [0, 0.30];
waterCfg.loadIds = loadIds;
waterCfg.researchStartTime_s = cfg.researchStartTime_s;
waterCfg.researchDuration_s = cfg.researchDuration_s;
waterCfg.modelStopTime_s = cfg.modelStopTime_s;
waterCfg.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
waterCfg.tailWindow_s = cfg.tailWindow_s;
waterCfg.currentTrackingWindow_s = cfg.currentTrackingWindow_s;
waterCfg.targetCurrentA = cfg.initialStateMetadata.targetCurrentA;
waterCfg.currentTrackingTolerance_A = cfg.currentTrackingTolerance_A;
waterCfg.airControlBasis = cfg.airControlBasis;
if isfield(cfg.initialStateMetadata, 'targetAirEquivalentOer')
    waterCfg.targetAirEquivalentOer = ...
        cfg.initialStateMetadata.targetAirEquivalentOer;
else
    waterCfg.targetAirEquivalentOer = cfg.initialStateMetadata.targetOer;
end
waterCfg.targetOer = waterCfg.targetAirEquivalentOer; % Legacy helper field.
waterCfg.meaClosureTolerance_kg_s = 1e-6;
waterCfg.localGasBalanceAbsTolerance_kg = 1e-6;
waterCfg.localGasBalanceRelativeTolerance = 1e-3;
waterCfg.systemGasBalanceAbsTolerance_kg = 5e-6;
waterCfg.systemGasBalanceRelativeTolerance = 5e-5;
waterCfg.species = struct('n2', 1, 'o2', 2, 'h2', 3, 'h2o', 4);
try
    ledger = routeA_stage1_water_ledger_from_outputs(caseOutputs, waterCfg);
    ledger.attempted = true;
    passed = ledger.auditPassed;
catch ME
    ledger = struct( ...
        'attempted', true, ...
        'auditPassed', false, ...
        'errorId', string(ME.identifier), ...
        'errorMessage', string(ME.message), ...
        'cases', struct([]));
    passed = false;
end
end

function matrix = summarizeMatrix(cases, groups, waterLedger, ...
    waterLedgerPassed, cfg, execution)
matrix = struct();
matrix.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
matrix.model = cfg.model;
matrix.parameterLayer = cfg.parameterLayer;
matrix.externalCaseEnabled = cfg.externalCaseEnabled;
matrix.airControlBasis = cfg.airControlBasis;
matrix.airControlTargetDefinition = ...
    ['targetAirEquivalentOer derives total compressor mass flow using ', ...
    'fresh-air O2 mass fraction; lambda_ca_in is an audited result'];
matrix.valveAreaFactor = cfg.valveAreaFactor;
matrix.baseValveMaxArea_m2 = cfg.baseValveMaxArea_m2;
matrix.requestedValveMaxArea_m2 = cfg.requestedValveMaxArea_m2;
matrix.parameterOverrides = cfg.parameterOverrides;
matrix.initialStateKind = cfg.initialStateKind;
matrix.preconditionAudit = cfg.preconditionAudit;
matrix.initialState = cfg.initialStateMetadata;
matrix.loads = cfg.loads;
matrix.targetRatios = cfg.targetRatios;
matrix.modeId = 1;
matrix.researchDuration_s = cfg.researchDuration_s;
matrix.studyMaxStep_s = cfg.studyMaxStep_s;
matrix.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
matrix.powerSpanAbsoluteTolerance_kW = ...
    cfg.powerSpanAbsoluteTolerance_kW;
matrix.powerSpanRelativeTolerance = cfg.powerSpanRelativeTolerance;
matrix.tailDefinition = sprintf( ...
    'mean/std/span over logical [%.16g,%.16g) s after the shared saved operating point', ...
    cfg.tailLogicalWindow_s(1), cfg.tailLogicalWindow_s(2));
matrix.referenceDefinition = ...
    'same load, same mode-1 initial operating point, same tail window, zero-target near-zero cEGR';
matrix.currentTrackingWindowDefinition = sprintf( ...
    'logical [%.16g,%.16g] s; excludes the 0.5 s source-compatible current hold', ...
    cfg.currentTrackingStartOffset_s, cfg.researchDuration_s);
matrix.lambdaAcceptanceDefinition = sprintf( ...
    'tail lambda_ca_in must exceed 1; logical [%.16g,%.16g) s minimum is diagnostic only', ...
    cfg.currentTrackingStartOffset_s, cfg.tailLogicalWindow_s(1));
matrix.totalCompressorFlowAcceptanceDefinition = ...
    'per-case setpoint tracking and same-load cEGR invariance use max(2%, 5e-4 kg/s)';
matrix.powerSpanAcceptanceDefinition = sprintf( ...
    'P_stack tail span <= max(%.16g kW, %.16g * abs(P_bar))', ...
    cfg.powerSpanAbsoluteTolerance_kW, cfg.powerSpanRelativeTolerance);
matrix.execution = execution;
matrix.cases = cases;
matrix.loadGroups = groups;
matrix.summaryTable = buildSummaryTable(cases);
matrix.allTailWindowsPassed = builtin('all', [groups.sharedTailWindowPassed]);
matrix.allTotalCompressorFlowInvariancePassed = builtin('all', ...
    [groups.totalCompressorFlowInvariancePassed]);
matrix.allGasClosuresPassed = builtin('all', [cases.gasClosurePassed]);
matrix.allCasesPassed = builtin('all', [cases.passed]);
matrix.waterLedger = waterLedger;
matrix.waterLedgerPassed = waterLedgerPassed;
matrix.passed = execution.matrixComplete && matrix.allTailWindowsPassed && ...
    matrix.allTotalCompressorFlowInvariancePassed && ...
    matrix.allGasClosuresPassed && matrix.allCasesPassed && ...
    matrix.waterLedgerPassed;
end

function summary = buildSummaryTable(cases)
count = numel(cases);
caseIdColumn = strings(count, 1);
loadIdColumn = strings(count, 1);
currentDensity = NaN(count, 1);
targetCurrent = NaN(count, 1);
targetAirEquivalentOer = NaN(count, 1);
targetRatio = NaN(count, 1);
actualRatio = NaN(count, 1);
voltage = NaN(count, 1);
deltaVoltage = NaN(count, 1);
power = NaN(count, 1);
deltaPower = NaN(count, 1);
powerSpan = NaN(count, 1);
powerSpanTolerance = NaN(count, 1);
lambdaTailMin = NaN(count, 1);
lambdaTransitionMin = NaN(count, 1);
inletO2MassFraction = NaN(count, 1);
freshAir = NaN(count, 1);
valveDeltaP = NaN(count, 1);
valveAreaMaximum = NaN(count, 1);
compressorMdotSet = NaN(count, 1);
compressorMdotActual = NaN(count, 1);
compressorMdotTrackingMaxAbsError = NaN(count, 1);
compressorMdotTrackingTolerance = NaN(count, 1);
compressorRpm = NaN(count, 1);
o2FaradayResidual = NaN(count, 1);
n2MixResidual = NaN(count, 1);
o2MixResidual = NaN(count, 1);
tailPurgeFree = false(count, 1);
gasClosurePassed = false(count, 1);
rpmLookupPassed = false(count, 1);
compressorMdotTrackingPassed = false(count, 1);
powerSpanPassed = false(count, 1);
sameLoadCompressorFlowPassed = false(count, 1);
passed = false(count, 1);
failureCategory = strings(count, 1);
for idx = 1:count
    value = cases(idx);
    caseIdColumn(idx) = value.caseId;
    loadIdColumn(idx) = value.loadId;
    currentDensity(idx) = value.currentDensity_A_cm2;
    targetCurrent(idx) = value.targetCurrentA;
    targetAirEquivalentOer(idx) = value.targetAirEquivalentOer;
    targetRatio(idx) = value.targetRatio;
    actualRatio(idx) = value.actualRatio;
    voltage(idx) = tailMean(value, 'stackVoltage_V');
    deltaVoltage(idx) = deltaMean(value, 'stackVoltage_V');
    power(idx) = tailMean(value, 'stackPower_kW');
    deltaPower(idx) = deltaMean(value, 'stackPower_kW');
    powerSpan(idx) = tailMaximum(value, 'stackPower_kW') - ...
        tailMinimum(value, 'stackPower_kW');
    powerSpanTolerance(idx) = value.tailPowerSpanTolerance_kW;
    lambdaTailMin(idx) = value.lambdaTailMin;
    lambdaTransitionMin(idx) = value.lambdaTransitionMin;
    inletO2MassFraction(idx) = tailMean(value, 'inletO2MassFraction');
    freshAir(idx) = tailMean(value, 'freshAirApprox_kg_s');
    valveDeltaP(idx) = tailMean(value, 'egrValveDeltaP_MPa');
    valveAreaMaximum(idx) = tailMaximum(value, 'egrValveAreaFraction');
    compressorMdotSet(idx) = tailMean(value, 'compressorMdotSet_kg_s');
    compressorMdotActual(idx) = tailMean(value, 'compressorMdot_kg_s');
    compressorMdotTrackingMaxAbsError(idx) = ...
        value.compressorMdotTrackingMaxAbsError_kg_s;
    compressorMdotTrackingTolerance(idx) = ...
        value.compressorMdotTrackingTolerance_kg_s;
    compressorRpm(idx) = tailMean(value, 'compressorRpm');
    o2FaradayResidual(idx) = gasValue(value, 'o2FaradayResidual_kg_s');
    n2MixResidual(idx) = gasValue(value, 'n2MixResidual_kg_s');
    o2MixResidual(idx) = gasValue(value, 'o2MixResidual_kg_s');
    tailPurgeFree(idx) = value.tailPurgeFree;
    gasClosurePassed(idx) = value.gasClosurePassed;
    rpmLookupPassed(idx) = value.compressorRpmLookupPassed;
    compressorMdotTrackingPassed(idx) = value.compressorMdotTrackingPassed;
    powerSpanPassed(idx) = value.tailPowerSpanPassed;
    sameLoadCompressorFlowPassed(idx) = ...
        value.sameTotalCompressorFlowPassed;
    passed(idx) = value.passed;
    failureCategory(idx) = value.failureCategory;
end
summary = table(caseIdColumn, loadIdColumn, currentDensity, targetCurrent, ...
    targetAirEquivalentOer, targetRatio, actualRatio, voltage, ...
    deltaVoltage, power, deltaPower, powerSpan, powerSpanTolerance, ...
    lambdaTailMin, lambdaTransitionMin, inletO2MassFraction, ...
    freshAir, valveDeltaP, valveAreaMaximum, compressorMdotSet, ...
    compressorMdotActual, compressorMdotTrackingMaxAbsError, ...
    compressorMdotTrackingTolerance, compressorRpm, o2FaradayResidual, ...
    n2MixResidual, ...
    o2MixResidual, tailPurgeFree, gasClosurePassed, rpmLookupPassed, ...
    compressorMdotTrackingPassed, powerSpanPassed, ...
    sameLoadCompressorFlowPassed, passed, ...
    failureCategory, ...
    'VariableNames', {'caseId', 'loadId', 'currentDensity_A_cm2', ...
    'targetCurrent_A', 'targetAirEquivalentOer', 'targetRatio', ...
    'actualRatio', ...
    'stackVoltage_V', 'deltaVoltage_V', 'stackPower_kW', ...
    'deltaPower_kW', 'stackPowerSpan_kW', ...
    'stackPowerSpanTolerance_kW', 'lambdaCaInTailMin', ...
    'lambdaCaInTransitionMin', ...
    'inletO2MassFraction', ...
    'freshAirApprox_kg_s', 'egrValveDeltaP_MPa', ...
    'egrValveAreaFractionMax', 'compressorMdotSet_kg_s', ...
    'compressorMdotActual_kg_s', ...
    'compressorMdotTrackingMaxAbsError_kg_s', ...
    'compressorMdotTrackingTolerance_kg_s', 'compressorRpm', ...
    'o2FaradayResidual_kg_s', 'n2MixResidual_kg_s', ...
    'o2MixResidual_kg_s', 'tailPurgeFree', 'gasClosurePassed', ...
    'compressorRpmLookupPassed', 'compressorMdotTrackingPassed', ...
    'stackPowerSpanPassed', ...
    'sameLoadCompressorFlowPassed', 'passed', 'failureCategory'});
end

function value = tailMean(result, name)
value = NaN;
if isstruct(result.tailMeans) && isfield(result.tailMeans, name)
    value = result.tailMeans.(name);
end
end

function value = deltaMean(result, name)
value = NaN;
if isstruct(result.deltaToReference) && isfield(result.deltaToReference, name)
    value = result.deltaToReference.(name);
end
end

function value = tailMaximum(result, name)
value = NaN;
if isstruct(result.tail) && isfield(result.tail, name)
    value = result.tail.(name).maximum;
end
end

function value = tailMinimum(result, name)
value = NaN;
if isstruct(result.tail) && isfield(result.tail, name)
    value = result.tail.(name).minimum;
end
end

function value = gasValue(result, name)
value = NaN;
if isstruct(result.gasClosure) && isfield(result.gasClosure, name)
    value = result.gasClosure.(name);
end
end

function displayMatrix(matrix)
fprintf('\nRoute A Stage 1 constant-current multi-load matrix\n');
fprintf(['  protocol: duration=%.0f s | tail=[%.0f,%.0f) s | MaxStep=%.6g s | ', ...
    'P_span<=max(%.6g kW, %.6g*abs(P_bar))\n'], ...
    matrix.researchDuration_s, matrix.tailLogicalWindow_s(1), ...
    matrix.tailLogicalWindow_s(2), matrix.studyMaxStep_s, ...
    matrix.powerSpanAbsoluteTolerance_kW, matrix.powerSpanRelativeTolerance);
fprintf(['  warm state: %s | t0=%.6f s | source I=%.6g A | ', ...
    'tail=[%.0f,%.0f) s\n'], ...
    matrix.initialState.normalOperationPhase, ...
    matrix.initialState.snapshotTimeS, ...
    matrix.initialState.targetCurrentA, ...
    matrix.tailLogicalWindow_s(1), matrix.tailLogicalWindow_s(2));
disp(matrix.summaryTable);
for idx = 1:numel(matrix.loadGroups)
    group = matrix.loadGroups(idx);
    fprintf(['  %s: j=%.6g A/cm^2 I=%.6g A airEqOER=%.6g ', ...
        'tailShared=%d reference=%d passed=%d\n'], ...
        group.loadId, group.currentDensity_A_cm2, group.targetCurrentA, ...
        group.targetAirEquivalentOer, group.sharedTailWindowPassed, ...
        group.referenceAvailable, group.passed);
end
fprintf(['  gasClosure=%d waterLedger=%d allTailWindows=%d ', ...
    'matrixPassed=%d\n'], ...
    matrix.allGasClosuresPassed, matrix.waterLedgerPassed, ...
    matrix.allTailWindowsPassed, matrix.passed);
end

function result = emptyCaseResult()
result = struct( ...
    'caseId', "", ...
    'loadId', "", ...
    'currentDensity_A_cm2', NaN, ...
    'targetCurrentA', NaN, ...
    'targetAirEquivalentOer', NaN, ...
    'targetOer', NaN, ...
    'targetRatio', NaN, ...
    'modeId', NaN, ...
    'initialStateKind', "", ...
    'valveAreaFactor', NaN, ...
    'requestedValveMaxArea_m2', NaN, ...
    'initialState', struct(), ...
    'researchStartModelTime_s', NaN, ...
    'researchDuration_s', NaN, ...
    'tailLogicalWindow_s', NaN(1, 2), ...
    'tailModelWindow_s', NaN(1, 2), ...
    'currentTrackingWindow_s', NaN(1, 2), ...
    'lambdaTransitionDiagnosticWindow_s', NaN(1, 2), ...
    'simCompleted', false, ...
    'errorId', "", ...
    'errorMessage', "", ...
    'tail', struct(), ...
    'tailMeans', struct(), ...
    'actualRatio', NaN, ...
    'targetError', NaN, ...
    'targetTolerance', NaN, ...
    'currentTrackingMaxError_A', NaN, ...
    'compressorMdotTrackingMaxAbsError_kg_s', NaN, ...
    'compressorMdotTrackingTolerance_kg_s', NaN, ...
    'tailPowerSpanTolerance_kW', NaN, ...
    'lambdaOperationalMin', NaN, ...
    'lambdaTailMin', NaN, ...
    'lambdaTransitionMin', NaN, ...
    'finiteTail', false, ...
    'trackingPassed', false, ...
    'currentPassed', false, ...
    'compressorMdotTrackingPassed', false, ...
    'tailPowerSpanPassed', false, ...
    'lambdaPassed', false, ...
    'pressureDirectionPassed', false, ...
    'areaPassed', false, ...
    'compressorRpmLookupPassed', false, ...
    'tailStable', false, ...
    'purge', struct(), ...
    'tailPurgeFree', false, ...
    'gasClosure', struct(), ...
    'gasClosurePassed', false, ...
    'localPassed', false, ...
    'referenceAvailable', false, ...
    'sameTailWindowPassed', false, ...
    'sameTotalCompressorFlowPassed', false, ...
    'totalCompressorFlowInvarianceTolerance_kg_s', NaN, ...
    'comparabilityPassed', false, ...
    'deltaToReference', struct(), ...
    'failureCategory', "", ...
    'errorLocation', "", ...
    'passed', false);
end

function output = emptyCaseOutput()
output = struct( ...
    'caseId', "", ...
    'loadId', "", ...
    'currentDensity_A_cm2', NaN, ...
    'targetCurrentA', NaN, ...
    'targetAirEquivalentOer', NaN, ...
    'targetOer', NaN, ...
    'targetRatio', NaN, ...
    'out', [], ...
    'initialState', struct(), ...
    'modeId', NaN);
end

function group = emptyLoadGroup()
group = struct( ...
    'loadId', "", ...
    'currentDensity_A_cm2', NaN, ...
    'targetCurrentA', NaN, ...
    'targetAirEquivalentOer', NaN, ...
    'targetOer', NaN, ...
    'caseIndices', [], ...
    'referenceAvailable', false, ...
    'sharedTailWindow_s', NaN(1, 2), ...
    'sharedTailWindowPassed', false, ...
    'compressorMdotMeans_kg_s', NaN(1, 0), ...
    'compressorMdotSetMeans_kg_s', NaN(1, 0), ...
    'totalCompressorFlowSetpointMean_kg_s', NaN, ...
    'totalCompressorFlowSetpointSpan_kg_s', Inf, ...
    'totalCompressorFlowActualSpan_kg_s', Inf, ...
    'totalCompressorFlowInvarianceTolerance_kg_s', NaN, ...
    'totalCompressorFlowInvariancePassed', false, ...
    'allLocalCasesPassed', false, ...
    'passed', false, ...
    'incompleteReason', "");
end

function id = caseId(loadId, targetRatio)
id = string(loadId) + "_cegr_" + replace( ...
    string(sprintf('%.2f', targetRatio)), '.', 'p');
end

function purge = purgeStats(out, model, cfg)
simlog = out.get(get_param(model, 'SimscapeLogName'));
mea = routeA_simscape_log_mea(simlog);
time = mea.x_i_anode.series.time;
anode = normalizeSeriesData(mea.x_i_anode.series.values('1'), time, ...
    'anode composition');
if size(anode, 2) < 1 || numel(time) < 2
    error('RouteA:MultiLoadPurgeSignal', ...
        'The anode nitrogen signal is unavailable for purge detection.');
end
slope = diff(anode(:, 1)) ./ diff(time(:));
candidate = find(slope < cfg.purgeDropSlope_1_s);
if isempty(candidate)
    eventTimes = zeros(0, 1);
else
    eventIndices = candidate([true; diff(candidate) > 1]) + 1;
    eventTimes = time(eventIndices);
end
tailEvents = eventTimes(eventTimes >= cfg.tailWindow_s(1) & ...
    eventTimes < cfg.tailWindow_s(2));
purge = struct();
purge.method = 'anode N2 mass-fraction slope';
purge.slopeThreshold_1_s = cfg.purgeDropSlope_1_s;
purge.eventTimesModel_s = eventTimes(:).';
purge.tailEventTimesModel_s = tailEvents(:).';
purge.tailEventCount = numel(tailEvents);
end

function data = normalizeSeriesData(data, time, label)
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
    error('RouteA:MultiLoadSeriesShape', ...
        'Unexpected signal shape for %s.', label);
end
end

function passed = tailStabilityPassed(tail, cfg)
passed = tail.egrRatio.span <= cfg.tailSpan.egrRatio && ...
    tail.egrMdot_kg_s.span <= cfg.tailSpan.egrMdot_kg_s && ...
    tail.freshAirApprox_kg_s.span <= cfg.tailSpan.freshAirApprox_kg_s && ...
    tail.inletTotalMdot_kg_s.span <= cfg.tailSpan.inletTotalMdot_kg_s && ...
    tail.stackCurrent_A.span <= cfg.tailSpan.stackCurrent_A && ...
    tail.stackVoltage_V.span <= cfg.tailSpan.stackVoltage_V && ...
    tail.stackPower_kW.span <= tailPowerSpanTolerance(tail, cfg) && ...
    tail.stackTemperature_C.span <= cfg.tailSpan.stackTemperature_C && ...
    tail.compressorMdot_kg_s.span <= cfg.tailSpan.compressorMdot_kg_s && ...
    tail.compressorMdotSet_kg_s.span <= ...
        cfg.tailSpan.compressorMdotSet_kg_s && ...
    tail.compressorMdotTrackingError_kg_s.span <= ...
        cfg.tailSpan.compressorMdotTrackingError_kg_s && ...
    tail.airControlError_kg_s.span <= cfg.tailSpan.airControlError_kg_s && ...
    tail.compressorTemperature_K.span <= cfg.tailSpan.compressorTemperature_K && ...
    tail.rhCaIn.span <= cfg.tailSpan.rhCaIn && ...
    tail.rhCaOut.span <= cfg.tailSpan.rhCaOut && ...
    tail.waterSeparator.span <= cfg.tailSpan.waterSeparator && ...
    tail.lambdaCaIn.span <= cfg.tailSpan.lambdaCaIn && ...
    tail.inletO2MassFraction.span <= cfg.tailSpan.inletO2MassFraction;
end

function tolerance_kW = tailPowerSpanTolerance(tail, cfg)
tolerance_kW = max(cfg.powerSpanAbsoluteTolerance_kW, ...
    cfg.powerSpanRelativeTolerance * abs(tail.stackPower_kW.mean));
end

function tolerance = targetTolerance(targetRatio)
if targetRatio == 0
    tolerance = 1e-4;
else
    tolerance = max(0.002, 0.10 * targetRatio);
end
end

function means = tailMeans(tail)
names = fieldnames(tail);
means = struct();
for idx = 1:numel(names)
    name = names{idx};
    means.(name) = tail.(name).mean;
end
end

function delta = meanDelta(later, earlier)
names = fieldnames(later);
delta = struct();
for idx = 1:numel(names)
    name = names{idx};
    if isfield(earlier, name)
        delta.(name) = later.(name) - earlier.(name);
    end
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

function value = finiteMinimum(values)
finiteValues = values(isfinite(values));
if isempty(finiteValues)
    value = NaN;
else
    value = min(finiteValues);
end
end

function value = spanOrInf(values)
if isempty(values) || any(~isfinite(values))
    value = Inf;
else
    value = max(values) - min(values);
end
end

function stats = windowStats(signal, window)
signalName = inputname(1);
values = windowData(signal, window, signalName);
finiteValues = values(isfinite(values));
stats = struct();
stats.start_s = window(1);
stats.end_s = window(2);
stats.sampleCount = numel(values);
stats.nonfiniteCount = sum(~isfinite(values));
if isempty(finiteValues)
    stats.mean = NaN;
    stats.std = NaN;
    stats.span = Inf;
    stats.minimum = NaN;
    stats.maximum = NaN;
    return;
end
stats.mean = mean(finiteValues);
stats.std = std(finiteValues);
stats.span = max(finiteValues) - min(finiteValues);
stats.minimum = min(finiteValues);
stats.maximum = max(finiteValues);
end

function values = windowData(signal, window, signalName)
if nargin < 3 || strlength(string(signalName)) == 0
    signalName = inputname(1);
end
if strlength(string(signalName)) == 0
    signalName = "unnamed signal";
end
mask = signal.Time >= window(1) & signal.Time < window(2);
values = signal.Data(mask);
values = values(:);
if isempty(values)
    error('RouteA:MultiLoadEmptyWindow', ...
        ['No samples were found for %s in [%.9g, %.9g); ', ...
        'available time range is [%.9g, %.9g].'], ...
        string(signalName), window(1), window(2), ...
        min(signal.Time), max(signal.Time));
end
end

function signal = loggedTimeseries(logsout, name)
element = logsout.get(name);
if isempty(element) || isempty(element.Values)
    error('RouteA:MultiLoadMissingLoggedSignal', ...
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

function signal = magnitudeTimeseries(signal)
signal = timeseries(abs(signal.Data), signal.Time);
end

function values = interpolate(time, data, targetTime)
values = interp1(time, data(:), targetTime, 'linear', 'extrap');
values = values(:);
if any(~isfinite(values))
    error('RouteA:MultiLoadInterpolation', ...
        'Could not align time bases for a derived cathode flow.');
end
end

function lambda = inletOxygenStoich(speciesMdot, stackCurrent, stackCells)
species = compositionMatrix(speciesMdot, 'routeA_mdot_species_ca_in');
if size(species, 2) < 2
    error('RouteA:MultiLoadSpeciesFlowShape', ...
        'The cathode inlet species-flow signal has fewer than two components.');
end
currentAtSpeciesTime = interp1(stackCurrent.Time, stackCurrent.Data(:), ...
    speciesMdot.Time, 'linear', 'extrap');
o2SupplyMolS = abs(species(:, 2)) / 0.0319988;
o2ConsumptionMolS = stackCells * abs(currentAtSpeciesTime) / ...
    (4 * 96485.33212);
lambda = timeseries(o2SupplyMolS ./ o2ConsumptionMolS, speciesMdot.Time);
end

function [species, total, massFraction] = inletSpeciesMetrics(speciesMdot)
species = abs(compositionMatrix(speciesMdot, 'routeA_mdot_species_ca_in'));
total = sum(species, 2);
if any(total <= 0) || any(~isfinite(total))
    error('RouteA:MultiLoadSpeciesTotal', ...
        'The cathode inlet species total is nonpositive or nonfinite.');
end
massFraction = species ./ total;
end

function data = compositionMatrix(signal, signalName)
data = squeeze(signal.Data);
if isvector(data)
    if isscalar(signal.Time)
        data = reshape(data, 1, []);
    else
        data = data(:);
    end
end
if size(data, 1) ~= numel(signal.Time)
    data = data.';
end
if size(data, 1) ~= numel(signal.Time)
    error('RouteA:MultiLoadCompositionShape', ...
        'Unexpected signal shape for %s.', signalName);
end
end

function rh = waterRelativeHumidity(signal, signalName)
data = compositionMatrix(signal, signalName);
if size(data, 2) < 4
    error('RouteA:MultiLoadRelativeHumidityShape', ...
        'The water relative-humidity component is unavailable: %s.', ...
        signalName);
end
rh = timeseries(data(:, 4), signal.Time);
end

function category = localFailureCategory(result)
reasons = strings(1, 0);
if ~result.finiteTail
    reasons(end + 1) = "numerical_finiteness";
end
if ~result.trackingPassed || ~result.currentPassed
    reasons(end + 1) = "tracking";
end
if ~result.compressorMdotTrackingPassed
    reasons(end + 1) = "flow_control_tracking";
end
if ~result.lambdaPassed || ~result.pressureDirectionPassed || ...
        ~result.areaPassed || ~result.compressorRpmLookupPassed
    reasons(end + 1) = "oxygen_or_actuator_capability";
end
if ~result.tailStable
    reasons(end + 1) = "tail_stability";
end
if ~result.tailPurgeFree
    reasons(end + 1) = "tail_timing_unclosed";
end
if ~result.gasClosurePassed
    reasons(end + 1) = "cathode_gas_closure";
end
if isempty(reasons)
    category = "";
else
    category = strjoin(reasons, ';');
end
end

function category = appendFailureCategory(category, reason)
if strlength(category) == 0
    category = string(reason);
else
    category = category + ";" + string(reason);
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
