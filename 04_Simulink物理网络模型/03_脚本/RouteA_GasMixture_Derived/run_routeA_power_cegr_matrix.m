function study = run_routeA_power_cegr_matrix()
% Run Power mode constant-power cEGR verification.
% Builds SimulationInput directly (bypasses v10 initial state check).
% Uses parsim with 2 workers for parallel execution.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
addpath(scriptDir); addpath(modelDir);

% Study config
dur = 600; ramp = 60; off = 0.5; tail = [540 600]; oer = 3;

% 6 cases: 40kW/120kW x cEGR=0/0.1/0.3
defs = {'p40kw_c0', 40, 0; 'p40kw_c01', 40, 0.1; 'p40kw_c03', 40, 0.3;
    'p120kw_c0', 120, 0; 'p120kw_c01', 120, 0.1; 'p120kw_c03', 120, 0.3};
n = size(defs,1);

% Load model
if ~bdIsLoaded(model), load_system(modelFile); end
mw = get_param(model, 'ModelWorkspace');
bl = reshape(double(mw.getVariable('routeA_command_profile_baseline')), 1, []);

% Resolve schema field indices (single source of truth)
schema = routeA_command_profile_schema();
idxAirTargetOer = find(schema.names == "air_target_oer");
idxCegrRatio = find(schema.names == "cegr_ratio");

% Build 6 inputs
t = [0; off; off+ramp; dur];
inputs(1:n) = Simulink.SimulationInput(model);
for i = 1:n
    pw = defs{i,2}; cr = defs{i,3};
    % Command profile: 4x23 [time, 22 values]
    cp = zeros(4, 23);
    cp(:,1) = t;                    % time column
    for c = 1:22, cp(:,c+1) = bl(c); end
    cp(:, idxAirTargetOer+1) = oer;              % air_target_oer
    cp(:, idxCegrRatio+1) = [0; 0; cr; cr];      % cegr_ratio
    % Power demand: just values (column vector), NOT [time, data]
    pdem = [0; 0; pw; pw];
    in = Simulink.SimulationInput(model);
    in = in.setBlockParameter([model '/System_Control_Observability/Electrical Load'], 'input_type', 'Power');
    in = in.setModelParameter('StopTime', sprintf('%.16g', dur), 'Solver', 'VariableStepAuto', ...
        'RelTol', '1e-3', 'AbsTol', '1e-3', 'MaxStep', '5', ...
        'SignalLogging', 'on', 'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', 'SimscapeLogType', 'all');
    in = in.setVariable('routeA_command_profile', cp, 'Workspace', model);
    in = in.setVariable('drive_cycle_time', t, 'Workspace', model);
    in = in.setVariable('drive_cycle_power', pdem, 'Workspace', model);
    in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
    in = in.setVariable('routeA_cegr_enabled', true, 'Workspace', model);
    in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
    in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
    in = in.setVariable('routeA_egr_target_input_mode_id', 1, 'Workspace', model);
    inputs(i) = in;
end

% Ensure parallel pool
p = gcp('nocreate');
if isempty(p), p = parpool('local', 2); end

% Run
fprintf('Running %d Power mode cases (parsim, %d workers)...\n', n, p.NumWorkers);
tic;
outs = parsim(inputs, 'AttachedFiles', {modelFile}, 'SetupFcn', @() addpath(scriptDir, modelDir), ...
    'ManageDependencies', 'on', 'ShowProgress', 'on', 'UseFastRestart', 'off', 'StopOnError', 'off');
fprintf('Done in %.0f s\n', toc);

% Results
res = struct('caseId', cell(n,1), 'passed', false, 'targetPower_kW', NaN, 'targetCegr', NaN, ...
    'tailPower_kW', NaN, 'tailVoltage_V', NaN, 'tailCurrent_A', NaN, ...
    'tailCegrRatio', NaN, 'tailCegrError', NaN, 'powerErrPct', NaN, 'steadyPassed', false, 'error', "");

for i = 1:n
    res(i).caseId = defs{i,1}; res(i).targetPower_kW = defs{i,2}; res(i).targetCegr = defs{i,3};
    o = outs(i);
    if strlength(string(o.ErrorMessage)) > 0
        res(i).error = string(o.ErrorMessage); fprintf('  %s: ERROR %s\n', defs{i,1}, o.ErrorMessage); continue;
    end
    try
        ls = o.logsout;
        cv = ls.get('routeA_stack_current_A').Values; vv = ls.get('routeA_stack_voltage_V').Values;
        pv = timeseries(cv.Data.*vv.Data*1e-3, cv.Time);
        ev = ls.get('routeA_egr_ratio_comp_in').Values;
        % Tail
        tm = pv.Time >= tail(1) & pv.Time < tail(2);
        res(i).tailPower_kW = mean(pv.Data(tm));
        res(i).tailVoltage_V = mean(vv.Data(tm));
        res(i).tailCurrent_A = mean(cv.Data(tm));
        em = ev.Time >= tail(1) & ev.Time < tail(2);
        res(i).tailCegrRatio = mean(ev.Data(em));
        res(i).tailCegrError = res(i).tailCegrRatio - defs{i,3};
        res(i).powerErrPct = abs(res(i).tailPower_kW - defs{i,2}) / max(abs(defs{i,2}),1) * 100;
        % Steady
        mid = mean(tail); f1 = vv.Time >= tail(1) & vv.Time < mid; f2 = vv.Time >= mid & vv.Time < tail(2);
        rc = abs(mean(vv.Data(f2)) - mean(vv.Data(f1))) / max(abs(mean(vv.Data(f1))), 1);
        res(i).steadyPassed = rc <= 0.005;
        res(i).passed = res(i).powerErrPct <= 0.5 && abs(res(i).tailCegrError) <= max(0.002, 0.1*max(defs{i,3},0.01)) && res(i).steadyPassed;
        fprintf('  %s: P=%.1fkW V=%.2fV I=%.1fA cEGR=%.4f err=%.3f%% pass=%d\n', ...
            defs{i,1}, res(i).tailPower_kW, res(i).tailVoltage_V, res(i).tailCurrent_A, res(i).tailCegrRatio, res(i).powerErrPct, res(i).passed);
    catch ME
        res(i).error = ME.message; fprintf('  %s: EXTRACT ERROR %s\n', defs{i,1}, ME.message);
    end
end

% Summary
fprintf('\n=== Power Mode cEGR Matrix ===\n');
ap = true;
for i = 1:n
    s = iff(res(i).passed, 'PASS', 'FAIL'); if ~res(i).passed, ap = false; end
    fprintf('%-12s %5.0fkW cEGR=%.1f V=%7.2fV I=%6.1fA Perr=%5.2f%% %s\n', ...
        res(i).caseId, res(i).targetPower_kW, res(i).targetCegr, res(i).tailVoltage_V, res(i).tailCurrent_A, res(i).powerErrPct, s);
end
fprintf('Overall: %s\n', iff(ap, 'ALL PASSED', 'SOME FAILED'));

study = struct('timestamp', string(datetime('now')), 'model', model, 'results', res, 'allPassed', ap);
assignin('base', 'routeA_power_cegr_study', study);
end
function s = iff(c, t, f)
if c, s = t; else, s = f; end
end