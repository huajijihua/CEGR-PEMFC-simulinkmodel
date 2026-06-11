function P = init_testbench_10kw_simplified_egr(caseIndex, dataMode, verbose)
%INIT_TESTBENCH_10KW_SIMPLIFIED_EGR Init data and parameters for simplified bench EGR model.
%
% The Simulink model is the main artifact. This script only prepares
% workspace parameters for one steady bench point.
%
% 在当前简化台架模型体系中的作用：
% 1. 这是 Simulink 主模型运行前的“工况装配脚本”，不是模型本体。
% 2. 从精简工况输入表 combined_noegr_cegr_fit_points.csv 读取某一个稳态点。
% 3. 把实验中的阴极入口流量、入口压力、出口背压、EGR 回流温压、
%    阳极入口条件和冷却条件转换成 Simulink 常量块需要的参数向量。
% 4. 生成并写入 base workspace 变量：
%    PhysicalParam_simplified、StackModelParam_simplified、
%    CaseBoundaryParam_simplified、CoolingCurveParam_simplified、
%    StackInitialState_simplified、EGRInitialNode_simplified。
% 5. Simulink 模型 CEGR_TestBench_10kW_SimplifiedEGR_v01.slx
%    运行时读取这些变量，脚本本身不替代模型里的气体、水、热、电压计算。

% 入口参数处理：
% caseIndex 选择第几个工况；dataMode 选择工况集合；verbose 控制是否打印初始化信息。
% 没传参数时默认取 EGR 数据集的第 1 个点，并打印初始化结果。
if nargin < 1 || isempty(caseIndex)
    caseIndex = 1;
end
if nargin < 2 || strlength(string(dataMode)) == 0
    dataMode = "egr";
else
    dataMode = lower(string(dataMode));
end
if nargin < 3 || isempty(verbose)
    verbose = true;
end

% 定位当前简化台架目录和模型文件。rootDir 是“03_台架测试_10kW_简化版”，
% projectRoot 是更外层项目目录。addpath 只把模型目录放到 MATLAB 路径，便于 sim/load_system 找到 slx。
rootDir = fileparts(fileparts(mfilename('fullpath')));
projectRoot = fileparts(fileparts(rootDir));
P = init_testbench_10kw_simplified_defaults();
P.rootDir = rootDir;
P.projectRoot = projectRoot;
P.modelName = 'CEGR_TestBench_10kW_SimplifiedEGR_v01';
P.modelFile = fullfile(rootDir, '01_模型', [P.modelName '.slx']);
addpath(fullfile(rootDir, '01_模型'));
P.stopTime_s = 120;
P.dt_s = 0.02;

% 读取统一工况表，并拆分成 no-EGR / EGR / 全部工况三张表。
% 这里的 assignin 是为了把表同步放到 base workspace，方便 Simulink 或命令行检查。
% 这属于有意的 Simulink 工作区副作用，不是普通业务函数推荐的写法。
[noEgr, egr, allCases] = readSimplifiedBenchData(rootDir, projectRoot);
P.noEgrTable = noEgr;
P.egrTable = egr;
P.allCaseTable = allCases;
P.dataMode = dataMode;
assignin('base', 'NoEGRBenchData_simplified', noEgr);
assignin('base', 'EGRBenchData_simplified', egr);
assignin('base', 'AllBenchData_simplified', allCases);

% 根据 dataMode 选择本次要索引的工况集合。
% all/combined 用统一表全量索引；initial_noegr 和 cegr0608 按数据来源筛选；
% noegr/egr 则按 is_no_egr 拆分后的表索引。
if dataMode == "all" || dataMode == "combined"
    cases = allCases;
elseif dataMode == "initial_noegr"
    cases = allCases(string(allCases.source_dataset) == "initial_noegr_steady_xlsx", :);
elseif dataMode == "cegr0608"
    cases = allCases(string(allCases.source_dataset) == "cegr_0608_txt", :);
elseif dataMode == "noegr"
    cases = noEgr;
elseif dataMode == "egr"
    cases = egr;
else
    error('CEGR:SimplifiedBench:BadMode', ...
        'dataMode must be "all", "initial_noegr", "cegr0608", "noegr", or "egr".');
end
if isempty(cases)
    error('CEGR:SimplifiedBench:NoCases', 'No cases available for dataMode "%s".', dataMode);
end
% caseIndex 是用户选择的工况编号，越界应直接报错，不能静默夹到首末工况。
% 否则会把错误索引伪装成有效仿真，影响标定和审计结论。
caseIndex = round(caseIndex);
if caseIndex < 1 || caseIndex > height(cases)
    error('CEGR:SimplifiedBench:CaseIndexOutOfRange', ...
        'caseIndex %d is out of range for dataMode "%s". Valid range is 1..%d.', ...
        caseIndex, dataMode, height(cases));
end
row = cases(caseIndex, :);
P.caseIndex = caseIndex;
P.case_id = char(string(row.case_id));
P.source_dataset = char(string(row.source_dataset));
P = configureFromUnifiedRow(P, row, noEgr);
P = readLocalCalibration(P);
P = readLocalPressureCalibration(P);
P = readLocalThermalCalibration(P);
P = buildSimplifiedBenchParams(P);
P = buildSimplifiedInitialStates(P);
assignSimplifiedWorkspace(P);

if verbose
    fprintf('Initialized %s case %s, EGR %.4f.\n', ...
        P.modelName, P.case_id, P.egr_fraction_cmd);
end
end

function [noEgr, egr, allCases] = readSimplifiedBenchData(rootDir, ~)
% 读取当前唯一活动工况表。该表只保留模型边界、标定和审计真正依赖的字段，
% 并已经合并原始无 EGR 点和 0608 CEGR 点。
% 第二个输入参数保留为 ~，说明现在不再需要 projectRoot 参与找数据。
dataFile = fullfile(rootDir, '00_输入参数', '实验数据', 'combined_noegr_cegr_fit_points.csv');
if ~isfile(dataFile)
    error('CEGR:SimplifiedBench:MissingData', 'Cannot find %s', dataFile);
end
allCases = readtable(dataFile, 'TextType', 'string');
allCases.case_index = (1:height(allCases)).';
allCases = normalizeUnifiedTable(allCases);
noEgr = allCases(allCases.is_no_egr == 1, :);
egr = allCases(allCases.is_no_egr == 0, :);
end

function T = normalizeUnifiedTable(T)
% 统一表字段类型。少数说明性字段保留为 string，其余字段尽量转成 double。
% 这样后续 requireFinite/isfinite 可以直接发现缺失或非法数值。
stringVars = ["case_id", "source_dataset", "source_file", "section", "date_label", ...
    "condition_note", "egr_fraction_source", "fresh_flow_lambda_use_note", ...
    "stoich_basis_note", "parse_notes"];
for k = 1:numel(stringVars)
    if ismember(stringVars(k), string(T.Properties.VariableNames))
        T.(stringVars(k)) = string(T.(stringVars(k)));
    end
end
numericVars = setdiff(string(T.Properties.VariableNames), stringVars);
for k = 1:numel(numericVars)
    name = numericVars(k);
    if iscell(T.(name)) || isstring(T.(name)) || ischar(T.(name))
        T.(name) = str2double(string(T.(name)));
    end
end
required = ["case_id", "source_dataset", "is_no_egr", ...
    "current_A", "current_density_A_cm2", "cell_voltage_V", "egr_fraction_model", ...
    "stack_in_flow_meter_SLPM", "bench_supply_flow_SLPM", ...
    "bench_supply_p_actual_kPa", "bench_supply_T_C", "bench_supply_RH_pct", ...
    "stack_in_p_kPa", "stack_in_T_C", "stack_in_RH_pct", ...
    "stack_out_p_kPa", "stack_out_T_C", "cathode_dp_kPa", ...
    "bench_out_p_kPa", "bench_out_T_C", ...
    "egr_return_p_kPa", "egr_return_T_C", "egr_return_RH_pct", ...
    "anode_stoich", "anode_in_p_kPa", "anode_in_T_C", "anode_in_RH_pct", ...
    "anode_out_p_kPa", ...
    "coolant_in_T_C", "coolant_out_T_C", "coolant_flow_L_min"];
% 对模型运行的最低必要字段做硬检查。缺字段直接报错，避免模型在错误输入下继续运行。
missing = setdiff(required, string(T.Properties.VariableNames));
if ~isempty(missing)
    error('CEGR:SimplifiedBench:BadDataTable', ...
        'Combined fitting table is missing required columns: %s', strjoin(missing, ', '));
end
end

function P = configureFromUnifiedRow(P, row, noEgr)
% 从单行统一工况表生成模型边界。这里是“实验数据 -> 模型输入”的核心映射层。
% 电流、电压、EGR 比例、入堆流量和入口/出口压力都从表里读取，不在脚本里临时猜测。
P.I_stack_default_A = requireFinite(row, "current_A");
P.current_density_A_cm2 = requireFinite(row, "current_density_A_cm2");
P.cell_voltage_bench_V = requireFinite(row, "cell_voltage_V");
P.egr_fraction_cmd = requireFinite(row, "egr_fraction_model");
validateEgrFraction(P.egr_fraction_cmd, "egr_fraction_model", row.case_id);

P.stack_in_flow_SLPM = requireFinite(row, "stack_in_flow_meter_SLPM");
validatePositive(P.stack_in_flow_SLPM, "stack_in_flow_meter_SLPM", row.case_id);
P.stack_in_flow_kg_s = slpmAirToKgS(P.stack_in_flow_SLPM);
P.fresh_supply_flow_SLPM = requireFinite(row, "bench_supply_flow_SLPM");
validatePositive(P.fresh_supply_flow_SLPM, "bench_supply_flow_SLPM", row.case_id);
P.fresh_supply_flow_kg_s = slpmAirToKgS(P.fresh_supply_flow_SLPM);

% 阴极供气边界。台架供气 p/T/RH 如果缺失，就用入堆 p/T/RH 作为等价边界。
% humidAirMassFractions 会把湿空气状态换算成质量分数，供模型常量块读取。
P.bench_stack_in_T_C = requireFinite(row, "stack_in_T_C");
P.bench_stack_in_p_kPa = requireFinite(row, "stack_in_p_kPa");
P.bench_stack_in_RH = percentToFraction(requireFinite(row, "stack_in_RH_pct"));
validateUnitFraction(P.bench_stack_in_RH, "stack_in_RH_pct", row.case_id);
P.bench_supply_gas_T_C = finiteOr(row.bench_supply_T_C, row.stack_in_T_C);
P.bench_supply_gas_p_kPa = finiteOr(row.bench_supply_p_actual_kPa, row.stack_in_p_kPa);
P.bench_supply_gas_RH = percentToFraction(finiteOr(row.bench_supply_RH_pct, row.stack_in_RH_pct));
validateUnitFraction(P.bench_supply_gas_RH, "bench_supply_RH_pct", row.case_id);
[P.cathode_supply_wO2, P.cathode_supply_wN2, P.cathode_supply_wH2O] = ...
    humidAirMassFractions(P, P.bench_supply_gas_p_kPa + P.p_amb_kPa, ...
    P.bench_supply_gas_T_C, P.bench_supply_gas_RH);
validateMassFractions([P.cathode_supply_wO2, P.cathode_supply_wN2, P.cathode_supply_wH2O], ...
    "cathode_supply_wO2/wN2/wH2O", row.case_id);
P.stack_out_p_kPa = row.stack_out_p_kPa;
P.stack_out_T_C = row.stack_out_T_C;
P.cathode_dp_kPa = row.cathode_dp_kPa;
P.egr_return_T_C = row.egr_return_T_C;
P.egr_return_p_kPa = row.egr_return_p_kPa;
P.egr_return_RH = percentToFraction(row.egr_return_RH_pct);
% EGR 工况必须有回流支路温度和压力；无 EGR 工况不实际经过分离器，
% 这里只用出口温压给 EGRInitialNode 一个数值初值。
if P.egr_fraction_cmd > 0
    P.separator_T_C = requireFinite(row, "egr_return_T_C");
    P.separator_p_kPa = requireFinite(row, "egr_return_p_kPa");
else
    P.separator_T_C = finiteOr(row.stack_out_T_C, row.bench_out_T_C);
    P.separator_p_kPa = finiteOr(row.stack_out_p_kPa, row.bench_out_p_kPa);
end

% 阳极和冷却边界。CEGR 表如果缺阳极/冷却实测值，数据整理阶段已经尽量补齐；
% ref 是按无 EGR 初始表插值得到的兜底参考，目前主要用于冷却入口/出口温度。
ref = interpNoEgr(noEgr, P.I_stack_default_A);
P.anode_stoich = requireFinite(row, "anode_stoich");
P.RH_an_in = percentToFraction(requireFinite(row, "anode_in_RH_pct"));
validateUnitFraction(P.RH_an_in, "anode_in_RH_pct", row.case_id);
P.anode_in_T_C = requireFinite(row, "anode_in_T_C");
P.p_anode_in_kPa = requireFinite(row, "anode_in_p_kPa") + P.p_amb_kPa;
P.p_anode_back_kPa = requireFinite(row, "anode_out_p_kPa") + P.p_amb_kPa;
P.anode_H2_dry_flow_kg_s = P.anode_stoich * ...
    P.I_stack_default_A * P.N_cell / (2 * P.F_C_mol) * P.M_H2_kg_mol;
[P.anode_in_wH2, P.anode_in_wH2O, P.anode_in_flow_kg_s] = ...
    humidHydrogenMassFractions(P, P.anode_H2_dry_flow_kg_s, ...
    P.p_anode_in_kPa, P.anode_in_T_C, P.RH_an_in);
validateMassFractions([P.anode_in_wH2, P.anode_in_wH2O], ...
    "anode_in_wH2/wH2O", row.case_id);
P.p_cathode_back_kPa = requireFinite(row, "stack_out_p_kPa") + P.p_amb_kPa;
P.T_cool_C = finiteOr(row.coolant_in_T_C, ref.coolant_in_T_C);
P.coolant_out_C = finiteOr(row.coolant_out_T_C, ref.coolant_out_T_C);
P.coolant_flow_L_min = requireFinite(row, "coolant_flow_L_min");

% Bench replay uses measured stack inlet mass flow as the inlet boundary.
end

function P = buildSimplifiedBenchParams(P)
% 把 P 结构体拆成 Simulink 模型常量块需要的几个向量。
% 模型端不直接读取 P，而是读取 PhysicalParam/StackModelParam/CaseBoundaryParam 等固定顺序向量。
P.egr_fraction_cmd_raw = P.egr_fraction_cmd;
if P.egr_fraction_cmd == 0
    P.egr_fraction_cmd = 0.0;
end

P.PhysicalParam = buildPhysicalParam(P);
P.StackModelParam = buildStackModelParam(P);
P.CaseBoundaryParam = buildCaseBoundaryParam(P);
P.CoolingCurveParam = buildCoolingCurveParam(P);
P.dt_s_simplified = P.dt_s;
end

function param = buildPhysicalParam(P)
% 物理常数向量，对应模型中的 PhysicalParam 常量块。
param = [
    P.R_J_molK
    P.F_C_mol
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.M_H2_kg_mol
    P.p_amb_kPa
    P.T_amb_C
    ];
end

function param = buildStackModelParam(P)
% 电堆模型参数向量，对应 PEMFCStackCore 的 stackModel 输入。
% 注意这个顺序必须和 Simulink MATLAB Function 里的索引完全一致。
param = [
    P.N_cell
    P.A_cell_cm2
    P.V_ca_m3
    P.V_an_m3
    P.K_ca_out_kg_s_kPa
    P.K_an_out_kg_s_kPa
    P.C_stack_J_K
    P.h_cool_W_K
    P.h_amb_W_K
    P.E_nernst_ref_V
    P.E_nernst_temp_coeff_V_K
    P.ASR0_ohm_cm2
    P.j0_c_A_cm2
    P.conc_loss_c
    P.iL_A_cm2
    P.sigma_pem_correction
    P.alpha_O2
    P.thermoneutralVoltage_V
    P.tau_mem_s
    ];
end

function param = buildCaseBoundaryParam(P)
% 单工况边界向量，对应模型中的 CaseBoundaryParam 常量块。
% 压力在进入模型前统一转为绝压：实验表中多数压力是表压，因此加 p_amb_kPa。
param = [
    P.I_stack_default_A
    P.bench_stack_in_p_kPa + P.p_amb_kPa
    P.bench_stack_in_T_C
    P.stack_in_flow_kg_s
    P.cathode_supply_wO2
    P.cathode_supply_wN2
    P.cathode_supply_wH2O
    P.p_cathode_back_kPa
    P.separator_T_C
    P.separator_p_kPa + P.p_amb_kPa
    P.egr_fraction_cmd
    P.anode_in_flow_kg_s
    P.anode_in_wH2
    P.anode_in_wH2O
    P.p_anode_back_kPa
    P.T_cool_C
    P.coolant_flow_L_min
    ];
end

function param = buildCoolingCurveParam(P)
% 冷却曲线向量：开关 + 流量断点 + 换热系数断点。
param = [
    P.cool_flow_curve_enabled
    P.cool_flow_curve_L_min(:)
    P.cool_flow_curve_h_W_K(:)
    ];
end

function P = readLocalCalibration(P)
% 读取本地电压/膜水标定参数。如果没有标定 CSV，就使用 defaults 文件中的默认值。
% CSV 可以按字段名覆盖 P，也可以按 stack_model_index 覆盖 StackModelParam 中的指定位置。
P.tau_mem_s = 1.0;

paramDir = fullfile(P.rootDir, '00_输入参数', '标定参数');
stackFile = fullfile(paramDir, 'simplified_noegr_stack_params.csv');
if isfile(stackFile)
    T = readtable(stackFile, 'TextType', 'string');
    for k = 1:height(T)
        name = char(string(T.parameter(k)));
        value = double(T.value(k));
        if isfield(P, name)
            P.(name) = value;
        elseif ismember("stack_model_index", string(T.Properties.VariableNames)) && isfinite(T.stack_model_index(k))
            idx = round(T.stack_model_index(k));
            P = applyLocalStackModelIndex(P, idx, value);
        end
    end
end
end

function P = readLocalThermalCalibration(P)
% 读取本地热参数标定结果。当前只允许覆盖冷却流量-换热系数曲线的 h 值。
paramDir = fullfile(P.rootDir, '00_输入参数', '标定参数');
thermalFile = fullfile(paramDir, 'simplified_thermal_params.csv');
if ~isfile(thermalFile)
    return;
end
T = readtable(thermalFile, 'TextType', 'string');
required = ["parameter", "curve_index", "value"];
if any(~ismember(required, string(T.Properties.VariableNames)))
    error('CEGR:SimplifiedBench:BadThermalCalibration', ...
        'Thermal calibration file must contain parameter, curve_index, value.');
end
for k = 1:height(T)
    name = string(T.parameter(k));
    idx = round(double(T.curve_index(k)));
    value = double(T.value(k));
    if name == "cool_flow_curve_h_W_K"
        if idx < 1 || idx > numel(P.cool_flow_curve_h_W_K) || ~isfinite(value) || value <= 0
            error('CEGR:SimplifiedBench:BadThermalCalibration', ...
                'Invalid cooling curve row %d in %s.', k, thermalFile);
        end
        P.cool_flow_curve_h_W_K(idx) = value;
    end
end
end

function P = readLocalPressureCalibration(P)
% 读取本地气路压力标定结果。当前只允许覆盖电堆气腔体积和出口等效导纳。
paramDir = fullfile(P.rootDir, '00_输入参数', '标定参数');
pressureFile = fullfile(paramDir, 'simplified_pressure_params.csv');
if ~isfile(pressureFile)
    return;
end
T = readtable(pressureFile, 'TextType', 'string');
required = ["parameter", "stack_model_index", "value"];
if any(~ismember(required, string(T.Properties.VariableNames)))
    error('CEGR:SimplifiedBench:BadPressureCalibration', ...
        'Pressure calibration file must contain parameter, stack_model_index, value.');
end
for k = 1:height(T)
    idx = round(double(T.stack_model_index(k)));
    value = double(T.value(k));
    if ~isfinite(value) || value <= 0
        error('CEGR:SimplifiedBench:BadPressureCalibration', ...
            'Invalid pressure calibration row %d in %s.', k, pressureFile);
    end
    switch idx
        case 3
            P.V_ca_m3 = value;
        case 4
            P.V_an_m3 = value;
        case 5
            P.K_ca_out_kg_s_kPa = value;
        case 6
            P.K_an_out_kg_s_kPa = value;
        otherwise
            error('CEGR:SimplifiedBench:BadPressureCalibration', ...
                'Unsupported pressure calibration StackModelParam index %d.', idx);
    end
end
end

function P = applyLocalStackModelIndex(P, idx, value)
% 把 CSV 中的 StackModelParam 索引映射回 P 的字段名。
% 这里只开放当前简化模型允许标定的参数，避免任意索引误改模型结构参数。
switch idx
    case 12
        P.ASR0_ohm_cm2 = value;
    case 13
        P.j0_c_A_cm2 = value;
    case 14
        P.conc_loss_c = value;
    case 15
        P.iL_A_cm2 = value;
    case 16
        P.sigma_pem_correction = value;
    case 17
        P.alpha_O2 = value;
    case 18
        P.thermoneutralVoltage_V = value;
    case 19
        P.tau_mem_s = value;
end
end

function P = buildSimplifiedInitialStates(P)
% 根据当前工况边界估算 UnitDelay 的初始状态。
% 前 5 个状态是阴极/阳极气体质量，第 6 个是电堆温度，第 7 个是膜水通量松弛状态。
T0_K = P.bench_stack_in_T_C + 273.15;
pDry = max(P.bench_stack_in_p_kPa + P.p_amb_kPa, P.p_amb_kPa);
pV = min(max(P.bench_stack_in_RH, 0) * satKPa(P.bench_stack_in_T_C), 0.98 * pDry);
pO2 = max((pDry - pV) * P.xO2_dry, 1e-6);
pN2 = max((pDry - pV) * P.xN2_dry, 1e-6);
pH2 = max(P.p_anode_in_kPa * 0.85, 1e-6);
pH2OvAn = min(P.RH_an_in * satKPa(P.bench_stack_in_T_C), 0.30 * P.p_anode_in_kPa);
P.stack_initial_state = [
    pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * T0_K)
    pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * T0_K)
    pV * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * T0_K)
    pH2 * 1000 * P.V_an_m3 * P.M_H2_kg_mol / (P.R_J_molK * T0_K)
    pH2OvAn * 1000 * P.V_an_m3 * P.M_H2O_kg_mol / (P.R_J_molK * T0_K)
    P.bench_stack_in_T_C
    0
    ];
% EGR 回流初始节点包含 O2/N2/H2O/液水流量、温度、压力和液水标志。
% 无 EGR 工况这里仍给一个合法初值，但模型中 EGR 比例为 0，不形成有效回流。
P.egr_initial_node = zeros(7, 1);
P.egr_initial_node(5) = P.separator_T_C;
P.egr_initial_node(6) = P.separator_p_kPa + P.p_amb_kPa;
end

function assignSimplifiedWorkspace(P)
% 把模型运行所需变量写入 base workspace。Simulink 常量块和 UnitDelay 初值会读取这些名字。
% 代码审查注意：assignin 一般不推荐滥用，但这里是 Simulink 工作区接口的一部分。
assignin('base', 'P_simplified_egr', P);
assignin('base', 'PhysicalParam_simplified', P.PhysicalParam);
assignin('base', 'StackModelParam_simplified', P.StackModelParam);
assignin('base', 'CaseBoundaryParam_simplified', P.CaseBoundaryParam);
assignin('base', 'CoolingCurveParam_simplified', P.CoolingCurveParam);
assignin('base', 'dt_s_simplified', P.dt_s_simplified);
assignin('base', 'StackInitialState_simplified', P.stack_initial_state);
assignin('base', 'EGRInitialNode_simplified', P.egr_initial_node);
end

function r = interpNoEgr(T, currentA)
% 按电流对原始无 EGR 数据插值，给缺失的阳极/冷却参考量提供一致的基准。
% 如果某列只有一个有效值就直接沿用；没有有效值则保留 NaN，让后续检查暴露问题。
vars = T.Properties.VariableNames;
T = T(string(T.source_dataset) == "initial_noegr_steady_xlsx", :);
if isempty(T)
    error('CEGR:SimplifiedBench:MissingReferenceNoEgr', ...
        'No initial no-EGR rows are available for anode/coolant fallback interpolation.');
end
r = T(1, :);
for k = 1:numel(vars)
    v = T.(vars{k});
    if isnumeric(v)
        valid = isfinite(T.current_A) & isfinite(v);
        if nnz(valid) >= 2
            r.(vars{k}) = interp1(T.current_A(valid), v(valid), currentA, 'linear', 'extrap');
        elseif nnz(valid) == 1
            r.(vars{k}) = v(find(valid, 1, 'first'));
        else
            r.(vars{k}) = NaN;
        end
    end
end
end

function f = percentToFraction(v)
% 把 0~100 的百分数转换成 0~1 的比例；已经是 0~1 的值保持不变。
f = v;
idx = isfinite(f) & abs(f) > 1;
f(idx) = f(idx) / 100;
end

function validateUnitFraction(v, name, caseId)
% 实验边界输入必须显式落在 0~1。超界值应暴露为数据错误，而不是在模型中截断。
if ~isfinite(v) || v < 0 || v > 1
    error('CEGR:SimplifiedBench:InvalidUnitFraction', ...
        'Invalid fraction "%s" for case %s: %.12g. Expected 0..1 after percent conversion.', ...
        name, string(caseId), v);
end
end

function validateEgrFraction(v, name, caseId)
% EGR 分流比例是实验/整理表给出的边界；超界必须报错，不能静默夹取。
if ~isfinite(v) || v < 0 || v > 0.95
    error('CEGR:SimplifiedBench:InvalidEgrFraction', ...
        'Invalid EGR fraction "%s" for case %s: %.12g. Expected 0..0.95.', ...
        name, string(caseId), v);
end
end

function validatePositive(v, name, caseId)
% 流量类边界必须为正。0 或负值会让混合器质量守恒失去物理意义。
if ~isfinite(v) || v <= 0
    error('CEGR:SimplifiedBench:InvalidPositiveValue', ...
        'Invalid positive value "%s" for case %s: %.12g.', ...
        name, string(caseId), v);
end
end

function validateMassFractions(w, name, caseId)
% 质量分数是边界条件。负值或全零会隐藏输入映射错误，必须在初始化阶段报错。
if any(~isfinite(w)) || any(w < 0) || sum(w) <= 0
    error('CEGR:SimplifiedBench:InvalidMassFractions', ...
        'Invalid mass fractions "%s" for case %s.', name, string(caseId));
end
end

function [wO2, wN2, wH2O] = humidAirMassFractions(P, pAbsKPa, T_C, RH)
% 湿空气摩尔分数 -> 质量分数。模型中的气体节点用质量流量/质量分数表达，
% 因此需要把 RH 和饱和蒸汽压换算成水蒸气比例。
pH2O = min(RH * satKPa(T_C), 0.98 * pAbsKPa);
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

function [wH2, wH2O, totalFlow] = humidHydrogenMassFractions(P, dryH2Flow, pAbsKPa, T_C, RH)
% 湿氢气边界换算。先由 RH 得到水蒸气分压，再按摩尔比把干氢流量换成水蒸气流量。
pH2O = min(RH * satKPa(T_C), 0.98 * pAbsKPa);
vaporRatio = max(pH2O, 0) / max(pAbsKPa - pH2O, 1e-6);
vaporFlow = dryH2Flow / P.M_H2_kg_mol * vaporRatio * P.M_H2O_kg_mol;
totalFlow = max(dryH2Flow + vaporFlow, 1e-12);
wH2 = dryH2Flow / totalFlow;
wH2O = vaporFlow / totalFlow;
end

function v = finiteOr(a, b)
% 优先取 a；如果 a 是 NaN/Inf，则取 b。用于“实验表缺局部供气值时采用入堆值”的场景。
if isfinite(a)
    v = a;
else
    v = b;
end
end

function v = requireFinite(row, name)
% 读取必需字段，并要求它是有限数值。这个函数是输入数据质量的硬门槛。
v = row.(name);
if ~isfinite(v)
    error('CEGR:SimplifiedBench:MissingRequiredValue', ...
        'Missing required numeric value "%s" for case %s.', ...
        name, string(row.case_id));
end
end

function m = slpmAirToKgS(slpm)
% 把标准升/分钟换算成 kg/s。1.293 kg/m3 是当前采用的标准空气密度近似。
m = slpm * 1.293 / 60000;
end

function p = satKPa(T)
% Antoine 型经验公式，返回给定摄氏温度下的饱和水蒸气压，单位 kPa。
Tc = min(max(T, -40), 120);
p = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end
