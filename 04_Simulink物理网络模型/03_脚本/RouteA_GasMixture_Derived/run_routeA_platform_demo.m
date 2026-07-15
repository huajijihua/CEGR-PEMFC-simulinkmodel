% Route A platform demo runner.
% Lightweight daily entry for the PEMFC-cEGR platform. The model contains
% the FCU/BoP control and physical calculations; this script only sets a
% nominal operating point, runs sim(), and returns a compact summary.

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
scriptDir = fileparts(mfilename('fullpath'));
modelDir = fullfile(scriptDir, '..', '..', '01_模型', 'RouteA_GasMixture_Derived');
modelFile = fullfile(modelDir, [model '.slx']);
oldDir = pwd;
addpath(scriptDir);
cd(modelDir);
routeA_platform_demo_cleanup = onCleanup(@() restoreFolderAndModel(oldDir, model, modelFile));

resetModelFromDisk(model, modelFile);
refreshModelWorkspace(model);

cfg = demoConfig();
fprintf('\nRoute A platform demo\n');
fprintf('  model=%s\n', model);
fprintf('  power=%.4g kW mdot=%.4g kg/s egr=%.4g pCaOut=%.4g MPa\n', ...
    cfg.targetPowerKW, cfg.targetMdot, cfg.targetEgrRatio, ...
    cfg.targetPCaOutMPa);

summary = runDemoCase(model, modelFile, cfg);
assignin('base', 'routeA_platform_demo_summary', summary);
dispSummary(summary);

function cfg = demoConfig()
cfg = struct();
cfg.caseId = "nominal_50p96kW_platform_demo";
cfg.stopTime = 10;
cfg.targetPowerKW = 50.96;
cfg.airMode = 1; % target_mdot
cfg.targetMdot = 0.045;
cfg.targetOer = 2.5;
cfg.directCompressorCmd = 0.5;
cfg.egrMode = 1; % target_ratio
cfg.targetEgrRatio = 0.02;
cfg.directEgrArea = NaN;
cfg.targetPCaOutMPa = 0.101325 + 0.06;
cfg.humidifierGain = 1;
cfg.stackTemperatureSetC = 80;
end

function summary = runDemoCase(model, modelFile, cfg)
summary = emptySummary();
summary.caseId = cfg.caseId;
summary.stopTime = cfg.stopTime;
summary.targetPowerKW = cfg.targetPowerKW;
summary.targetMdotKgS = cfg.targetMdot;
summary.targetOer = cfg.targetOer;
summary.targetEgrRatio = cfg.targetEgrRatio;
summary.targetPCaOutMPa = cfg.targetPCaOutMPa;

try
    resetModelFromDisk(model, modelFile);
    refreshModelWorkspace(model);
    paths = routeA_block_paths(model);
    markDemoSignals(model, paths);
    mw = get_param(model, 'ModelWorkspace');
    pipeArea = getWorkspaceValue(mw, 'cegr_pipe_area', 0.0019634954);
    if ~isfinite(cfg.directEgrArea)
        cfg.directEgrArea = 2e-3 * pipeArea;
    end

    simIn = Simulink.SimulationInput(model);
    simIn = simIn.setModelParameter( ...
        'StopTime', sprintf('%.16g', cfg.stopTime), ...
        'SignalLogging', 'on', ...
        'SignalLoggingName', 'logsout', ...
        'ReturnWorkspaceOutputs', 'on', ...
        'SimscapeLogType', 'all');
    simIn = simIn.setVariable('drive_cycle_time', ...
        [0; 5; cfg.stopTime], 'Workspace', model);
    simIn = simIn.setVariable('drive_cycle_power', ...
        [0; cfg.targetPowerKW; cfg.targetPowerKW], 'Workspace', model);
    simIn = simIn.setVariable('routeA_air_control_mode_id', ...
        cfg.airMode, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_mdot_comp_inlet', ...
        cfg.targetMdot, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_oer', ...
        cfg.targetOer, 'Workspace', model);
    simIn = simIn.setVariable('routeA_compressor_cmd_direct', ...
        cfg.directCompressorCmd, 'Workspace', model);
    simIn = simIn.setVariable('routeA_egr_control_mode_id', ...
        cfg.egrMode, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_egr_ratio_comp_in', ...
        cfg.targetEgrRatio, 'Workspace', model);
    simIn = simIn.setVariable('routeA_egr_valve_area_direct', ...
        cfg.directEgrArea, 'Workspace', model);
    simIn = simIn.setVariable('routeA_target_p_ca_out_MPa', ...
        cfg.targetPCaOutMPa, 'Workspace', model);
    simIn = simIn.setVariable('routeA_cathode_humidifier_gain', ...
        cfg.humidifierGain, 'Workspace', model);
    simIn = simIn.setVariable('routeA_stack_temperature_set_C', ...
        cfg.stackTemperatureSetC, 'Workspace', model);
    simIn = simIn.setBlockParameter(paths.stackTemperature, ...
        'Value', 'routeA_stack_temperature_set_C');

    simOut = sim(simIn);
    summary.simCompleted = true;
    summary = collectSummary(simOut, summary, model);
    summary.kpiFiniteOk = all(isfinite([summary.actualPowerKW, ...
        summary.compressorCmd, summary.compressorRpmCmd, ...
        summary.compInletMdotKgS, summary.egrRatioCompIn, ...
        summary.egrValveAreaCmd, summary.pCaOutMPa, ...
        summary.RHCaIn, summary.RHCaOut, summary.mWaterSep]));
    summary.passed = summary.simCompleted && summary.kpiFiniteOk;
catch ME
    summary.errorId = string(ME.identifier);
    summary.errorMessage = firstLine(string(ME.message));
end
resetModelFromDisk(model, modelFile);
end

function summary = emptySummary()
summary = struct('caseId', "", 'passed', false, 'simCompleted', false, ...
    'errorId', "", 'errorMessage', "", 'stopTime', NaN, ...
    'targetPowerKW', NaN, 'targetMdotKgS', NaN, 'targetOer', NaN, ...
    'targetEgrRatio', NaN, 'targetPCaOutMPa', NaN, ...
    'actualPowerKW', NaN, 'compressorCmd', NaN, ...
    'compressorRpmCmd', NaN, 'compInletMdotKgS', NaN, ...
    'egrRatioCompIn', NaN, 'egrValveAreaCmd', NaN, ...
    'pCaOutMPa', NaN, 'RHCaIn', NaN, 'RHCaOut', NaN, ...
    'mWaterSep', NaN, 'kpiFiniteOk', false);
end

function summary = collectSummary(simOut, summary, model)
logsout = simOut.logsout;
summary.actualPowerKW = collectSimscapePower(simOut, model);
summary.compressorCmd = scalarLastOrFallback(simOut, logsout, ...
    "routeA_compressor_cmd", "routeA_compressor_cmd_ts");
summary.compressorRpmCmd = scalarLastOrFallback(simOut, logsout, ...
    "routeA_compressor_rpm_cmd", "routeA_compressor_rpm_cmd_ts");
summary.compInletMdotKgS = scalarLastOrNaN(logsout, ...
    "routeA_mdot_comp_inlet");
summary.egrRatioCompIn = scalarLastOrFallback(simOut, logsout, ...
    "routeA_egr_ratio_comp_in", "routeA_egr_ratio_comp_in_ts");
summary.egrValveAreaCmd = scalarLastOrFallback(simOut, logsout, ...
    "routeA_egr_valve_area_cmd", "routeA_egr_valve_area_cmd_ts");
summary.pCaOutMPa = scalarLastOrNaN(logsout, "routeA_p_outlet") / 1e6;
summary.RHCaIn = scalarLastOrFallback(simOut, logsout, ...
    "routeA_RH_ca_in", "routeA_RH_ca_in_ts");
summary.RHCaOut = scalarLastOrFallback(simOut, logsout, ...
    "routeA_RH_ca_out", "routeA_RH_ca_out_ts");
summary.mWaterSep = scalarLastOrFallback(simOut, logsout, ...
    "routeA_m_water_sep", "routeA_m_water_sep_ts");
end

function markDemoSignals(model, paths)
nameLineFromBlockOut(paths.compressorFlowConverter, ...
    'routeA_mdot_comp_inlet');
nameLineFromBlockOut(paths.compressorCommandSwitch, ...
    'routeA_compressor_cmd');
nameLineFromBlockOut(paths.compressorRpmCommand, ...
    'routeA_compressor_rpm_cmd');
nameLineFromBlockOutPort(paths.fcu, 1, ...
    'routeA_egr_valve_area_cmd');
nameLineFromBlockOutPort(paths.fcu, 4, ...
    'routeA_egr_ratio_comp_in');
nameLineFromBlockOut(paths.outletPConverter, 'routeA_p_outlet');
nameLineFromBlockOut(paths.cathodeRHInWorkspace, ...
    'routeA_RH_ca_in');
nameLineFromBlockOut(paths.rhOutWorkspace, 'routeA_RH_ca_out');
nameLineFromBlockOut(paths.waterSepWorkspace, 'routeA_m_water_sep');
end

function nameLineFromBlockOut(blockPath, signalName)
nameLineFromBlockOutPort(blockPath, 1, signalName);
end

function nameLineFromBlockOutPort(blockPath, portNumber, signalName)
if getSimulinkBlockHandle(blockPath) == -1
    return;
end
ph = get_param(blockPath, 'PortHandles');
if numel(ph.Outport) < portNumber
    return;
end
lineHandle = get_param(ph.Outport(portNumber), 'Line');
if lineHandle ~= -1
    set_param(lineHandle, 'Name', signalName);
    try
        set_param(lineHandle, 'DataLogging', 'on');
    catch
    end
    try
        set_param(lineHandle, 'DataLoggingNameMode', 'Custom', ...
            'DataLoggingName', signalName);
    catch
    end
end
end

function value = scalarLastOrFallback(simOut, logsout, signalName, variableName)
value = scalarLastOrNaN(logsout, signalName);
if ~isfinite(value)
    value = scalarLastFromSimOutOrNaN(simOut, variableName);
end
end

function value = scalarLastOrNaN(logsout, signalName)
value = lastLoggedValueOrNaN(logsout, signalName);
if isempty(value)
    value = NaN;
else
    value = value(1);
end
end

function value = scalarLastFromSimOutOrNaN(simOut, variableName)
value = NaN;
try
    signal = simOut.get(char(variableName));
catch
    return;
end
if isempty(signal)
    return;
end
try
    data = signal.Data;
    value = data(end);
catch
    try
        value = signal(end);
    catch
        value = NaN;
    end
end
end

function value = lastLoggedValueOrNaN(logsout, signalName)
value = NaN;
for idx = 1:logsout.numElements
    candidate = logsout.get(idx);
    if string(candidate.Name) == signalName
        signal = candidate.Values;
        data = signal.Data;
        nTime = numel(signal.Time);
        if isvector(data)
            value = data(end);
        elseif size(data, 1) == nTime
            value = squeeze(data(end, :));
        elseif size(data, ndims(data)) == nTime
            reshaped = reshape(data, [], nTime);
            value = reshaped(:, end).';
        else
            value = squeeze(data(end, :));
        end
        value = value(:).';
        return;
    end
end
end

function powerKW = collectSimscapePower(simOut, model)
powerKW = NaN;
try
    simlog = simOut.get(['simlog_' model]);
    mea = routeA_simscape_log_mea(simlog);
    powerKW = mea.power_elec.series.values('kW');
    powerKW = powerKW(end);
catch
end
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

function restoreFolderAndModel(oldDir, model, modelFile)
cd(oldDir);
if bdIsLoaded(model)
    close_system(model, 0);
end
if exist(modelFile, 'file')
    load_system(modelFile);
end
end

function dispSummary(summary)
fprintf('\nRoute A platform demo result\n');
fprintf('  passed=%d simCompleted=%d finite=%d\n', ...
    summary.passed, summary.simCompleted, summary.kpiFiniteOk);
if summary.passed
    fprintf('  P=%.4g kW cmd=%.4g rpm=%.4g mdot=%.4g kg/s\n', ...
        summary.actualPowerKW, summary.compressorCmd, ...
        summary.compressorRpmCmd, summary.compInletMdotKgS);
    fprintf('  egr=%.4g area=%.4g pCaOut=%.4g MPa RHin=%.4g RHout=%.4g water=%.4g\n', ...
        summary.egrRatioCompIn, summary.egrValveAreaCmd, ...
        summary.pCaOutMPa, summary.RHCaIn, summary.RHCaOut, ...
        summary.mWaterSep);
else
    fprintf('  error=%s %s\n', summary.errorId, summary.errorMessage);
end
end
