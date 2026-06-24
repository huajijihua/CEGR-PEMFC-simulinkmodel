function result = calibrate_testbench_10kw_simplified_egr()
%CALIBRATE_TESTBENCH_10KW_SIMPLIFIED_EGR Refit simplified bench EGR model.
%
% Fits the no-EGR polarization curve on the same voltage equation used in
% PEMFCStackCore, with a weak EGR delta-voltage trend objective. EGR absolute
% voltage is still treated as validation so that gas/water errors are not
% hidden by a direct EGR voltage offset.
%
% 在当前简化台架模型体系中的作用：
% 1. 这是 Simulink 主模型的“电压参数标定与回放脚本”，不是气路模型本体。
% 2. 先调用初始化脚本为每个无 EGR 工况装配 Simulink 输入，再读取
%    PEMFCStackCore 输出的 Nernst 电压、活化损失、欧姆损失、浓差损失等诊断量。
% 3. 只对允许标定的电压相关参数做拟合，并写回
%    00_输入参数/标定参数/simplified_noegr_stack_params.csv。
% 4. 当前目标函数以 no-EGR 绝对电压为主，并加入较小权重的 EGR 相对
%    no-EGR 基准电压变化量；EGR 绝对电压仍作为验证输出。
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
baseEgr = evaluateEgr(P0.egrTable(isfinite(P0.egrTable.cell_voltage_V), :));
stackFit = fitNoEgrVoltageEquation(baseNoEgr, P0, baseEgr);
writeStackParams(stackFile, stackFit.spec, stackFit.values, P0);
fitNoEgr = evaluateNoEgr(noEgr);
fprintf('Stage 1 done: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitNoEgr.err_V), max(abs(fitNoEgr.err_V)));

fitEgr = evaluateEgr(P0.egrTable(isfinite(P0.egrTable.cell_voltage_V), :));
fprintf('EGR replay done after weak delta-voltage weighting: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitEgr.err_V), max(abs(fitEgr.err_V)));

fprintf('FINAL_NOEGR_RMSE=%.6f\n', rmse(fitNoEgr.err_V));
fprintf('FINAL_EGR_RMSE=%.6f\n', rmse(fitEgr.err_V));
fprintf('NOEGR_MAX_ABS=%.6f\n', max(abs(fitNoEgr.err_V)));
fprintf('EGR_MAX_ABS=%.6f\n', max(abs(fitEgr.err_V)));

outputFiles = writeCalibrationOutputs(resultDir, stackFit, baseNoEgr, fitNoEgr, fitEgr, P0);
plotCalibration(fitNoEgr, fitEgr, rootDir);

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
% 当前五参数版本暂不考虑浓差极化：
% theta1~theta4 拟合书籍活化极化经验式，sigma_pem_correction 拟合膜电导率修正。
names = ["theta1_act"; "theta2_act"; "theta3_act"; "theta4_act"; "sigma_pem_correction"];
idx = [12; 13; 14; 15; 16];
default = P.StackModelParam(idx);
lower = [0.0; -5.0e-3; -5.0e-4; 0.0; 0.05];
upper = [2.0; 5.0e-3; -5.0e-5; 5.0e-4; 1.50];
default = min(max(default, lower), upper);
scale = ["linear"; "linear"; "linear"; "linear"; "linear"];
spec = struct('names', names, 'stackModelIndex', idx, ...
    'default', default, 'lower', lower, 'upper', upper, 'scale', scale);
end

function fit = fitNoEgrVoltageEquation(simFit, P, egrFit)
% 用 no-EGR/EGR 回放得到的中间变量做解析拟合。
% 这里没有每次都调用 Simulink 优化，而是把 PEMFCStackCore 的电压方程拆出来快速拟合。
spec = baseVoltageSpec(P);
egrDeltaWeight = 0.6;
j = simFit.current_A ./ P.A_cell_cm2;
Vexp = simFit.V_exp;
egrJ = egrFit.current_A ./ P.A_cell_cm2;
egrVexp = egrFit.V_exp;
jLeak = 0.01;
deltaCm = 0.0025;

    function [V, etaAct, etaOhm, etaCon] = predictFromTable(T, param)
        % 给定候选参数，按 Nernst - 活化 - 欧姆计算单片电压；当前版本暂不考虑浓差极化。
        param = min(max(param(:), spec.lower), spec.upper);
        theta1 = param(1);
        theta2 = param(2);
        theta3 = param(3);
        theta4 = param(4);
        sigmaPemCorrection = param(5);
        jLocal = T.current_A ./ P.A_cell_cm2;
        TK = T.T_stack_C + 273.15;
        etaAct = theta1 + theta2 .* TK + theta3 .* TK .* log(T.C_O2_mol_m3) + ...
            theta4 .* TK .* log(jLocal + jLeak);
        sigmaPem = sigmaPemCorrection .* (0.005193 .* T.lambda_m - 0.00326) .* ...
            exp(1268 .* (1 / 303.15 - 1 ./ TK));
        assert(all(sigmaPem > 0));
        etaOhm = jLocal .* (deltaCm ./ sigmaPem);
        etaCon = zeros(size(jLocal));
        V = T.E_Nernst_V - etaAct - etaOhm - etaCon;
    end

    function [V, etaAct, etaOhm, etaCon] = predict(param)
        [V, etaAct, etaOhm, etaCon] = predictFromTable(simFit, param);
    end

    function f = objective(z, rowMask)
        % 优化目标：no-EGR 绝对电压为主，EGR 只按相对 no-EGR 基准的电压变化趋势加权。
        param = physicalFromUnit(z, spec);
        [V, etaAct, etaOhm] = predict(param);
        err = V - Vexp;
        errMain = err(rowMask);
        egrDeltaErr = egrDeltaResidual(param);
        negLoss = [min(etaAct(rowMask), 0); min(etaOhm(rowMask), 0)];
        f = mean(errMain.^2) + egrDeltaWeight * mean(egrDeltaErr.^2) + 100 * mean(negLoss.^2);
    end

    function err = egrDeltaResidual(param)
        Vno = predict(param);
        Vegr = predictFromTable(egrFit, param);
        VnoExpRef = interpNoEgrReference(Vexp);
        VnoSimRef = interpNoEgrReference(Vno);
        err = (Vegr - VnoSimRef) - (egrVexp - VnoExpRef);
    end

    function yq = interpNoEgrReference(y)
        % no-EGR 数据中可能有重复电流点；先按电流密度合并，再作为 EGR 相对基准。
        [jUnique, ~, groupIdx] = unique(j);
        yUnique = accumarray(groupIdx, y(:), [], @mean);
        yq = interp1(jUnique, yUnique, egrJ, 'pchip', 'extrap');
    end

[stageParam, stageTable] = estimateSegmentedInitial(spec.default);
[multiStartTable, zBest] = runMultiStart(stageParam, 64);
opts = optimset('Display', 'off', 'MaxIter', 6000, 'MaxFunEvals', 24000, ...
    'TolX', 1e-10, 'TolFun', 1e-12);
z = fminsearch(@(z) objective(z, true(size(j))), zBest, opts);
values = physicalFromUnit(z, spec);
fit = struct('spec', spec, 'values', values, 'egrDeltaWeight', egrDeltaWeight, ...
    'stageInitial', stageParam, 'stageTable', stageTable, ...
    'multiStartTable', multiStartTable);
fprintf('Stage 1 analytic RMSE %.5f V before Simulink replay.\n', ...
    rmse(predict(values) - Vexp));

    function [param, stageTable] = estimateSegmentedInitial(param0)
        % 分段初值估计：低电流定活化项，中电流定膜电导率修正。
        param = param0(:);
        stageTable = table('Size', [0 6], ...
            'VariableTypes', {'string','string','double','double','double','double'}, ...
            'VariableNames', {'stage','free_parameters','row_count','rmse_before','rmse_after','max_abs_after'});
        [param, stageTable] = runStage(param, stageTable, "low_current_activation", [1 2 3 4], j <= 0.4);
        [param, stageTable] = runStage(param, stageTable, "mid_current_ohmic", 5, j > 0.4 & j <= 1.1);
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
    'etaOhm_V','etaCon_V','C_O2_mol_m3','lambda_m','max_gas_residual'});
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
fit = table('Size', [n 18], 'VariableTypes', repmat("double", 1, 18), ...
    'VariableNames', {'case_index','current_A','egr_fraction_raw','egr_fraction_used','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','T_stack_C','E_Nernst_V','etaAct_V','etaOhm_V','etaCon_V', ...
    'C_O2_mol_m3','lambda_m','max_gas_residual'});
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
% 关键索引：2=V_cell，20=xO2In，21=RHIn，31=maxGasRes，36~39=电压损失项，
% 40=lambdaO2，43=C_O2_mol_m3。43 号位沿用原 i0Scale 诊断位，避免改变 summary 向量长度。
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
end
if ismember('T_stack_C', fit.Properties.VariableNames)
    fit.T_stack_C(k) = s(9);
end
if ismember('lambda_m', fit.Properties.VariableNames)
    fit.lambda_m(k) = s(8);
end
fit.C_O2_mol_m3(k) = s(43);
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
% 把物理参数映射到优化变量。当前五参数全部使用线性有界空间，保留 log10 分支用于后续扩展。
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
% 把优化变量映射回物理参数。当前五参数全部使用线性有界空间，保留 log10 分支用于后续扩展。
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
    T = [T; table("tau_mem_s", 18, P.tau_mem_s, ...
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
metrics = buildMetricsTable(fitNoEgr, fitEgr, stackFit.egrDeltaWeight);

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

function T = buildMetricsTable(noEgrFit, egrFit, egrDeltaWeight)
% 汇总 no-EGR 拟合和 EGR 验证的总体误差，以及 EGR 误差与输入诊断的相关性。
names = ["noEGR_fit"; "EGR_validation"];
egrWeight = repmat(egrDeltaWeight, 2, 1);
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
T = table(names, rows, egrWeight, rmseV, maxAbsV, meanErrV, corrErrEgr, corrErrXO2, ...
    stackOutTRmse, stackOutTMax, stackInRHRmse, stackInRHMax, stackOutPRmse, ...
    cathodeDpRmse, egrReturnTRmse, egrReturnRHRmse, egrReturnPRmse, ...
    corrVErrStackOutT, corrVErrEgrReturnRH, ...
    'VariableNames', {'dataset','rows','egr_delta_weight','rmse_V','max_abs_err_V','mean_err_V', ...
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
        case "theta1_act"
            unit(k) = "V";
            modelLocation(k) = "StackModelParam_simplified(12)";
            meaning(k) = "活化极化经验式常数项，参与 etaAct 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "书籍活化极化 theta1；ASR0 当前不启用，避免与活化常数项耦合";
        case "theta2_act"
            unit(k) = "V/K";
            modelLocation(k) = "StackModelParam_simplified(13)";
            meaning(k) = "活化极化经验式温度项系数，参与 etaAct 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "书籍活化极化 theta2；温度和电流相关性较强，需检查边界";
        case "theta3_act"
            unit(k) = "V/K";
            modelLocation(k) = "StackModelParam_simplified(14)";
            meaning(k) = "活化极化经验式氧浓度项系数，参与 etaAct 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "书籍活化极化 theta3；约束为负值以保留低氧浓度增大活化损失的方向";
        case "theta4_act"
            unit(k) = "V/K";
            modelLocation(k) = "StackModelParam_simplified(15)";
            meaning(k) = "活化极化经验式电流项系数，参与 etaAct 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "书籍活化极化 theta4；电流输入使用 j+I_leak，单位 A/cm2";
        case "sigma_pem_correction"
            unit(k) = "-";
            modelLocation(k) = "StackModelParam_simplified(16)";
            meaning(k) = "膜电导率 sigma_PEM 修正系数，参与 etaOhm 计算";
            calibrationRole(k) = "noEGR voltage fit";
            sourceNote(k) = "欧姆极化可拟合参数；sigma_PEM 的 lambda 来自电堆内部膜水含量";
        case "tau_mem_s"
            unit(k) = "s";
            modelLocation(k) = "StackModelParam_simplified(18)";
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

function plotCalibration(noEgrFit, egrFit, rootDir)
% 生成交互式标定图：电压、温度和压力的实验/仿真对比。
% 这里只打开 MATLAB figure，不保存图片文件。
figure('Name', 'Simplified bench calibration', 'NumberTitle', 'off');
tiledlayout(2, 3, 'TileSpacing', 'compact');

nexttile;
drawPairSpans(noEgrFit.current_A, noEgrFit.V_exp, noEgrFit.V_sim);
scatter(noEgrFit.current_A, noEgrFit.V_exp, 42, 'o', ...
    'MarkerEdgeColor', [0 0 0], 'MarkerFaceColor', [0.92 0.92 0.92], ...
    'LineWidth', 1.1); hold on;
scatter(noEgrFit.current_A, noEgrFit.V_sim, 48, 's', ...
    'MarkerEdgeColor', [0.00 0.27 0.75], 'MarkerFaceColor', 'none', ...
    'LineWidth', 1.2);
grid on; xlabel('Current A'); ylabel('Cell voltage V'); title('No-EGR polarization');
legend('Experiment', 'Simulation', 'Location', 'best');

nexttile;
drawPairSpans(egrFit.egr_fraction_used, egrFit.V_exp, egrFit.V_sim);
scatter(egrFit.egr_fraction_used, egrFit.V_exp, 58, 'o', ...
    'MarkerEdgeColor', [0.10 0.10 0.10], 'MarkerFaceColor', [1.00 0.82 0.00], ...
    'LineWidth', 1.1); hold on;
scatter(egrFit.egr_fraction_used, egrFit.V_sim, 64, '^', ...
    'MarkerEdgeColor', [0.35 0.00 0.70], 'MarkerFaceColor', 'none', ...
    'LineWidth', 1.4);
grid on; xlabel('EGR fraction'); ylabel('Cell voltage V'); title('EGR voltage');
legend('Experiment', 'Simulation', 'Location', 'best');

nexttile;
temperatureFit = readTemperatureFit(rootDir);
drawPairSpans(temperatureFit.current_A, temperatureFit.stack_T_target_C, temperatureFit.stack_T_sim_C);
scatter(temperatureFit.current_A, temperatureFit.stack_T_target_C, 48, 'o', ...
    'MarkerEdgeColor', [0.10 0.10 0.10], 'MarkerFaceColor', [0.55 0.80 0.55], ...
    'LineWidth', 1.1); hold on;
scatter(temperatureFit.current_A, temperatureFit.stack_T_sim_C, 52, '^', ...
    'MarkerEdgeColor', [0.00 0.37 0.45], 'MarkerFaceColor', 'none', ...
    'LineWidth', 1.3);
grid on; xlabel('Current A'); ylabel('Stack temperature C'); title('Stack mean temperature');
legend('Experiment target', 'Simulation', 'Location', 'best');

nexttile;
drawPairSpans(temperatureFit.current_A, temperatureFit.stack_out_T_exp_C, temperatureFit.stack_out_T_sim_C);
scatter(temperatureFit.current_A, temperatureFit.stack_out_T_exp_C, 48, 'o', ...
    'MarkerEdgeColor', [0.10 0.10 0.10], 'MarkerFaceColor', [0.90 0.72 0.42], ...
    'LineWidth', 1.1); hold on;
scatter(temperatureFit.current_A, temperatureFit.stack_out_T_sim_C, 52, '^', ...
    'MarkerEdgeColor', [0.58 0.25 0.00], 'MarkerFaceColor', 'none', ...
    'LineWidth', 1.3);
grid on; xlabel('Current A'); ylabel('Outlet temperature C'); title('Stack outlet temperature');
legend('Experiment', 'Simulation', 'Location', 'best');

pressureFit = readPressureFit(rootDir);
nexttile;
drawPairSpans(pressureFit.current_A, pressureFit.pCa_target_abs_kPa, pressureFit.pCa_model_abs_kPa);
scatter(pressureFit.current_A, pressureFit.pCa_target_abs_kPa, 44, 'o', ...
    'MarkerEdgeColor', [0.10 0.10 0.10], 'MarkerFaceColor', [0.82 0.90 1.00], ...
    'LineWidth', 1.1); hold on;
scatter(pressureFit.current_A, pressureFit.pCa_model_abs_kPa, 50, 's', ...
    'MarkerEdgeColor', [0.00 0.27 0.75], 'MarkerFaceColor', 'none', ...
    'LineWidth', 1.2);
grid on; xlabel('Current A'); ylabel('Pressure kPa abs'); title('Cathode channel pressure');
legend('Experiment avg', 'Simulation', 'Location', 'best');

nexttile;
drawPairSpans(pressureFit.current_A, pressureFit.pAn_target_abs_kPa, pressureFit.pAn_model_abs_kPa);
scatter(pressureFit.current_A, pressureFit.pAn_target_abs_kPa, 44, 'o', ...
    'MarkerEdgeColor', [0.10 0.10 0.10], 'MarkerFaceColor', [0.94 0.82 0.94], ...
    'LineWidth', 1.1); hold on;
scatter(pressureFit.current_A, pressureFit.pAn_model_abs_kPa, 50, 's', ...
    'MarkerEdgeColor', [0.48 0.00 0.55], 'MarkerFaceColor', 'none', ...
    'LineWidth', 1.2);
grid on; xlabel('Current A'); ylabel('Pressure kPa abs'); title('Anode channel pressure');
legend('Experiment avg', 'Simulation', 'Location', 'best');
end

function drawPairSpans(x, yExp, ySim)
% 用细红虚线连接同一工况的实验值和仿真值，突出误差大小。
hold on;
for k = 1:numel(x)
    if isfinite(x(k)) && isfinite(yExp(k)) && isfinite(ySim(k))
        plot([x(k), x(k)], [yExp(k), ySim(k)], 'r--', ...
            'LineWidth', 0.65, 'HandleVisibility', 'off');
    end
end
end

function temperatureFit = readTemperatureFit(rootDir)
% 读取已完成的温度标定结果，用于主标定图展示。
temperatureFile = fullfile(rootDir, '04_验证结果', 'temperature_fit_v01', ...
    'temperature_fit_fitted.csv');
if ~isfile(temperatureFile)
    error('CEGR:SimplifiedCalibration:MissingTemperatureFit', ...
        'Temperature fit file not found: %s', temperatureFile);
end
temperatureFit = readtable(temperatureFile);
end

function pressureFit = readPressureFit(rootDir)
% 读取已完成的压力标定结果，用于主标定图展示。
pressureFile = fullfile(rootDir, '04_验证结果', 'pressure_fit_v01', ...
    'pressure_fit_final.csv');
if ~isfile(pressureFile)
    error('CEGR:SimplifiedCalibration:MissingPressureFit', ...
        'Pressure fit file not found: %s', pressureFile);
end
pressureFit = readtable(pressureFile);
end
