function results = run_testbench_10kw_simplified_custom_inlet_study(stopTime_s)
%RUN_TESTBENCH_10KW_SIMPLIFIED_CUSTOM_INLET_STUDY
% 自定义进气阶段：固定环境空气组分、固定各电流点总入堆流量、扫描 EGR 比例。
%
% 研究口径：
% 1. 只使用 initial_noegr_steady_xlsx 的 13 个主 no-EGR 点做电流锚点。
% 2. 新鲜空气统一按 25 C / 1 atm(abs) / 50% RH 计算组分。
% 3. 各电流点先解析历史 no-EGR 边界对应的 lambdaO2_initial，再反算新环境下的 no-EGR 总流量。
% 4. 开 EGR 后总入堆质量流量保持为该点反算值，入堆温度/压力保持台架点不变。
% 5. 分离器出口压力使用该点 stack_out_p_kPa，分离器出口温度按 stack_out_T 迭代。

if nargin < 1 || isempty(stopTime_s)
    stopTime_s = 120;
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
resultDir = fullfile(rootDir, '04_验证结果', 'custom_inlet_study_v01');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

caseDefFile = fullfile(resultDir, 'custom_inlet_case_definition.csv');
scanFile = fullfile(resultDir, 'custom_inlet_egr_scan.csv');
summaryFile = fullfile(resultDir, 'custom_inlet_summary.md');

ambient = struct();
ambient.p_kPa_g = 0.0;
ambient.T_C = 25.0;
ambient.RH = 0.50;

P0 = init_testbench_10kw_simplified_egr(1, 'initial_noegr', false);
[ambient.wO2, ambient.wN2, ambient.wH2O] = humidAirMassFractionsLocal( ...
    P0, ambient.p_kPa_g + P0.p_amb_kPa, ambient.T_C, ambient.RH);

initialCases = P0.allCaseTable(string(P0.allCaseTable.source_dataset) == "initial_noegr_steady_xlsx", :);
initialCases = sortrows(initialCases, 'current_density_A_cm2');
model = P0.modelName;
load_system(model);

caseRows = cell(height(initialCases), 1);
scanRows = {};

for k = 1:height(initialCases)
    Pbase = init_testbench_10kw_simplified_egr(k, 'initial_noegr', false);
    lambdaInitial = boundaryLambdaO2(Pbase, Pbase.stack_in_flow_kg_s, Pbase.cathode_supply_wO2);
    recomputedFlowKgS = recomputeNoEgrFlow(Pbase, lambdaInitial, ambient.wO2);
    recomputedFlowSLPM = kgSToSlpmAirLocal(recomputedFlowKgS);
    band = egrBandName(Pbase.current_density_A_cm2);
    egrGrid = egrGridForBand(band);

    caseRows{k} = table( ...
        string(Pbase.case_id), Pbase.caseIndex, Pbase.I_stack_default_A, Pbase.current_density_A_cm2, ...
        string(band), lambdaInitial, ...
        Pbase.stack_in_flow_kg_s, Pbase.stack_in_flow_SLPM, ...
        recomputedFlowKgS, recomputedFlowSLPM, ...
        Pbase.cathode_supply_wO2, Pbase.cathode_supply_wN2, Pbase.cathode_supply_wH2O, ...
        ambient.p_kPa_g, ambient.T_C, ambient.RH, ambient.wO2, ambient.wN2, ambient.wH2O, ...
        'VariableNames', { ...
        'case_id', 'boundary_case_index', 'current_A', 'current_density_A_cm2', ...
        'egr_band', 'lambdaO2_initial', ...
        'historical_stack_in_flow_kg_s', 'historical_stack_in_flow_SLPM', ...
        'stack_in_flow_recomputed_kg_s', 'stack_in_flow_recomputed_SLPM', ...
        'historical_supply_wO2', 'historical_supply_wN2', 'historical_supply_wH2O', ...
        'ambient_supply_p_kPa_g', 'ambient_supply_T_C', 'ambient_supply_RH', ...
        'ambient_supply_wO2', 'ambient_supply_wN2', 'ambient_supply_wH2O'});

    for egr = egrGrid
        row = runOneScanPoint(Pbase, ambient, lambdaInitial, recomputedFlowKgS, ...
            recomputedFlowSLPM, band, egr, stopTime_s, model);
        scanRows{end + 1, 1} = struct2table(row); %#ok<AGROW>
    end
end

caseDefinition = vertcat(caseRows{:});
scanTable = vertcat(scanRows{:});
scanTable = sortrows(scanTable, {'current_density_command_A_cm2', 'egr_fraction_cmd'});

writetable(caseDefinition, caseDefFile);
writetable(scanTable, scanFile);
writeSummary(summaryFile, caseDefinition, scanTable, ambient, stopTime_s);

results = struct();
results.case_definition = caseDefinition;
results.scan = scanTable;
results.case_definition_file = caseDefFile;
results.scan_file = scanFile;
results.summary_file = summaryFile;

fprintf('Custom inlet study complete: %s\n', summaryFile);
end

function row = runOneScanPoint(Pbase, ambient, lambdaInitial, flowKgS, flowSLPM, band, egr, stopTime_s, model)
row = blankScanRow();
row.study_type = "custom_inlet_fixed_total_flow";
row.condition = "ambient50RH_fixed_total_flow";
row.case_id = string(Pbase.case_id);
row.boundary_case_index = Pbase.caseIndex;
row.current_A = Pbase.I_stack_default_A;
row.current_density_command_A_cm2 = Pbase.current_density_A_cm2;
row.egr_band = string(band);
row.egr_fraction_cmd = egr;
row.ambient_supply_p_kPa_g = ambient.p_kPa_g;
row.ambient_supply_T_C = ambient.T_C;
row.ambient_supply_RH = ambient.RH;
row.ambient_supply_wO2 = ambient.wO2;
row.ambient_supply_wN2 = ambient.wN2;
row.ambient_supply_wH2O = ambient.wH2O;
row.lambdaO2_initial = lambdaInitial;
row.historical_stack_in_flow_kg_s = Pbase.stack_in_flow_kg_s;
row.historical_stack_in_flow_SLPM = Pbase.stack_in_flow_SLPM;
row.stack_in_flow_recomputed_kg_s = flowKgS;
row.stack_in_flow_recomputed_SLPM = flowSLPM;
row.separator_p_kPa_g = Pbase.stack_out_p_kPa;
row.separator_T_initial_C = Pbase.stack_out_T_C;

overrideBase = struct( ...
    'bench_supply_gas_p_kPa', ambient.p_kPa_g, ...
    'bench_supply_gas_T_C', ambient.T_C, ...
    'bench_supply_gas_RH', ambient.RH, ...
    'stack_in_flow_kg_s', flowKgS, ...
    'stack_in_flow_SLPM', flowSLPM, ...
    'egr_fraction_cmd', egr, ...
    'separator_p_kPa', Pbase.stack_out_p_kPa);

separatorT = Pbase.stack_out_T_C;
lastP = [];
lastS = [];
stackOutTSim = NaN;
iterCount = 0;
converged = false;

try
    for iter = 1:3
        iterCount = iter;
        override = overrideBase;
        override.separator_T_C = separatorT;
        P = init_testbench_10kw_simplified_egr(Pbase.caseIndex, 'initial_noegr', false, override);
        out = simulateCase(P, stopTime_s, model);
        s = lastSummary(out);
        stackOutTSim = 2 * s(9) - P.bench_stack_in_T_C;
        lastP = P;
        lastS = s;
        if abs(stackOutTSim - separatorT) < 0.5
            converged = true;
            break;
        end
        separatorT = stackOutTSim;
    end

    row.status = "ok";
    row.separator_iter_count = iterCount;
    row.separator_iter_converged = converged;
    row.separator_T_final_C = lastP.separator_T_C;
    row.separator_T_sim_C = stackOutTSim;
    row.lambdaO2_target_error = lastS(40) - lambdaInitial;
    row.V_cell_sim = lastS(2);
    row.pO2_stack_kPa = lastS(4);
    row.p_stack_internal_kPa_abs = lastS(5);
    row.pH2_stack_kPa = lastS(6);
    row.pAn_stack_kPa_abs = lastS(7);
    row.lambda_m = lastS(8);
    row.T_stack_C = lastS(9);
    row.xO2_ca_in = lastS(20);
    row.pO2_ca_in_kPa = lastS(19);
    row.RH_ca_in = lastS(21);
    row.lambda_O2_actual = lastS(40);
    row.stack_out_T_sim_C = stackOutTSim;
    row.maxGasRes_kg_s = lastS(31);
    row.Qnet_W = lastS(22);
    row.Qgen_W = lastS(32);
    row.Qcool_W = lastS(33);
    row.Qamb_W = lastS(34);
    row.Qgas_W = lastS(35);
    row.gas_residual_ok = row.maxGasRes_kg_s <= 1e-8;
    row.m_stack_in_kg_s = lastS(69);
    row.m_egr_return_kg_s = lastS(70);
    row.m_bench_out_kg_s = lastS(71);
    row.liquid_drain_separator_kg_s = lastS(79);
    row.condensed_separator_kg_s = lastS(80);
    row.separator_out_RH = lastS(82);
    row.m_separator_gas_kg_s = lastS(85);
    row.flow_fixed_ok = abs(lastS(69) - flowKgS) <= max(1e-10, 1e-6 * flowKgS);
    row.humidity_ok = row.RH_ca_in >= 0 && row.RH_ca_in <= 1.05;
    row.oxygen_starvation_risk = row.lambda_O2_actual < 1.2;
    row.oxygen_ok = ~row.oxygen_starvation_risk && row.xO2_ca_in > 0;
    row.pressure_order_ok = row.p_stack_internal_kPa_abs >= lastP.p_cathode_back_kPa - 1e-9;
    row.separator_ok = converged || egr == 0;
    row.normal_operation_ok = row.flow_fixed_ok && row.humidity_ok && row.oxygen_ok && ...
        row.pressure_order_ok && row.separator_ok && row.gas_residual_ok;
    row.risk_label = buildRiskLabel(row);
catch ME
    row.status = "error";
    row.error_message = string(ME.identifier + ": " + ME.message);
    row.separator_iter_count = iterCount;
    row.separator_iter_converged = false;
    row.separator_T_final_C = separatorT;
end
end

function row = blankScanRow()
row = struct( ...
    'study_type', "", ...
    'condition', "", ...
    'case_id', "", ...
    'status', "pending", ...
    'error_message', "", ...
    'boundary_case_index', NaN, ...
    'current_A', NaN, ...
    'current_density_command_A_cm2', NaN, ...
    'egr_band', "", ...
    'egr_fraction_cmd', NaN, ...
    'ambient_supply_p_kPa_g', NaN, ...
    'ambient_supply_T_C', NaN, ...
    'ambient_supply_RH', NaN, ...
    'ambient_supply_wO2', NaN, ...
    'ambient_supply_wN2', NaN, ...
    'ambient_supply_wH2O', NaN, ...
    'historical_stack_in_flow_kg_s', NaN, ...
    'historical_stack_in_flow_SLPM', NaN, ...
    'stack_in_flow_recomputed_kg_s', NaN, ...
    'stack_in_flow_recomputed_SLPM', NaN, ...
    'lambdaO2_initial', NaN, ...
    'lambdaO2_target_error', NaN, ...
    'separator_iter_count', NaN, ...
    'separator_iter_converged', false, ...
    'separator_T_initial_C', NaN, ...
    'separator_T_final_C', NaN, ...
    'separator_T_sim_C', NaN, ...
    'separator_p_kPa_g', NaN, ...
    'V_cell_sim', NaN, ...
    'pO2_stack_kPa', NaN, ...
    'p_stack_internal_kPa_abs', NaN, ...
    'pH2_stack_kPa', NaN, ...
    'pAn_stack_kPa_abs', NaN, ...
    'lambda_m', NaN, ...
    'T_stack_C', NaN, ...
    'stack_out_T_sim_C', NaN, ...
    'xO2_ca_in', NaN, ...
    'pO2_ca_in_kPa', NaN, ...
    'RH_ca_in', NaN, ...
    'lambda_O2_actual', NaN, ...
    'm_stack_in_kg_s', NaN, ...
    'm_egr_return_kg_s', NaN, ...
    'm_bench_out_kg_s', NaN, ...
    'liquid_drain_separator_kg_s', NaN, ...
    'condensed_separator_kg_s', NaN, ...
    'separator_out_RH', NaN, ...
    'm_separator_gas_kg_s', NaN, ...
    'maxGasRes_kg_s', NaN, ...
    'Qnet_W', NaN, ...
    'Qgen_W', NaN, ...
    'Qcool_W', NaN, ...
    'Qamb_W', NaN, ...
    'Qgas_W', NaN, ...
    'gas_residual_ok', false, ...
    'flow_fixed_ok', false, ...
    'humidity_ok', false, ...
    'oxygen_starvation_risk', false, ...
    'oxygen_ok', false, ...
    'pressure_order_ok', false, ...
    'separator_ok', false, ...
    'normal_operation_ok', false, ...
    'risk_label', "");
end

function label = buildRiskLabel(row)
if row.status ~= "ok"
    label = "simulation_error";
elseif ~row.gas_residual_ok
    label = "gas_residual_high";
elseif ~row.oxygen_ok
    label = "oxygen_limit";
elseif ~row.humidity_ok
    label = "humidity_limit";
elseif ~row.pressure_order_ok
    label = "pressure_order_fail";
elseif ~row.separator_ok
    label = "separator_not_converged";
elseif ~row.flow_fixed_ok
    label = "flow_not_fixed";
else
    label = "ok";
end
end

function value = boundaryLambdaO2(P, totalFlowKgS, wO2)
nO2In = totalFlowKgS * wO2 / P.M_O2_kg_mol;
nO2React = P.I_stack_default_A * P.N_cell / (4 * P.F_C_mol);
value = nO2In / max(nO2React, eps);
end

function flowKgS = recomputeNoEgrFlow(P, lambdaTarget, ambientWO2)
nO2React = P.I_stack_default_A * P.N_cell / (4 * P.F_C_mol);
nO2In = lambdaTarget * nO2React;
flowKgS = nO2In * P.M_O2_kg_mol / ambientWO2;
end

function band = egrBandName(j)
if j < 0.4
    band = "low";
elseif j <= 1.1
    band = "mid";
else
    band = "high";
end
end

function grid = egrGridForBand(band)
switch string(band)
    case "low"
        grid = 0:0.05:0.70;
    case "mid"
        grid = 0:0.05:0.40;
    case "high"
        grid = 0:0.05:0.30;
    otherwise
        error('CEGR:SimplifiedBench:BadBand', 'Unknown EGR band "%s".', string(band));
end
grid = round(grid, 4);
end

function out = simulateCase(P, stopTime_s, model)
in = Simulink.SimulationInput(model);
in = in.setModelParameter('StopTime', num2str(stopTime_s), ...
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

function s = lastSummary(out)
v = out.summary_vector.signals.values;
s = squeeze(v(:, 1, end));
end

function [wO2, wN2, wH2O] = humidAirMassFractionsLocal(P, pAbsKPa, T_C, RH)
pH2O = min(RH * satKPaLocal(T_C), 0.98 * pAbsKPa);
yH2O = min(max(pH2O / max(pAbsKPa, 1e-6), 0), 0.98);
yO2 = (1 - yH2O) * P.xO2_dry;
yN2 = (1 - yH2O) * P.xN2_dry;
mO2 = yO2 * P.M_O2_kg_mol;
mN2 = yN2 * P.M_N2_kg_mol;
mH2O = yH2O * P.M_H2O_kg_mol;
s = max(mO2 + mN2 + mH2O, 1e-12);
wO2 = mO2 / s;
wN2 = mN2 / s;
wH2O = mH2O / s;
end

function p = satKPaLocal(T)
Tc = min(max(T, -40), 120);
p = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end

function slpm = kgSToSlpmAirLocal(m)
slpm = m * 60000 / 1.293;
end

function writeSummary(path, caseDefinition, scanTable, ambient, stopTime_s)
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));

ok = scanTable(scanTable.status == "ok", :);
normal = ok(ok.normal_operation_ok, :);
egr0 = ok(abs(ok.egr_fraction_cmd) < 1e-12, :);
lambdaTol = max(0.02 * ones(height(egr0), 1), 0.01 * egr0.lambdaO2_initial);
lambdaAnchorPass = abs(egr0.lambda_O2_actual - egr0.lambdaO2_initial) <= lambdaTol;
nonConv = ok(~ok.separator_iter_converged & ok.egr_fraction_cmd > 0, :);
highGasResidual = ok(~ok.gas_residual_ok, :);
oxygenRisk = ok(ok.oxygen_starvation_risk, :);
monotonic = monotonicXO2Check(ok);

fprintf(fid, '# 自定义进气阶段结果摘要\n\n');
fprintf(fid, '- Stop time: %.3g s\n', stopTime_s);
fprintf(fid, '- 新鲜空气边界: %.2f kPa(g), %.2f C, RH %.2f\n', ...
    ambient.p_kPa_g, ambient.T_C, ambient.RH);
fprintf(fid, '- 新鲜空气质量分数: wO2=%.6f, wN2=%.6f, wH2O=%.6f\n', ...
    ambient.wO2, ambient.wN2, ambient.wH2O);
fprintf(fid, '- 锚点数量: %d\n', height(caseDefinition));
fprintf(fid, '- 扫描点总数: %d\n', height(scanTable));
fprintf(fid, '- 成功仿真点数: %d\n', height(ok));
fprintf(fid, '- 正常工况点数: %d\n', height(normal));
fprintf(fid, '- 仿真失败点数: %d\n\n', height(scanTable) - height(ok));

fprintf(fid, '## 边界与数值检查\n\n');
fprintf(fid, '- no-EGR 反算流量回放满足 lambdaO2 目标的锚点: %d / %d\n', ...
    nnz(lambdaAnchorPass), height(egr0));
fprintf(fid, '- xO2 随 EGR 增大单调下降的电流锚点: %d / %d\n', ...
    monotonic.pass_count, monotonic.total_count);
fprintf(fid, '- 分离器温度迭代未收敛点数: %d\n', height(nonConv));
fprintf(fid, '- 高气体守恒残差点数 (`maxGasRes > 1e-8 kg/s`): %d\n', height(highGasResidual));
fprintf(fid, '- 缺气风险点数 (`lambda_O2_actual < 1.2`): %d\n', height(oxygenRisk));
if ~isempty(ok)
    fprintf(fid, '- 成功点最大气体守恒残差: %.6g kg/s\n', max(ok.maxGasRes_kg_s));
    fprintf(fid, '- 成功点最大 separator 排水: %.6g kg/s\n', max(ok.liquid_drain_separator_kg_s));
    fprintf(fid, '- 成功点最小入口氧计量比: %.6f\n\n', min(ok.lambda_O2_actual));
end

fprintf(fid, '## 分负载段汇总（正常工况点）\n\n');
fprintf(fid, '缺气风险或气体守恒残差异常点不参与本表端点均值，避免把风险区电压混入趋势判断。\n\n');
fprintf(fid, '| band | normal rows | mean max normal EGR | mean RH@EGR0 | mean RH@max normal EGR | mean dRH | mean V@EGR0 (V) | mean V@max normal EGR (V) | mean dV (mV) | min normal lambdaO2 |\n');
fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for band = ["low", "mid", "high"]
    Tband = normal(normal.egr_band == band, :);
    if isempty(Tband)
        continue;
    end
    [base, top] = bandEndpoints(Tband);
    fprintf(fid, '| %s | %d | %.3f | %.4f | %.4f | %.4f | %.5f | %.5f | %.2f | %.4f |\n', ...
        band, height(Tband), mean(top.egr_fraction_cmd), mean(base.RH_ca_in), mean(top.RH_ca_in), ...
        mean(top.RH_ca_in - base.RH_ca_in), mean(base.V_cell_sim), mean(top.V_cell_sim), ...
        1000 * mean(top.V_cell_sim - base.V_cell_sim), min(Tband.lambda_O2_actual));
end
fprintf(fid, '\n');

if height(nonConv) > 0
    fprintf(fid, '## 分离器温度未收敛点\n\n');
    for k = 1:height(nonConv)
        fprintf(fid, '- `%s`, EGR=%.2f, j=%.1f, iter=%g, T_sep_final=%.3f C, T_out_sim=%.3f C\n', ...
            char(nonConv.case_id(k)), nonConv.egr_fraction_cmd(k), nonConv.current_density_command_A_cm2(k), ...
            nonConv.separator_iter_count(k), nonConv.separator_T_final_C(k), nonConv.separator_T_sim_C(k));
    end
    fprintf(fid, '\n');
end

if height(highGasResidual) > 0
    fprintf(fid, '## 高气体守恒残差点\n\n');
    for k = 1:height(highGasResidual)
        fprintf(fid, '- `%s`, EGR=%.2f, j=%.1f, maxGasRes=%.6g kg/s, lambdaO2=%.4f, RH_in=%.4f, V=%.5f V\n', ...
            char(highGasResidual.case_id(k)), highGasResidual.egr_fraction_cmd(k), ...
            highGasResidual.current_density_command_A_cm2(k), highGasResidual.maxGasRes_kg_s(k), ...
            highGasResidual.lambda_O2_actual(k), highGasResidual.RH_ca_in(k), ...
            highGasResidual.V_cell_sim(k));
    end
    fprintf(fid, '\n');
end

if height(oxygenRisk) > 0
    fprintf(fid, '## 缺气风险点\n\n');
    for k = 1:height(oxygenRisk)
        fprintf(fid, '- `%s`, EGR=%.2f, j=%.1f, lambdaO2=%.4f, RH_in=%.4f, V=%.5f V\n', ...
            char(oxygenRisk.case_id(k)), oxygenRisk.egr_fraction_cmd(k), ...
            oxygenRisk.current_density_command_A_cm2(k), oxygenRisk.lambda_O2_actual(k), ...
            oxygenRisk.RH_ca_in(k), oxygenRisk.V_cell_sim(k));
    end
    fprintf(fid, '\n');
end

badCases = scanTable(scanTable.status ~= "ok", :);
if ~isempty(badCases)
    fprintf(fid, '## 仿真失败点\n\n');
    for k = 1:height(badCases)
        fprintf(fid, '- `%s`, EGR=%.2f: %s\n', char(badCases.case_id(k)), ...
            badCases.egr_fraction_cmd(k), char(badCases.error_message(k)));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '## 结论口径\n\n');
fprintf(fid, '- 本结果只用于趋势判断，不代表已经被 EGR 专项实验完全验证的定量结论。\n');
fprintf(fid, '- 若某些高负载点很早进入低氧区，应优先按边界与守恒解释，不回头用电压参数补偿。\n');
end

function [base, top] = bandEndpoints(T)
cases = unique(T.case_id, 'stable');
rowsBase = cell(numel(cases), 1);
rowsTop = cell(numel(cases), 1);
for i = 1:numel(cases)
    Ti = T(T.case_id == cases(i), :);
    Ti = sortrows(Ti, 'egr_fraction_cmd');
    rowsBase{i} = Ti(1, :);
    rowsTop{i} = Ti(end, :);
end
base = vertcat(rowsBase{:});
top = vertcat(rowsTop{:});
end

function out = monotonicXO2Check(T)
cases = unique(T.case_id, 'stable');
pass = true(numel(cases), 1);
for i = 1:numel(cases)
    Ti = T(T.case_id == cases(i), :);
    Ti = sortrows(Ti, 'egr_fraction_cmd');
    dx = diff(Ti.xO2_ca_in);
    pass(i) = all(dx <= 1e-9);
end
out = struct('pass_count', nnz(pass), 'total_count', numel(cases));
end
