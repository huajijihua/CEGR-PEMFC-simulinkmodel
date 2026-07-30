# Route A P1 面板能力矩阵

状态：P1 面板直驱迭代中；矩阵用于开发期接线追踪，用户运行主路径是当前窗口的单工况操作。

本文件是人类可读索引；可执行矩阵以 `03_脚本/RouteA_GasMixture_Derived/routeA_p1_panel_capability_matrix.m` 为准。矩阵从参数注册表和观测注册表读回名称、单位、状态，并补充 UI 属性、`simCase` 路径、`SimulationInput` 写入点、结果链接、owner 和后续阶段。矩阵和契约脚本只用于开发期接线、排错和必要回归，不是用户运行面板前必须完成的研究验收包。

## P1 当前工作口径

P1 当前只追求一条通顺的面板直驱链：用户在基础或高级视图选择模式、勾选开关、输入合法数值，面板将值收集到 `simCase`，经 `routeA_validate_case` 和 `routeA_panel_build_simulation_input` 传入当前正式模型；模型实际运行后，状态、KPI、可观测域和失败信息返回同一窗口。

开发期脚本可以帮助发现映射遗漏和无效输入，但不替代模型实际计算，也不要求重复旧的 600 s/3600 s、cEGR 矩阵或历史研究工况。P1 的 cEGR 仅保留 0 和 0.3 两个简单示例，其他合法目标值直接由用户面板输入。

## 计数与边界

| 项目 | 当前读回 | 说明 |
|---|---:|---|
| 旧计划 active 基线 | 25 | 仅用于追溯计划初始计数 |
| 当前 active 参数 | 40 | 原 active 项 + 10 个本轮阳极输入；以注册表实际读回为准 |
| P1 result 观测 | 22 | 进入结果契约和 `signalManifest` |
| status-only / unresolved | 4 | 阳极入口/出口压力、阳极 purge、冷却侧响应；阳极输入已 active，阳极结果仍待确认 |
| cEGR 控制入口 | 1 | 目标比例 profile；不同时开放阀面积命令 |
| 研究矩阵 | 0 | P1 只运行独立单工况 |

## 参数映射

| 域 | `canonicalName` | UI 属性 | `simCase` 路径 | 写入点 / 时序 | 观测链接 |
|---|---|---|---|---|---|
| 电边界 | `electrical.mode` | `BoundaryModeDropDown` / `AdvancedBoundaryModeDropDown` | `controls.electrical.mode` | 电负载 `input_type` | stack I/V/P |
| 电边界 | `electrical.current.profile` | boundary command | `controls.electrical.profile` | `drive_cycle_current` | stack I/V/P |
| 电边界 | `electrical.power.profile` | boundary command | `controls.electrical.profile` | `drive_cycle_power` | stack I/V/P |
| 电边界 | `electrical.voltage.profile` | boundary command | `controls.electrical.profile` | `drive_cycle_voltage` | stack I/V/P |
| Voltage PI | `electrical.voltageController.Kp_A_V` | `AdvancedKpEditField` | `controls.electrical.voltageController.Kp_A_V` | `routeA_voltage_pi_Kp` | voltage/current response |
| Voltage PI | `electrical.voltageController.Ki_A_V_s` | `AdvancedKiEditField` | `controls.electrical.voltageController.Ki_A_V_s` | `routeA_voltage_pi_Ki` | voltage/current response |
| Voltage PI | `electrical.voltageController.currentMin_A` | `AdvancedCurrentMinEditField` | `controls.electrical.voltageController.currentMin_A` | `routeA_voltage_current_min_A` | current limit |
| Voltage PI | `electrical.voltageController.currentMax_A` | `AdvancedCurrentMaxEditField` | `controls.electrical.voltageController.currentMax_A` | `routeA_voltage_current_max_A` | current limit |
| 阴极空气 | `cathode.airControlMode` | air mode dropdown | `controls.cathode.airControlMode` | `routeA_air_control_mode_id` | compressor flow / cEGR |
| 阴极空气 | `cathode.targetOer` | OER edit field | `controls.cathode.targetOer` | `air_target_oer` profile | inlet air response |
| 阴极空气 | `cathode.targetMdot_kg_s` | target mdot edit field | `controls.cathode.targetMdot_kg_s` | `air_target_mdot_kg_s` profile | compressor inlet mdot |
| 阴极空气 | `cathode.directCommand` | direct command edit field | `controls.cathode.directCommand` | `air_direct_command` profile | compressor inlet mdot |
| 阴极空气 | `cathode.sourcePressure_MPa_abs` | `AdvancedSourcePressureEditField` | `controls.cathode.sourcePressure_MPa_abs` | cathode source profile | inlet pressure |
| 阴极空气 | `cathode.sourceTemperature_C` | `AdvancedSourceTemperatureEditField` | `controls.cathode.sourceTemperature_C` | cathode source profile | inlet temperature |
| 阴极空气 | `cathode.outletPressure_MPa_abs` | backpressure edit field | `controls.cathode.outletPressure_MPa_abs` | outlet pressure profile | outlet pressure |
| 阴极空气 | `cathode.humidifierRH` | RH edit field | `controls.cathode.humidifierRH` | humidifier RH profile | inlet/outlet RH |
| 阴极空气 | `cathode.humidifierEnabled` | humidifier checkbox | `controls.cathode.humidifierEnabled` | humidifier gain profile | inlet/outlet RH |
| 阴极组分 | `cathode.o2MoleFraction` | `AdvancedO2EditField` | `controls.cathode.o2MoleFraction` | `env_yO2` compile-time variable | inlet composition |
| 阴极组分 | `cathode.h2oMoleFraction` | `AdvancedH2OEditField` | `controls.cathode.h2oMoleFraction` | `env_yH20` compile-time variable | inlet composition / RH |
| cEGR | `cegr.enabled` | cEGR checkbox | `controls.cegr.enabled` | `routeA_cegr_enabled` | actual ratio / mdot |
| cEGR | `cegr.targetRatio` | cEGR ratio edit field | `controls.cegr.targetRatio` | `cegr_ratio` profile | actual ratio / error / mdot |
| cEGR | `cegr.valveMode` | valve mode dropdown | `controls.cegr.valveMode` | `routeA_cegr_valve_mode_id` | valve area / pressure |
| cEGR | `cegr.controlMode` | control mode dropdown | `controls.cegr.controlMode` | `routeA_egr_control_mode_id` | control error |
| cEGR | `cegr.targetInputMode` | target input dropdown | `controls.cegr.targetInputMode` | `routeA_egr_target_input_mode_id` | actual ratio |
| 热管理 | `thermal.stackTemperatureSet_C` | stack temperature edit field | `controls.thermal.stackTemperatureSet_C` | `stack_temperature_set_C` profile | stack temperature |
| 求解器 | `solver.stopTime_s` | stop time edit field | `solver.stopTime_s` | model `StopTime` | signal time range |
| 求解器 | `solver.solver` | `AdvancedSolverDropDown` | `solver.solver` | model `Solver` | solver provenance |
| 求解器 | `solver.relTol` | `AdvancedRelTolEditField` | `solver.relTol` | model `RelTol` | solver provenance |
| 求解器 | `solver.absTol` | `AdvancedAbsTolEditField` | `solver.absTol` | model `AbsTol` | solver provenance |
| 求解器 | `solver.maxStep_s` | `AdvancedMaxStepEditField` | `solver.maxStep_s` | model `MaxStep` | solver provenance |
| 阳极 | `anode.sourcePressure_MPa_abs` | `AnodeSourcePressureEditField` | `controls.anode.sourcePressure_MPa_abs` | `routeA_command_profile.anode_source_pressure_MPa_abs` | 输入已接入；结果 status-only |
| 阳极 | `anode.sourceTemperature_C` | `AnodeSourceTemperatureEditField` | `controls.anode.sourceTemperature_C` | `routeA_command_profile.anode_source_temperature_C` | 输入已接入；结果 status-only |
| 阳极 | `anode.h2MoleFraction` | `AnodeH2EditField` | `controls.anode.h2MoleFraction` | `tank_yH2` + `routeA_command_profile.anode_source_h2_mole_fraction` | 编译时组分 + profile |
| 阳极 | `anode.inletPressure_MPa_abs` | `AnodeInletPressureEditField` | `controls.anode.inletPressure_MPa_abs` | `routeA_command_profile.anode_inlet_pressure_MPa_abs` | 输入已接入；结果 status-only |
| 阳极 | `anode.humidifierRH` | `AnodeHumidifierRHEditField` | `controls.anode.humidifierRH` | `routeA_command_profile.anode_humidifier_rh` | 输入已接入；结果 status-only |
| 阳极 | `anode.recirculationBaseCommand` | `AnodeRecirculationBaseEditField` | `controls.anode.recirculationBaseCommand` | `routeA_command_profile.anode_recirculation_base` | 输入已接入；结果 status-only |
| 阳极 | `anode.recirculationCurrentGain_A_inv` | `AnodeRecirculationGainEditField` | `controls.anode.recirculationCurrentGain_A_inv` | `routeA_command_profile.anode_recirculation_current_gain_A_inv` | 输入已接入；结果 status-only |
| 阳极 | `anode.purgeEnabled` | `AnodePurgeEnabledCheckBox` | `controls.anode.purgeEnabled` | `routeA_command_profile.anode_purge_enable` | 开关已接入；结果 status-only |
| 阳极 | `anode.purgeOnN2MoleFraction` | `AnodePurgeOnN2EditField` | `controls.anode.purgeOnN2MoleFraction` | `routeA_command_profile.anode_purge_on_n2_mole_fraction` | 阈值顺序校验 |
| 阳极 | `anode.purgeOffN2MoleFraction` | `AnodePurgeOffN2EditField` | `controls.anode.purgeOffN2MoleFraction` | `routeA_command_profile.anode_purge_off_n2_mole_fraction` | 阈值顺序校验 |

所有控件统一经过 `routeA_validate_case`，面板 callback 不直接改模型。air mode 是互斥控制源：1=质量流量，2=OER，3=direct command。P1 cEGR 只允许 target-ratio 主入口，阀面积和开度只能作为诊断结果。

## P1 输入栏完成边界与操作语义

P1 只把已经闭合到 `SimulationInput` 的输入做成可操作控件，控件类型与模型语义保持一致：

| 控件语义 | P1 做法 | 当前有效性 |
|---|---|---|
| 模式选择 | 电边界 `Current / Power / Voltage`、空气模式 `质量流量 / OER / 空压机命令`、cEGR 阀模式 | 下拉选择；每次只保留一个主控制源；空压机命令为归一化执行命令 `[0,1]` |
| 二值开关 | 加湿器启用、cEGR 启用 | 勾选后对应输入生效；取消后输入禁用，cEGR 目标按 0 进入本次 case |
| 数值输入 | 命令值、ramp、空气目标、入口/出口边界、RH、组分、堆温、solver 容差和 PI 限幅 | 统一进入 `simCase`，由 `routeA_validate_case` 在仿真前拒止非法值 |
| P1 固定选择 | cEGR 控制模式=目标比例、目标输入=cEGR 比例、solver=`VariableStepAuto` | 控件保留来源可追溯性，但不开放当前 runner 不支持的替代项 |
| 只读/后续 | 阳极结果观测、冷却泵/散热器、液水库存/排液、阀面积主控、设备 map | 已接入阳极输入可编辑；未闭合参数仍只读目录或后续入口 |

基础视图只保留常用且已闭合的电边界、空气控制、背压/RH/加湿器、cEGR 目标、堆温和仿真时长。高级视图补充入口压力/温度、O2/H2O、阀模式、Voltage PI 和 solver 容差；在基础/高级之间切换不会重置高级专属值。空气模式、Voltage PI、加湿器 RH 和 cEGR 目标会随当前开关/模式联动启用或禁用，灰显值不会作为当前有效控制源。阴极 RH 是加湿器出口/阴极入口 RH，温度参考是共享 `T_stack`/加湿温度；高级页的阴极源温度是新鲜空气入口边界。模式 3 的空压机命令仍经过空压机图谱，不是直接给电堆气体。

P1 的实际仿真验证只选 `cEGR=0` 与 `cEGR=0.3` 两个简单面板 case。Current/Power/Voltage、三种 air mode 和非法输入通过无仿真接口审计覆盖，不构成研究矩阵。

## 结果观测映射

| 域 | `canonicalName` | 来源信号 | 结果路径 | 状态 |
|---|---|---|---|---|
| stack | `stack.current` | `routeA_stack_current_A` | `domains.stack.current_A` | verified |
| stack | `stack.voltage` | `routeA_stack_voltage_V` | `domains.stack.voltage_V` | verified |
| stack | `stack.power` | `routeA_stack_power_kW` / V*I | `domains.stack.power_kW` | optional |
| stack | `stack.temperature` | `routeA_stack_temperature_C` | `domains.stack.temperature_C` | verified |
| cathode | `cathode.compressorInletMassFlow` | `routeA_mdot_comp_inlet` | `domains.cathode.compressorInletMassFlow_kg_s` | verified |
| cathode | `cathode.compressorInletPressure` | `routeA_p_comp_inlet` | `domains.cathode.compressorInletPressure_Pa` | verified |
| cathode | `cathode.compressorInletTemperature` | `routeA_T_comp_inlet` | `domains.cathode.compressorInletTemperature_K` | verified |
| cathode | `cathode.inletSpeciesMassFlow` | `routeA_mdot_species_ca_in_ts` | `domains.cathode.inletSpeciesMassFlow_kg_s` | verified |
| cathode | `cathode.inletComposition` | `routeA_yi_comp_inlet` | `domains.cathode.inletComposition` | verified |
| cathode | `cathode.outletComposition` | `routeA_yi_outlet` | `domains.cathode.outletComposition` | verified |
| cathode | `cathode.inletRelativeHumidity` | `routeA_RH_ca_in_ts` | `domains.cathode.inletRelativeHumidity` | verified |
| cathode | `cathode.outletRelativeHumidity` | `routeA_RH_ca_out_ts` | `domains.cathode.outletRelativeHumidity` | verified |
| cathode | `cathode.outletPressure` | `routeA_p_outlet` | `domains.cathode.cathodeOutletPressure_MPa` | verified |
| cathode | `cathode.outletTemperature` | `routeA_T_outlet` | `domains.cathode.cathodeOutletTemperature_K` | verified |
| cathode | `cathode.exhaustMassFlow` | `routeA_exhaust_mdot_ts` | observation manifest | optional |
| water | `cathode.waterSeparationRate` | `routeA_m_water_sep_ts` | `domains.cathode.waterSeparationRate_kg_s` | optional |
| cEGR | `cegr.actualRatio` | `routeA_egr_ratio_comp_in` | `domains.cegr.actualRatio` | verified |
| cEGR | `cegr.controlError` | `routeA_egr_control_error` | `domains.cegr.control` | verified |
| cEGR | `cegr.massFlow` | `EGR_mdot_log` | `domains.cegr.massFlow_kg_s` | verified |
| cEGR | `cegr.valveUpstreamPressure` | `routeA_p_egr_valve_up` | `domains.cegr.valveUpstreamPressure_Pa` | verified |
| cEGR | `cegr.valveDownstreamPressure` | `routeA_p_egr_valve_down` | `domains.cegr.valveDownstreamPressure_Pa` | verified |
| cEGR | `cegr.valveAreaCommand` | `routeA_egr_valve_area_cmd` | `domains.cegr.valveArea_m2` | optional |
| anode / thermal | 4 status-only entries | unresolved | no result field | P4 |

水域的能力状态固定保留 `L2_not_closed`，只展示气相与凝结通量证据；不宣称完整液水库存、液水输运、排水或分离器效率闭合。cEGR 能力分类固定为 `tracking_verified`、`control_not_tracking`、`capacity_or_limit`、`disabled_or_zero_target`、`not_observable`。

## Gate 状态

| Gate | 当前状态 |
|---|---|
| W0/G0 | 参数/观测/控件映射用于开发追踪，活动链路持续迭代 |
| W1/G1 | 单文件面板和域布局已实现，继续按窗口操作反馈迭代 |
| W2/G2 | I/P/V、三种 air mode、solver 和非法输入校验已接线 |
| W3/G3 | 温度、RH、组分、出口温度和 L2 水能力已接线 |
| W4 | cEGR 诊断和能力分类已接线，0/0.3 作为简单验证样本 |
| W5/G4 | v02 结果契约、failureStack、signalManifest、full export 回读已接线 |
| W6/G5 | 面板直驱链作为主线；acceptance/contract runner 仅保留为可选开发工具 |
| G6 | 保持最新面板窗口打开，由用户进行面板-模型联合评审 |
