function study = run_routeA_voltage_cegr_matrix()
% Run Voltage mode constant-voltage cEGR verification.
% Builds SimulationInput directly (bypasses v10 initial state check).
% Uses parsim with 2 workers for parallel execution.
%
% 6 cases: 410V/375V x cEGR=0/0.1/0.3
% PI params: Kp=1, Ki=0.05 (model workspace defaults, historically validated)

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
addpath(scriptDir); addpath(modelDir);

% Study config
dur = 600; ramp = 60; off = 0.5; tail = [540 600]; oer = 3;

% 6 cases: 410V/375V x cEGR=0/0.1/0.3
defs = {'v410_c0', 410, 0; 'v410_c01', 410, 0.1; 'v410_c03', 410, 0.3;
    'v375_c0', 375, 0; 'v375_c01', 375, 0.1; 'v375_c03', 375, 0.3};
n = size(defs,1);

% Load model
if ~bdIsLoaded(model), load_system(modelFile); end
mw = get_param(model, 'ModelWorkspace');
bl = reshape(double(mw.getVariable('routeA_command_profile_baseline')), 1, []);

% Resolve schema field indices (single source of truth)
schema = routeA_command_profile_schema();
idxAirTargetOer = find(schema.names == "air_target_oer");
idxCegrRatio = find(schema.names == "cegr_ratio");

% PI controller parameters (model workspace defaults)
kp = 1;      % routeA_voltage_pi_Kp
ki = 0.05;   % routeA_voltage_pi_Ki
imin = 0;    % routeA_voltage_current_min_A
imax = 392;  % routeA_voltage_current_max_A

% Build 6 inputs
t = [0; off; off+ramp; dur];
inputs(1:n) = Simulink.SimulationInput(model);
for i = 1:n
    vtg = defs{i,2}; cr = defs{i,3};
    % Command profile: 4x23 [time, 22 values]
    cp = zeros(4, 23);
    cp(:,1) = t;                    % time column
    for c = 1:22, cp(:,c+1) = bl(c); end
    cp(:, idxAirTargetOer+1) = oer;              % air_target_oer
    cp(:, idxCegrRatio+1) = [0; 0; cr; cr];      % cegr_ratio
    % Voltage demand: start from initial state voltage (~427.6V), ramp to target
    % This prevents PI controller saturation from a 0V command mismatch
    v_init = 427.6;
    vdem = [v_init; v_init; vtg; vtg];
    in = Simulink.SimulationInput(model);
    in = in.setBlockParameter([model '/System_Control_Observability/Electrical Load'], 'input_type', 'Voltage');
    in = in.setModelParameter('StopTime', sprintf('%.16g', dur), 'Solver', 'VariableStepAuto', ...
        'RelTol', '1e-3', 'AbsTol', '1e-3', 'MaxStep', '5', ...
        'SignalLogging', 'on', 'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', 'SimscapeLogType', 'all');
    in = in.setVariable('routeA_command_profile', cp, 'Workspace', model);
    in = in.setVariable('drive_cycle_time', t, 'Workspace', model);
    in = in.setVariable('drive_cycle_voltage', vdem, 'Workspace', model);
    % PI controller parameters
    in = in.setVariable('routeA_voltage_pi_Kp', kp, 'Workspace', model);
    in = in.setVariable('routeA_voltage_pi_Ki', ki, 'Workspace', model);
    in = in.setVariable('routeA_voltage_current_min_A', imin, 'Workspace', model);
    in = in.setVariable('routeA_voltage_current_max_A', imax, 'Workspace', model);
    % Control mode settings
    in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
    in = in.setVariable('routeA_cegr_enabled', true, 'Workspace', model);
    in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
    in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
    in = in.setVariable('routeA_egr_target_input_mode_id', 1, 'Workspace', model);
    inputs(i) = in;
end

% Save model before parsim (required for worker distribution)
save_system(model);

% Ensure parallel pool
p = gcp('nocreate');
if isempty(p), p = parpool('local', 2); end

% Run
fprintf('Running %d Voltage mode cases (parsim, %d workers)...\n', n, p.NumWorkers);
tic;
outs = parsim(inputs, 'AttachedFiles', {modelFile}, 'SetupFcn', @() addpath(scriptDir, modelDir), ...
    'ManageDependencies', 'on', 'ShowProgress', 'on', 'UseFastRestart', 'off', 'StopOnError', 'off');
fprintf('Done in %.0f s\n', toc);

% Results
res = struct('caseId', cell(n,1), 'passed', false, 'targetVoltage_V', NaN, 'targetCegr', NaN, ...
    'tailVoltage_V', NaN, 'tailCurrent_A', NaN, 'tailPower_kW', NaN, ...
    'tailCegrRatio', NaN, 'tailCegrError', NaN, 'voltageErrPct', NaN, ...
    'voltageSpan_V', NaN, 'steadyPassed', false, 'error', "");

for i = 1:n
    res(i).caseId = defs{i,1}; res(i).targetVoltage_V = defs{i,2}; res(i).targetCegr = defs{i,3};
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
        vm = vv.Time >= tail(1) & vv.Time < tail(2);
        res(i).tailVoltage_V = mean(vv.Data(vm));
        res(i).tailCurrent_A = mean(cv.Data(vm));
        res(i).tailPower_kW = mean(pv.Data(vm));
        em = ev.Time >= tail(1) & ev.Time < tail(2);
        res(i).tailCegrRatio = mean(ev.Data(em));
        res(i).tailCegrError = res(i).tailCegrRatio - defs{i,3};
        res(i).voltageErrPct = abs(res(i).tailVoltage_V - defs{i,2}) / max(abs(defs{i,2}),1) * 100;
        % Voltage span within tail window
        res(i).voltageSpan_V = max(vv.Data(vm)) - min(vv.Data(vm));
        % Steady check: compare first half vs second half of tail window
        mid = mean(tail); f1 = vv.Time >= tail(1) & vv.Time < mid; f2 = vv.Time >= mid & vv.Time < tail(2);
        rc = abs(mean(vv.Data(f2)) - mean(vv.Data(f1))) / max(abs(mean(vv.Data(f1))), 1);
        res(i).steadyPassed = rc <= 0.005;
        % Pass criteria: voltage error < 0.5%, span < 0.5% of target, cEGR accuracy, steady
        spanLimit = 0.005 * max(abs(defs{i,2}), 1);
        res(i).passed = res(i).voltageErrPct <= 0.5 && res(i).voltageSpan_V <= spanLimit && ...
            abs(res(i).tailCegrError) <= max(0.002, 0.1*max(defs{i,3},0.01)) && res(i).steadyPassed;
        fprintf('  %s: V=%.2fV I=%.1fA P=%.1fkW cEGR=%.4f Verr=%.3f%% span=%.3fV pass=%d\n', ...
            defs{i,1}, res(i).tailVoltage_V, res(i).tailCurrent_A, res(i).tailPower_kW, ...
            res(i).tailCegrRatio, res(i).voltageErrPct, res(i).voltageSpan_V, res(i).passed);
    catch ME
        res(i).error = ME.message; fprintf('  %s: EXTRACT ERROR %s\n', defs{i,1}, ME.message);
    end
end

% Summary
fprintf('\n=== Voltage Mode cEGR Matrix ===\n');
ap = true;
for i = 1:n
    s = iff(res(i).passed, 'PASS', 'FAIL'); if ~res(i).passed, ap = false; end
    fprintf('%-12s %5.0fV cEGR=%.1f V=%7.2fV I=%6.1fA P=%6.1fkW Verr=%5.2f%% %s\n', ...
        res(i).caseId, res(i).targetVoltage_V, res(i).targetCegr, ...
        res(i).tailVoltage_V, res(i).tailCurrent_A, res(i).tailPower_kW, ...
        res(i).voltageErrPct, s);
end
fprintf('Overall: %s\n', iff(ap, 'ALL PASSED', 'SOME FAILED'));

study = struct('timestamp', string(datetime('now')), 'model', model, 'results', res, 'allPassed', ap);
assignin('base', 'routeA_voltage_cegr_study', study);
end

function s = iff(c, t, f)
if c, s = t; else, s = f; end
end