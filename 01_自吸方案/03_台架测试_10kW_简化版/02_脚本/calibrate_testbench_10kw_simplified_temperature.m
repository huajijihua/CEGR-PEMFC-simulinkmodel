function result = calibrate_testbench_10kw_simplified_temperature()
%CALIBRATE_TESTBENCH_10KW_SIMPLIFIED_TEMPERATURE Fit stack thermal curve.
%
% 作用：
% 1. 只标定电堆热平衡中的冷却流量-等效换热系数曲线 cool_flow_curve_h_W_K。
% 2. 不调整电压参数、不调整压力边界、不调整气体导纳。
% 3. 热平衡状态 T_stack 按入/出口平均温度解释，因此默认目标温度取
%    (stack_in_T_C + stack_out_T_C)/2；阴极出口温度由模型按
%    T_ca_out = 2*T_stack - T_ca_in 输出。
% 4. 标定结果写入 00_输入参数/标定参数/simplified_thermal_params.csv，
%    init_testbench_10kw_simplified_egr.m 后续会自动读取。

rootDir = fileparts(fileparts(mfilename('fullpath')));
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
resultDir = fullfile(rootDir, '04_验证结果', 'temperature_fit_v01');
if ~isfolder(paramDir), mkdir(paramDir); end
if ~isfolder(resultDir), mkdir(resultDir); end

thermalFile = fullfile(paramDir, 'simplified_thermal_params.csv');
if isfile(thermalFile), delete(thermalFile); end

P0 = init_testbench_10kw_simplified_egr(1, 'all', false);
allCases = P0.allCaseTable;
fitCases = allCases(isfinite(allCases.stack_in_T_C) & isfinite(allCases.stack_out_T_C) & ...
    isfinite(allCases.coolant_in_T_C) & isfinite(allCases.coolant_flow_L_min), :);
assert(~isempty(fitCases), 'CEGR:SimplifiedThermalCalibration:NoTemperatureData');

baseline = evaluateTemperatureCases(fitCases);
[curve, fitInfo] = fitCoolingCurveFromBalance(baseline, P0);
writeThermalParams(thermalFile, P0.cool_flow_curve_L_min, curve);
fitted = evaluateTemperatureCases(fitCases);

outputFiles = writeTemperatureOutputs(resultDir, baseline, fitted, fitInfo, ...
    P0.cool_flow_curve_L_min, P0.cool_flow_curve_h_W_K, curve);

fprintf('THERMAL_BASELINE_STACK_RMSE=%.6f C\n', rmse(baseline.stack_T_err_C));
fprintf('THERMAL_FITTED_STACK_RMSE=%.6f C\n', rmse(fitted.stack_T_err_C));
fprintf('THERMAL_BASELINE_OUTLET_RMSE=%.6f C\n', rmse(baseline.stack_out_T_err_C));
fprintf('THERMAL_FITTED_OUTLET_RMSE=%.6f C\n', rmse(fitted.stack_out_T_err_C));

result = struct();
result.baseline = baseline;
result.fitted = fitted;
result.fit_info = fitInfo;
result.cool_flow_curve_L_min = P0.cool_flow_curve_L_min(:);
result.cool_flow_curve_h_old = P0.cool_flow_curve_h_W_K(:);
result.cool_flow_curve_h_new = curve(:);
result.outputs = outputFiles;
end

function fit = evaluateTemperatureCases(data)
% 回放温度相关工况，输出电堆温度目标、模型堆温、出口温度和热平衡诊断。
n = height(data);
fit = table('Size', [n 24], ...
    'VariableTypes', {'double','string','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'case_index','case_id','is_no_egr','current_A','current_density_A_cm2', ...
    'coolant_flow_L_min','coolant_in_T_C','stack_in_T_exp_C','stack_out_T_exp_C', ...
    'stack_T_target_C','stack_T_sim_C','stack_T_err_C','stack_out_T_sim_C','stack_out_T_err_C', ...
    'Qgen_W','Qcool_W','Qamb_W','Qgas_W','mCaOut_kg_s','mAnOut_kg_s', ...
    'h_required_W_K','h_curve_W_K','target_minus_coolant_C','valid_h_required'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'all', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    caIn = lastVector(out.get('stack_in_node'));
    caOut = lastVector(out.get('stack_ca_out_node'));
    fit.case_index(k) = data.case_index(k);
    fit.case_id(k) = string(P.case_id);
    fit.is_no_egr(k) = data.is_no_egr(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.current_density_A_cm2(k) = P.current_density_A_cm2;
    fit.coolant_flow_L_min(k) = P.coolant_flow_L_min;
    fit.coolant_in_T_C(k) = P.T_cool_C;
    fit.stack_in_T_exp_C(k) = P.bench_stack_in_T_C;
    fit.stack_out_T_exp_C(k) = P.stack_out_T_C;
    fit.stack_T_target_C(k) = 0.5 * (P.bench_stack_in_T_C + P.stack_out_T_C);
    fit.stack_T_sim_C(k) = s(9);
    fit.stack_T_err_C(k) = s(9) - fit.stack_T_target_C(k);
    fit.stack_out_T_sim_C(k) = caOut(5);
    fit.stack_out_T_err_C(k) = fit.stack_out_T_sim_C(k) - P.stack_out_T_C;
    fit.Qgen_W(k) = s(32);
    fit.Qcool_W(k) = s(33);
    fit.Qamb_W(k) = s(34);
    fit.Qgas_W(k) = s(35);
    fit.mCaOut_kg_s(k) = s(16);
    fit.mAnOut_kg_s(k) = s(17);
    fit.h_curve_W_K(k) = effectiveH(P.coolant_flow_L_min, P.cool_flow_curve_L_min, P.cool_flow_curve_h_W_K);
    [hReq, valid] = requiredHFromBalance(fit.stack_T_target_C(k), P, caIn, s);
    fit.h_required_W_K(k) = hReq;
    fit.target_minus_coolant_C(k) = fit.stack_T_target_C(k) - P.T_cool_C;
    fit.valid_h_required(k) = valid;
end
end

function [curve, fitInfo] = fitCoolingCurveFromBalance(baseline, P0)
% 用热平衡反推的 h_required 拟合冷却曲线。每个流量断点保留一个独立 h 值，
% 不用单调约束强行合并相邻断点；若数据呈非单调，直接在节点表中标记。
bp = P0.cool_flow_curve_L_min(:);
h0 = P0.cool_flow_curve_h_W_K(:);
mask = baseline.valid_h_required & isfinite(baseline.h_required_W_K) & ...
    baseline.h_required_W_K > 1 & baseline.h_required_W_K < 5000;
flow = baseline.coolant_flow_L_min(mask);
hReq = baseline.h_required_W_K(mask);
assert(numel(hReq) >= 3, 'CEGR:SimplifiedThermalCalibration:InsufficientHData');

nodeTarget = nan(size(bp));
nodeCount = zeros(size(bp));
for k = 1:numel(bp)
    atNode = abs(flow - bp(k)) < 1e-9;
    nodeCount(k) = nnz(atNode);
    if nodeCount(k) > 0
        nodeTarget(k) = median(hReq(atNode), 'omitnan');
    end
end

hasNodeTarget = isfinite(nodeTarget);
curve = h0;
curve(hasNodeTarget) = nodeTarget(hasNodeTarget);
if nnz(hasNodeTarget) >= 2
    innerMissing = ~hasNodeTarget & bp >= min(bp(hasNodeTarget)) & bp <= max(bp(hasNodeTarget));
    curve(innerMissing) = interp1(bp(hasNodeTarget), nodeTarget(hasNodeTarget), bp(innerMissing), 'linear');
end
curve = min(max(curve, 1), 5000);

predOld = interp1(bp, h0, flow, 'linear', 'extrap');
predNew = interp1(bp, curve, flow, 'linear', 'extrap');
flowFitInfo = table(flow, hReq, predOld, predNew, hReq - predOld, hReq - predNew, ...
    'VariableNames', {'coolant_flow_L_min','h_required_W_K','h_old_W_K','h_new_W_K', ...
    'h_residual_old_W_K','h_residual_new_W_K'});
nodeInfo = table(bp, h0, curve, nodeTarget, nodeCount, ~hasNodeTarget, ...
    [false; abs(diff(curve)) < 1e-6], [false; diff(curve) < 0], ...
    'VariableNames', {'coolant_flow_L_min','h_old_W_K','h_new_W_K', ...
    'h_required_median_W_K','valid_case_count','used_default_or_interpolation', ...
    'same_as_previous_node','decreases_from_previous_node'});
fitInfo = struct('byCase', flowFitInfo, 'byNode', nodeInfo);
end

function [hReq, valid] = requiredHFromBalance(Ttarget, P, caIn, s)
% 由稳态热平衡反推 hCoolEff:
% Qgen - h*(T-Tcool) - hAmb*(T-Tamb) - Qgas = 0。
% 与 PEMFCStackCore 方案 B 一致：Ttarget 是阴极入/出口平均温度，
% Tca_out = 2*Ttarget - Tca_in。
den = Ttarget - P.T_cool_C;
if abs(den) < 0.2
    hReq = NaN;
    valid = false;
    return;
end
mCaOut = s(16);
mAnOut = s(17);
Qgen = s(32);
Qamb = P.h_amb_W_K * (Ttarget - P.T_amb_C);
TcaOut = 2 * Ttarget - caIn(5);
Qgas = mCaOut * 1050 * (TcaOut - caIn(5)) + mAnOut * 1050 * max(Ttarget - caIn(5), 0);
hReq = (Qgen - Qamb - Qgas) / den;
valid = isfinite(hReq) && hReq > 0;
end

function h = effectiveH(flow, bp, hv)
% 与 PEMFCStackCore 内部插值口径一致的冷却曲线插值。
if flow <= bp(1)
    h = hv(1);
elseif flow >= bp(end)
    h = hv(end);
else
    h = interp1(bp(:), hv(:), flow, 'linear');
end
end

function writeThermalParams(filePath, bp, h)
% 写出热标定 CSV。初始化脚本只读取 cool_flow_curve_h_W_K 行。
T = table(repmat("cool_flow_curve_h_W_K", numel(h), 1), (1:numel(h)).', bp(:), h(:), ...
    repmat("W/K", numel(h), 1), ...
    repmat("冷却流量-等效换热系数曲线，按 T_stack=(stack_in_T+stack_out_T)/2 目标拟合", numel(h), 1), ...
    'VariableNames', {'parameter','curve_index','coolant_flow_L_min','value','unit','meaning_cn'});
writetable(T, filePath);
end

function outputFiles = writeTemperatureOutputs(resultDir, baseline, fitted, fitInfo, bp, hOld, hNew)
% 写出温度标定输出表。
if ~isfolder(resultDir), mkdir(resultDir); end
curve = table(bp(:), hOld(:), hNew(:), hNew(:) - hOld(:), ...
    'VariableNames', {'coolant_flow_L_min','h_old_W_K','h_new_W_K','delta_h_W_K'});
metrics = table(["baseline"; "fitted"], [height(baseline); height(fitted)], ...
    [rmse(baseline.stack_T_err_C); rmse(fitted.stack_T_err_C)], ...
    [max(abs(baseline.stack_T_err_C), [], 'omitnan'); max(abs(fitted.stack_T_err_C), [], 'omitnan')], ...
    [rmse(baseline.stack_out_T_err_C); rmse(fitted.stack_out_T_err_C)], ...
    [max(abs(baseline.stack_out_T_err_C), [], 'omitnan'); max(abs(fitted.stack_out_T_err_C), [], 'omitnan')], ...
    'VariableNames', {'dataset','rows','stack_T_rmse_C','stack_T_max_abs_C', ...
    'stack_out_T_rmse_C','stack_out_T_max_abs_C'});

outputFiles = struct();
outputFiles.baseline = fullfile(resultDir, 'temperature_fit_baseline.csv');
outputFiles.fitted = fullfile(resultDir, 'temperature_fit_fitted.csv');
outputFiles.curve = fullfile(resultDir, 'temperature_fit_cooling_curve.csv');
outputFiles.h_required = fullfile(resultDir, 'temperature_fit_h_required.csv');
outputFiles.h_required_by_flow = fullfile(resultDir, 'temperature_fit_h_required_by_flow.csv');
outputFiles.metrics = fullfile(resultDir, 'temperature_fit_metrics.csv');
writetable(baseline, outputFiles.baseline);
writetable(fitted, outputFiles.fitted);
writetable(curve, outputFiles.curve);
writetable(fitInfo.byCase, outputFiles.h_required);
writetable(fitInfo.byNode, outputFiles.h_required_by_flow);
writetable(metrics, outputFiles.metrics);
end

function out = simulateCase(P)
% 用 SimulationInput 把本工况参数注入模型，避免依赖当前 base workspace 的旧值。
in = Simulink.SimulationInput(P.modelName);
in = in.setModelParameter('StopTime', num2str(P.stopTime_s), ...
    'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(P.dt_s));
in = in.setVariable('PhysicalParam_simplified', P.PhysicalParam);
in = in.setVariable('StackModelParam_simplified', P.StackModelParam);
in = in.setVariable('CaseBoundaryParam_simplified', P.CaseBoundaryParam);
in = in.setVariable('CoolingCurveParam_simplified', P.CoolingCurveParam);
in = in.setVariable('dt_s_simplified', P.dt_s_simplified);
in = in.setVariable('StackInitialState_simplified', P.stack_initial_state);
in = in.setVariable('EGRInitialNode_simplified', P.egr_initial_node);
out = sim(in);
end

function v = lastVector(ts)
% 取 To Workspace timeseries 最后一个时刻的向量值。
v = ts.signals.values(:, :, end);
v = v(:);
end

function y = rmse(x)
% 忽略 NaN 后计算均方根误差。
x = x(isfinite(x));
y = sqrt(mean(x.^2));
end
