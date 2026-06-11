function result = calibrate_testbench_10kw_simplified_pressure()
%CALIBRATE_TESTBENCH_10KW_SIMPLIFIED_PRESSURE Fit internal stack channel pressures.
%
% 作用：
% 1. 以实验进/出口绝压平均值为目标，标定 PEMFCStackCore 内部阴极/阳极通道压力。
% 2. 第一阶段只标定 StackModelParam(5:6)：K_ca_out_kg_s_kPa、K_an_out_kg_s_kPa。
% 3. 若 K-only 结果仍不合格，本脚本会在结果中标记需要开放 V_ca_m3、V_an_m3；
%    体积参数不在第一轮自动写入，避免用动态库存体积补偿稳态导纳错误。
% 4. 标定结果写入 00_输入参数/标定参数/simplified_pressure_params.csv，
%    init_testbench_10kw_simplified_egr.m 后续会自动读取。

rootDir = fileparts(fileparts(mfilename('fullpath')));
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
resultDir = fullfile(rootDir, '04_验证结果', 'pressure_fit_v01');
if ~isfolder(paramDir), mkdir(paramDir); end
if ~isfolder(resultDir), mkdir(resultDir); end

pressureFile = fullfile(paramDir, 'simplified_pressure_params.csv');
if isfile(pressureFile), delete(pressureFile); end

P0 = init_testbench_10kw_simplified_egr(1, 'all', false);
allCases = P0.allCaseTable;
fitCases = allCases(isfinite(allCases.stack_in_p_kPa) & isfinite(allCases.stack_out_p_kPa) & ...
    isfinite(allCases.anode_in_p_kPa) & isfinite(allCases.anode_out_p_kPa), :);
assert(~isempty(fitCases), 'CEGR:SimplifiedPressureCalibration:NoPressureData');

baseline = evaluatePressureCases(fitCases);
[pressureParams, kInfo] = fitOutletConductanceFromPressure(baseline, P0);
writePressureParams(pressureFile, P0, pressureParams, false);
fittedK = evaluatePressureCases(fitCases);

metrics = buildPressureMetrics(baseline, fittedK);
needsVolumeStage = any(metrics.needs_volume_stage(string(metrics.dataset) == "fitted_k_only"));
volumeInfo = table();
finalFit = fittedK;
finalParams = pressureParams;
volumeStageApplied = false;
if needsVolumeStage
    [finalParams, finalFit, volumeInfo, volumeStageApplied] = ...
        fitVolumeByCoarseSweep(fitCases, pressureParams, P0, pressureFile, metrics);
    if volumeStageApplied
        writePressureParams(pressureFile, P0, finalParams, true);
    else
        writePressureParams(pressureFile, P0, pressureParams, false);
    end
    metrics = buildPressureMetrics(baseline, fittedK, finalFit);
end
outputFiles = writePressureOutputs(resultDir, baseline, fittedK, finalFit, kInfo, ...
    volumeInfo, finalParams, metrics);

fprintf('PRESSURE_BASELINE_CA_RMSE=%.6f kPa\n', metrics.pCa_rmse_kPa(1));
fprintf('PRESSURE_FITTED_CA_RMSE=%.6f kPa\n', metrics.pCa_rmse_kPa(2));
fprintf('PRESSURE_BASELINE_AN_RMSE=%.6f kPa\n', metrics.pAn_rmse_kPa(1));
fprintf('PRESSURE_FITTED_AN_RMSE=%.6f kPa\n', metrics.pAn_rmse_kPa(2));
fprintf('PRESSURE_NEEDS_VOLUME_STAGE=%d\n', needsVolumeStage);

result = struct();
result.baseline = baseline;
result.fitted_k_only = fittedK;
result.fitted_final = finalFit;
result.k_info = kInfo;
result.pressure_params = finalParams;
result.metrics = metrics;
result.needs_volume_stage = needsVolumeStage;
result.volume_stage_applied = volumeStageApplied;
result.outputs = outputFiles;
end

function fit = evaluatePressureCases(data)
% 回放压力相关工况，输出内部通道压力和实验平均压力目标。
n = height(data);
fit = table('Size', [n 29], ...
    'VariableTypes', {'double','string','double','double','double','double','double','double','double','double', ...
    'double','double','double','double','double','double','double','double','double','double', ...
    'double','double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'case_index','case_id','is_no_egr','current_A','current_density_A_cm2', ...
    'pCa_in_abs_kPa','pCa_out_abs_kPa','pCa_target_abs_kPa','pCa_model_abs_kPa','pCa_err_kPa', ...
    'pAn_in_abs_kPa','pAn_out_abs_kPa','pAn_target_abs_kPa','pAn_model_abs_kPa','pAn_err_kPa', ...
    'cathode_dp_kPa','anode_dp_kPa','mCaOut_kg_s','mAnOut_kg_s','Kca_current_kg_s_kPa', ...
    'Kan_current_kg_s_kPa','Kca_required_kg_s_kPa','Kan_required_kg_s_kPa','Vca_m3','Van_m3', ...
    'lambdaO2','stack_T_C','max_gas_residual_kg_s','valid_for_k_fit'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'all', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));

    fit.case_index(k) = data.case_index(k);
    fit.case_id(k) = string(P.case_id);
    fit.is_no_egr(k) = data.is_no_egr(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.current_density_A_cm2(k) = P.current_density_A_cm2;

    fit.pCa_in_abs_kPa(k) = P.bench_stack_in_p_kPa + P.p_amb_kPa;
    fit.pCa_out_abs_kPa(k) = P.p_cathode_back_kPa;
    fit.pCa_target_abs_kPa(k) = 0.5 * (fit.pCa_in_abs_kPa(k) + fit.pCa_out_abs_kPa(k));
    fit.pCa_model_abs_kPa(k) = s(5);
    fit.pCa_err_kPa(k) = fit.pCa_model_abs_kPa(k) - fit.pCa_target_abs_kPa(k);

    fit.pAn_in_abs_kPa(k) = P.p_anode_in_kPa;
    fit.pAn_out_abs_kPa(k) = P.p_anode_back_kPa;
    fit.pAn_target_abs_kPa(k) = 0.5 * (fit.pAn_in_abs_kPa(k) + fit.pAn_out_abs_kPa(k));
    fit.pAn_model_abs_kPa(k) = s(7);
    fit.pAn_err_kPa(k) = fit.pAn_model_abs_kPa(k) - fit.pAn_target_abs_kPa(k);

    fit.cathode_dp_kPa(k) = fit.pCa_in_abs_kPa(k) - fit.pCa_out_abs_kPa(k);
    fit.anode_dp_kPa(k) = fit.pAn_in_abs_kPa(k) - fit.pAn_out_abs_kPa(k);
    fit.mCaOut_kg_s(k) = s(16);
    fit.mAnOut_kg_s(k) = s(17);
    fit.Kca_current_kg_s_kPa(k) = P.K_ca_out_kg_s_kPa;
    fit.Kan_current_kg_s_kPa(k) = P.K_an_out_kg_s_kPa;
    fit.Vca_m3(k) = P.V_ca_m3;
    fit.Van_m3(k) = P.V_an_m3;
    fit.lambdaO2(k) = s(40);
    fit.stack_T_C(k) = s(9);
    fit.max_gas_residual_kg_s(k) = s(31);

    dpCaTarget = fit.pCa_target_abs_kPa(k) - fit.pCa_out_abs_kPa(k);
    dpAnTarget = fit.pAn_target_abs_kPa(k) - fit.pAn_out_abs_kPa(k);
    fit.Kca_required_kg_s_kPa(k) = fit.mCaOut_kg_s(k) / dpCaTarget;
    fit.Kan_required_kg_s_kPa(k) = fit.mAnOut_kg_s(k) / dpAnTarget;
    fit.valid_for_k_fit(k) = dpCaTarget > 0.2 && dpAnTarget > 0.2 && ...
        isfinite(fit.Kca_required_kg_s_kPa(k)) && isfinite(fit.Kan_required_kg_s_kPa(k)) && ...
        fit.Kca_required_kg_s_kPa(k) > 0 && fit.Kan_required_kg_s_kPa(k) > 0;
end
end

function [pressureParams, kInfo] = fitOutletConductanceFromPressure(baseline, P0)
% 用稳态出口流量和目标平均压力反推出口导纳，取中位数作为第一阶段参数。
maskCa = baseline.valid_for_k_fit & baseline.Kca_required_kg_s_kPa > 1e-7 & ...
    baseline.Kca_required_kg_s_kPa < 1e-2;
maskAn = baseline.valid_for_k_fit & baseline.Kan_required_kg_s_kPa > 1e-8 & ...
    baseline.Kan_required_kg_s_kPa < 1e-3;
assert(nnz(maskCa) >= 3 && nnz(maskAn) >= 3, ...
    'CEGR:SimplifiedPressureCalibration:InsufficientConductanceData');

pressureParams = struct();
pressureParams.V_ca_m3 = P0.V_ca_m3;
pressureParams.V_an_m3 = P0.V_an_m3;
pressureParams.K_ca_out_kg_s_kPa = median(baseline.Kca_required_kg_s_kPa(maskCa), 'omitnan');
pressureParams.K_an_out_kg_s_kPa = median(baseline.Kan_required_kg_s_kPa(maskAn), 'omitnan');

kInfo = baseline(:, {'case_index','case_id','is_no_egr','current_density_A_cm2', ...
    'pCa_target_abs_kPa','pCa_model_abs_kPa','pCa_err_kPa', ...
    'pAn_target_abs_kPa','pAn_model_abs_kPa','pAn_err_kPa', ...
    'mCaOut_kg_s','mAnOut_kg_s','Kca_required_kg_s_kPa','Kan_required_kg_s_kPa', ...
    'valid_for_k_fit'});
end

function [bestParams, bestFit, volumeInfo, applied] = fitVolumeByCoarseSweep(fitCases, pressureParams, P0, pressureFile, kMetrics)
% 若 K-only 仍不合格，粗扫 V_ca/V_an，验证体积参数是否真的改善内部压力。
baseNeeds = kMetrics.needs_volume_stage(string(kMetrics.dataset) == "fitted_k_only");
needsCa = kMetrics.pCa_rmse_kPa(string(kMetrics.dataset) == "fitted_k_only") > 2.0 || ...
    kMetrics.pCa_max_abs_kPa(string(kMetrics.dataset) == "fitted_k_only") > 5.0;
needsAn = kMetrics.pAn_rmse_kPa(string(kMetrics.dataset) == "fitted_k_only") > 2.0 || ...
    kMetrics.pAn_max_abs_kPa(string(kMetrics.dataset) == "fitted_k_only") > 5.0;
if ~baseNeeds
    bestParams = pressureParams;
    bestFit = evaluatePressureCases(fitCases);
    volumeInfo = table();
    applied = false;
    return;
end

vCaCandidates = P0.V_ca_m3;
if needsCa
    vCaCandidates = unique(P0.V_ca_m3 * [0.25 0.5 1.0 2.0 4.0]);
end
vAnCandidates = P0.V_an_m3;
if needsAn
    vAnCandidates = unique(P0.V_an_m3 * [0.25 0.5 1.0 2.0 4.0]);
end

n = numel(vCaCandidates) * numel(vAnCandidates);
volumeInfo = table('Size', [n 7], ...
    'VariableTypes', {'double','double','double','double','double','double','double'}, ...
    'VariableNames', {'V_ca_m3','V_an_m3','pCa_rmse_kPa','pAn_rmse_kPa', ...
    'pCa_max_abs_kPa','pAn_max_abs_kPa','objective'});
bestObjective = inf;
bestParams = pressureParams;
bestFit = table();
row = 0;
for i = 1:numel(vCaCandidates)
    for j = 1:numel(vAnCandidates)
        row = row + 1;
        tryParams = pressureParams;
        tryParams.V_ca_m3 = vCaCandidates(i);
        tryParams.V_an_m3 = vAnCandidates(j);
        writePressureParams(pressureFile, P0, tryParams, true);
        tryFit = evaluatePressureCases(fitCases);
        caRmse = rmse(tryFit.pCa_err_kPa);
        anRmse = rmse(tryFit.pAn_err_kPa);
        caMax = max(abs(tryFit.pCa_err_kPa), [], 'omitnan');
        anMax = max(abs(tryFit.pAn_err_kPa), [], 'omitnan');
        objective = caRmse + anRmse + 0.2 * (caMax + anMax);
        volumeInfo{row, :} = [tryParams.V_ca_m3, tryParams.V_an_m3, caRmse, anRmse, caMax, anMax, objective];
        if objective < bestObjective
            bestObjective = objective;
            bestParams = tryParams;
            bestFit = tryFit;
        end
    end
end

baseObjective = kMetrics.pCa_rmse_kPa(2) + kMetrics.pAn_rmse_kPa(2) + ...
    0.2 * (kMetrics.pCa_max_abs_kPa(2) + kMetrics.pAn_max_abs_kPa(2));
applied = bestObjective < 0.95 * baseObjective;
if ~applied
    bestParams = pressureParams;
    writePressureParams(pressureFile, P0, pressureParams, false);
    bestFit = evaluatePressureCases(fitCases);
end
end

function metrics = buildPressureMetrics(baseline, fittedK, finalFit)
% 生成压力标定指标。阈值用于判断是否需要进一步开放 V_ca/V_an。
if nargin < 3
    datasets = ["baseline"; "fitted_k_only"];
    fits = {baseline; fittedK};
else
    datasets = ["baseline"; "fitted_k_only"; "fitted_final"];
    fits = {baseline; fittedK; finalFit};
end
rows = zeros(numel(fits), 1);
pCaRmse = zeros(numel(fits), 1);
pAnRmse = zeros(numel(fits), 1);
pCaMax = zeros(numel(fits), 1);
pAnMax = zeros(numel(fits), 1);
for k = 1:numel(fits)
    rows(k) = height(fits{k});
    pCaRmse(k) = rmse(fits{k}.pCa_err_kPa);
    pAnRmse(k) = rmse(fits{k}.pAn_err_kPa);
    pCaMax(k) = max(abs(fits{k}.pCa_err_kPa), [], 'omitnan');
    pAnMax(k) = max(abs(fits{k}.pAn_err_kPa), [], 'omitnan');
end
needsVolume = pCaRmse > 2.0 | pAnRmse > 2.0 | pCaMax > 5.0 | pAnMax > 5.0;
metrics = table(datasets, rows, pCaRmse, pAnRmse, pCaMax, pAnMax, needsVolume, ...
    'VariableNames', {'dataset','rows','pCa_rmse_kPa','pAn_rmse_kPa', ...
    'pCa_max_abs_kPa','pAn_max_abs_kPa','needs_volume_stage'});
end

function outputFiles = writePressureOutputs(resultDir, baseline, fittedK, finalFit, kInfo, volumeInfo, pressureParams, metrics)
% 写出压力标定输出表。
if ~isfolder(resultDir), mkdir(resultDir); end
paramTable = pressureParamTable(pressureParams, true);

outputFiles = struct();
outputFiles.baseline = fullfile(resultDir, 'pressure_fit_baseline.csv');
outputFiles.fitted_k_only = fullfile(resultDir, 'pressure_fit_k_only.csv');
outputFiles.fitted_final = fullfile(resultDir, 'pressure_fit_final.csv');
outputFiles.k_required = fullfile(resultDir, 'pressure_fit_k_required.csv');
outputFiles.volume_sweep = fullfile(resultDir, 'pressure_fit_volume_sweep.csv');
outputFiles.parameters = fullfile(resultDir, 'pressure_fit_parameter_report.csv');
outputFiles.metrics = fullfile(resultDir, 'pressure_fit_metrics.csv');
writetable(baseline, outputFiles.baseline);
writetable(fittedK, outputFiles.fitted_k_only);
writetable(finalFit, outputFiles.fitted_final);
writetable(kInfo, outputFiles.k_required);
if ~isempty(volumeInfo)
    writetable(volumeInfo, outputFiles.volume_sweep);
end
writetable(paramTable, outputFiles.parameters);
writetable(metrics, outputFiles.metrics);
end

function writePressureParams(filePath, P0, pressureParams, includeVolumes)
% 写出压力标定 CSV。初始化脚本只读取 stack_model_index 3:6 的合法行。
paramTable = pressureParamTable(pressureParams, includeVolumes);
if ~includeVolumes
    paramTable = paramTable(paramTable.stack_model_index >= 5, :);
end
paramTable.old_value = zeros(height(paramTable), 1);
for k = 1:height(paramTable)
    switch paramTable.stack_model_index(k)
        case 3
            paramTable.old_value(k) = P0.V_ca_m3;
        case 4
            paramTable.old_value(k) = P0.V_an_m3;
        case 5
            paramTable.old_value(k) = P0.K_ca_out_kg_s_kPa;
        case 6
            paramTable.old_value(k) = P0.K_an_out_kg_s_kPa;
    end
end
paramTable = movevars(paramTable, 'old_value', 'After', 'value');
writetable(paramTable, filePath);
end

function T = pressureParamTable(pressureParams, includeVolumes)
% 组装压力参数表。
parameter = ["V_ca_m3"; "V_an_m3"; "K_ca_out_kg_s_kPa"; "K_an_out_kg_s_kPa"];
stack_model_index = [3; 4; 5; 6];
value = [pressureParams.V_ca_m3; pressureParams.V_an_m3; ...
    pressureParams.K_ca_out_kg_s_kPa; pressureParams.K_an_out_kg_s_kPa];
unit = ["m3"; "m3"; "kg/(s*kPa)"; "kg/(s*kPa)"];
meaning_cn = [
    "阴极等效气体库存体积，仅在 K-only 压力拟合不合格时开放"
    "阳极等效气体库存体积，仅在 K-only 压力拟合不合格时开放"
    "阴极出口等效导纳，使内部 pCa 接近进出口绝压平均值"
    "阳极出口等效导纳，使内部 pAn 接近进出口绝压平均值"
    ];
T = table(parameter, stack_model_index, value, unit, meaning_cn);
if ~includeVolumes
    T.meaning_cn(1:2) = T.meaning_cn(1:2) + "；当前未写入";
end
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
