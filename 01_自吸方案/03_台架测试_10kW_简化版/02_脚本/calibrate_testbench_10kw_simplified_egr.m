function result = calibrate_testbench_10kw_simplified_egr()
%CALIBRATE_TESTBENCH_10KW_SIMPLIFIED_EGR Refit simplified bench EGR model.
%
% Fits the no-EGR polarization curve on the same voltage equation used in
% PEMFCStackCore, then validates with Simulink. EGR voltage effects are kept
% on the physical gas/water/voltage chain, not on a direct EGR penalty term.
%
% 在当前简化台架模型体系中的作用：
% 1. 这是 Simulink 主模型的“电压参数标定与回放脚本”，不是气路模型本体。
% 2. 先调用初始化脚本为每个无 EGR 工况装配 Simulink 输入，再读取
%    PEMFCStackCore 输出的 Nernst 电压、活化损失、欧姆损失、浓差损失等诊断量。
% 3. 只对允许标定的电压相关参数做拟合，并写回
%    00_输入参数/标定参数/simplified_noegr_stack_params.csv。
% 4. 写回参数后再用同一个 Simulink 模型回放 no-EGR 和 EGR 工况，
%    检查误差与入口氧分数、实际氧计量比等诊断趋势。
% 5. 本脚本会覆盖标定参数 CSV；运行前应确认当前参数可以被新的拟合结果替换。

% 定位参数目录。这个标定脚本会重写 simplified_noegr_stack_params.csv，
% 因此它不是只读脚本；运行前要确认当前标定参数可以被新的拟合结果覆盖。
rootDir = fileparts(fileparts(mfilename('fullpath')));
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
if ~isfolder(paramDir)
    mkdir(paramDir);
end
resultDir = fullfile(rootDir, '04_验证结果', 'voltage_fit_v01');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

stackFile = fullfile(paramDir, 'simplified_noegr_stack_params.csv');
if isfile(stackFile), delete(stackFile); end

% 先按无 EGR 数据初始化一次，取得统一工况表和默认参数。
% 删除旧参数文件后再初始化，意味着第一轮拟合从 defaults 中的默认值开始。
P0 = init_testbench_10kw_simplified_egr(1, 'noegr', false);
noEgr = P0.noEgrTable;

% 标定流程：
% 1) 用当前参数跑一遍无 EGR 工况，得到电压方程中的中间诊断量；
% 2) 用 fminsearch 拟合允许调整的电压参数；
% 3) 写回 CSV；
% 4) 再用 Simulink 回放无 EGR 和 EGR 工况，检查误差。
fprintf('Stage 1: no-EGR voltage-equation fit using %d points.\n', height(noEgr));
baseNoEgr = evaluateNoEgr(noEgr);
stackFit = fitNoEgrVoltageEquation(baseNoEgr, P0);
writeStackParams(stackFile, stackFit.spec, stackFit.values, P0);
fitNoEgr = evaluateNoEgr(noEgr);
fprintf('Stage 1 done: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitNoEgr.err_V), max(abs(fitNoEgr.err_V)));

fitEgr = evaluateEgr(P0.egrTable(isfinite(P0.egrTable.cell_voltage_V), :));
fprintf('EGR replay done without direct voltage penalty: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitEgr.err_V), max(abs(fitEgr.err_V)));

fprintf('FINAL_NOEGR_RMSE=%.6f\n', rmse(fitNoEgr.err_V));
fprintf('FINAL_EGR_RMSE=%.6f\n', rmse(fitEgr.err_V));
fprintf('NOEGR_MAX_ABS=%.6f\n', max(abs(fitNoEgr.err_V)));
fprintf('EGR_MAX_ABS=%.6f\n', max(abs(fitEgr.err_V)));

outputFiles = writeCalibrationOutputs(resultDir, stackFit, baseNoEgr, fitNoEgr, fitEgr, P0);
plotCalibration(fitNoEgr, fitEgr);

% 返回结构体，方便命令行继续查看 noegr/egr 误差表和最终写入的参数。
result = struct();
result.baseline_noegr = baseNoEgr;
result.noegr = fitNoEgr;
result.egr = fitEgr;
result.stack_params = readtable(stackFile, 'TextType', 'string');
result.outputs = outputFiles;
end

function spec = baseVoltageSpec(P)
% 定义本次允许拟合的电压参数、它们在 StackModelParam 中的位置、默认值和边界。
% 当前四参数版本暂不考虑浓差极化：
% ASR0、阴极交换电流密度 I0_c、sigma_PEM 修正系数和阴极电荷转移系数 alpha_O2。
names = ["ASR0_ohm_cm2"; "j0_c_A_cm2"; "sigma_pem_correction"; "alpha_O2"];
idx = [12; 13; 16; 17];
default = P.StackModelParam(idx);
lower = [0.0; 1.0e-10; 0.05; 0.15];
upper = [0.50; 1.0e-3; 1.50; 1.00];
default = min(max(default, lower), upper);
scale = ["linear"; "log10"; "linear"; "linear"];
spec = struct('names', names, 'stackModelIndex', idx, ...
    'default', default, 'lower', lower, 'upper', upper, 'scale', scale);
end

function fit = fitNoEgrVoltageEquation(simFit, P)
% 用无 EGR 回放得到的中间变量做解析拟合。
% 这里没有每次都调用 Simulink 优化，而是把 PEMFCStackCore 的电压方程拆出来快速拟合。
spec = baseVoltageSpec(P);
I = simFit.current_A;
j = I ./ P.A_cell_cm2;
TK = simFit.T_stack_C + 273.15;
E = simFit.E_Nernst_V;
Vexp = simFit.V_exp;
lambdaM = simFit.lambda_m;
alphaH2 = 0.5;
j0A = 0.1;
jLeak = 0.01;
deltaCm = 0.0025;

    function V = predict(param)
        % 给定候选参数，按 Nernst - 活化 - 欧姆计算单片电压；当前版本暂不考虑浓差极化。
        param = min(max(param(:), spec.lower), spec.upper);
        ASR0 = param(1);
        j0C = param(2);
        sigmaPemCorrection = param(3);
        alphaO2 = param(4);
        etaActAn = 8.314462618 .* TK ./ (2 * alphaH2 * 96485.33212) .* ...
            log(max((j + jLeak) ./ j0A, 1));
        etaActCa = 8.314462618 .* TK ./ (4 * alphaO2 * 96485.33212) .* ...
            log(max((j + jLeak) ./ j0C, 1));
        etaAct = etaActAn + etaActCa;
        sigmaPem = sigmaPemCorrection .* (0.005193 .* lambdaM - 0.00326) .* ...
            exp(1268 .* (1 / 303.15 - 1 ./ TK));
        assert(all(sigmaPem > 0));
        etaOhm = j .* (deltaCm ./ sigmaPem + ASR0);
        etaCon = zeros(size(j));
        V = E - etaAct - etaOhm - etaCon;
    end

    function f = objective(z, rowMask)
        % 优化目标是平均平方误差。当前只拟合四个电压参数，不额外加经验正则项。
        param = physicalFromUnit(z, spec);
        err = predict(param) - Vexp;
        err = err(rowMask);
        f = mean(err.^2);
    end

[stageParam, stageTable] = estimateSegmentedInitial(spec.default);
[multiStartTable, zBest] = runMultiStart(stageParam, 64);
opts = optimset('Display', 'off', 'MaxIter', 6000, 'MaxFunEvals', 24000, ...
    'TolX', 1e-10, 'TolFun', 1e-12);
z = fminsearch(@(z) objective(z, true(size(j))), zBest, opts);
values = physicalFromUnit(z, spec);
fit = struct('spec', spec, 'values', values, ...
    'stageInitial', stageParam, 'stageTable', stageTable, ...
    'multiStartTable', multiStartTable);
fprintf('Stage 1 analytic RMSE %.5f V before Simulink replay.\n', ...
    rmse(predict(values) - Vexp));

    function [param, stageTable] = estimateSegmentedInitial(param0)
        % 分段初值估计：低电流定 I0_c/alpha_O2，中电流定欧姆相关项。
        param = param0(:);
        stageTable = table('Size', [0 6], ...
            'VariableTypes', {'string','string','double','double','double','double'}, ...
            'VariableNames', {'stage','free_parameters','row_count','rmse_before','rmse_after','max_abs_after'});
        [param, stageTable] = runStage(param, stageTable, "low_current_activation", [2 4], j <= 0.4);
        [param, stageTable] = runStage(param, stageTable, "mid_current_ohmic", [1 3], j > 0.4 & j <= 1.1);
        fprintf('Segmented initial RMSE %.5f V before joint fit.\n', rmse(predict(param) - Vexp));
    end

    function [paramOut, stageTable] = runStage(paramIn, stageTable, stageName, freeIdx, rowMask)
        rowMask = rowMask(:) & isfinite(Vexp(:));
        paramOut = paramIn(:);
        if nnz(rowMask) == 0
            return;
        end
        zBase = unitFromPhysical(paramOut, spec);
        errBefore = predict(paramOut) - Vexp;
        obj = @(zFree) objectiveStage(zFree, zBase, freeIdx, rowMask);
        localOpts = optimset('Display', 'off', 'MaxIter', 1500, 'MaxFunEvals', 6000, ...
            'TolX', 1e-9, 'TolFun', 1e-11);
        zFree = fminsearch(obj, zBase(freeIdx), localOpts);
        zBase(freeIdx) = zFree(:);
        paramOut = physicalFromUnit(zBase, spec);
        errAfter = predict(paramOut) - Vexp;
        newRow = table(stageName, strjoin(spec.names(freeIdx), ","), nnz(rowMask), ...
            rmse(errBefore(rowMask)), rmse(errAfter(rowMask)), max(abs(errAfter(rowMask))), ...
            'VariableNames', stageTable.Properties.VariableNames);
        stageTable = [stageTable; newRow]; %#ok<AGROW>
    end

    function f = objectiveStage(zFree, zBase, freeIdx, rowMask)
        zTry = zBase(:);
        zTry(freeIdx) = zFree(:);
        f = objective(zTry, rowMask);
    end

    function [scanTable, zBestOut] = runMultiStart(stageParam, randomStartCount)
        % 多起点粗搜索：判断局部优化是否卡在某个初值附近。
        % 第 1 组为分段初值，第 2 组为 CSV/default 初值，其余为可复现随机初值。
        rng(20260611, 'twister');
        nParam = numel(spec.names);
        nStart = randomStartCount + 2;
        zStarts = zeros(nParam, nStart);
        zStarts(:, 1) = unitFromPhysical(stageParam, spec);
        zStarts(:, 2) = unitFromPhysical(spec.default, spec);
        for s = 3:nStart
            zStarts(:, s) = unitFromPhysical(randomPhysicalPoint(), spec);
        end

        startId = (1:nStart).';
        source = strings(nStart, 1);
        source(1) = "segmented";
        source(2) = "csv_default";
        source(3:end) = "random";
        rmseStart = zeros(nStart, 1);
        rmseAfter = zeros(nStart, 1);
        maxAbsAfter = zeros(nStart, 1);
        paramMat = zeros(nStart, nParam);
        zBestOut = zStarts(:, 1);
        bestObj = inf;
        scanOpts = optimset('Display', 'off', 'MaxIter', 1800, ...
            'MaxFunEvals', 7200, 'TolX', 1e-8, 'TolFun', 1e-10);

        for s = 1:nStart
            p0 = physicalFromUnit(zStarts(:, s), spec);
            err0 = predict(p0) - Vexp;
            rmseStart(s) = rmse(err0);
            zFit = fminsearch(@(z) objective(z, true(size(j))), zStarts(:, s), scanOpts);
            pFit = physicalFromUnit(zFit, spec);
            errFit = predict(pFit) - Vexp;
            rmseAfter(s) = rmse(errFit);
            maxAbsAfter(s) = max(abs(errFit));
            paramMat(s, :) = pFit(:).';
            obj = mean(errFit.^2);
            if obj < bestObj
                bestObj = obj;
                zBestOut = zFit(:);
            end
        end

        scanTable = table(startId, source, rmseStart, rmseAfter, maxAbsAfter);
        for k = 1:nParam
            scanTable.(spec.names(k)) = paramMat(:, k);
        end
        scanTable = sortrows(scanTable, "rmseAfter", "ascend");
        fprintf('Multistart best analytic RMSE %.5f V from %d starts.\n', ...
            scanTable.rmseAfter(1), nStart);
    end

    function param = randomPhysicalPoint()
        % 在线性参数用线性均匀采样，在 log 参数用 log10 均匀采样。
        param = zeros(numel(spec.names), 1);
        for kk = 1:numel(spec.names)
            u = rand();
            if spec.scale(kk) == "log10"
                lb = log10(spec.lower(kk));
                ub = log10(spec.upper(kk));
                param(kk) = 10 .^ (lb + u * (ub - lb));
            else
                param(kk) = spec.lower(kk) + u * (spec.upper(kk) - spec.lower(kk));
            end
        end
    end
end

function fit = evaluateNoEgr(data)
% 逐个无 EGR 工况运行 Simulink，并把实验电压、仿真电压和关键诊断量整理成表。
n = height(data);
fit = table('Size', [n 18], 'VariableTypes', repmat("double", 1, 18), ...
    'VariableNames', {'case_index','current_A','egr_fraction','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','pCa_kPa','T_stack_C','E_Nernst_V','etaAct_V', ...
    'etaOhm_V','etaCon_V','i0Scale','lambda_m','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'all', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    caIn = lastVector(out.get('stack_in_node'));
    caOut = lastVector(out.get('stack_ca_out_node'));
    egrReturn = lastVector(out.get('egr_return_node'));
    benchOut = lastVector(out.get('bench_out_node'));
    fit.case_index(k) = data.case_index(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.egr_fraction(k) = P.egr_fraction_cmd;
    fit = fillCommonFit(fit, k, s, P, caIn, caOut, egrReturn, benchOut);
end
assert(any(abs(fit.V_exp) > 0) && any(abs(fit.V_sim) > 0), ...
    'CEGR:SimplifiedCalibration:InvalidNoEgrFit', 'No-EGR fit table was not populated.');
end

function fit = evaluateEgr(data)
% 逐个 EGR 工况运行 Simulink。这里不重新拟合 EGR 经验扣压项，
% 用同一套电压参数检查混合气、氧分压、湿度和膜态链路能否解释趋势。
n = height(data);
fit = table('Size', [n 15], 'VariableTypes', repmat("double", 1, 15), ...
    'VariableNames', {'case_index','current_A','egr_fraction_raw','egr_fraction_used','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','E_Nernst_V','etaAct_V','etaOhm_V','etaCon_V','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'all', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    caIn = lastVector(out.get('stack_in_node'));
    caOut = lastVector(out.get('stack_ca_out_node'));
    egrReturn = lastVector(out.get('egr_return_node'));
    benchOut = lastVector(out.get('bench_out_node'));
    fit.case_index(k) = data.case_index(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.egr_fraction_raw(k) = P.egr_fraction_cmd_raw;
    fit.egr_fraction_used(k) = P.egr_fraction_cmd;
    fit = fillCommonFit(fit, k, s, P, caIn, caOut, egrReturn, benchOut);
end
assert(any(abs(fit.V_exp) > 0) && any(abs(fit.V_sim) > 0), ...
    'CEGR:SimplifiedCalibration:InvalidEgrFit', 'EGR fit table was not populated.');
end

function fit = fillCommonFit(fit, k, s, P, caIn, caOut, egrReturn, benchOut)
% 从 summary_vector 取出通用诊断量。索引必须和 Simulink 中 SystemSummary 的输出顺序一致。
% 关键索引：2=V_cell，20=xO2In，21=RHIn，31=maxGasRes，36~39=电压损失项，40=lambdaO2。
fit.V_exp(k) = P.cell_voltage_bench_V;
fit.V_sim(k) = s(2);
fit.err_V(k) = s(2) - P.cell_voltage_bench_V;
fit.xO2In(k) = s(20);
fit.RHIn(k) = s(21);
fit.lambdaO2(k) = s(40);
fit.E_Nernst_V(k) = s(36);
fit.etaAct_V(k) = s(37);
fit.etaOhm_V(k) = s(38);
fit.etaCon_V(k) = s(39);
fit.max_gas_residual(k) = s(31);
if ismember('pCa_kPa', fit.Properties.VariableNames)
    fit.pCa_kPa(k) = s(5);
    fit.T_stack_C(k) = s(9);
    fit.i0Scale(k) = s(43);
    fit.lambda_m(k) = s(8);
end
fit = fillConditionDiagnostics(fit, k, P, caIn, caOut, egrReturn, benchOut);
end

function fit = fillConditionDiagnostics(fit, k, P, caIn, caOut, egrReturn, benchOut)
% 补充温度、湿度、压力诊断。入口和出口压力多为边界回放量；
% 出口温度、EGR 回流温湿压用于发现热湿/分离器链路是否有系统偏差。
fit = ensureConditionColumns(fit);
fit.exp_stack_in_p_abs_kPa(k) = P.bench_stack_in_p_kPa + P.p_amb_kPa;
fit.sim_stack_in_p_abs_kPa(k) = caIn(6);
fit.stack_in_p_err_kPa(k) = fit.sim_stack_in_p_abs_kPa(k) - fit.exp_stack_in_p_abs_kPa(k);
fit.exp_stack_in_T_C(k) = P.bench_stack_in_T_C;
fit.sim_stack_in_T_C(k) = caIn(5);
fit.stack_in_T_err_C(k) = fit.sim_stack_in_T_C(k) - fit.exp_stack_in_T_C(k);
fit.exp_stack_in_RH(k) = P.bench_stack_in_RH;
fit.sim_stack_in_RH(k) = fit.RHIn(k);
fit.stack_in_RH_err(k) = fit.sim_stack_in_RH(k) - fit.exp_stack_in_RH(k);

fit.exp_stack_out_p_abs_kPa(k) = P.stack_out_p_kPa + P.p_amb_kPa;
fit.sim_stack_out_p_abs_kPa(k) = caOut(6);
fit.stack_out_p_err_kPa(k) = fit.sim_stack_out_p_abs_kPa(k) - fit.exp_stack_out_p_abs_kPa(k);
fit.exp_stack_out_T_C(k) = P.stack_out_T_C;
fit.sim_stack_out_T_C(k) = caOut(5);
fit.stack_out_T_err_C(k) = fit.sim_stack_out_T_C(k) - fit.exp_stack_out_T_C(k);
fit.exp_cathode_dp_kPa(k) = P.cathode_dp_kPa;
fit.sim_cathode_dp_kPa(k) = caIn(6) - caOut(6);
fit.cathode_dp_err_kPa(k) = fit.sim_cathode_dp_kPa(k) - fit.exp_cathode_dp_kPa(k);

fit.exp_egr_return_p_abs_kPa(k) = finiteOrNaN(P.egr_return_p_kPa) + P.p_amb_kPa;
fit.sim_egr_return_p_abs_kPa(k) = egrReturn(6);
fit.egr_return_p_err_kPa(k) = fit.sim_egr_return_p_abs_kPa(k) - fit.exp_egr_return_p_abs_kPa(k);
fit.exp_egr_return_T_C(k) = finiteOrNaN(P.egr_return_T_C);
fit.sim_egr_return_T_C(k) = egrReturn(5);
fit.egr_return_T_err_C(k) = fit.sim_egr_return_T_C(k) - fit.exp_egr_return_T_C(k);
fit.exp_egr_return_RH(k) = finiteOrNaN(P.egr_return_RH);
fit.sim_egr_return_RH(k) = gasNodeRH(egrReturn, P);
fit.egr_return_RH_err(k) = fit.sim_egr_return_RH(k) - fit.exp_egr_return_RH(k);

fit.exp_bench_out_p_abs_kPa(k) = finiteOrNaN(P.stack_out_p_kPa) + P.p_amb_kPa;
fit.sim_bench_out_p_abs_kPa(k) = benchOut(6);
fit.bench_out_p_err_kPa(k) = fit.sim_bench_out_p_abs_kPa(k) - fit.exp_bench_out_p_abs_kPa(k);
fit.exp_bench_out_T_C(k) = finiteOrNaN(P.stack_out_T_C);
fit.sim_bench_out_T_C(k) = benchOut(5);
fit.bench_out_T_err_C(k) = fit.sim_bench_out_T_C(k) - fit.exp_bench_out_T_C(k);
end

function fit = ensureConditionColumns(fit)
% 动态添加条件审查列，避免 no-EGR/EGR 预分配表重复维护几十个变量名。
names = ["exp_stack_in_p_abs_kPa","sim_stack_in_p_abs_kPa","stack_in_p_err_kPa", ...
    "exp_stack_in_T_C","sim_stack_in_T_C","stack_in_T_err_C", ...
    "exp_stack_in_RH","sim_stack_in_RH","stack_in_RH_err", ...
    "exp_stack_out_p_abs_kPa","sim_stack_out_p_abs_kPa","stack_out_p_err_kPa", ...
    "exp_stack_out_T_C","sim_stack_out_T_C","stack_out_T_err_C", ...
    "exp_cathode_dp_kPa","sim_cathode_dp_kPa","cathode_dp_err_kPa", ...
    "exp_egr_return_p_abs_kPa","sim_egr_return_p_abs_kPa","egr_return_p_err_kPa", ...
    "exp_egr_return_T_C","sim_egr_return_T_C","egr_return_T_err_C", ...
    "exp_egr_return_RH","sim_egr_return_RH","egr_return_RH_err", ...
    "exp_bench_out_p_abs_kPa","sim_bench_out_p_abs_kPa","bench_out_p_err_kPa", ...
    "exp_bench_out_T_C","sim_bench_out_T_C","bench_out_T_err_C"];
for n = names
    if ~ismember(n, string(fit.Properties.VariableNames))
        fit.(n) = NaN(height(fit), 1);
    end
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

function z = unitFromBounded(x, lb, ub)
% 把有上下界的物理参数映射到无界优化变量 z，便于 fminsearch 使用。
x = min(max(x(:), lb(:) + 1e-12), ub(:) - 1e-12);
r = (x - lb(:)) ./ max(ub(:) - lb(:), 1e-12);
z = log(r ./ max(1 - r, 1e-12));
end

function x = boundedFromUnit(z, lb, ub)
% 把无界优化变量映射回物理参数上下界范围内。
r = 1 ./ (1 + exp(-z(:)));
x = lb(:) + r .* (ub(:) - lb(:));
end

function z = unitFromPhysical(x, spec)
% 把物理参数映射到优化变量。j0_c 使用 log10 空间，其余参数使用线性空间。
x = x(:);
z = zeros(size(x));
for k = 1:numel(x)
    if spec.scale(k) == "log10"
        xk = log10(max(x(k), realmin));
        lb = log10(spec.lower(k));
        ub = log10(spec.upper(k));
        z(k) = unitFromBounded(xk, lb, ub);
    else
        z(k) = unitFromBounded(x(k), spec.lower(k), spec.upper(k));
    end
end
end

function x = physicalFromUnit(z, spec)
% 把优化变量映射回物理参数。j0_c 使用 log10 空间，其余参数使用线性空间。
z = z(:);
x = zeros(size(z));
for k = 1:numel(z)
    if spec.scale(k) == "log10"
        lb = log10(spec.lower(k));
        ub = log10(spec.upper(k));
        x(k) = 10 .^ boundedFromUnit(z(k), lb, ub);
    else
        x(k) = boundedFromUnit(z(k), spec.lower(k), spec.upper(k));
    end
end
end

function v = lastVector(ts)
% 取 To Workspace timeseries 最后一个时刻的向量值。
v = ts.signals.values(:, :, end);
v = v(:);
end

function writeStackParams(filePath, spec, values, P)
% 把拟合后的核心电压参数写入 CSV。主初始化脚本后续会读取这个文件覆盖默认值。
folder = fileparts(filePath);
if ~isfolder(folder), mkdir(folder); end
T = table(spec.names(:), spec.stackModelIndex(:), values(:), ...
    'VariableNames', {'parameter', 'stack_model_index', 'value'});
if nargin >= 4 && isfield(P, 'tau_mem_s')
    T = [T; table("tau_mem_s", 19, P.tau_mem_s, ...
        'VariableNames', {'parameter', 'stack_model_index', 'value'})];
end
T = addStackParamMetadata(T);
writetable(T, filePath);
end

function outputFiles = writeCalibrationOutputs(resultDir, stackFit, baseNoEgr, fitNoEgr, fitEgr, P)
% 写出标定结果表。文件为本轮验证产物，便于检查边界、残差和 EGR 泛化。
if ~isfolder(resultDir)
    mkdir(resultDir);
end
paramReport = buildParameterReport(stackFit.spec, stackFit.values, stackFit.stageInitial);
baseNoEgr = addResidualDiagnostics(baseNoEgr, P);
fitNoEgr = addResidualDiagnostics(fitNoEgr, P);
fitEgr = addResidualDiagnostics(fitEgr, P);
metrics = buildMetricsTable(fitNoEgr, fitEgr);

outputFiles = struct();
outputFiles.parameter_report = fullfile(resultDir, 'voltage_fit_parameter_report.csv');
outputFiles.stage_initialization = fullfile(resultDir, 'voltage_fit_stage_initialization.csv');
outputFiles.multistart_scan = fullfile(resultDir, 'voltage_fit_multistart_scan.csv');
outputFiles.noegr_baseline = fullfile(resultDir, 'voltage_fit_stage0_noegr_baseline.csv');
outputFiles.noegr_residuals = fullfile(resultDir, 'voltage_fit_noegr_residuals.csv');
outputFiles.egr_validation = fullfile(resultDir, 'voltage_fit_egr_validation.csv');
outputFiles.metrics = fullfile(resultDir, 'voltage_fit_metrics.csv');

writetable(paramReport, outputFiles.parameter_report);
writetable(stackFit.stageTable, outputFiles.stage_initialization);
writetable(stackFit.multiStartTable, outputFiles.multistart_scan);
writetable(baseNoEgr, outputFiles.noegr_baseline);
writetable(fitNoEgr, outputFiles.noegr_residuals);
writetable(fitEgr, outputFiles.egr_validation);
writetable(metrics, outputFiles.metrics);

fprintf('Wrote voltage fit outputs to %s\n', resultDir);
if any(paramReport.boundary_warning)
    warning('CEGR:SimplifiedCalibration:BoundaryFit', ...
        'At least one fitted parameter is close to a bound; inspect voltage_fit_parameter_report.csv before accepting values.');
end
end

function T = buildParameterReport(spec, values, stageInitial)
% 生成参数边界状态表。边界贴近不自动判失败，但必须显式标出。
n = numel(values);
boundFraction = zeros(n, 1);
for k = 1:n
    if spec.scale(k) == "log10"
        lb = log10(spec.lower(k));
        ub = log10(spec.upper(k));
        v = log10(values(k));
    else
        lb = spec.lower(k);
        ub = spec.upper(k);
        v = values(k);
    end
    boundFraction(k) = (v - lb) / max(ub - lb, eps);
end
boundaryWarning = boundFraction <= 0.02 | boundFraction >= 0.98;
T = table(spec.names(:), spec.stackModelIndex(:), spec.scale(:), spec.lower(:), ...
    spec.upper(:), spec.default(:), stageInitial(:), values(:), boundFraction, ...
    boundaryWarning, 'VariableNames', {'parameter','stack_model_index','scale', ...
    'lower','upper','default_value','segmented_initial','fitted_value', ...
    'bound_fraction','boundary_warning'});
end

function T = addResidualDiagnostics(T, P)
% 给回放结果补充误差、当前密度和欧姆总面积电阻诊断。
j = T.current_A ./ P.A_cell_cm2;
T.current_density_A_cm2 = j;
T.abs_err_V = abs(T.err_V);
T.ohmic_area_ohm_cm2 = T.etaOhm_V ./ max(j, eps);
lossTotal = T.etaAct_V + T.etaOhm_V + T.etaCon_V;
T.conc_loss_fraction = T.etaCon_V ./ max(lossTotal, eps);
T.loss_terms_nonnegative = T.etaAct_V >= 0 & T.etaOhm_V >= 0 & T.etaCon_V >= 0;
end

function T = buildMetricsTable(noEgrFit, egrFit)
% 汇总 no-EGR 拟合和 EGR 验证的总体误差，以及 EGR 误差与输入诊断的相关性。
names = ["noEGR_fit"; "EGR_validation"];
rmseV = [rmse(noEgrFit.err_V); rmse(egrFit.err_V)];
maxAbsV = [max(abs(noEgrFit.err_V)); max(abs(egrFit.err_V))];
meanErrV = [mean(noEgrFit.err_V, 'omitnan'); mean(egrFit.err_V, 'omitnan')];
rows = [height(noEgrFit); height(egrFit)];
corrErrEgr = [NaN; safeCorr(egrFit.err_V, egrFit.egr_fraction_used)];
corrErrXO2 = [safeCorr(noEgrFit.err_V, noEgrFit.xO2In); safeCorr(egrFit.err_V, egrFit.xO2In)];
stackOutTRmse = [rmse(noEgrFit.stack_out_T_err_C); rmse(egrFit.stack_out_T_err_C)];
stackOutTMax = [max(abs(noEgrFit.stack_out_T_err_C), [], 'omitnan'); max(abs(egrFit.stack_out_T_err_C), [], 'omitnan')];
stackInRHRmse = [rmse(noEgrFit.stack_in_RH_err); rmse(egrFit.stack_in_RH_err)];
stackInRHMax = [max(abs(noEgrFit.stack_in_RH_err), [], 'omitnan'); max(abs(egrFit.stack_in_RH_err), [], 'omitnan')];
stackOutPRmse = [rmse(noEgrFit.stack_out_p_err_kPa); rmse(egrFit.stack_out_p_err_kPa)];
cathodeDpRmse = [rmse(noEgrFit.cathode_dp_err_kPa); rmse(egrFit.cathode_dp_err_kPa)];
egrReturnTRmse = [NaN; rmse(egrFit.egr_return_T_err_C)];
egrReturnRHRmse = [NaN; rmse(egrFit.egr_return_RH_err)];
egrReturnPRmse = [NaN; rmse(egrFit.egr_return_p_err_kPa)];
corrVErrStackOutT = [safeCorr(noEgrFit.err_V, noEgrFit.stack_out_T_err_C); safeCorr(egrFit.err_V, egrFit.stack_out_T_err_C)];
corrVErrEgrReturnRH = [NaN; safeCorr(egrFit.err_V, egrFit.egr_return_RH_err)];
T = table(names, rows, rmseV, maxAbsV, meanErrV, corrErrEgr, corrErrXO2, ...
    stackOutTRmse, stackOutTMax, stackInRHRmse, stackInRHMax, stackOutPRmse, ...
    cathodeDpRmse, egrReturnTRmse, egrReturnRHRmse, egrReturnPRmse, ...
    corrVErrStackOutT, corrVErrEgrReturnRH, ...
    'VariableNames', {'dataset','rows','rmse_V','max_abs_err_V','mean_err_V', ...
    'corr_err_vs_egr_fraction','corr_err_vs_xO2In','stack_out_T_rmse_C', ...
    'stack_out_T_max_abs_C','stack_in_RH_rmse','stack_in_RH_max_abs', ...
    'stack_out_p_rmse_kPa','cathode_dp_rmse_kPa','egr_return_T_rmse_C', ...
    'egr_return_RH_rmse','egr_return_p_rmse_kPa','corr_Verr_vs_stack_out_Terr', ...
    'corr_Verr_vs_egr_return_RHerr'});
end

function c = safeCorr(x, y)
% 不依赖额外工具箱的相关系数计算。
mask = isfinite(x) & isfinite(y);
if nnz(mask) < 2
    c = NaN;
    return;
end
x = x(mask) - mean(x(mask));
y = y(mask) - mean(y(mask));
den = sqrt(sum(x.^2) * sum(y.^2));
if den <= eps
    c = NaN;
else
    c = sum(x .* y) / den;
end
end

function x = finiteOrNaN(x)
% 缺失或非有限实验值统一保留为 NaN，避免条件诊断把缺测当作零误差。
if isempty(x) || ~isfinite(x)
    x = NaN;
end
end

function RH = gasNodeRH(node, P)
% 根据 7x1 气体节点向量估算水蒸气相对湿度。
% node(1:3)=O2/N2/H2O 气相质量流量，node(5)=T_C，node(6)=p_abs_kPa。
mO2 = max(node(1), 0);
mN2 = max(node(2), 0);
mV = max(node(3), 0);
nTot = mO2 / P.M_O2_kg_mol + mN2 / P.M_N2_kg_mol + mV / P.M_H2O_kg_mol;
if nTot <= 0 || node(6) <= 0 || ~isfinite(node(5))
    RH = NaN;
    return;
end
xV = (mV / P.M_H2O_kg_mol) / nTot;
pV = node(6) * xV;
RH = pV / max(satKPaLocal(node(5)), 1e-9);
end

function p = satKPaLocal(T)
% Buck 饱和水蒸气压公式，T 单位 degC。
p = 0.61121 .* exp((18.678 - T ./ 234.5) .* (T ./ (257.14 + T)));
end

function T = addStackParamMetadata(T)
% 给标定参数表补充人可读说明列。这些附加列不参与脚本读取，核心读取列仍是
% parameter / stack_model_index / value。
unit = strings(height(T), 1);
modelLocation = strings(height(T), 1);
meaning = strings(height(T), 1);
calibrationRole = strings(height(T), 1);
sourceNote = strings(height(T), 1);
for k = 1:height(T)
    switch string(T.parameter(k))
        case "ASR0_ohm_cm2"
            unit(k) = "ohm*cm2";
            modelLocation(k) = "StackModelParam_simplified(12)";
            meaning(k) = "膜外接触/装配等效面积比内阻，参与 etaOhm 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "欧姆极化可拟合参数；膜电导率 sigma_PEM 由电堆膜水含量 lambda 计算";
        case "j0_c_A_cm2"
            unit(k) = "A/cm2";
            modelLocation(k) = "StackModelParam_simplified(13)";
            meaning(k) = "阴极交换电流密度，参与 etaAct 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "以书中 I0,c=3e-6 A/cm2 为初值，用无 EGR 极化数据拟合";
        case "conc_loss_c"
            unit(k) = "-";
            modelLocation(k) = "StackModelParam_simplified(14)";
            meaning(k) = "浓差损失经验系数 c，当前 etaCon=0 时仅为接口占位";
            calibrationRole(k) = "disabled in current voltage fit";
            sourceNote(k) = "当前实验电流范围未呈现明显浓差拐点，暂不拟合";
        case "iL_A_cm2"
            unit(k) = "A/cm2";
            modelLocation(k) = "StackModelParam_simplified(15)";
            meaning(k) = "极限电流密度，当前 etaCon=0 时仅为接口占位";
            calibrationRole(k) = "disabled in current voltage fit";
            sourceNote(k) = "当前实验电流范围未呈现明显浓差拐点，暂不拟合";
        case "sigma_pem_correction"
            unit(k) = "-";
            modelLocation(k) = "StackModelParam_simplified(16)";
            meaning(k) = "膜电导率 sigma_PEM 修正系数，参与 etaOhm 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "欧姆极化可拟合参数；sigma_PEM 的 lambda 来自电堆内部膜水含量";
        case "alpha_O2"
            unit(k) = "-";
            modelLocation(k) = "StackModelParam_simplified(17)";
            meaning(k) = "阴极电荷转移系数，参与 etaActCa 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "书中参考值 0.3；当前开放范围 0.15..1.00，需和 j0_c 联合检查可辨识性";
        case "tau_mem_s"
            unit(k) = "s";
            modelLocation(k) = "StackModelParam_simplified(19)";
            meaning(k) = "膜水通量一阶松弛时间常数";
            calibrationRole(k) = "model dynamic setting";
            sourceNote(k) = "膜水动态设置，不作为本轮电压拟合参数";
    end
end
T.unit = unit;
T.model_location = modelLocation;
T.meaning_cn = meaning;
T.calibration_role = calibrationRole;
T.source_note = sourceNote;
end

function y = rmse(x)
% 忽略 NaN 后计算均方根误差。
x = x(isfinite(x));
y = sqrt(mean(x.^2));
end

function plotCalibration(noEgrFit, egrFit)
% 生成交互式标定图：无 EGR 极化曲线、残差、EGR 电压散点和入口氧诊断。
% 这里只打开 MATLAB figure，不保存图片文件。
figure('Name', 'Simplified bench calibration', 'NumberTitle', 'off');
tiledlayout(2, 2);

nexttile;
plot(noEgrFit.current_A, noEgrFit.V_exp, 'ko', noEgrFit.current_A, noEgrFit.V_sim, 'b.-');
grid on; xlabel('Current A'); ylabel('Cell voltage V'); title('No-EGR polarization');
legend('Experiment', 'Simulation', 'Location', 'best');

nexttile;
plot(noEgrFit.current_A, noEgrFit.err_V, 'r.-');
grid on; xlabel('Current A'); ylabel('Sim - Exp V'); title('No-EGR residual');

nexttile;
scatter(egrFit.egr_fraction_used, egrFit.V_exp, 36, egrFit.current_A, 'filled'); hold on;
scatter(egrFit.egr_fraction_used, egrFit.V_sim, 36, egrFit.current_A, 'x');
grid on; xlabel('EGR fraction'); ylabel('Cell voltage V'); title('EGR voltage');

nexttile;
plot(egrFit.egr_fraction_used, egrFit.xO2In, 'b.-'); hold on;
plot(egrFit.egr_fraction_used, egrFit.lambdaO2, 'm.-');
grid on; xlabel('EGR fraction'); title('Inlet oxygen diagnostics');
legend('xO2 inlet', 'lambda O2 actual', 'Location', 'best');
end
