% run_routeA_phaseB_regression.m
% Phase B 回归验证：确认 22 列 profile 收缩为结构体后，恒电流 100A + cEGR=0 与基线一致。
%
% 直接构建 SimulationInput（绕过 v09 初态 schema 检查，与 S3 验证脚本同款），
% 专注验证 routeA_assemble_command_profile 新函数链路。
%
% 用法：>> run_routeA_phaseB_regression
%
% 通过判据：
%   1. 无 DAE IC Failure，仿真正常完成
%   2. 尾窗(540-600s)电压跨度 < 0.5%
%   3. 尾窗电压与 S3 基线(408.89V @ 100A)相对偏差 < 1%

model = 'PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01';
fprintf('=== Phase B 回归验证: 恒电流 100A + cEGR=0 ===\n');

% 1. 用新函数构建 controls 结构体 -> command profile
controls = struct();
controls.cathode = struct('airControlMode', 2, 'targetOer', 3.0, ...
    'sourcePressure_MPa_abs', 0.15, 'sourceTemperature_C', 20, ...
    'outletPressure_MPa_abs', 0.1613, 'humidifierRH', 0.9, 'humidifierEnabled', 1);
controls.cegr = struct('targetRatio', 0);
controls.anode = struct('sourcePressure_MPa_abs', 0.3, 'sourceTemperature_C', 20, ...
    'inletPressure_MPa_abs', 0.15, 'humidifierRH', 0.5, ...
    'recirculationBaseCommand', 0.2, 'recirculationCurrentGain_A_inv', 0.00204, ...
    'purgeEnabled', 1, 'purgeOnN2MoleFraction', 0.5, 'purgeOffN2MoleFraction', 0.1);
controls.thermal = struct('stackTemperatureSet_C', 80);

study = struct('researchDuration_s', 600, 'commandStartOffset_s', 0.5, ...
    'startupRampDuration_s', 60);
profile = routeA_assemble_command_profile(controls, study);

% 2. 构建 SimulationInput
in = Simulink.SimulationInput(model);

% 求解器
in = in.setModelParameter('StartTime', '0', 'StopTime', '600', ...
    'Solver', 'VariableStepAuto', 'SolverType', 'Variable-step', ...
    'RelTol', '1e-3', 'AbsTol', '1e-3', 'MaxStep', '5', ...
    'SignalLogging', 'on', 'SignalLoggingName', 'logsout', ...
    'ReturnWorkspaceOutputs', 'on', 'SimscapeLogType', 'all', ...
    'LoadInitialState', 'off');

% 电边界：恒电流 100A（60s 斜坡）
t = [0; 0.5; 60.5; 600];
icmd = [0; 0; 100; 100];
in = in.setVariable('drive_cycle_time', t, 'Workspace', model);
in = in.setVariable('drive_cycle_current', icmd, 'Workspace', model);

% 气路/cEGR 控制变量
in = in.setVariable('routeA_air_control_mode_id', 2, 'Workspace', model);
in = in.setVariable('routeA_egr_control_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_cegr_enabled', true, 'Workspace', model);
in = in.setVariable('routeA_cegr_valve_mode_id', 1, 'Workspace', model);
in = in.setVariable('routeA_egr_target_input_mode_id', 1, 'Workspace', model);

% command profile（新函数输出的 workspaceValue，向后兼容）
in = in.setVariable('routeA_command_profile', profile.workspaceValue, 'Workspace', model);

% 电边界模式
paths = routeA_block_paths(model);
in = in.setBlockParameter(paths.electricalLoad, 'input_type', 'Current');
in = in.setBlockParameter(paths.currentCommand, 'VariableName', ...
    '[drive_cycle_time, drive_cycle_current]');

% 3. 保存模型并运行
save_system(model);
fprintf('开始仿真...\n');
out = sim(in);
fprintf('仿真完成\n');

% 4. 提取尾窗 KPI
logsout = out.get('logsout');
vTs = logsout.get('routeA_stack_voltage_V').Values;
vData = vTs.Data; tData = vTs.Time;
tailMask = tData >= 540 & tData <= 600;
vTail = vData(tailMask);
vMean = mean(vTail);
vSpan = (max(vTail) - min(vTail)) / vMean;
vBaseline = 408.89;  % S3 基线
vRelError = abs(vMean - vBaseline) / vBaseline;

fprintf('\n=== 结果 ===\n');
fprintf('尾窗电压均值: %.4f V\n', vMean);
fprintf('尾窗电压跨度: %.4f V (%.4f%%)\n', max(vTail)-min(vTail), vSpan*100);
fprintf('相对基线偏差: %.4f%%\n', vRelError*100);

pass = true;
if vSpan > 0.005
    fprintf('FAIL: 电压跨度 %.4f%% > 0.5%%\n', vSpan*100);
    pass = false;
end
if vRelError > 0.01
    fprintf('FAIL: 相对基线偏差 %.4f%% > 1%%\n', vRelError*100);
    pass = false;
end
if pass
    fprintf('\nPASS: Phase B 回归验证通过\n');
else
    fprintf('\nFAIL: Phase B 回归验证未通过\n');
end