function study = run_routeA_focused_study(studyCfg)
% Run focused cathode-cEGR cases through one serial formal runner.
%
% The runner reuses the shared Route A input adapter and cathode/electrical
% output assessor, while the model boundary owns the fixed anode and thermal
% interfaces. Current, Power, and Voltage cases are run as separate calls.

if nargin < 1 || isempty(studyCfg)
    error('RouteA:FocusedStudyConfig', ...
        'A nonempty study configuration is required.');
end

paths = routeA_focused_paths();
addpath(char(paths.sharedScriptDir));
model = char(paths.modelName);
modelDir = char(paths.modelDir);
if ~bdIsLoaded(model)
    load_system(char(paths.modelFile));
end

defaults = routeA_focused_parameter_defaults();
cfg = normalizeConfig(studyCfg, defaults);
caseCount = numel(cfg.cases);
results = cell(caseCount, 1);
outputs = cell(caseCount, 1);
execution = struct( ...
    'requestedCaseIds', strings(0, 1), ...
    'preparedCaseIds', strings(0, 1), ...
    'executedCaseIds', strings(0, 1), ...
    'completedCaseIds', strings(0, 1), ...
    'failedCaseIds', strings(0, 1), ...
    'executionMode', "serial", ...
    'halted', false, ...
    'haltReason', "");

for idx = 1:caseCount
    rawCaseCfg = cfg.cases(idx);
    caseCfg = rawCaseCfg;
    caseId = string(caseCfg.caseId);
    execution.requestedCaseIds(end + 1, 1) = caseId;
    result = failureTemplate();
    result.caseId = caseId;
    try
        [caseCfg, caseAdapter] = routeA_focused_case_adapter( ...
            rawCaseCfg, defaults);
        caseId = string(caseCfg.caseId);
        adapterCfg = rmfield(cfg, ...
            {'retainSimulationOutputs', 'resultFile', 'cases', 'boundaryType'});
        [in, context] = routeA_prepare_electrical_boundary_input( ...
            model, modelDir, caseCfg, adapterCfg);
        [in, focusedBridge] = applyFocusedVariables( ...
            in, caseCfg, defaults, model);
        context.focusedCaseAdapter = caseAdapter;
        context.focusedParameterBridge = focusedBridge;
        execution.preparedCaseIds(end + 1, 1) = caseId;
        out = sim(in);
        execution.executedCaseIds(end + 1, 1) = caseId;
        if strlength(string(out.ErrorMessage)) > 0
            error('RouteA:FocusedSimulationError', '%s', out.ErrorMessage);
        end
        result = routeA_focused_assess_outputs( ...
            out, model, context, caseCfg);
        result.caseCfg = caseCfg;
        result.caseAdapter = caseAdapter;
        result.parameterBridge = focusedBridge;
        result.simCompleted = true;
        execution.completedCaseIds(end + 1, 1) = caseId;
        if cfg.retainSimulationOutputs
            outputs{idx} = out;
        end
    catch exception
        result.errorId = string(exception.identifier);
        result.errorMessage = string(exception.message);
        result.failureCategory = "simulation_or_collection_error";
        execution.failedCaseIds(end + 1, 1) = caseId;
    end
    results{idx} = harmonizeResult(result);
end

results = packResults(results);
execution.matrixComplete = numel(execution.completedCaseIds) == caseCount;
if ~execution.matrixComplete
    execution.halted = true;
    execution.haltReason = "one_or_more_cases_failed";
end

study = struct();
study.schemaVersion = "RouteA_Focused_Study_v01";
study.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
study.model = string(model);
study.modelFile = paths.modelFile;
study.sourceModel = paths.sourceModelName;
study.parameterLayer = "platform_default";
study.initializationPolicy = "cold_start_only";
study.boundaryType = cfg.boundaryType;
study.researchDuration_s = cfg.researchDuration_s;
study.tailLogicalWindow_s = cfg.tailLogicalWindow_s;
study.parameterInterface = defaults.interface;
study.solver = struct( ...
    'name', cfg.solver, ...
    'relativeTolerance', cfg.relativeTolerance, ...
    'absoluteTolerance', cfg.absoluteTolerance, ...
    'maxStep_s', cfg.studyMaxStep_s);
study.cases = results;
study.execution = execution;
study.passed = execution.matrixComplete && ...
    all([results.passed]);
study.retainSimulationOutputs = cfg.retainSimulationOutputs;
if cfg.retainSimulationOutputs
    study.outputs = outputs;
else
study.outputs = {};
end

study.performance = routeA_focused_performance_analysis(study);

if strlength(cfg.resultFile) > 0
    routeA_focused_study = study; %#ok<NASGU>
    save(char(cfg.resultFile), 'routeA_focused_study', '-v7.3');
    study.resultFile = cfg.resultFile;
else
    study.resultFile = "";
end
assignin('base', 'routeA_focused_study', study);
end

function cfg = normalizeConfig(user, defaults)
cfg = struct( ...
    'calculationType', "steady", ...
    'researchDuration_s', defaults.solver.stopTime_s, ...
    'tailLogicalWindow_s', [defaults.solver.stopTime_s - 60, defaults.solver.stopTime_s], ...
    'steadyWindowDuration_s', 60, ...
    'steadyRelativeVariationLimit', 0.005, ...
    'engineeringSteadyRelativeVariationLimit', 0.01, ...
    'solver', defaults.solver.solver, ...
    'relativeTolerance', defaults.solver.relTol, ...
    'absoluteTolerance', defaults.solver.absTol, ...
    'studyMaxStep_s', defaults.solver.maxStep_s, ...
    'commandStartOffset_s', 0.5, ...
    'startupRampDuration_s', 60, ...
    'retainSimulationOutputs', false, ...
    'resultFile', "", ...
    'cases', struct([]));

names = fieldnames(user);
for idx = 1:numel(names)
    if ~isfield(cfg, names{idx})
        error('RouteA:FocusedStudyField', ...
            'Unsupported focused study field: %s.', names{idx});
    end
    cfg.(names{idx}) = user.(names{idx});
end

if isempty(cfg.cases) || ~isstruct(cfg.cases)
    error('RouteA:FocusedCases', 'studyCfg.cases must be a nonempty struct array.');
end
types = strings(1, numel(cfg.cases));
for idx = 1:numel(cfg.cases)
    if ~isfield(cfg.cases(idx), 'caseId') || ...
            strlength(string(cfg.cases(idx).caseId)) == 0
        cfg.cases(idx).caseId = "focused_case_" + idx;
    end
    if isfield(cfg.cases(idx), 'boundary') && ...
            isstruct(cfg.cases(idx).boundary) && ...
            isfield(cfg.cases(idx).boundary, 'type')
        types(idx) = string(cfg.cases(idx).boundary.type);
    elseif isfield(cfg.cases(idx), 'controls') && ...
            isstruct(cfg.cases(idx).controls) && ...
            isfield(cfg.cases(idx).controls, 'electrical') && ...
            isfield(cfg.cases(idx).controls.electrical, 'mode')
        types(idx) = string(cfg.cases(idx).controls.electrical.mode);
    else
        error('RouteA:FocusedBoundary', ...
            'Each focused case must define boundary.type or controls.electrical.mode.');
    end
end
types = unique(types, 'stable');
if numel(types) ~= 1 || ~any(types == ["Current", "Power", "Voltage"])
    error('RouteA:FocusedBoundaryType', ...
        'A focused study call must contain one Current, Power, or Voltage boundary type.');
end
cfg.boundaryType = types(1);
cfg.calculationType = lower(string(cfg.calculationType));
cfg.solver = string(cfg.solver);
cfg.tailLogicalWindow_s = cfg.tailLogicalWindow_s(:).';
cfg.resultFile = string(cfg.resultFile);
end

function [in, bridge] = applyFocusedVariables(in, caseCfg, defaults, model)
[focused, bridge] = routeA_focused_parameter_bridge(caseCfg, defaults);
values = { ...
    'focused_stack_temperature_C', focused.stackTemperature_C; ...
    'focused_anode_feed_p_MPa_abs', focused.anodeFeedPressure_MPa_abs; ...
    'focused_anode_inlet_mdot_kg_s', focused.anodeInletMdot_kg_s; ...
    'focused_anode_outlet_p_MPa_abs', focused.anodeOutletPressure_MPa_abs; ...
    'focused_anode_boundary_T_C', focused.anodeBoundaryTemperature_C; ...
    'focused_anode_yH2', focused.anodeHydrogenMoleFraction; ...
    'focused_anode_pipe_length', focused.anodePipeLength_m; ...
    'focused_anode_pipe_area', focused.anodePipeArea_m2; ...
    'focused_anode_pipe_extra_length', focused.anodePipeExtraLength_m; ...
    'focused_anode_pipe_roughness', focused.anodePipeRoughness_m};
for idx = 1:size(values, 1)
    in = in.setVariable(values{idx, 1}, values{idx, 2}, ...
        'Workspace', model);
end
end

function result = failureTemplate()
result = struct( ...
    'caseId', "", ...
    'simCompleted', false, ...
    'passed', false, ...
    'failureCategory', "not_run", ...
    'errorId', "", ...
    'errorMessage', "");
end

function result = harmonizeResult(value)
result = failureTemplate();
names = fieldnames(value);
for idx = 1:numel(names)
    result.(names{idx}) = value.(names{idx});
end
end

function results = packResults(cells)
fields = {};
for idx = 1:numel(cells)
    fields = union(fields, fieldnames(cells{idx}), 'stable');
end
results = repmat(struct(), numel(cells), 1);
for idx = 1:numel(cells)
    for fieldIdx = 1:numel(fields)
        name = fields{fieldIdx};
        if isfield(cells{idx}, name)
            results(idx).(name) = cells{idx}.(name);
        else
            results(idx).(name) = [];
        end
    end
end
end
