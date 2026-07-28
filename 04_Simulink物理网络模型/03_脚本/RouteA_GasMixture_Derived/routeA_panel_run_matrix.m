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

[command, cegr, oer, o2] = ndgrid(axisValues{1}, axisValues{2}, ...
    axisValues{3}, axisValues{4});
count = numel(command);
if count > 24
    error('RouteA:PanelMatrixSize', ...
        'The panel matrix is limited to 24 cases per run.');
end

cases = repmat(struct('caseId', "", 'simCase', struct(), ...
    'simulationInput', [], 'output', [], 'results', struct(), ...
    'passed', false, 'errorId', "", 'errorMessage', ""), count, 1);
inputs = repmat(Simulink.SimulationInput( ...
    'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01'), count, 1);
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
    inputs(idx) = routeA_panel_build_simulation_input(sc, rampDuration_s);
end

modelDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', ...
    '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, ...
    'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx');
scriptDir = fileparts(mfilename('fullpath'));
if executionMode == "parallel"
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
    for idx = 1:count
        outputs{idx} = sim(inputs(idx));
    end
end

for idx = 1:count
    cases(idx).simulationInput = inputs(idx);
    cases(idx).output = outputs{idx};
    try
        out = outputs{idx};
        if strlength(string(out.ErrorMessage)) > 0
            error('RouteA:PanelMatrixSimulation', '%s', out.ErrorMessage);
        end
        result = routeA_panel_extract_results(out, cases(idx).simCase);
        result.actual_cegr_ratio = actualCegrRatio(out);
        result.target_command = cases(idx).simCase.controls.electrical.profile;
        result = assessAcceptance(result, cases(idx).simCase);
        cases(idx).results = result;
        cases(idx).passed = result.passed;
    catch ME
        cases(idx).errorId = string(ME.identifier);
        cases(idx).errorMessage = string(ME.message);
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
study.summaryTable = buildSummaryTable(cases);
end

function result = assessAcceptance(result, simCase)
finiteKpi = all(isfinite([result.voltage_V, result.current_A, ...
    result.power_kW, result.actual_cegr_ratio]));
result.command_error = NaN;
result.command_error_pct = NaN;
result.cegr_error = NaN;
result.cegr_tolerance = NaN;
result.steady_relative_change = NaN;
result.finitePassed = finiteKpi;
result.steadyPassed = false;
result.trackingPassed = false;
result.cegrPassed = false;
if ~finiteKpi
    result.passed = false;
    return;
end

target = simCase.controls.electrical.profile;
mode = string(simCase.controls.electrical.mode);
switch mode
    case "Current"
        actual = result.current_A;
    case "Power"
        actual = result.power_kW;
    case "Voltage"
        actual = result.voltage_V;
    otherwise
        error('RouteA:PanelMatrixMode', 'Unsupported matrix mode: %s.', mode);
end
result.command_error = actual - target;
result.command_error_pct = abs(result.command_error) / ...
    max(abs(target), 1) * 100;
result.trackingPassed = result.command_error_pct <= 0.5;

result.cegr_error = result.actual_cegr_ratio - ...
    simCase.controls.cegr.targetRatio;
result.cegr_tolerance = max(0.002, ...
    0.1 * max(simCase.controls.cegr.targetRatio, 0.01));
cegrPassed = abs(result.cegr_error) <= result.cegr_tolerance;
result.cegrPassed = cegrPassed;

time = result.voltage_ts.Time;
tailStart = max(time) - min(60, max(time) - min(time));
tailMask = time >= tailStart;
tailTime = time(tailMask);
tailVoltage = result.voltage_ts.Data(tailMask);
if numel(tailTime) >= 4
    midpoint = (tailTime(1) + tailTime(end)) / 2;
    first = tailVoltage(tailTime <= midpoint);
    second = tailVoltage(tailTime > midpoint);
    if ~isempty(first) && ~isempty(second)
        result.steady_relative_change = abs(mean(second) - mean(first)) / ...
            max(abs(mean(first)), 1);
    end
end
result.steadyPassed = isfinite(result.steady_relative_change) && ...
    result.steady_relative_change <= 0.005;

% A short matrix is a compile/logging smoke. It must be finite, but should
% not be rejected because the cEGR or electrical loop has not settled yet.
if simCase.solver.stopTime_s < 120
    result.passed = finiteKpi;
else
    result.passed = result.trackingPassed && cegrPassed && result.steadyPassed;
end
end

function ratio = actualCegrRatio(out)
ratio = NaN;
logsout = out.get('logsout');
if isempty(logsout) || ...
        ~any(strcmp(logsout.getElementNames, 'routeA_egr_ratio_comp_in'))
    return;
end
signal = logsout.get('routeA_egr_ratio_comp_in').Values;
mask = signal.Time >= max(signal.Time) - 60;
if any(mask)
    ratio = mean(signal.Data(mask));
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
