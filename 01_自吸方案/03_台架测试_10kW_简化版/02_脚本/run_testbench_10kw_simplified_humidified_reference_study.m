function results = run_testbench_10kw_simplified_humidified_reference_study(stopTime_s)
%RUN_TESTBENCH_10KW_SIMPLIFIED_HUMIDIFIED_REFERENCE_STUDY
% 生成“加压加湿 no-EGR”参考线：
% 1. 只取 13 个 initial no-EGR 主点。
% 2. 直接回放各点原生台架边界，不再把供气退回到环境 25 C / 1 atm。
% 3. 同时读取说明书推荐工况表，核对原生点与“加压加湿”推荐口径是否一致。

if nargin < 1 || isempty(stopTime_s)
    stopTime_s = 120;
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
resultDir = fullfile(rootDir, '04_验证结果', 'custom_inlet_study_v01');
if ~isfolder(resultDir)
    mkdir(resultDir);
end

outFile = fullfile(resultDir, 'humidified_reference_scan.csv');
summaryFile = fullfile(resultDir, 'humidified_reference_summary.md');

recommended = load_testbench_10kw_recommended_conditions();
recommended = recommended(ismember(recommended.current_A, ...
    [38; 76; 114; 152; 228; 266; 342; 418; 494; 570; 646; 684; 722]), :);

P0 = init_testbench_10kw_simplified_egr(1, 'initial_noegr', false);
model = P0.modelName;
load_system(model);

scanRows = {};
for caseIdx = 1:13
    Pbase = init_testbench_10kw_simplified_egr(caseIdx, 'initial_noegr', false);
    recRow = lookupRecommendedRow(recommended, Pbase.I_stack_default_A);
    row = runOneReferencePoint(Pbase, recRow, stopTime_s, model);
    scanRows{end + 1, 1} = struct2table(row); %#ok<AGROW>
end

scanTable = vertcat(scanRows{:});
scanTable = sortrows(scanTable, {'current_density_command_A_cm2'});
writetable(scanTable, outFile);
writeSummary(summaryFile, scanTable);

results = struct();
results.scan = scanTable;
results.scan_file = outFile;
results.summary_file = summaryFile;

fprintf('Humidified reference study complete: %s\n', summaryFile);
end

function row = runOneReferencePoint(Pbase, recRow, stopTime_s, model)
row = blankReferenceRow();
row.study_type = "pressurized_humidified_reference_native_noegr";
row.condition = "recommended_pressurized_humidified_noegr";
row.case_id = string(Pbase.case_id);
row.boundary_case_index = Pbase.caseIndex;
row.current_A = Pbase.I_stack_default_A;
row.current_density_command_A_cm2 = Pbase.current_density_A_cm2;
row.egr_band = egrBandName(Pbase.current_density_A_cm2);
row.egr_fraction_cmd = 0.0;

row.reference_cathode_stoich = recRow.cathode_stoich;
row.reference_supply_p_kPa_g = recRow.cathode_p_kPa_g;
row.reference_supply_T_C = recRow.cathode_in_T_C;
row.reference_supply_RH = recRow.cathode_RH_pct / 100.0;
row.reference_anode_stoich = recRow.anode_stoich;
row.reference_anode_p_kPa_g = recRow.anode_p_kPa_g;
row.reference_anode_T_C = recRow.anode_in_T_C;
row.reference_anode_RH = recRow.anode_RH_pct / 100.0;

row.native_stack_in_flow_kg_s = Pbase.stack_in_flow_kg_s;
row.native_stack_in_flow_SLPM = Pbase.stack_in_flow_SLPM;
row.native_stack_in_p_kPa_g = Pbase.bench_stack_in_p_kPa;
row.native_stack_in_T_C = Pbase.bench_stack_in_T_C;
row.native_supply_p_kPa_g = Pbase.bench_supply_gas_p_kPa;
row.native_supply_T_C = Pbase.bench_supply_gas_T_C;
row.native_supply_RH = Pbase.bench_supply_gas_RH;
row.native_anode_stoich = Pbase.anode_stoich;
row.native_anode_p_kPa_g = Pbase.p_anode_in_kPa - Pbase.p_amb_kPa;
row.native_anode_T_C = Pbase.anode_in_T_C;
row.native_anode_RH = Pbase.RH_an_in;
row.reference_alignment_ok = referenceAlignmentOk(row);

try
    out = simulateCase(Pbase, stopTime_s, model);
    s = lastSummary(out);
    row.status = "ok";
    row.V_cell_sim = s(2);
    row.lambda_m = s(8);
    row.T_stack_C = s(9);
    row.stack_out_T_sim_C = 2 * s(9) - Pbase.bench_stack_in_T_C;
    row.xO2_ca_in = s(20);
    row.pO2_ca_in_kPa = s(19);
    row.RH_ca_in = s(21);
    row.lambda_O2_actual = s(40);
    row.lambda_O2_reference_error = row.lambda_O2_actual - row.reference_cathode_stoich;
    row.maxGasRes_kg_s = s(31);
    row.gas_residual_ok = row.maxGasRes_kg_s <= 1e-8;
    row.oxygen_starvation_risk = row.lambda_O2_actual < 1.2;
catch ME
    row.status = "error";
    row.error_message = string(ME.identifier + ": " + ME.message);
end
end

function tf = referenceAlignmentOk(row)
tolP = 0.6;
tolT = 1.5;
tolRH = 0.02;
tf = abs(row.native_stack_in_p_kPa_g - row.reference_supply_p_kPa_g) <= tolP && ...
    abs(row.native_stack_in_T_C - row.reference_supply_T_C) <= tolT && ...
    abs(row.native_supply_RH - row.reference_supply_RH) <= tolRH && ...
    abs(row.native_anode_p_kPa_g - row.reference_anode_p_kPa_g) <= tolP && ...
    abs(row.native_anode_T_C - row.reference_anode_T_C) <= tolT && ...
    abs(row.native_anode_RH - row.reference_anode_RH) <= tolRH;
end

function recRow = lookupRecommendedRow(T, currentA)
idx = find(abs(T.current_A - currentA) < 1e-9, 1, 'first');
if isempty(idx)
    error('CEGR:SimplifiedBench:MissingRecommendedRow', ...
        'No recommended-condition row found for current %.6g A.', currentA);
end
recRow = T(idx, :);
end

function row = blankReferenceRow()
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
    'reference_cathode_stoich', NaN, ...
    'reference_supply_p_kPa_g', NaN, ...
    'reference_supply_T_C', NaN, ...
    'reference_supply_RH', NaN, ...
    'reference_anode_stoich', NaN, ...
    'reference_anode_p_kPa_g', NaN, ...
    'reference_anode_T_C', NaN, ...
    'reference_anode_RH', NaN, ...
    'native_stack_in_flow_kg_s', NaN, ...
    'native_stack_in_flow_SLPM', NaN, ...
    'native_stack_in_p_kPa_g', NaN, ...
    'native_stack_in_T_C', NaN, ...
    'native_supply_p_kPa_g', NaN, ...
    'native_supply_T_C', NaN, ...
    'native_supply_RH', NaN, ...
    'native_anode_stoich', NaN, ...
    'native_anode_p_kPa_g', NaN, ...
    'native_anode_T_C', NaN, ...
    'native_anode_RH', NaN, ...
    'reference_alignment_ok', false, ...
    'V_cell_sim', NaN, ...
    'lambda_m', NaN, ...
    'T_stack_C', NaN, ...
    'stack_out_T_sim_C', NaN, ...
    'xO2_ca_in', NaN, ...
    'pO2_ca_in_kPa', NaN, ...
    'RH_ca_in', NaN, ...
    'lambda_O2_actual', NaN, ...
    'lambda_O2_reference_error', NaN, ...
    'maxGasRes_kg_s', NaN, ...
    'gas_residual_ok', false, ...
    'oxygen_starvation_risk', false);
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

function writeSummary(path, T)
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
ok = T(T.status == "ok", :);

fprintf(fid, '# 加压加湿 no-EGR 参考线摘要\n\n');
fprintf(fid, '- 参考线来源：`initial_noegr` 原生台架边界回放，并与说明书 `电堆信息及推荐测试工况.xlsx` 逐点核对。\n');
fprintf(fid, '- 参考点数量: %d\n', height(T));
fprintf(fid, '- 成功点数: %d\n', height(ok));
fprintf(fid, '- 失败点数: %d\n', height(T) - height(ok));
fprintf(fid, '- 与说明书加压加湿口径对齐的点数: %d / %d\n', nnz(T.reference_alignment_ok), height(T));
if ~isempty(ok)
    fprintf(fid, '- 最大气体守恒残差: %.6g kg/s\n', max(ok.maxGasRes_kg_s));
    fprintf(fid, '- 最小入口氧计量比: %.6f\n', min(ok.lambda_O2_actual));
    fprintf(fid, '- `lambda_O2_actual` 相对说明书阴极计量比的最大偏差: %.6f\n', ...
        max(abs(ok.lambda_O2_reference_error)));
end
end
