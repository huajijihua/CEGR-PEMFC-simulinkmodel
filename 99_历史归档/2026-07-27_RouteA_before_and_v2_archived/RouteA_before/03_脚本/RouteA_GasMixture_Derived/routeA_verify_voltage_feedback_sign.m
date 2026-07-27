function result = routeA_verify_voltage_feedback_sign()
% Verify the local stack dV/dI sign with an approximately +1 A response.
%
% The test remains on the Voltage branch. A small negative voltage-reference
% step increases load current through the proposed feedback sign. The stack
% current and voltage are read from the MEA Simscape log, not the sparse
% Measurements signal log.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', ...
    'RouteA_GasMixture_Derived');
model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
modelFile = fullfile(modelDir, [model '.slx']);
initialStateFile = fullfile(modelDir, ...
    'RouteA_platform_default_initial_state.mat');
oldDir = pwd;
addpath(scriptDir);
addpath(modelDir);
cd(modelDir);
cleanup = onCleanup(@() routeA_restore_model_and_folder( ...
    model, modelFile, oldDir));

loaded = load(initialStateFile, 'routeA_initial_metadata_voltage');
if ~isfield(loaded, 'routeA_initial_metadata_voltage')
    error('RouteA:VoltageFeedbackSignInitialState', ...
        'The formal Voltage initial-state metadata is unavailable.');
end
metadata = loaded.routeA_initial_metadata_voltage;
if ~isfield(metadata, 'targetVoltage_V') || ...
        string(metadata.loadInputType) ~= "Voltage"
    error('RouteA:VoltageFeedbackSignMetadata', ...
        'The formal Voltage initial-state metadata is incomplete.');
end

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);
t0 = metadata.snapshotTimeS;
stepTime = t0 + 10;
stopTime = t0 + 60;
referenceStep_V = -0.75;
in = Simulink.SimulationInput(model);
[in, initialState] = routeA_attach_platform_default_initial_state( ...
    in, model, modelDir, initialStateFile, "Voltage");
in = in.setModelParameter( ...
    'StopTime', sprintf('%.16g', stopTime), ...
    'MaxStep', '5', ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SimscapeLogType', 'all');
in = in.setVariable('drive_cycle_time', ...
    [t0; stepTime - 1e-3; stepTime; stopTime], 'Workspace', model);
in = in.setVariable('drive_cycle_voltage', ...
    [metadata.targetVoltage_V; metadata.targetVoltage_V; ...
    metadata.targetVoltage_V + referenceStep_V; ...
    metadata.targetVoltage_V + referenceStep_V], 'Workspace', model);
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_target_oer', 3, 'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', 1, ...
    'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 1, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in', 0, ...
    'Workspace', model);
in = in.setVariable('routeA_target_egr_ratio_comp_in_profile', ...
    [t0, 0; stopTime, 0], 'Workspace', model);
out = sim(in);

mea = routeA_simscape_log_mea(out.get(get_param(model, 'SimscapeLogName')));
currentTime = mea.Icell.series.time;
current = mea.Icell.series.values('A');
voltageTime = mea.Vstack.series.time;
voltage = mea.Vstack.series.values('V');
preWindow = [t0 + 5, stepTime - 0.1];
postWindow = [t0 + 40, t0 + 58];
preCurrent = mean(windowValues(currentTime, current, preWindow, 'current'));
postCurrent = mean(windowValues(currentTime, current, postWindow, 'current'));
preVoltage = mean(windowValues(voltageTime, voltage, preWindow, 'voltage'));
postVoltage = mean(windowValues(voltageTime, voltage, postWindow, 'voltage'));

result = struct();
result.model = string(model);
result.initialState = initialState;
result.referenceStep_V = referenceStep_V;
result.preWindow_s = preWindow;
result.postWindow_s = postWindow;
result.deltaCurrent_A = postCurrent - preCurrent;
result.deltaVoltage_V = postVoltage - preVoltage;
result.dVdI_V_A = result.deltaVoltage_V / result.deltaCurrent_A;
result.approximateOneAmperePassed = result.deltaCurrent_A >= 0.8 && ...
    result.deltaCurrent_A <= 1.2;
result.negativeSlopePassed = isfinite(result.dVdI_V_A) && ...
    result.deltaCurrent_A > 0 && result.dVdI_V_A < 0;
result.passed = result.approximateOneAmperePassed && ...
    result.negativeSlopePassed;
assignin('base', 'routeA_voltage_feedback_sign_check', result);
fprintf(['Route A Voltage feedback sign: dI=%.6g A dV=%.6g V ', ...
    'dV/dI=%.6g V/A passed=%d\n'], result.deltaCurrent_A, ...
    result.deltaVoltage_V, result.dVdI_V_A, result.passed);
if ~result.passed
    error('RouteA:VoltageFeedbackSign', ...
        'The approximately +1 A voltage-reference perturbation failed.');
end
clear cleanup;
end

function values = windowValues(time, data, window, label)
mask = time >= window(1) & time < window(2);
values = data(mask);
values = values(:);
if isempty(values) || any(~isfinite(values))
    error('RouteA:VoltageFeedbackSignWindow', ...
        'The %s perturbation window is unavailable or nonfinite.', label);
end
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
end

function refreshModelWorkspace(model)
mw = get_param(model, 'ModelWorkspace');
if strcmp(mw.DataSource, 'MATLAB File')
    mw.reload;
end
end
