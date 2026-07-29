function study = run_routeA_electrical_boundary_study(studyCfg)
% Run independent Route A I/P/V cases through one shared study pipeline.
%
% studyCfg.cases is a struct array. Each case defines caseId, boundary, and
% optional cegr/air/controller/acceptance fields. Every case gets a fresh
% SimulationInput and the resulting SimulationOutput is retained in
% study.caseOutputs for downstream audits.

if nargin < 1 || isempty(studyCfg)
    studyCfg = struct();
end
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() cd(oldDir));

cfg = normalizeStudyConfig(studyCfg, modelDir);
ensureModelLoaded(model, modelFile);
inputCfg = inputStudyConfig(cfg);
caseCount = numel(cfg.cases);
resultCells = cell(caseCount, 1);
caseOutputs = repmat(emptyCaseOutput(), caseCount, 1);
inputByCase = cell(caseCount, 1);
contextByCase = cell(caseCount, 1);
execution = struct('requestedCaseIds', strings(1, 0), ...
    'preparedCaseIds', strings(1, 0), 'executedCaseIds', strings(1, 0), ...
    'completedCaseIds', strings(1, 0), 'failedCaseIds', strings(1, 0), ...
    'requestedBoundaryType', cfg.boundaryType, ...
    'requestedExecutionMode', cfg.executionMode, 'executionMode', "", ...
    'parallelWorkersRequested', cfg.parallelWorkers, ...
    'parallelWorkersUsed', 0, 'halted', false, 'haltReason', "");
for idx = 1:caseCount
    caseCfg = cfg.cases(idx);
    caseId = string(caseCfg.caseId);
    execution.requestedCaseIds(end + 1) = caseId;
    result = failureResult(caseCfg);
    caseOutput = initializedCaseOutput(caseCfg);
    try
        [inputByCase{idx}, contextByCase{idx}] = ...
            routeA_prepare_electrical_boundary_input( ...
            model, modelDir, caseCfg, inputCfg);
        execution.preparedCaseIds(end + 1) = caseId;
    catch ME
        result = recordFailure(result, ME, "input_assembly_error");
        execution.failedCaseIds(end + 1) = caseId;
    end
    resultCells{idx} = result;
    caseOutputs(idx) = harmonizeCaseOutput(caseOutput);
end
preflight = buildCasePlans(cfg.cases, contextByCase, cfg);
assignin('base', 'routeA_electrical_boundary_preflight', preflight);

preparedIndices = find(~cellfun(@isempty, inputByCase));
if ~isempty(preparedIndices)
    inputs = [inputByCase{preparedIndices}];
    try
        [outputs, runInfo] = executeSimulationInputs(inputs, cfg, ...
            scriptDir, modelDir, modelFile);
        execution.executionMode = runInfo.executionMode;
        execution.parallelWorkersUsed = runInfo.parallelWorkersUsed;
        for runIdx = 1:numel(preparedIndices)
            idx = preparedIndices(runIdx);
            caseCfg = cfg.cases(idx);
            caseId = string(caseCfg.caseId);
            execution.executedCaseIds(end + 1) = caseId;
            result = resultCells{idx};
            out = outputs{runIdx};
            try
                verifySimulationOutput(out);
                context = contextByCase{idx};
                result = routeA_assess_electrical_boundary_outputs( ...
                    out, model, context, caseCfg);
                result.caseCfg = caseCfg;
                result.simCompleted = true;
                caseOutputs(idx) = harmonizeCaseOutput( ...
                    caseOutputFromResult(result, out, context, caseCfg));
                execution.completedCaseIds(end + 1) = caseId;
            catch ME
                result = recordFailure(result, ME, ...
                    "simulation_or_collection_error");
                execution.failedCaseIds(end + 1) = caseId;
            end
            resultCells{idx} = result;
        end
    catch ME
        execution.executionMode = "dispatch_failed";
        for runIdx = 1:numel(preparedIndices)
            idx = preparedIndices(runIdx);
            caseId = string(cfg.cases(idx).caseId);
            resultCells{idx} = recordFailure(resultCells{idx}, ME, ...
                "simulation_dispatch_error");
            execution.failedCaseIds(end + 1) = caseId;
        end
    end
else
    execution.executionMode = "not_started";
end
execution.matrixComplete = numel(execution.completedCaseIds) == caseCount;
if ~execution.matrixComplete
    execution.halted = true;
    execution.haltReason = "one_or_more_cases_failed";
end

cases = packResults(resultCells);
waterLedger = skippedWaterLedger();
waterLedgerPassed = true;
if cfg.runWaterLedger && execution.matrixComplete
    [waterLedger, waterLedgerPassed] = runSharedWaterLedger( ...
        caseOutputs, cfg, model);
end
study = struct();
study.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
study.model = string(model);
study.modelFile = string(modelFile);
study.parameterLayer = parameterLayer(model);
study.externalCaseEnabled = externalCaseEnabled(model);
study.preflight = preflight;
study.researchDuration_s = cfg.researchDuration_s;
study.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
study.steadyWindowDuration_s = cfg.steadyWindowDuration_s;
study.steadyRelativeVariationLimit = cfg.steadyRelativeVariationLimit;
study.engineeringSteadyRelativeVariationLimit = ...
    cfg.engineeringSteadyRelativeVariationLimit;
study.calculationType = cfg.calculationType;
study.initializationPolicy = "cold_start_only";
study.boundaryType = cfg.boundaryType;
study.solver = struct('startTime_s', 0, 'name', cfg.solver, ...
    'relativeTolerance', cfg.relativeTolerance, ...
    'absoluteTolerance', cfg.absoluteTolerance, ...
    'maxStep_s', cfg.studyMaxStep_s);
study.studyMaxStep_s = cfg.studyMaxStep_s;
study.retainSimulationOutputs = cfg.retainSimulationOutputs;
study.commandStartOffset_s = cfg.commandStartOffset_s;
study.cases = cases;
study.execution = execution;
study.waterLedger = waterLedger;
study.waterLedgerPassed = waterLedgerPassed;
study.allCasesPassed = execution.matrixComplete && ...
    builtin('all', [cases.passed]);
study.passed = study.allCasesPassed && waterLedgerPassed;
study.summaryTable = buildSummaryTable(cases);
if cfg.retainSimulationOutputs
    study.caseOutputs = caseOutputs;
    study.outputs = {caseOutputs.out};
else
    study.caseOutputs = stripSimulationOutputs(caseOutputs);
    study.outputs = {};
end
study.resultFile = saveCompactStudy(study, cfg.resultFile);
assignin('base', 'routeA_electrical_boundary_study', study);
assignin('base', 'routeA_electrical_boundary_summary', study.summaryTable);
displayStudy(study);
end

function cfg = normalizeStudyConfig(user, ~)
cfg = struct( ...
    'calculationType', "steady", ...
    'researchDuration_s', 600, ...
    'tailLogicalWindow_s', [540, 600], ...
    'steadyWindowDuration_s', 60, ...
    'steadyRelativeVariationLimit', 0.005, ...
    'engineeringSteadyRelativeVariationLimit', 0.01, ...
    'solver', "VariableStepAuto", ...
    'relativeTolerance', 1e-3, ...
    'absoluteTolerance', 1e-3, ...
    'studyMaxStep_s', 5, ...
    'commandStartOffset_s', 0.5, ...
    'startupRampDuration_s', 60, ...
    'voltageNoLoadMargin_V', 20, ...
    'runWaterLedger', false, ...
    'executionMode', "serial", ...
    'parallelWorkers', 2, ...
    'showProgress', true, ...
    'retainSimulationOutputs', false, ...
    'resultFile', "", ...
    'cases', struct([]));
hasExplicitMaxStep = isfield(user, 'studyMaxStep_s');
names = fieldnames(user);
for idx = 1:numel(names)
    if ~isfield(cfg, names{idx})
        error('RouteA:ElectricalBoundaryStudyField', ...
            'Unsupported study configuration field: %s.', names{idx});
    end
    cfg.(names{idx}) = user.(names{idx});
end
if isempty(cfg.cases) || ~isstruct(cfg.cases)
    error('RouteA:ElectricalBoundaryCases', ...
        'studyCfg.cases must be a nonempty struct array.');
end
boundaryTypes = strings(1, numel(cfg.cases));
for idx = 1:numel(cfg.cases)
    if ~isfield(cfg.cases(idx), 'boundary') || ...
            ~isstruct(cfg.cases(idx).boundary) || ...
            ~isfield(cfg.cases(idx).boundary, 'type')
        error('RouteA:ElectricalBoundaryCaseType', ...
            'Every case must define exactly one boundary.type.');
    end
    boundaryTypes(idx) = string(cfg.cases(idx).boundary.type);
end
boundaryTypes = unique(boundaryTypes, 'stable');
if ~builtin('all', ismember(boundaryTypes, ["Current", "Power", "Voltage"]))
    error('RouteA:ElectricalBoundaryCaseType', ...
        'Each case boundary.type must be Current, Power, or Voltage.');
end
if numel(boundaryTypes) ~= 1
    error('RouteA:ElectricalBoundaryMixedModes', ...
        ['One study task may contain only one electrical boundary type. ', ...
        'Run Current, Power, and Voltage as separate study calls.']);
end
cfg.boundaryType = boundaryTypes(1);
validateattributes(cfg.researchDuration_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
cfg.calculationType = lower(string(cfg.calculationType));
if ~isscalar(cfg.calculationType) || ...
        ~any(cfg.calculationType == ["steady", "transient"])
    error('RouteA:ElectricalBoundaryCalculationType', ...
        'calculationType must be steady or transient.');
end
if cfg.calculationType == "transient" && ~hasExplicitMaxStep
    cfg.studyMaxStep_s = 0.1;
end
if cfg.calculationType == "transient" && ...
        ~isfield(user, 'retainSimulationOutputs')
    cfg.retainSimulationOutputs = true;
end
cfg.solver = string(cfg.solver);
if ~isscalar(cfg.solver) || cfg.solver ~= "VariableStepAuto"
    error('RouteA:ElectricalBoundarySolver', ...
        'Route A currently supports the VariableStepAuto solver only.');
end
validateattributes(cfg.relativeTolerance, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.absoluteTolerance, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.tailLogicalWindow_s, {'numeric'}, ...
    {'vector', 'numel', 2, 'nonnegative', 'finite'});
cfg.tailLogicalWindow_s = cfg.tailLogicalWindow_s(:).';
if cfg.tailLogicalWindow_s(2) > cfg.researchDuration_s || ...
        cfg.tailLogicalWindow_s(2) <= cfg.tailLogicalWindow_s(1)
    error('RouteA:ElectricalBoundaryStudyTail', ...
        'The logical tail window is invalid.');
end
validateattributes(cfg.studyMaxStep_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.steadyWindowDuration_s, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
validateattributes(cfg.steadyRelativeVariationLimit, {'numeric'}, ...
    {'scalar', 'positive', 'finite', '<=', 1});
validateattributes(cfg.engineeringSteadyRelativeVariationLimit, {'numeric'}, ...
    {'scalar', 'positive', 'finite', '<=', 1});
if cfg.engineeringSteadyRelativeVariationLimit < ...
        cfg.steadyRelativeVariationLimit
    error('RouteA:ElectricalBoundarySteadyLimits', ...
        ['engineeringSteadyRelativeVariationLimit must be greater than or ', ...
        'equal to steadyRelativeVariationLimit.']);
end
if cfg.calculationType == "steady" && ...
        diff(cfg.tailLogicalWindow_s) + eps < cfg.steadyWindowDuration_s
    error('RouteA:ElectricalBoundarySteadyWindow', ...
        'The steady tail window must cover steadyWindowDuration_s.');
end
validateattributes(cfg.commandStartOffset_s, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
validateattributes(cfg.startupRampDuration_s, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
validateattributes(cfg.voltageNoLoadMargin_V, {'numeric'}, ...
    {'scalar', 'positive', 'finite'});
if cfg.commandStartOffset_s + cfg.startupRampDuration_s >= ...
        cfg.researchDuration_s
    error('RouteA:ElectricalBoundaryStartupRamp', ...
        'The startup ramp must finish before the study ends.');
end
cfg.runWaterLedger = logical(cfg.runWaterLedger);
cfg.executionMode = lower(string(cfg.executionMode));
if ~isscalar(cfg.executionMode) || ...
        ~any(cfg.executionMode == ["serial", "parallel"])
    error('RouteA:ElectricalBoundaryExecutionMode', ...
        'executionMode must be serial or parallel.');
end
validateattributes(cfg.parallelWorkers, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 4, 'finite'});
cfg.showProgress = logical(cfg.showProgress);
cfg.retainSimulationOutputs = logical(cfg.retainSimulationOutputs);
if cfg.calculationType == "transient" && ~cfg.retainSimulationOutputs
    error('RouteA:TransientCurveRetention', ...
        ['Transient studies must retain SimulationOutput time-series data ', ...
        'so physical quantities remain available as time curves.']);
end
cfg.resultFile = string(cfg.resultFile);
if ~isscalar(cfg.resultFile)
    error('RouteA:ElectricalBoundaryResultFile', ...
        'resultFile must be a scalar path or an empty string.');
end
if strlength(cfg.resultFile) > 0
    [folder, ~, extension] = fileparts(cfg.resultFile);
    if strlength(string(extension)) == 0 || ...
            ~strcmpi(extension, '.mat') || ~isfolder(folder)
        error('RouteA:ElectricalBoundaryResultFile', ...
            'resultFile must name an existing folder and a .mat file.');
    end
end
for idx = 1:numel(cfg.cases)
    if ~isfield(cfg.cases(idx), 'caseId') || ...
            strlength(string(cfg.cases(idx).caseId)) == 0
        cfg.cases(idx).caseId = "electrical_case_" + idx;
    else
        cfg.cases(idx).caseId = string(cfg.cases(idx).caseId);
    end
end
end

function result = failureResult(caseCfg)
result = struct( ...
    'caseId', string(caseCfg.caseId), 'modeId', 1, ...
    'boundaryType', "", 'targetRatio', scalarTargetRatio(caseCfg), ...
    'actualRatio', NaN, 'targetError', NaN, 'targetTolerance', NaN, ...
    'targetCurrentA', NaN, 'targetPower_kW', NaN, ...
    'targetVoltage_V', NaN, 'targetAirEquivalentOer', NaN, ...
    'initialState', struct(), 'simCompleted', false, ...
    'passed', false, 'localPassed', false, ...
    'errorId', "", 'errorMessage', "", 'errorLocation', "", ...
    'failureCategory', "not_run");
end

function output = emptyCaseOutput()
output = struct( ...
    'caseId', "", 'targetRatio', NaN, 'out', [], ...
    'initialState', struct(), 'modeId', 1, 'boundaryType', "", 'loadId', "", ...
    'currentDensity_A_cm2', NaN, 'targetCurrentA', NaN, ...
    'targetPower_kW', NaN, 'targetVoltage_V', NaN, ...
    'targetAirEquivalentOer', NaN);
end

function output = initializedCaseOutput(caseCfg)
output = emptyCaseOutput();
output.caseId = string(caseCfg.caseId);
output.targetRatio = scalarTargetRatio(caseCfg);
output.loadId = getTextField(caseCfg, 'loadId', "");
output.currentDensity_A_cm2 = numericField(caseCfg, ...
    'currentDensity_A_cm2', NaN);
if isfield(caseCfg, 'boundary') && isfield(caseCfg.boundary, 'type')
    output.boundaryType = string(caseCfg.boundary.type);
end
end

function output = caseOutputFromResult(result, out, context, caseCfg)
output = emptyCaseOutput();
output.caseId = result.caseId;
output.targetRatio = result.targetRatio;
output.out = out;
output.initialState = result.initialState;
output.modeId = 1;
output.boundaryType = result.boundaryType;
output.loadId = getTextField(caseCfg, 'loadId', "");
output.currentDensity_A_cm2 = numericField(caseCfg, ...
    'currentDensity_A_cm2', NaN);
output.targetCurrentA = result.targetCurrentA;
output.targetPower_kW = result.targetPower_kW;
output.targetVoltage_V = result.targetVoltage_V;
output.targetAirEquivalentOer = context.air.targetOer;
end

function output = harmonizeCaseOutput(value)
output = emptyCaseOutput();
names = fieldnames(output);
for idx = 1:numel(names)
    if isfield(value, names{idx})
        output.(names{idx}) = value.(names{idx});
    end
end
end

function ensureModelLoaded(model, modelFile)
if ~bdIsLoaded(model)
    load_system(modelFile);
end
end

function cfg = inputStudyConfig(studyCfg)
cfg = rmfield(studyCfg, {'runWaterLedger', 'executionMode', ...
    'parallelWorkers', 'showProgress', 'retainSimulationOutputs', ...
    'resultFile', 'cases', 'boundaryType'});
end

function [outputs, info] = executeSimulationInputs( ...
    inputs, cfg, scriptDir, modelDir, modelFile)
count = numel(inputs);
outputs = cell(count, 1);
info = struct('executionMode', "serial", 'parallelWorkersUsed', 0);
if cfg.executionMode == "parallel" && count > 1
    [~, workerCount] = acquireParallelPool(cfg.parallelWorkers);
    showProgress = onOff(cfg.showProgress);
    rawOutputs = parsim(inputs, ...
        'AttachedFiles', {modelFile}, ...
        'SetupFcn', @() setupWorkerPaths(scriptDir, modelDir), ...
        'ManageDependencies', 'on', ...
        'ShowProgress', showProgress, ...
        'UseFastRestart', 'off', ...
        'StopOnError', 'off');
    outputs = num2cell(rawOutputs(:));
    info.executionMode = "parallel";
    info.parallelWorkersUsed = workerCount;
    return;
end
for idx = 1:count
    outputs{idx} = sim(inputs(idx));
end
if cfg.executionMode == "parallel"
    info.executionMode = "serial_single_case";
else
    info.executionMode = "serial";
end
end

function [pool, workerCount] = acquireParallelPool(requestedWorkers)
pool = gcp('nocreate');
if isempty(pool)
    pool = parpool('local', requestedWorkers);
elseif pool.NumWorkers > 4
    error('RouteA:ParallelPoolWorkerLimit', ...
        ['The existing parallel pool has %d workers. Route A permits at ', ...
        'most four; close or resize that pool explicitly before this run.'], ...
        pool.NumWorkers);
elseif pool.NumWorkers < requestedWorkers
    error('RouteA:ParallelPoolTooSmall', ...
        ['The existing parallel pool has %d workers but this study requests ', ...
        '%d. Resize the pool explicitly before this run.'], ...
        pool.NumWorkers, requestedWorkers);
end
workerCount = pool.NumWorkers;
end

function setupWorkerPaths(scriptDir, modelDir)
addpath(scriptDir);
addpath(modelDir);
end

function value = onOff(flag)
if flag
    value = 'on';
else
    value = 'off';
end
end

function verifySimulationOutput(out)
if ~isa(out, 'Simulink.SimulationOutput')
    error('RouteA:SimulationOutputType', ...
        'Simulation did not return a Simulink.SimulationOutput.');
end
if strlength(string(out.ErrorMessage)) > 0
    error('RouteA:SimulationOutputError', '%s', out.ErrorMessage);
end
end

function result = recordFailure(result, exception, category)
result.errorId = string(exception.identifier);
result.errorMessage = string(exception.message);
if ~isempty(exception.stack)
    result.errorLocation = string(exception.stack(1).name) + ":" + ...
        string(exception.stack(1).line);
end
result.failureCategory = category;
end

function plans = buildCasePlans(cases, contexts, cfg)
plans = repmat(struct( ...
    'caseId', "", 'preflightPassed', false, 'failureReason', "", ...
    'initialState', struct(), 'controls', struct(), 'solver', struct(), ...
    'time', struct()), numel(cases), 1);
for idx = 1:numel(cases)
    plans(idx).caseId = string(cases(idx).caseId);
    context = contexts{idx};
    if isempty(context)
        plans(idx).failureReason = "input_assembly_error";
        continue;
    end
    metadata = context.initialStateMetadata;
    plans(idx).preflightPassed = true;
    plans(idx).initialState = struct( ...
        'mode', string(context.initialStateMode), ...
        'policy', string(context.initializationPolicy), ...
        'operatingPointLoaded', context.initialStateSelection.operatingPointLoaded, ...
        'selectionReason', string(context.initialStateSelection.reason), ...
        'mismatches', context.initialStateSelection.mismatches, ...
        'file', "", ...
        'loadInputType', string(metadata.loadInputType), ...
        'referenceCurrentDensity_A_cm2', metadata.currentDensity_A_cm2, ...
        'snapshotTime_s', metadata.snapshotTimeS, ...
        'normalOperationPhase', string(metadata.normalOperationPhase), ...
        'periodicVerification', metadata.periodicVerification, ...
        'physicalSummary', metadata.physicalSummary, ...
        'initializationCondition', metadata.initializationCondition);
    plans(idx).controls = struct( ...
        'electricalBoundary', context.boundaryProfile, ...
        'cegr', context.cegrProfile, ...
        'air', context.air, ...
        'cathode', context.cathode, ...
        'anode', context.anode, ...
        'thermal', context.thermal);
    plans(idx).solver = context.solver;
    plans(idx).time = struct( ...
        'logicalStartTime_s', context.logicalStartTime_s, ...
        'modelSnapshotTime_s', context.modelTimeOrigin_s, ...
        'duration_s', context.researchDuration_s, ...
        'tailLogicalWindow_s', context.tailLogicalWindow_s, ...
        'tailModelWindow_s', context.tailWindow_s, ...
        'calculationType', string(cfg.calculationType));
end
end

function outputs = stripSimulationOutputs(outputs)
for idx = 1:numel(outputs)
    outputs(idx).out = [];
end
end

function resultFile = saveCompactStudy(study, configuredPath)
resultFile = "";
if strlength(configuredPath) == 0
    return;
end
routeA_electrical_boundary_study = study;
routeA_electrical_boundary_study.caseOutputs = ...
    stripSimulationOutputs(routeA_electrical_boundary_study.caseOutputs);
routeA_electrical_boundary_study.outputs = {};
save(char(configuredPath), 'routeA_electrical_boundary_study', '-v7.3');
resultFile = configuredPath;
end

function cases = packResults(cells)
fields = {};
for idx = 1:numel(cells)
    fields = union(fields, fieldnames(cells{idx}), 'stable');
end
cases = repmat(struct(), numel(cells), 1);
for idx = 1:numel(cells)
    for fieldIdx = 1:numel(fields)
        name = fields{fieldIdx};
        if isfield(cells{idx}, name)
            cases(idx).(name) = cells{idx}.(name);
        else
            cases(idx).(name) = [];
        end
    end
end
end

function [ledger, passed] = runSharedWaterLedger(caseOutputs, cfg, model)
ledger = struct('attempted', false, 'auditPassed', false, ...
    'skipReason', "", 'cases', struct([]));
passed = false;
if numel(caseOutputs) == 0 || ...
        any(~arrayfun(@(item) isa(item.out, ...
        'Simulink.SimulationOutput'), caseOutputs))
    ledger.skipReason = "missing_simulation_output";
    return;
end
types = strings(1, numel(caseOutputs));
for idx = 1:numel(caseOutputs)
    if isfield(caseOutputs(idx), 'boundaryType')
        types(idx) = string(caseOutputs(idx).boundaryType);
    end
end
% The case output stores the mode in result metadata only; wrappers pass one
% electrical mode per study, so infer it from the first completed case config.
firstCase = cfg.cases(1);
mode = string(firstCase.boundary.type);
availableRatios = [caseOutputs.targetRatio];
requiredLedgerRatios = [0, 0.30];
if ~builtin('all', arrayfun(@(target) builtin('any', ...
        abs(availableRatios - target) < eps), requiredLedgerRatios))
    ledger.skipReason = "water_ledger_requires_zero_and_030_targets";
    return;
end
ledgerRatioTolerance = 1e-9;
selected = caseOutputs(arrayfun(@(item) builtin('any', ...
    abs(item.targetRatio - requiredLedgerRatios) <= ledgerRatioTolerance), ...
    caseOutputs));
selectedLoadIds = string({selected.loadId});
multiLoad = builtin('any', strlength(selectedLoadIds) > 0) && ...
    numel(unique(selectedLoadIds)) > 1;
if (~multiLoad && numel(selected) ~= 2) || (multiLoad && isempty(selected))
    ledger.skipReason = "water_ledger_case_selection";
    return;
end
waterCfg = struct();
waterCfg.model = model;
waterCfg.targetRatios = [0, 0.30];
waterCfg.initialStateMetadata = selected(1).initialState;
waterCfg.researchStartTime_s = selected(1).initialState.snapshotTimeS;
waterCfg.researchDuration_s = cfg.researchDuration_s;
waterCfg.modelStopTime_s = waterCfg.researchStartTime_s + ...
    cfg.researchDuration_s;
waterCfg.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
waterCfg.tailWindow_s = waterCfg.researchStartTime_s + ...
    cfg.tailLogicalWindow_s;
waterCfg.targetAirEquivalentOer = selected(1).targetAirEquivalentOer;
if multiLoad
    waterCfg.loadIds = unique(selectedLoadIds, 'stable');
end
waterCfg.meaClosureTolerance_kg_s = 1e-6;
waterCfg.localGasBalanceAbsTolerance_kg = 1e-6;
waterCfg.localGasBalanceRelativeTolerance = 1e-3;
waterCfg.systemGasBalanceAbsTolerance_kg = 5e-6;
waterCfg.systemGasBalanceRelativeTolerance = 5e-5;
waterCfg.species = struct('n2', 1, 'o2', 2, 'h2', 3, 'h2o', 4);
waterCfg.trackingWindow_s = waterCfg.tailWindow_s;
if mode == "Current"
    waterCfg.loadTrackingMode = "constant_current";
    waterCfg.targetCurrentA = selected(1).targetCurrentA;
    waterCfg.currentTrackingTolerance_A = 5e-3;
    waterCfg.currentTrackingWindow_s = waterCfg.trackingWindow_s;
elseif mode == "Power"
    waterCfg.loadTrackingMode = "constant_power";
    waterCfg.targetPower_kW = selected(1).targetPower_kW;
    waterCfg.powerTrackingRelativeTolerance = 5e-3;
    waterCfg.powerTrackingWindow_s = waterCfg.trackingWindow_s;
else
    waterCfg.loadTrackingMode = "constant_voltage";
    waterCfg.targetVoltage_V = selected(1).targetVoltage_V;
    waterCfg.voltageTrackingRelativeTolerance = 5e-3;
    waterCfg.voltageTrackingWindow_s = waterCfg.trackingWindow_s;
end
try
    ledger = routeA_stage1_water_ledger_from_outputs(selected, waterCfg);
    ledger.attempted = true;
    passed = ledger.auditPassed;
catch ME
    ledger.attempted = true;
    ledger.auditPassed = false;
    ledger.errorId = string(ME.identifier);
    ledger.errorMessage = string(ME.message);
    passed = false;
end
end

function value = scalarTargetRatio(caseCfg)
value = 0;
if ~isfield(caseCfg, 'cegr') || isempty(caseCfg.cegr)
    return;
end
cegr = caseCfg.cegr;
if isnumeric(cegr) && isscalar(cegr)
    value = cegr;
elseif isstruct(cegr) && isfield(cegr, 'targetRatio')
    value = cegr.targetRatio;
elseif isstruct(cegr) && isfield(cegr, 'profile') && ...
        isnumeric(cegr.profile) && isscalar(cegr.profile)
    value = cegr.profile;
end
end

function value = getTextField(s, name, fallback)
if isfield(s, name)
    value = string(s.(name));
else
    value = string(fallback);
end
end

function value = numericField(s, name, fallback)
if isfield(s, name)
    value = s.(name);
else
    value = fallback;
end
end

function value = parameterLayer(model)
mw = get_param(model, 'ModelWorkspace');
value = string(mw.getVariable('routeA_parameter_layer'));
end

function value = externalCaseEnabled(model)
mw = get_param(model, 'ModelWorkspace');
value = logical(mw.getVariable('routeA_external_case_enabled'));
end

function ledger = skippedWaterLedger()
ledger = struct('attempted', false, 'auditPassed', true, ...
    'skipReason', "disabled_or_incomplete", 'cases', struct([]));
end

function summary = buildSummaryTable(cases)
count = numel(cases);
caseId = strings(count, 1);
boundaryType = strings(count, 1);
targetRatio = NaN(count, 1);
actualRatio = NaN(count, 1);
boundaryError = NaN(count, 1);
current_A = NaN(count, 1);
power_kW = NaN(count, 1);
voltage_V = NaN(count, 1);
compressorMdot = NaN(count, 1);
lambda = NaN(count, 1);
passed = false(count, 1);
for idx = 1:count
    item = cases(idx);
    caseId(idx) = string(item.caseId);
    if isfield(item, 'boundaryType')
        boundaryType(idx) = string(item.boundaryType);
    end
    targetRatio(idx) = item.targetRatio;
    actualRatio(idx) = item.actualRatio;
    if isfield(item, 'boundary') && isfield(item.boundary, 'tailRelativeError')
        boundaryError(idx) = item.boundary.tailRelativeError;
    end
    if isfield(item, 'tail')
        current_A(idx) = item.tail.stackCurrent_A.mean;
        power_kW(idx) = item.tail.stackPower_kW.mean;
        voltage_V(idx) = item.tail.stackVoltage_V.mean;
        compressorMdot(idx) = item.tail.compressorMdot_kg_s.mean;
        lambda(idx) = item.tail.lambdaCaIn.minimum;
    end
    passed(idx) = item.passed;
end
summary = table(caseId, boundaryType, targetRatio, actualRatio, ...
    boundaryError, current_A, power_kW, voltage_V, compressorMdot, ...
    lambda, passed);
end

function displayStudy(study)
fprintf('\nRoute A I/P/V electrical-boundary study\n');
fprintf('  cases=%d completed=%d passed=%d water=%d overall=%d\n', ...
    numel(study.cases), numel(study.execution.completedCaseIds), ...
    study.allCasesPassed, study.waterLedgerPassed, study.passed);
disp(study.summaryTable);
end
