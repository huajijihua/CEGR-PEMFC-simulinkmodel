function results = run_testbench_10kw_simplified_constant_voltage_38A_cegr_study(stopTime_s)
%RUN_TESTBENCH_10KW_SIMPLIFIED_CONSTANT_VOLTAGE_38A_CEGR_STUDY
% 低负载恒电压研究：以 initial_noegr_01 的 38 A 台架边界为基准，
% 固定总入堆流量、温度、压力、冷却和阳极边界，只扫描 CEGR 比例，
% 并求解维持 V_cell = 0.800 V/cell 所需的电堆电流。

if nargin < 1 || isempty(stopTime_s)
    stopTime_s = 120;
end

targetVCell = 0.800;
baseCurrentA = 38.0;
strictVoltageTolV = 1e-4;
acceptVoltageTolV = 5e-4;
gasResidualTolKgS = 1e-8;
flowRelTol = 1e-6;
oxygenLambdaMin = 1.2;
maxIter = 32;
currentTolA = 0.01;
currentMinA = 1.0;
currentMaxA = 60.0;
egrGrid = round(0:0.05:0.70, 4);

rootDir = fileparts(fileparts(mfilename('fullpath')));
resultDir = fullfile(rootDir, '04_验证结果', 'constant_voltage_38A_cegr_v01');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

scanFile = fullfile(resultDir, 'constant_voltage_38A_cegr_scan.csv');
scanCnFile = fullfile(resultDir, 'constant_voltage_38A_cegr_scan_cn.csv');
scanDictionaryFile = fullfile(resultDir, 'constant_voltage_38A_cegr_scan_column_dictionary.csv');
summaryFile = fullfile(resultDir, 'constant_voltage_38A_cegr_summary.md');

Pbase = init_testbench_10kw_simplified_egr(1, 'initial_noegr', false);
validateBaseCase(Pbase, baseCurrentA);

model = Pbase.modelName;
load_system(model);

basePowerW = targetVCell * baseCurrentA * Pbase.N_cell;
baseH2MolS = baseCurrentA * Pbase.N_cell / (2 * Pbase.F_C_mol);

scanRows = cell(numel(egrGrid), 1);
for k = 1:numel(egrGrid)
    egr = egrGrid(k);
    row = solveOneEgrPoint(Pbase, egr, targetVCell, stopTime_s, model, ...
        currentMinA, currentMaxA, strictVoltageTolV, acceptVoltageTolV, ...
        currentTolA, maxIter, gasResidualTolKgS, flowRelTol, oxygenLambdaMin, ...
        baseCurrentA, basePowerW, baseH2MolS);
    scanRows{k} = struct2table(row);
end

scanTable = vertcat(scanRows{:});
scanTable = sortrows(scanTable, 'egr_fraction_cmd');
scanTable.xO2_monotonic_ok = monotonicNonincreasing(scanTable.xO2_ca_in);

writetable(scanTable, scanFile);
writeChineseScanTable(scanCnFile, scanTable);
writeScanDictionary(scanDictionaryFile);
writeSummary(summaryFile, scanTable, Pbase, targetVCell, stopTime_s, ...
    strictVoltageTolV, acceptVoltageTolV, gasResidualTolKgS, oxygenLambdaMin, ...
    basePowerW, baseH2MolS);

results = struct();
results.scan = scanTable;
results.scan_file = scanFile;
results.scan_cn_file = scanCnFile;
results.scan_dictionary_file = scanDictionaryFile;
results.summary_file = summaryFile;

fprintf('Constant-voltage 38A CEGR study complete: %s\n', summaryFile);
end

function validateBaseCase(P, baseCurrentA)
if string(P.case_id) ~= "initial_noegr_01"
    error('CEGR:SimplifiedBench:UnexpectedBaseCase', ...
        'Expected initial_noegr_01, got %s.', string(P.case_id));
end
if abs(P.I_stack_default_A - baseCurrentA) > 1e-9
    error('CEGR:SimplifiedBench:UnexpectedBaseCurrent', ...
        'Expected %.6g A base current, got %.12g A.', baseCurrentA, P.I_stack_default_A);
end
if abs(P.cell_voltage_bench_V - 0.80165625) > 5e-7
    error('CEGR:SimplifiedBench:UnexpectedBaseVoltage', ...
        'Expected base measured voltage 0.80165625 V/cell, got %.12g.', ...
        P.cell_voltage_bench_V);
end
end

function row = solveOneEgrPoint(Pbase, egr, targetVCell, stopTime_s, model, ...
    currentMinA, currentMaxA, strictVoltageTolV, acceptVoltageTolV, ...
    currentTolA, maxIter, gasResidualTolKgS, flowRelTol, oxygenLambdaMin, ...
    baseCurrentA, basePowerW, baseH2MolS)

row = blankScanRow();
row.study_type = "constant_voltage_fixed_38A_boundary";
row.condition = "initial_noegr_01_fixed_flow_temperature_pressure";
row.case_id = string(Pbase.case_id);
row.boundary_case_index = Pbase.caseIndex;
row.target_V_cell = targetVCell;
row.base_current_A = baseCurrentA;
row.base_measured_V_cell = Pbase.cell_voltage_bench_V;
row.egr_fraction_cmd = egr;
row.stop_time_s = stopTime_s;
row.fixed_stack_in_flow_kg_s = Pbase.stack_in_flow_kg_s;
row.fixed_stack_in_flow_SLPM = Pbase.stack_in_flow_SLPM;
row.fixed_stack_in_p_kPa_g = Pbase.bench_stack_in_p_kPa;
row.fixed_stack_in_T_C = Pbase.bench_stack_in_T_C;
row.fixed_stack_out_p_kPa_g = Pbase.stack_out_p_kPa;
row.fixed_separator_T_C = Pbase.separator_T_C;
row.fixed_coolant_in_T_C = Pbase.T_cool_C;
row.fixed_coolant_flow_L_min = Pbase.coolant_flow_L_min;
row.fixed_anode_flow_kg_s = Pbase.anode_in_flow_kg_s;
row.fixed_anode_back_p_kPa_abs = Pbase.p_anode_back_kPa;

try
    override = fixedBoundaryOverride(Pbase, egr);
    P = init_testbench_10kw_simplified_egr(Pbase.caseIndex, 'initial_noegr', false, override);

    lo = simulateAtCurrent(P, currentMinA, stopTime_s, model);
    hi = simulateAtCurrent(P, currentMaxA, stopTime_s, model);
    row.bracket_low_current_A = currentMinA;
    row.bracket_low_V_cell = lo.V_cell_sim;
    row.bracket_high_current_A = currentMaxA;
    row.bracket_high_V_cell = hi.V_cell_sim;
    row.simulation_count = 2;

    fLo = lo.V_cell_sim - targetVCell;
    fHi = hi.V_cell_sim - targetVCell;
    if ~(isfinite(fLo) && isfinite(fHi)) || fLo * fHi > 0
        row.status = "no_bracket";
        row.error_message = sprintf('No voltage bracket: f(%.3g A)=%.6g, f(%.3g A)=%.6g.', ...
            currentMinA, fLo, currentMaxA, fHi);
        row = populateFromPoint(row, closerPoint(lo, hi, targetVCell), P, targetVCell, ...
            acceptVoltageTolV, gasResidualTolKgS, flowRelTol, oxygenLambdaMin, ...
            baseCurrentA, basePowerW, baseH2MolS);
        row.risk_label = buildRiskLabel(row);
        return;
    end

    best = closerPoint(lo, hi, targetVCell);
    loCurrent = currentMinA;
    hiCurrent = currentMaxA;
    for iter = 1:maxIter
        midCurrent = 0.5 * (loCurrent + hiCurrent);
        mid = simulateAtCurrent(P, midCurrent, stopTime_s, model);
        row.simulation_count = row.simulation_count + 1;
        best = closerPoint(best, mid, targetVCell);
        fMid = mid.V_cell_sim - targetVCell;
        if abs(fMid) <= strictVoltageTolV || abs(hiCurrent - loCurrent) <= currentTolA
            row.bisection_iter_count = iter;
            break;
        end
        if fLo * fMid <= 0
            hiCurrent = midCurrent;
            fHi = fMid; %#ok<NASGU>
        else
            loCurrent = midCurrent;
            fLo = fMid;
        end
        row.bisection_iter_count = iter;
    end

    row.status = "ok";
    row = populateFromPoint(row, best, P, targetVCell, acceptVoltageTolV, ...
        gasResidualTolKgS, flowRelTol, oxygenLambdaMin, baseCurrentA, ...
        basePowerW, baseH2MolS);
    row.risk_label = buildRiskLabel(row);
catch ME
    row.status = "error";
    row.error_message = string(ME.identifier + ": " + ME.message);
    row.risk_label = buildRiskLabel(row);
end
end

function override = fixedBoundaryOverride(Pbase, egr)
override = struct( ...
    'bench_supply_gas_p_kPa', Pbase.bench_supply_gas_p_kPa, ...
    'bench_supply_gas_T_C', Pbase.bench_supply_gas_T_C, ...
    'bench_supply_gas_RH', Pbase.bench_supply_gas_RH, ...
    'stack_in_flow_kg_s', Pbase.stack_in_flow_kg_s, ...
    'stack_in_flow_SLPM', Pbase.stack_in_flow_SLPM, ...
    'egr_fraction_cmd', egr, ...
    'separator_T_C', Pbase.separator_T_C, ...
    'separator_p_kPa', Pbase.separator_p_kPa);
end

function point = simulateAtCurrent(P, currentA, stopTime_s, model)
caseBoundary = P.CaseBoundaryParam;
caseBoundary(1) = currentA;

in = Simulink.SimulationInput(model);
in = in.setModelParameter('StopTime', num2str(stopTime_s), ...
    'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(P.dt_s));
in = in.setVariable('PhysicalParam_simplified', P.PhysicalParam);
in = in.setVariable('StackModelParam_simplified', P.StackModelParam);
in = in.setVariable('CaseBoundaryParam_simplified', caseBoundary);
in = in.setVariable('CoolingCurveParam_simplified', P.CoolingCurveParam);
in = in.setVariable('dt_s_simplified', P.dt_s_simplified);
in = in.setVariable('StackInitialState_simplified', P.stack_initial_state);
in = in.setVariable('EGRInitialNode_simplified', P.egr_initial_node);
out = sim(in);
s = lastSummary(out);

point = struct();
point.current_A = currentA;
point.V_cell_sim = s(2);
point.pO2_stack_kPa = s(4);
point.p_stack_internal_kPa_abs = s(5);
point.pH2_stack_kPa = s(6);
point.pAn_stack_kPa_abs = s(7);
point.lambda_m = s(8);
point.T_stack_C = s(9);
point.pO2_ca_in_kPa = s(19);
point.xO2_ca_in = s(20);
point.RH_ca_in = s(21);
point.Qnet_W = s(22);
point.maxGasRes_kg_s = s(31);
point.Qgen_W = s(32);
point.Qcool_W = s(33);
point.Qamb_W = s(34);
point.Qgas_W = s(35);
point.lambda_O2_actual = s(40);
point.m_stack_in_kg_s = s(69);
point.m_egr_return_kg_s = s(70);
point.m_bench_out_kg_s = s(71);
point.liquid_drain_separator_kg_s = s(79);
point.condensed_separator_kg_s = s(80);
point.separator_out_RH = s(82);
point.m_separator_gas_kg_s = s(85);
end

function s = lastSummary(out)
v = out.summary_vector.signals.values;
s = squeeze(v(:, 1, end));
end

function best = closerPoint(a, b, targetVCell)
if abs(a.V_cell_sim - targetVCell) <= abs(b.V_cell_sim - targetVCell)
    best = a;
else
    best = b;
end
end

function row = populateFromPoint(row, point, P, targetVCell, acceptVoltageTolV, ...
    gasResidualTolKgS, flowRelTol, oxygenLambdaMin, baseCurrentA, basePowerW, baseH2MolS)

row.I_solution_A = point.current_A;
row.I_reduction_A = baseCurrentA - point.current_A;
row.I_reduction_pct = 100 * row.I_reduction_A / baseCurrentA;
row.V_cell_sim = point.V_cell_sim;
row.V_error_V = point.V_cell_sim - targetVCell;
row.voltage_target_ok = abs(row.V_error_V) <= acceptVoltageTolV;
row.P_stack_W = point.V_cell_sim * point.current_A * P.N_cell;
row.P_reduction_W = basePowerW - row.P_stack_W;
row.P_reduction_pct = 100 * row.P_reduction_W / basePowerW;
row.H2_reaction_mol_s = point.current_A * P.N_cell / (2 * P.F_C_mol);
row.H2_reduction_mol_s = baseH2MolS - row.H2_reaction_mol_s;
row.H2_reduction_pct = 100 * row.H2_reduction_mol_s / baseH2MolS;
row.pO2_stack_kPa = point.pO2_stack_kPa;
row.p_stack_internal_kPa_abs = point.p_stack_internal_kPa_abs;
row.pH2_stack_kPa = point.pH2_stack_kPa;
row.pAn_stack_kPa_abs = point.pAn_stack_kPa_abs;
row.lambda_m = point.lambda_m;
row.T_stack_C = point.T_stack_C;
row.pO2_ca_in_kPa = point.pO2_ca_in_kPa;
row.xO2_ca_in = point.xO2_ca_in;
row.RH_ca_in = point.RH_ca_in;
row.lambda_O2_actual = point.lambda_O2_actual;
row.m_stack_in_kg_s = point.m_stack_in_kg_s;
row.m_egr_return_kg_s = point.m_egr_return_kg_s;
row.m_bench_out_kg_s = point.m_bench_out_kg_s;
row.liquid_drain_separator_kg_s = point.liquid_drain_separator_kg_s;
row.condensed_separator_kg_s = point.condensed_separator_kg_s;
row.separator_out_RH = point.separator_out_RH;
row.m_separator_gas_kg_s = point.m_separator_gas_kg_s;
row.maxGasRes_kg_s = point.maxGasRes_kg_s;
row.Qnet_W = point.Qnet_W;
row.Qgen_W = point.Qgen_W;
row.Qcool_W = point.Qcool_W;
row.Qamb_W = point.Qamb_W;
row.Qgas_W = point.Qgas_W;
row.flow_fixed_ok = abs(point.m_stack_in_kg_s - P.stack_in_flow_kg_s) <= ...
    max(1e-10, flowRelTol * P.stack_in_flow_kg_s);
row.gas_residual_ok = point.maxGasRes_kg_s <= gasResidualTolKgS;
row.oxygen_starvation_risk = point.lambda_O2_actual < oxygenLambdaMin;
row.oxygen_ok = ~row.oxygen_starvation_risk && point.xO2_ca_in > 0;
row.humidity_ok = point.RH_ca_in >= 0 && point.RH_ca_in <= 1.05;
row.pressure_order_ok = point.p_stack_internal_kPa_abs >= P.p_cathode_back_kPa - 1e-9;
row.boundary_fixed_ok = boundaryFixedOk(P, row);
row.normal_operation_ok = row.voltage_target_ok && row.flow_fixed_ok && ...
    row.gas_residual_ok && row.oxygen_ok && row.humidity_ok && ...
    row.pressure_order_ok && row.boundary_fixed_ok;
end

function tf = boundaryFixedOk(P, row)
tf = abs(P.stack_in_flow_kg_s - row.fixed_stack_in_flow_kg_s) <= ...
    max(1e-10, 1e-6 * row.fixed_stack_in_flow_kg_s) && ...
    abs(P.bench_stack_in_p_kPa - row.fixed_stack_in_p_kPa_g) <= 1e-9 && ...
    abs(P.bench_stack_in_T_C - row.fixed_stack_in_T_C) <= 1e-9 && ...
    abs(P.p_cathode_back_kPa - (row.fixed_stack_out_p_kPa_g + P.p_amb_kPa)) <= 1e-9 && ...
    abs(P.T_cool_C - row.fixed_coolant_in_T_C) <= 1e-9 && ...
    abs(P.coolant_flow_L_min - row.fixed_coolant_flow_L_min) <= 1e-9 && ...
    abs(P.anode_in_flow_kg_s - row.fixed_anode_flow_kg_s) <= ...
    max(1e-12, 1e-6 * row.fixed_anode_flow_kg_s);
end

function label = buildRiskLabel(row)
if row.status == "error"
    label = "simulation_error";
elseif row.status == "no_bracket"
    label = "no_voltage_bracket";
elseif ~row.voltage_target_ok
    label = "voltage_target_miss";
elseif ~row.flow_fixed_ok
    label = "flow_not_fixed";
elseif ~row.boundary_fixed_ok
    label = "boundary_not_fixed";
elseif ~row.gas_residual_ok
    label = "gas_residual_high";
elseif ~row.oxygen_ok
    label = "oxygen_limit";
elseif ~row.humidity_ok
    label = "humidity_limit";
elseif ~row.pressure_order_ok
    label = "pressure_order_fail";
else
    label = "ok";
end
end

function out = monotonicNonincreasing(x)
out = false(size(x));
valid = isfinite(x);
if nnz(valid) == numel(x)
    pass = all(diff(x) <= 1e-9);
    out(:) = pass;
end
end

function row = blankScanRow()
row = struct( ...
    'study_type', "", ...
    'condition', "", ...
    'case_id', "", ...
    'status', "pending", ...
    'error_message', "", ...
    'risk_label', "", ...
    'boundary_case_index', NaN, ...
    'target_V_cell', NaN, ...
    'base_current_A', NaN, ...
    'base_measured_V_cell', NaN, ...
    'egr_fraction_cmd', NaN, ...
    'stop_time_s', NaN, ...
    'fixed_stack_in_flow_kg_s', NaN, ...
    'fixed_stack_in_flow_SLPM', NaN, ...
    'fixed_stack_in_p_kPa_g', NaN, ...
    'fixed_stack_in_T_C', NaN, ...
    'fixed_stack_out_p_kPa_g', NaN, ...
    'fixed_separator_T_C', NaN, ...
    'fixed_coolant_in_T_C', NaN, ...
    'fixed_coolant_flow_L_min', NaN, ...
    'fixed_anode_flow_kg_s', NaN, ...
    'fixed_anode_back_p_kPa_abs', NaN, ...
    'bracket_low_current_A', NaN, ...
    'bracket_low_V_cell', NaN, ...
    'bracket_high_current_A', NaN, ...
    'bracket_high_V_cell', NaN, ...
    'simulation_count', 0, ...
    'bisection_iter_count', 0, ...
    'I_solution_A', NaN, ...
    'I_reduction_A', NaN, ...
    'I_reduction_pct', NaN, ...
    'V_cell_sim', NaN, ...
    'V_error_V', NaN, ...
    'voltage_target_ok', false, ...
    'P_stack_W', NaN, ...
    'P_reduction_W', NaN, ...
    'P_reduction_pct', NaN, ...
    'H2_reaction_mol_s', NaN, ...
    'H2_reduction_mol_s', NaN, ...
    'H2_reduction_pct', NaN, ...
    'pO2_stack_kPa', NaN, ...
    'p_stack_internal_kPa_abs', NaN, ...
    'pH2_stack_kPa', NaN, ...
    'pAn_stack_kPa_abs', NaN, ...
    'lambda_m', NaN, ...
    'T_stack_C', NaN, ...
    'pO2_ca_in_kPa', NaN, ...
    'xO2_ca_in', NaN, ...
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
    'flow_fixed_ok', false, ...
    'gas_residual_ok', false, ...
    'oxygen_starvation_risk', false, ...
    'oxygen_ok', false, ...
    'humidity_ok', false, ...
    'pressure_order_ok', false, ...
    'boundary_fixed_ok', false, ...
    'normal_operation_ok', false);
end

function writeChineseScanTable(path, T)
dict = scanColumnDictionary();
names = string(T.Properties.VariableNames);
header = strings(1, numel(names));
for k = 1:numel(names)
    idx = find(dict.column_name == names(k), 1, 'first');
    if isempty(idx)
        header(k) = names(k);
    elseif strlength(dict.unit(idx)) > 0 && dict.unit(idx) ~= "-"
        header(k) = dict.chinese_name(idx) + " (" + dict.unit(idx) + ")";
    else
        header(k) = dict.chinese_name(idx);
    end
end
writecell([cellstr(header); table2cell(T)], path, 'Encoding', 'UTF-8');
end

function writeScanDictionary(path)
dict = scanColumnDictionary();
writetable(dict, path, 'Encoding', 'UTF-8');
end

function dict = scanColumnDictionary()
rows = {
    'study_type', '研究类型', '-', '本行所属研究口径'
    'condition', '工况说明', '-', '固定边界条件的简短说明'
    'case_id', '基准工况编号', '-', '使用的原始台架工况编号'
    'status', '求解状态', '-', 'ok 表示该 EGR 点完成求解'
    'error_message', '错误信息', '-', '仿真或求解失败时的错误说明'
    'risk_label', '风险标签', '-', 'ok 或具体未通过的风险类型'
    'boundary_case_index', '边界工况索引', '-', 'initial_noegr 数据表中的工况序号'
    'target_V_cell', '目标单电池电压', 'V/cell', '恒电压求解目标'
    'base_current_A', '基准电流', 'A', '本研究固定参考的 38 A 基准电流'
    'base_measured_V_cell', '基准实测单电池电压', 'V/cell', 'initial_noegr_01 原始实测电压'
    'egr_fraction_cmd', 'CEGR循环比例', '-', '阴极尾气循环比例命令值'
    'stop_time_s', '仿真时长', 's', '单点稳态回放的仿真结束时间'
    'fixed_stack_in_flow_kg_s', '固定阴极入堆质量流量', 'kg/s', '扫描过程中保持不变的总入堆质量流量'
    'fixed_stack_in_flow_SLPM', '固定阴极入堆标准体积流量', 'SLPM', '扫描过程中保持不变的总入堆标准流量'
    'fixed_stack_in_p_kPa_g', '固定阴极入堆入口压力', 'kPa(g)', '阴极入堆入口表压'
    'fixed_stack_in_T_C', '固定阴极入堆入口温度', 'C', '阴极入堆入口温度'
    'fixed_stack_out_p_kPa_g', '固定阴极出口背压', 'kPa(g)', '阴极出口背压表压'
    'fixed_separator_T_C', '固定分离器/EGR回流温度', 'C', 'EGR回流初始温度边界'
    'fixed_coolant_in_T_C', '固定冷却液入口温度', 'C', '冷却侧入口温度'
    'fixed_coolant_flow_L_min', '固定冷却液流量', 'L/min', '冷却液体积流量'
    'fixed_anode_flow_kg_s', '固定阳极入口质量流量', 'kg/s', '阳极湿氢入口总质量流量'
    'fixed_anode_back_p_kPa_abs', '固定阳极出口背压', 'kPa(abs)', '阳极出口绝对背压'
    'bracket_low_current_A', '求根下界电流', 'A', '二分求解初始低电流边界'
    'bracket_low_V_cell', '下界电流对应电压', 'V/cell', '低电流边界仿真的单电池电压'
    'bracket_high_current_A', '求根上界电流', 'A', '二分求解初始高电流边界'
    'bracket_high_V_cell', '上界电流对应电压', 'V/cell', '高电流边界仿真的单电池电压'
    'simulation_count', '仿真次数', '-', '该 EGR 点二分求解累计调用 Simulink 的次数'
    'bisection_iter_count', '二分迭代次数', '-', '该 EGR 点求电流的二分迭代次数'
    'I_solution_A', '恒电压所需电流', 'A', '使 V_cell 接近 0.800 V/cell 的求解电流'
    'I_reduction_A', '相对38A降电流', 'A', '38 A 减去恒电压所需电流'
    'I_reduction_pct', '相对38A降电流比例', '%', '相对 38 A 的电流降低百分比'
    'V_cell_sim', '仿真单电池电压', 'V/cell', '求解电流下的末端单电池电压'
    'V_error_V', '电压误差', 'V/cell', 'V_cell_sim 减去目标电压'
    'voltage_target_ok', '电压目标是否通过', '-', '电压误差是否满足验收门槛'
    'P_stack_W', '电堆输出功率', 'W', 'V_cell_sim * I_solution_A * N_cell'
    'P_reduction_W', '相对基准功率下降', 'W', '目标电压38A基准功率减去当前功率'
    'P_reduction_pct', '相对基准功率下降比例', '%', '功率下降百分比'
    'H2_reaction_mol_s', '反应氢耗摩尔流量', 'mol/s', '按法拉第反应电流估算的氢耗'
    'H2_reduction_mol_s', '反应氢耗下降量', 'mol/s', '相对38A基准反应氢耗的下降量'
    'H2_reduction_pct', '反应氢耗下降比例', '%', '相对38A基准反应氢耗的下降百分比'
    'pO2_stack_kPa', '堆内氧分压', 'kPa', 'PEMFCStackCore 诊断的阴极氧分压'
    'p_stack_internal_kPa_abs', '堆内阴极压力', 'kPa(abs)', 'PEMFCStackCore 诊断的阴极内部绝压'
    'pH2_stack_kPa', '堆内氢分压', 'kPa', 'PEMFCStackCore 诊断的阳极氢分压'
    'pAn_stack_kPa_abs', '堆内阳极压力', 'kPa(abs)', 'PEMFCStackCore 诊断的阳极内部绝压'
    'lambda_m', '膜含水量', '-', '电堆膜水状态诊断量'
    'T_stack_C', '电堆温度', 'C', '电堆热平衡温度诊断量'
    'pO2_ca_in_kPa', '阴极入口氧分压', 'kPa', '混合后阴极入口氧分压'
    'xO2_ca_in', '阴极入口氧摩尔分数', '-', '混合后阴极入口氧气摩尔分数'
    'RH_ca_in', '阴极入口相对湿度', '-', '混合后阴极入口相对湿度'
    'lambda_O2_actual', '实际氧气计量比', '-', '基于实际入口氧流量计算的氧气计量比'
    'm_stack_in_kg_s', '实际入堆质量流量', 'kg/s', '模型诊断的阴极入口总质量流量'
    'm_egr_return_kg_s', 'EGR回流质量流量', 'kg/s', '分离器后返回混合器的气相质量流量'
    'm_bench_out_kg_s', '台架外排质量流量', 'kg/s', '未回流而排出的阴极尾气质量流量'
    'liquid_drain_separator_kg_s', '分离器排液流量', 'kg/s', '分离器液态水排出质量流量'
    'condensed_separator_kg_s', '分离器冷凝流量', 'kg/s', '分离器中冷凝出的水质量流量'
    'separator_out_RH', '分离器出口相对湿度', '-', '分离器气相出口相对湿度'
    'm_separator_gas_kg_s', '分离器气相出口流量', 'kg/s', '分离器出口气相 O2/N2/H2O 总流量'
    'maxGasRes_kg_s', '最大气体守恒残差', 'kg/s', '气体质量守恒残差诊断量'
    'Qnet_W', '电堆净热量', 'W', '热平衡净热流诊断量'
    'Qgen_W', '电堆产热', 'W', '电化学反应与损失产生的热量'
    'Qcool_W', '冷却带走热量', 'W', '冷却回路换热项'
    'Qamb_W', '环境散热', 'W', '电堆向环境散热项'
    'Qgas_W', '气体焓流热量', 'W', '进出气体携带的热量项'
    'flow_fixed_ok', '流量固定检查', '-', '实际入堆流量是否等于固定基准流量'
    'gas_residual_ok', '气体守恒检查', '-', '最大气体守恒残差是否小于门槛'
    'oxygen_starvation_risk', '缺气风险标记', '-', '实际氧计量比低于1.2时为真'
    'oxygen_ok', '氧气裕度检查', '-', '未触发缺气风险且入口氧分数为正'
    'humidity_ok', '湿度范围检查', '-', '入口相对湿度是否在合理范围内'
    'pressure_order_ok', '压力顺序检查', '-', '堆内阴极压力是否不低于出口背压'
    'boundary_fixed_ok', '固定边界检查', '-', '除 EGR 与混合组分外的操作条件是否保持固定'
    'normal_operation_ok', '有效工况总判定', '-', '所有关键验收条件是否同时通过'
    'xO2_monotonic_ok', '氧浓度单调性检查', '-', '整组扫描中 xO2 是否随 EGR 增大而单调下降'
    };
dict = cell2table(rows, 'VariableNames', ...
    {'column_name', 'chinese_name', 'unit', 'description'});
dict.column_name = string(dict.column_name);
dict.chinese_name = string(dict.chinese_name);
dict.unit = string(dict.unit);
dict.description = string(dict.description);
end

function writeSummary(path, T, Pbase, targetVCell, stopTime_s, strictVoltageTolV, ...
    acceptVoltageTolV, gasResidualTolKgS, oxygenLambdaMin, basePowerW, baseH2MolS)

fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));

ok = T(T.status == "ok", :);
normal = ok(ok.normal_operation_ok, :);
egr0 = ok(abs(ok.egr_fraction_cmd) < 1e-12, :);
best = normal;
if ~isempty(best)
    best = sortrows(best, 'I_reduction_A', 'descend');
end

fprintf(fid, '# 38A基准恒电压 CEGR 降电流研究摘要\n\n');
fprintf(fid, '- 基准工况: `%s`, I=%.6g A, 实测 V_cell=%.8f V/cell\n', ...
    string(Pbase.case_id), Pbase.I_stack_default_A, Pbase.cell_voltage_bench_V);
fprintf(fid, '- 目标电压: %.6f V/cell\n', targetVCell);
fprintf(fid, '- Stop time: %.3g s\n', stopTime_s);
fprintf(fid, '- EGR扫描: 0:0.05:0.70\n');
fprintf(fid, '- 电压求解严目标: %.6g V/cell, 验收目标: %.6g V/cell\n', ...
    strictVoltageTolV, acceptVoltageTolV);
fprintf(fid, '- 气体守恒残差门槛: %.6g kg/s\n', gasResidualTolKgS);
fprintf(fid, '- 缺气风险门槛: lambda_O2_actual < %.3g\n', oxygenLambdaMin);
fprintf(fid, '- 基准功率口径: %.6f W, 基准反应氢耗: %.9g mol/s\n\n', ...
    basePowerW, baseH2MolS);

fprintf(fid, '## 固定基准操作条件\n\n');
fprintf(fid, '本研究使用 `initial_noegr_01` 的 38 A 台架点作为固定边界。扫描 CEGR 时，只改变 `egr_fraction_cmd` 以及由循环混合导致的阴极入口气体组分；以下操作条件保持不变。\n\n');
fprintf(fid, '| 类别 | 参数 | 中文含义 | 数值 |\n');
fprintf(fid, '| --- | --- | --- | ---: |\n');
fprintf(fid, '| 电堆 | `N_cell` | 电堆串联单电池数量 | %.0f |\n', Pbase.N_cell);
fprintf(fid, '| 电堆 | `A_cell_cm2` | 单电池有效反应面积 | %.3f cm2 |\n', Pbase.A_cell_cm2);
fprintf(fid, '| 阴极入堆 | `stack_in_flow_kg_s` | 阴极总入堆质量流量 | %.9g kg/s |\n', Pbase.stack_in_flow_kg_s);
fprintf(fid, '| 阴极入堆 | `stack_in_flow_SLPM` | 阴极总入堆标准体积流量 | %.3f SLPM |\n', Pbase.stack_in_flow_SLPM);
fprintf(fid, '| 阴极入堆 | `bench_stack_in_p_kPa` | 阴极入堆入口压力 | %.3f kPa(g), %.3f kPa(abs) |\n', ...
    Pbase.bench_stack_in_p_kPa, Pbase.bench_stack_in_p_kPa + Pbase.p_amb_kPa);
fprintf(fid, '| 阴极入堆 | `bench_stack_in_T_C` | 阴极入堆入口温度 | %.3f C |\n', Pbase.bench_stack_in_T_C);
fprintf(fid, '| 阴极入堆 | `bench_stack_in_RH` | 阴极入堆入口相对湿度 | %.3f %% |\n', 100 * Pbase.bench_stack_in_RH);
fprintf(fid, '| 阴极供气组分 | `bench_supply_gas_p_kPa` | 进入混合器的新鲜供气压力 | %.3f kPa(g), %.3f kPa(abs) |\n', ...
    Pbase.bench_supply_gas_p_kPa, Pbase.bench_supply_gas_p_kPa + Pbase.p_amb_kPa);
fprintf(fid, '| 阴极供气组分 | `bench_supply_gas_T_C` | 进入混合器的新鲜供气温度 | %.3f C |\n', Pbase.bench_supply_gas_T_C);
fprintf(fid, '| 阴极供气组分 | `bench_supply_gas_RH` | 进入混合器的新鲜供气相对湿度 | %.3f %% |\n', 100 * Pbase.bench_supply_gas_RH);
fprintf(fid, '| 阴极供气组分 | `cathode_supply_wO2 / wN2 / wH2O` | 新鲜供气中氧气/氮气/水蒸气质量分数 | %.6f / %.6f / %.6f |\n', ...
    Pbase.cathode_supply_wO2, Pbase.cathode_supply_wN2, Pbase.cathode_supply_wH2O);
fprintf(fid, '| 阴极出口 | `p_cathode_back_kPa` | 阴极出口背压 | %.3f kPa(g), %.3f kPa(abs) |\n', ...
    Pbase.stack_out_p_kPa, Pbase.p_cathode_back_kPa);
fprintf(fid, '| 分离器/EGR回流初值 | `separator_T_C` | 分离器/EGR回流初始温度 | %.3f C |\n', Pbase.separator_T_C);
fprintf(fid, '| 分离器/EGR回流初值 | `separator_p_kPa` | 分离器/EGR回流初始压力 | %.3f kPa(g), %.3f kPa(abs) |\n', ...
    Pbase.separator_p_kPa, Pbase.separator_p_kPa + Pbase.p_amb_kPa);
fprintf(fid, '| 阳极 | `anode_stoich` | 阳极氢气计量比 | %.6f |\n', Pbase.anode_stoich);
fprintf(fid, '| 阳极 | `anode_in_flow_kg_s` | 阳极入口湿氢总质量流量 | %.9g kg/s |\n', Pbase.anode_in_flow_kg_s);
fprintf(fid, '| 阳极 | `p_anode_in_kPa` | 阳极入口压力 | %.3f kPa(g), %.3f kPa(abs) |\n', ...
    Pbase.p_anode_in_kPa - Pbase.p_amb_kPa, Pbase.p_anode_in_kPa);
fprintf(fid, '| 阳极 | `anode_in_T_C` | 阳极入口温度 | %.3f C |\n', Pbase.anode_in_T_C);
fprintf(fid, '| 阳极 | `RH_an_in` | 阳极入口相对湿度 | %.3f %% |\n', 100 * Pbase.RH_an_in);
fprintf(fid, '| 阳极 | `p_anode_back_kPa` | 阳极出口背压 | %.3f kPa(g), %.3f kPa(abs) |\n', ...
    Pbase.p_anode_back_kPa - Pbase.p_amb_kPa, Pbase.p_anode_back_kPa);
fprintf(fid, '| 冷却 | `T_cool_C` | 冷却液入口温度 | %.3f C |\n', Pbase.T_cool_C);
fprintf(fid, '| 冷却 | `coolant_out_C` | 冷却液出口实测参考温度 | %.3f C |\n', Pbase.coolant_out_C);
fprintf(fid, '| 冷却 | `coolant_flow_L_min` | 冷却液体积流量 | %.3f L/min |\n\n', Pbase.coolant_flow_L_min);

fprintf(fid, '## 结果概览\n\n');
fprintf(fid, '- 扫描点数: %d\n', height(T));
fprintf(fid, '- 成功求解点数: %d\n', height(ok));
fprintf(fid, '- 正常有效点数: %d\n', height(normal));
fprintf(fid, '- 非正常点数: %d\n', height(T) - height(normal));
fprintf(fid, '- xO2随EGR单调下降: %d\n', all(T.xO2_monotonic_ok));
if ~isempty(egr0)
    fprintf(fid, '- EGR=0回归电流: %.6f A, 相对38A差值: %.6f A\n', ...
        egr0.I_solution_A(1), egr0.I_solution_A(1) - Pbase.I_stack_default_A);
end
if ~isempty(normal)
    fprintf(fid, '- 最大有效降电流: %.6f A at EGR=%.2f\n', ...
        best.I_reduction_A(1), best.egr_fraction_cmd(1));
    fprintf(fid, '- 最大有效功率下降: %.6f W, %.3f %%\n', ...
        best.P_reduction_W(1), best.P_reduction_pct(1));
    fprintf(fid, '- 最大有效反应氢耗下降: %.9g mol/s, %.3f %%\n\n', ...
        best.H2_reduction_mol_s(1), best.H2_reduction_pct(1));
end

fprintf(fid, '## 有效点表\n\n');
fprintf(fid, '| EGR | I_solution_A | I_reduction_A | I_reduction_pct | V_cell | lambda_O2 | xO2_in | P_reduction_pct | H2_reduction_pct |\n');
fprintf(fid, '| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n');
for k = 1:height(normal)
    fprintf(fid, '| %.2f | %.6f | %.6f | %.3f | %.6f | %.6f | %.6f | %.3f | %.3f |\n', ...
        normal.egr_fraction_cmd(k), normal.I_solution_A(k), ...
        normal.I_reduction_A(k), normal.I_reduction_pct(k), ...
        normal.V_cell_sim(k), normal.lambda_O2_actual(k), ...
        normal.xO2_ca_in(k), normal.P_reduction_pct(k), ...
        normal.H2_reduction_pct(k));
end
fprintf(fid, '\n');

bad = T(~T.normal_operation_ok, :);
if ~isempty(bad)
    fprintf(fid, '## 非正常点\n\n');
    for k = 1:height(bad)
        fprintf(fid, '- EGR=%.2f, status=%s, risk=%s, I=%.6f A, Verr=%.6g, lambdaO2=%.6f, maxGasRes=%.6g. %s\n', ...
            bad.egr_fraction_cmd(k), string(bad.status(k)), string(bad.risk_label(k)), ...
            bad.I_solution_A(k), bad.V_error_V(k), bad.lambda_O2_actual(k), ...
            bad.maxGasRes_kg_s(k), string(bad.error_message(k)));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '## 结论口径\n\n');
fprintf(fid, '- 本结果只隔离固定38A台架边界下阴极入口组分变化对恒电压所需电流的影响。\n');
fprintf(fid, '- 功率和氢耗下降按目标电压、单电池数和法拉第反应电流估算，不包含循环泵、空压机或控制代价。\n');
fprintf(fid, '- 缺气、守恒残差或边界未固定的点不得作为经济性有效点。\n');
end
