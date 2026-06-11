function audit = run_core_fix_v01_audit(stopTime_s)
%RUN_CORE_FIX_V01_AUDIT Replay all unified cases after core-fix v01 changes.
%
% 在当前简化台架模型体系中的作用：
% 1. 这是 Simulink 主模型的“批量审计脚本”，不是标定脚本，也不修改模型参数。
% 2. 逐个读取统一工况表中的 29 个稳态点，调用初始化脚本生成该点的模型输入。
% 3. 用 CEGR_TestBench_10kW_SimplifiedEGR_v01.slx 回放每个工况，
%    记录实验边界、仿真电压、压力、氧分压、入口氧分数、膜水、
%    气体/水守恒残差、热量项和电压损失项。
% 4. 输出 04_验证结果/core_fix_v01_audit.csv 和
%    04_验证结果/core_fix_v01_summary.md，供后续判断模型边界和物理链路是否可信。
% 5. 如果某个工况仿真失败，脚本会把错误写入审计表，不会中断整批审计。

% 审计脚本用于批量回放统一工况表中的所有点，并输出 CSV/Markdown 结果。
% stopTime_s 默认 120 s；如果只想快速检查可传入更短时间。
if nargin < 1 || isempty(stopTime_s)
    stopTime_s = 120;
end

% 定位模型目录和结果目录。结果目录不存在时自动创建。
% addpath 是为了让 load_system/sim 找到当前简化台架模型。
rootDir = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(rootDir, '01_模型');
resultDir = fullfile(rootDir, '04_验证结果');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
addpath(modelDir);

% 初始化第一个工况，只是为了拿到全量工况表和模型名。
% 后续循环中每个工况都会重新调用 init，确保边界参数逐点更新。
P0 = init_testbench_10kw_simplified_egr(1, 'all', false);
cases = P0.allCaseTable;
model = P0.modelName;
load_system(model);

% 预分配审计结果表。大部分列是 double，少数状态/文本列改成 string。
% 这样循环中只填值，不动态增长表格，运行更稳定。
varNames = auditVariableNames();
varTypes = repmat("double", 1, numel(varNames));
textVars = ["case_id", "source_dataset", "status", "message"];
for k = 1:numel(textVars)
    varTypes(varNames == textVars(k)) = "string";
end
audit = table('Size', [height(cases), numel(varNames)], ...
    'VariableTypes', cellstr(varTypes), 'VariableNames', cellstr(varNames));

% 主循环：每个工况先记录实验输入边界，再运行 Simulink 并记录模型输出诊断。
% try/catch 的作用是让单个工况失败时不终止整批审计，而是在结果表中记录错误信息。
for k = 1:height(cases)
    P = init_testbench_10kw_simplified_egr(k, 'all', false);
    audit.case_id(k) = string(P.case_id);
    audit.source_dataset(k) = string(P.source_dataset);
    audit.current_A(k) = P.I_stack_default_A;
    audit.current_density_A_cm2(k) = P.current_density_A_cm2;
    audit.egr_fraction(k) = P.egr_fraction_cmd;
    audit.V_exp(k) = P.cell_voltage_bench_V;
    audit.stack_in_flow_SLPM(k) = P.stack_in_flow_SLPM;
    audit.stack_in_flow_kg_s(k) = P.stack_in_flow_kg_s;
    audit.fresh_supply_flow_SLPM(k) = P.fresh_supply_flow_SLPM;
    audit.stack_in_p_kPa_g(k) = P.bench_stack_in_p_kPa;
    audit.stack_out_p_kPa_g(k) = P.stack_out_p_kPa;
    audit.cathode_dp_kPa(k) = P.cathode_dp_kPa;
    audit.stack_in_T_C(k) = P.bench_stack_in_T_C;
    audit.stack_in_RH(k) = P.bench_stack_in_RH;
    try
        % summary_vector 的索引来自模型 SystemSummary 输出顺序。
        % 这里既记录电压误差，也记录压力、氧分压、膜水、水相和能量残差等物理诊断。
        out = simulateCase(P, stopTime_s, model);
        s = lastSummary(out);
        audit.status(k) = "ok";
        audit.V_sim(k) = s(2);
        audit.err_V(k) = s(2) - P.cell_voltage_bench_V;
        audit.pO2_stack_kPa(k) = s(4);
        audit.pCa_stack_kPa_abs(k) = s(5);
        audit.pCa_out_boundary_kPa_abs(k) = P.p_cathode_back_kPa;
        audit.pH2_stack_kPa(k) = s(6);
        audit.pAn_stack_kPa_abs(k) = s(7);
        audit.T_stack_C(k) = s(9);
        audit.xO2_stack(k) = s(10);
        audit.RH_stack(k) = s(11);
        audit.pO2_in_kPa(k) = s(19);
        audit.xO2_in(k) = s(20);
        audit.RH_in(k) = s(21);
        audit.lambda_m(k) = s(8);
        audit.lambda_ca(k) = s(49);
        audit.lambda_an(k) = s(50);
        audit.mMem_kg_s(k) = s(12);
        audit.N_drag_mol_s(k) = s(51);
        audit.N_diff_mol_s(k) = s(52);
        audit.J_drag_mol_m2_s(k) = s(59);
        audit.J_diff_mol_m2_s(k) = s(60);
        audit.J_net_mol_m2_s(k) = s(61);
        audit.mDrag_kg_s(k) = s(62);
        audit.mDiff_kg_s(k) = s(63);
        audit.mMem_raw_kg_s(k) = s(64);
        audit.mMem_limit_delta_kg_s(k) = s(65);
        audit.mCaOut_kg_s(k) = s(16);
        audit.mIn_kg_s(k) = s(41);
        audit.mIn_error_kg_s(k) = s(41) - P.stack_in_flow_kg_s;
        audit.lambdaO2(k) = s(40);
        audit.phaseCa_kg_s(k) = s(26);
        audit.phaseAn_kg_s(k) = s(29);
        audit.condensedCa_kg(k) = s(57);
        audit.condensedAn_kg(k) = s(58);
        audit.psatCa_next_kPa(k) = s(53);
        audit.psatAn_next_kPa(k) = s(54);
        audit.mV_ca_preclip_kg(k) = s(55);
        audit.mV_an_preclip_kg(k) = s(56);
        audit.resO2_kg_s(k) = s(23);
        audit.resN2_kg_s(k) = s(24);
        audit.resH2Oca_kg_s(k) = s(25);
        audit.resH2_kg_s(k) = s(27);
        audit.resH2Oan_kg_s(k) = s(28);
        audit.maxGasRes_kg_s(k) = s(31);
        audit.Qnet_W(k) = s(22);
        audit.Qgen_W(k) = s(32);
        audit.Qcool_W(k) = s(33);
        audit.Qamb_W(k) = s(34);
        audit.Qgas_W(k) = s(35);
        audit.E_Nernst_V(k) = s(36);
        audit.etaAct_V(k) = s(37);
        audit.etaOhm_V(k) = s(38);
        audit.etaCon_V(k) = s(39);
        audit.message(k) = "";
    catch ME
        audit.status(k) = "error";
        audit.message(k) = string(ME.identifier + ": " + ME.message);
    end
end

% 写出完整审计 CSV 和简短 Markdown 摘要。
auditFile = fullfile(resultDir, 'core_fix_v01_audit.csv');
summaryFile = fullfile(resultDir, 'core_fix_v01_summary.md');
writetable(audit, auditFile);
writeSummary(summaryFile, audit, stopTime_s);
fprintf('Wrote %s\n', auditFile);
fprintf('Wrote %s\n', summaryFile);
end

function out = simulateCase(P, stopTime_s, model)
% 用 SimulationInput 注入当前工况的全部运行变量。
% 这种写法比依赖 base workspace 更清楚，也能降低上一次仿真残留变量的影响。
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
% 取 summary_vector 最后一个时刻，作为该稳态回放工况的结果。
v = out.summary_vector.signals.values;
s = squeeze(v(:, 1, end));
end

function names = auditVariableNames()
% 审计表字段清单。字段顺序必须和主循环中填表顺序一致，便于后续 CSV 分析。
names = ["case_id", "source_dataset", "status", "message", ...
    "current_A", "current_density_A_cm2", "egr_fraction", "V_exp", "V_sim", "err_V", ...
    "stack_in_flow_SLPM", "stack_in_flow_kg_s", "fresh_supply_flow_SLPM", "stack_in_p_kPa_g", ...
    "stack_out_p_kPa_g", "cathode_dp_kPa", "stack_in_T_C", "stack_in_RH", ...
    "pO2_stack_kPa", "pCa_stack_kPa_abs", "pCa_out_boundary_kPa_abs", ...
    "pH2_stack_kPa", "pAn_stack_kPa_abs", "T_stack_C", "xO2_stack", ...
    "RH_stack", "pO2_in_kPa", "xO2_in", "RH_in", "lambda_m", ...
    "lambda_ca", "lambda_an", "mMem_kg_s", "N_drag_mol_s", "N_diff_mol_s", ...
    "J_drag_mol_m2_s", "J_diff_mol_m2_s", "J_net_mol_m2_s", ...
    "mDrag_kg_s", "mDiff_kg_s", "mMem_raw_kg_s", "mMem_limit_delta_kg_s", ...
    "mCaOut_kg_s", "mIn_kg_s", "mIn_error_kg_s", "lambdaO2", "phaseCa_kg_s", "phaseAn_kg_s", ...
    "condensedCa_kg", "condensedAn_kg", "psatCa_next_kPa", "psatAn_next_kPa", ...
    "mV_ca_preclip_kg", "mV_an_preclip_kg", "resO2_kg_s", "resN2_kg_s", ...
    "resH2Oca_kg_s", "resH2_kg_s", "resH2Oan_kg_s", "maxGasRes_kg_s", ...
    "Qnet_W", "Qgen_W", "Qcool_W", "Qamb_W", "Qgas_W", ...
    "E_Nernst_V", "etaAct_V", "etaOhm_V", "etaCon_V"];
end

function writeSummary(path, audit, stopTime_s)
% 生成给人快速阅读的摘要。详细逐点数据仍以 CSV 为准。
ok = audit(audit.status == "ok", :);
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Core Fix v01 Audit Summary\n\n');
fprintf(fid, '- Stop time: %.3g s\n', stopTime_s);
fprintf(fid, '- Total cases: %d\n', height(audit));
fprintf(fid, '- Successful cases: %d\n', height(ok));
fprintf(fid, '- Failed cases: %d\n\n', height(audit) - height(ok));
if ~isempty(ok)
    % 这里只做几项硬指标汇总：仿真成功数、电压误差、压差覆盖范围、守恒残差和入口流量误差。
    fprintf(fid, '## Key Metrics\n\n');
    fprintf(fid, '- Voltage RMSE, all successful cases: %.6f V\n', rmsLocal(ok.err_V));
    fprintf(fid, '- Max absolute voltage error: %.6f V\n', max(abs(ok.err_V)));
    fprintf(fid, '- Initial no-EGR cathode dp range in data: %.3f to %.3f kPa\n', ...
        min(ok.cathode_dp_kPa(ok.source_dataset == "initial_noegr_steady_xlsx")), ...
        max(ok.cathode_dp_kPa(ok.source_dataset == "initial_noegr_steady_xlsx")));
    fprintf(fid, '- Max gas residual: %.6g kg/s\n', max(ok.maxGasRes_kg_s));
    fprintf(fid, '- Max inlet-flow error: %.6g kg/s\n', max(abs(ok.mIn_error_kg_s)));
    fprintf(fid, '- Min actual oxygen stoich lambdaO2: %.6g\n', min(ok.lambdaO2));
    fprintf(fid, '- Max cathode condensation diagnostic: %.6g kg\n', max(ok.condensedCa_kg));
    fprintf(fid, '- Direct EGR voltage penalty terms are not used in the simplified bench core.\n\n');
end
if any(audit.status == "error")
    % 如果有失败工况，把 case_id 和错误信息列出来，方便回到输入表定位。
    fprintf(fid, '## Failed Cases\n\n');
    bad = audit(audit.status == "error", :);
    for k = 1:height(bad)
        fprintf(fid, '- `%s`: %s\n', bad.case_id(k), bad.message(k));
    end
end
end

function r = rmsLocal(x)
% 忽略 NaN 后计算 RMSE；如果没有有效数据则返回 NaN。
x = x(isfinite(x));
if isempty(x)
    r = NaN;
else
    r = sqrt(mean(x.^2));
end
end
