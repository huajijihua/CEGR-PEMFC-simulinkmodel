function P = init_testbench_10kw_simplified_defaults()
%INIT_TESTBENCH_10KW_SIMPLIFIED_DEFAULTS Defaults for the simplified bench model.
%
% This file is scoped to CEGR_TestBench_10kW_SimplifiedEGR_v01 only. It does
% not call or inherit from the vehicle v3 initialization scripts.
%
% 在当前简化台架模型体系中的作用：
% 1. 这是 Simulink 主模型的“默认参数字典”，不是仿真执行脚本。
% 2. 集中定义物理常数、环境条件、电堆几何、出口等效导纳、
%    热参数、电压模型默认参数、膜水时间常数和冷却曲线。
% 3. 工况相关字段先给 NaN 或基础默认值，后续由
%    init_testbench_10kw_simplified_egr.m 根据实验表覆盖。
% 4. 这样可以把“模型结构参数”和“单个实验工况输入”分开，
%    便于追踪某个数值来自模型假设还是测试数据。

% 这个函数只负责给 P 结构体填入“没有具体工况时也必须存在”的默认值。
% 主初始化脚本会在读取实验表后覆盖其中大部分工况边界。这样做的好处是：
% 1) 所有字段先集中定义，后续脚本不容易因为字段缺失报错；
% 2) 默认参数和实验工况参数分开，便于判断某个数值到底来自模型假设还是测试数据。
P = struct();

% Physical constants and ambient boundary.
% 物理常数和环境条件。单位写在变量名里，例如 kg_mol 表示 kg/mol，kPa 表示千帕。
% xO2_dry/xN2_dry 是干空气摩尔分数，用于把湿空气边界换算成 O2/N2/H2O 质量分数。
P.R_J_molK = 8.314462618;
P.F_C_mol = 96485.33212;
P.M_O2_kg_mol = 0.031998;
P.M_N2_kg_mol = 0.0280134;
P.M_H2O_kg_mol = 0.01801528;
P.M_H2_kg_mol = 0.00201588;
P.p_amb_kPa = 101.325;
P.T_amb_C = 25.0;
P.xO2_dry = 0.2095;
P.xN2_dry = 0.7905;

% Stack geometry and flow/thermal closure used by the simplified bench SLX.
% 电堆几何、气体库存体积、出口等效导纳和热容/换热系数。
% 这些量不直接来自单个工况表，而是模型结构参数；其中 K_ca_out_kg_s_kPa
% 会影响“内部阴极压力-出口背压”形成的出堆流量。
P.N_cell = 16;
P.A_cell_cm2 = 380.0;
P.V_ca_m3 = 2.0e-4;
P.V_an_m3 = 1.5e-4;
P.K_ca_out_kg_s_kPa = 1.2e-4;
P.K_an_out_kg_s_kPa = 6.67e-6;
P.C_stack_J_K = 4.5e4;
P.h_cool_W_K = 836.0;
P.h_amb_W_K = 9.0;

% Voltage fit defaults for the simplified bench fit.
% 电压标定默认值。PEMFCStackCore 内部直接固定书籍参考常数：
% alpha_H2=0.5, I0_a=0.1 A/cm2, I_leak=0.01 A/cm2,
% delta_PEM=25 um, sigma_PEM 修正系数=0.21, rho_PEM=1980 kg/m3, EW=1.1 kg/mol。
% 这里保留最基础的电压拟合/占位参数：
% 当前拟合 ASR0、I0_c、sigma_PEM 修正系数和 alpha_O2；
% 浓差系数 c 和极限电流密度 Ilim 仅保留为接口占位，当前 etaCon=0。
P.E_nernst_ref_V = 1.229;
P.E_nernst_temp_coeff_V_K = 8.5e-4;
P.ASR0_ohm_cm2 = 1.0e-4;
P.j0_c_A_cm2 = 3.0e-6;
P.conc_loss_c = 0.3;
P.iL_A_cm2 = 10.0;
P.sigma_pem_correction = 0.21;
P.alpha_O2 = 0.3;
P.thermoneutralVoltage_V = 1.254;
P.tau_mem_s = 1.0;

% Cooling curve used by the simplified stack heat balance.
% 冷却流量-等效换热系数曲线。模型运行时会把当前工况冷却流量映射到 h_cool。
% 第一项 enabled 是开关，后面两组数组分别是流量断点和对应换热系数。
P.cool_flow_curve_enabled = 1.0;
P.cool_flow_curve_L_min = [5.5 6.0 6.5 7.5 9.1 10.0 11.1 11.5];
P.cool_flow_curve_h_W_K = [836.0 836.0 905.666666666667 1045.0 ...
    1267.93333333334 1393.33333333333 1546.6 1602.33333333333];

% Case-level defaults overwritten by the measured bench case table.
% 工况级变量先给 NaN，是有意设计：如果实验表缺关键值，后续 requireFinite 会直接报错，
% 不会悄悄用默认值把缺失数据掩盖掉。只有 egr_fraction_cmd 给 0，表示默认无 EGR。
P.I_stack_default_A = 38.0;
P.current_density_A_cm2 = NaN;
P.cell_voltage_bench_V = NaN;
P.egr_fraction_cmd = 0.0;
P.stack_in_flow_SLPM = NaN;
P.stack_in_flow_kg_s = NaN;
P.fresh_supply_flow_SLPM = NaN;
P.fresh_supply_flow_kg_s = NaN;
P.bench_stack_in_T_C = NaN;
P.bench_stack_in_p_kPa = NaN;
P.bench_stack_in_RH = NaN;
P.stack_out_p_kPa = NaN;
P.stack_out_T_C = NaN;
P.cathode_dp_kPa = NaN;
P.separator_T_C = NaN;
P.separator_p_kPa = NaN;
P.anode_stoich = NaN;
P.RH_an_in = NaN;
P.p_anode_in_kPa = NaN;
P.p_anode_back_kPa = NaN;
P.p_cathode_back_kPa = NaN;
P.T_cool_C = NaN;
P.coolant_out_C = NaN;
P.coolant_flow_L_min = NaN;
end
