% Route A steady-state comparison of the two persisted V4 base models.
% The with-cEGR model retains the complete recirculation path. The no-cEGR
% model replaces only the cross-subsystem recirculation connection with an
% Infinite Flow Resistance (FC), so cathode exhaust leaves through the
% existing exhaust path without relying on a numerically near-closed valve.

scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
cleanup = onCleanup(@() restoreModels(oldDir));

stopTime = 120;
targetPowerKW = 50.96;
targetEgrRatio = 0.02;
cases = [
    caseDef("no_cegr", "PEMFuelCellSystem_GasMixture_noCEGR_RouteA_v01", ...
        2, 0, targetPowerKW, stopTime)
    caseDef("with_cegr", "PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01", ...
        1, targetEgrRatio, targetPowerKW, stopTime)];
results = repmat(emptyResult(), numel(cases), 1);

fprintf('\nRoute A dual-baseline steady-state comparison\n');
fprintf('  power=%.4g kW stopTime=%.4g s\n', targetPowerKW, stopTime);
for idx = 1:numel(cases)
    results(idx) = runCase(cases(idx), modelDir);
end

comparison = struct();
comparison.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
comparison.stopTime = stopTime;
comparison.targetPowerKW = targetPowerKW;
comparison.targetEgrRatio = targetEgrRatio;
comparison.results = results;
comparison.simCompleted = all([results.simCompleted]);
comparison.finiteOk = all([results.finiteOk]);
comparison.powerSteady = all([results.powerSteady]);
comparison.noCegrClosed = abs(results(1).egrRatio) <= 1e-8;
comparison.withCegrActive = abs(results(2).egrRatio - targetEgrRatio) <= 1e-3 && ...
    results(2).egrTailSpan <= 1e-4;
comparison.passed = comparison.simCompleted && comparison.finiteOk && ...
    comparison.powerSteady && comparison.noCegrClosed && ...
    comparison.withCegrActive;
assignin('base', 'routeA_steady_state_cegr_comparison', comparison);
displayComparison(comparison);

function c = caseDef(caseId, model, egrMode, targetEgrRatio, targetPowerKW, stopTime)
c = struct('caseId', string(caseId), 'model', string(model), ...
    'egrMode', egrMode, 'targetEgrRatio', targetEgrRatio, ...
    'targetPowerKW', targetPowerKW, 'stopTime', stopTime, ...
    'targetMdotKgS', 0.045, 'targetOer', 2.5, ...
    'directCompressorCmd', 0.5, ...
    'targetPCaOutMPa', 0.161325, 'humidifierGain', 1, ...
    'stackTemperatureSetC', 80);
end

function result = emptyResult()
result = struct('caseId', "", 'model', "", 'simCompleted', false, ...
    'finiteOk', false, 'powerSteady', false, 'errorId', "", ...
    'errorMessage', "", 'actualPowerKW', NaN, ...
    'powerTailSpanKW', NaN, 'egrRatio', NaN, 'egrTailSpan', NaN, ...
    'exhaustMdotKgS', NaN, 'stopTime', NaN);
end

function result = runCase(c, modelDir)
result = emptyResult();
result.caseId = c.caseId;
result.model = c.model;
result.stopTime = c.stopTime;
model = char(c.model);
modelFile = fullfile(modelDir, [model '.slx']);

try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    mw = get_param(model, 'ModelWorkspace');
    pipeArea = getWorkspaceValue(mw, 'cegr_pipe_area', 0.0019634954);

    in = Simulink.SimulationInput(model);
    in = in.setModelParameter( ...
        'StopTime', sprintf('%.16g', c.stopTime), ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'all');
    in = in.setVariable('drive_cycle_time', [0; 0.5; c.stopTime], ...
        'Workspace', model);
    in = in.setVariable('drive_cycle_power', ...
        [0; c.targetPowerKW; c.targetPowerKW], 'Workspace', model);
    in = in.setVariable('routeA_air_control_mode_id', 1, 'Workspace', model);
    in = in.setVariable('routeA_target_mdot_comp_inlet', ...
        c.targetMdotKgS, 'Workspace', model);
    in = in.setVariable('routeA_target_oer', c.targetOer, 'Workspace', model);
    in = in.setVariable('routeA_compressor_cmd_direct', ...
        c.directCompressorCmd, 'Workspace', model);
    in = in.setVariable('routeA_egr_control_mode_id', c.egrMode, ...
        'Workspace', model);
    in = in.setVariable('routeA_target_egr_ratio_comp_in', ...
        c.targetEgrRatio, 'Workspace', model);
    in = in.setVariable('routeA_egr_valve_area_direct', ...
        2e-3 * pipeArea, 'Workspace', model);
    in = in.setVariable('routeA_target_p_ca_out_MPa', ...
        c.targetPCaOutMPa, 'Workspace', model);
    in = in.setVariable('routeA_cathode_humidifier_gain', ...
        c.humidifierGain, 'Workspace', model);
    in = in.setVariable('routeA_stack_temperature_set_C', ...
        c.stackTemperatureSetC, 'Workspace', model);

    out = sim(in);
    result.simCompleted = true;
    simlog = out.get(get_param(model, 'SimscapeLogName'));
    mea = routeA_simscape_log_mea(simlog);
    power = mea.power_elec.series.values('kW');
    egr = out.get('routeA_egr_ratio_comp_in_ts');
    exhaust = out.get('routeA_exhaust_mdot_ts');
    result.actualPowerKW = power(end);
    result.powerTailSpanKW = tailSpan(power);
    result.egrRatio = egr.Data(end);
    result.egrTailSpan = timeTailSpan(egr, 10);
    result.exhaustMdotKgS = exhaust.Data(end);
    result.finiteOk = all(isfinite([result.actualPowerKW, ...
        result.powerTailSpanKW, result.egrRatio, result.egrTailSpan, ...
        result.exhaustMdotKgS]));
    result.powerSteady = result.powerTailSpanKW <= 1e-3;
catch ME
    result.errorId = string(ME.identifier);
    result.errorMessage = firstLine(string(ME.message));
end

resetModelFromDisk(model, modelFile);
end

function value = tailSpan(values)
values = values(:);
count = max(3, ceil(0.1 * numel(values)));
tail = values(end-count+1:end);
value = max(tail) - min(tail);
end

function value = timeTailSpan(signal, seconds)
tail = signal.Time >= signal.Time(end) - seconds;
data = signal.Data(tail);
value = max(data) - min(data);
end

function value = getWorkspaceValue(modelWorkspace, name, fallback)
value = fallback;
try
    value = modelWorkspace.getVariable(name);
catch
end
end

function txt = firstLine(txt)
parts = splitlines(txt);
txt = parts(1);
end

function resetModelFromDisk(model, modelFile)
if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
end

function refreshModelWorkspace(model)
modelWorkspace = get_param(model, 'ModelWorkspace');
if strcmp(modelWorkspace.DataSource, 'MATLAB File')
    modelWorkspace.reload;
end
end

function restoreModels(oldDir)
cd(oldDir);
models = ["PEMFuelCellSystem_GasMixture_noCEGR_RouteA_v01", ...
    "PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01"];
for idx = 1:numel(models)
    if bdIsLoaded(models(idx))
        close_system(models(idx), 0);
    end
end
end

function displayComparison(comparison)
fprintf('\nRoute A dual-baseline result\n');
fprintf('  passed=%d simCompleted=%d finite=%d powerSteady=%d\n', ...
    comparison.passed, comparison.simCompleted, comparison.finiteOk, ...
    comparison.powerSteady);
for idx = 1:numel(comparison.results)
    r = comparison.results(idx);
    fprintf(['  %s P=%.6g kW Pspan=%.3g egr=%.6g egrSpan=%.3g ', ...
        'exhaust=%.6g kg/s\n'], r.caseId, r.actualPowerKW, ...
        r.powerTailSpanKW, r.egrRatio, r.egrTailSpan, ...
        r.exhaustMdotKgS);
end
fprintf('  noCegrClosed=%d withCegrActive=%d\n', ...
    comparison.noCegrClosed, comparison.withCegrActive);
end
