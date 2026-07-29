function study = routeA_panel_run_matrix(baseCase, axes, executionMode)
% Run a bounded Route A panel matrix from one validated simCase.
%
% axes is a scalar struct with numeric vectors:
%   .electricalCommand
%   .cegrRatio
%   .targetOer
%   .o2MoleFraction
%
% The Cartesian product is built explicitly. Each case receives an
% independent SimulationInput and workspace override. Serial execution is
% the default; parallel execution is enabled only when requested.

if nargin < 3 || isempty(executionMode)
    executionMode = 'serial';
end
executionMode = lower(string(executionMode));
if ~any(executionMode == ["serial", "parallel"])
    error('RouteA:PanelMatrixExecutionMode', ...
        'executionMode must be serial or parallel.');
end
if ~isstruct(baseCase) || ~isscalar(baseCase)
    error('RouteA:PanelMatrixBaseCase', ...
        'baseCase must be a scalar simCase struct.');
end
baseCase = routeA_validate_case(baseCase);
if ~isstruct(axes) || ~isscalar(axes)
    error('RouteA:PanelMatrixAxes', ...
        'axes must be a scalar struct.');
end

axisNames = {'electricalCommand', 'cegrRatio', 'targetOer', ...
    'o2MoleFraction'};
axisValues = cell(size(axisNames));
for idx = 1:numel(axisNames)
    name = axisNames{idx};
    if ~isfield(axes, name) || isempty(axes.(name))
        error('RouteA:PanelMatrixAxis', ...
            'Matrix axis %s must contain at least one value.', name);
    end
    value = axes.(name);
    validateattributes(value, {'numeric'}, ...
        {'vector', 'real', 'finite', 'nonempty'});
    axisValues{idx} = value(:).';
end

paths = routeA_project_paths();
model = paths.modelName;
[command, cegr, oer, o2] = ndgrid(axisValues{1}, axisValues{2}, ...
    axisValues{3}, axisValues{4});
count = numel(command);
if count > 24
    error('RouteA:PanelMatrixSize', ...
        'The panel matrix is limited to 24 cases per run.');
end

cases = repmat(struct('caseId', "", 'simCase', struct(), ...
    'simulationInput', [], 'context', struct(), 'output', [], ...
    'results', struct(), ...
    'passed', false, 'errorId', "", 'errorMessage', "", ...
    'failureCategory', "not_run"), count, 1);
inputs = repmat(Simulink.SimulationInput(model), count, 1);
params = routeA_platform_default_parameters();
rampDuration_s = min(params.numerics.startupRampDuration_s.value, ...
    0.1 * baseCase.solver.stopTime_s);
if rampDuration_s <= 0 || rampDuration_s >= baseCase.solver.stopTime_s
    error('RouteA:PanelMatrixRampDuration', ...
        'The matrix ramp duration must be positive and less than stopTime.');
end

for idx = 1:count
    sc = baseCase;
    sc.caseId = sprintf('%s_m%03d', char(baseCase.caseId), idx);
    sc.controls.electrical.profile = command(idx);
    sc.controls.cegr.targetRatio = cegr(idx);
    sc.controls.cegr.enabled = cegr(idx) > 0;
    sc.controls.cathode.targetOer = oer(idx);
    sc.controls.cathode.o2MoleFraction = o2(idx);
    sc = routeA_validate_case(sc);
    cases(idx).caseId = sc.caseId;
    cases(idx).simCase = sc;
    [inputs(idx), cases(idx).context] = ...
        routeA_panel_build_simulation_input(sc, rampDuration_s);
end

modelDir = paths.modelDir;
modelFile = paths.modelFile;
scriptDir = paths.scriptDir;
if executionMode == "parallel"
    dispatchErrors = repmat(struct('identifier', "", 'message', "", ...
        'category', ""), count, 1);
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local', 2);
    elseif pool.NumWorkers < 2
        error('RouteA:PanelMatrixPool', ...
            'Parallel matrix execution requires at least two workers.');
    end
    rawOutputs = parsim(inputs, 'AttachedFiles', {modelFile}, ...
        'SetupFcn', @() addpath(scriptDir, modelDir), ...
        'ManageDependencies', 'on', 'ShowProgress', 'on', ...
        'UseFastRestart', 'off', 'StopOnError', 'off');
    outputs = num2cell(rawOutputs);
else
    outputs = cell(count, 1);
    dispatchErrors = repmat(struct('identifier', "", 'message', "", ...
        'category', ""), count, 1);
    for idx = 1:count
        try
            outputs{idx} = sim(inputs(idx));
        catch ME
            dispatchErrors(idx).identifier = string(ME.identifier);
            dispatchErrors(idx).message = string(ME.message);
            dispatchErrors(idx).category = matrixFailureCategory(ME);
        end
    end
end

for idx = 1:count
    cases(idx).simulationInput = inputs(idx);
    cases(idx).output = outputs{idx};
    try
        if isempty(outputs{idx})
            cases(idx).errorId = dispatchErrors(idx).identifier;
            cases(idx).errorMessage = dispatchErrors(idx).message;
            cases(idx).failureCategory = dispatchErrors(idx).category;
            cases(idx).results = struct( ...
                'caseId', cases(idx).caseId, ...
                'status', "simulation_failed", ...
                'passed', false, ...
                'warningOnly', false, ...
                'failureCategory', cases(idx).failureCategory, ...
                'errorId', cases(idx).errorId, ...
                'errorMessage', cases(idx).errorMessage);
            continue;
        end
        out = outputs{idx};
        if strlength(string(out.ErrorMessage)) > 0
            error('RouteA:PanelMatrixSimulation', '%s', out.ErrorMessage);
        end
        result = routeA_panel_extract_results(out, cases(idx).simCase, ...
            cases(idx).context);
        cases(idx).results = result;
        cases(idx).passed = result.passed;
        cases(idx).failureCategory = result.failureCategory;
    catch ME
        cases(idx).errorId = string(ME.identifier);
        cases(idx).errorMessage = string(ME.message);
        cases(idx).failureCategory = matrixFailureCategory(ME);
        cases(idx).results = struct( ...
            'caseId', cases(idx).caseId, ...
            'status', "simulation_failed", ...
            'passed', false, ...
            'warningOnly', false, ...
            'failureCategory', cases(idx).failureCategory, ...
            'errorId', cases(idx).errorId, ...
            'errorMessage', cases(idx).errorMessage);
    end
end

study = struct();
study.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
study.model = "PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01";
study.executionMode = executionMode;
study.caseCount = count;
if baseCase.solver.stopTime_s < 120
    study.acceptanceMode = "smoke";
else
    study.acceptanceMode = "formal";
end
study.cases = cases;
study.allPassed = all([cases.passed]);
study.failureCount = sum(~[cases.passed]);
study.modelVersion = cases(1).context.initialStateMetadata.modelVersion;
study.topologyHash = string(cases(1).context.initialStateMetadata.topologyHash);
study.parameterLayer = string(cases(1).context.initialStateMetadata.parameterLayer);
study.initializationPolicy = string(cases(1).context.initializationPolicy);
study.operatingPointLoaded = logical( ...
    cases(1).context.initialStateSelection.operatingPointLoaded);
study.externalCaseEnabled = logical( ...
    cases(1).context.initialStateMetadata.externalCaseEnabled);
if isfield(cases(1).results, 'waterCapability')
    study.waterCapability = cases(1).results.waterCapability;
else
    study.waterCapability = struct( ...
        'level', "L2", ...
        'status', "not_available", ...
        'liquidWaterConclusionAllowed', false, ...
        'warnings', "No completed panel result was available for the water-capability contract.");
end
study.warningCount = sum(arrayfun(@(item) isfield(item.results, 'warningOnly') && ...
    item.results.warningOnly, cases));
study.summaryTable = buildSummaryTable(cases);
end

function category = matrixFailureCategory(exception)
identifier = string(exception.identifier);
if contains(identifier, "OperatingPoint")
    category = "initial_state_or_interface";
elseif contains(identifier, "Observation") || contains(identifier, "MissingSignal")
    category = "observation_contract";
elseif contains(identifier, "ElectricalBoundary") || contains(identifier, "Panel")
    category = "panel_input_or_acceptance";
else
    category = "simulation_failed";
end
end

function tableOut = buildSummaryTable(cases)
count = numel(cases);
caseId = strings(count, 1);
command = NaN(count, 1);
targetCegr = NaN(count, 1);
actualCegr = NaN(count, 1);
voltage = NaN(count, 1);
current = NaN(count, 1);
power = NaN(count, 1);
passed = false(count, 1);
for idx = 1:count
    caseId(idx) = string(cases(idx).caseId);
    if ~isempty(cases(idx).simCase)
        command(idx) = cases(idx).simCase.controls.electrical.profile;
        targetCegr(idx) = cases(idx).simCase.controls.cegr.targetRatio;
    end
    passed(idx) = cases(idx).passed;
    if isfield(cases(idx).results, 'actual_cegr_ratio')
        actualCegr(idx) = cases(idx).results.actual_cegr_ratio;
    end
    if isfield(cases(idx).results, 'voltage_V')
        voltage(idx) = cases(idx).results.voltage_V;
        current(idx) = cases(idx).results.current_A;
        power(idx) = cases(idx).results.power_kW;
    end
end
tableOut = table(caseId, command, targetCegr, actualCegr, voltage, ...
    current, power, passed);
end
