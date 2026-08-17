# Route A 模型-面板参数汇总表 v01

本表由 `routeA_audit_parameter_inventory.m` 从当前 `.slx` 的模型工作区和 `Simulink.findVars` 生成。模型引用是参数有效性的唯一依据；面板可写项必须指向实际被模型引用的写入目标。

- 模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01`
- 生成时间：2026-08-12 08:57:49
- 模型 Dirty：`off`
- 2026-08-14 语义更新：阴极 separator 参数按 L2 流阻/边界代理解释，不代表已闭合的液水分离器工程参数。

## 覆盖摘要

| 项目 | 数量 | 含义 |
|---|---:|---|
| 模型工作区变量 | 138 | 当前 `.slx` 保存的变量 |
| 被模型实际引用的工作区变量 | 86 | `Simulink.findVars` 在模型范围内检出 |
| 面板活动参数 | 102 | 通过统一 `simCase -> SimulationInput` 链路应用 |
| 面板写入目标未被模型引用 | 0 | 必须移出可写面板或补齐模型接线 |
| 模型已引用但尚未开放为面板活动参数 | 5 | 保留目录并按验证准入决定是否开放 |

## 数量口径与从属关系

以下三组数字使用不同计数单位，不能直接相加：模型工作区按变量计数，面板按输入契约条目计数，设备目录按设备参数目录条目计数。

- 模型工作区变量：`138 = 86 实际引用 + 52 未引用/辅助 + 0 面板映射但未被引用`。
- 实际引用变量：`86 = 81 已由面板承接 + 5 已引用但待开放`。
- 活动面板参数：`102` 个契约条目，按页签拆分为基础/高级/设备页；其中可能包含非工作区输入、一个条目写入多个变量，以及图谱数组和几何派生写入，因此不与工作区变量数相加。
- 设备页目录：`129 = 54 可编辑字段 + 74 platform_default 源目录 + 1 未接入审查`；空压机三数组作为一个图谱编辑器组原子提交，但在参数契约中保留三条数组记录。

状态解释：模型已引用/面板已承接 = 已闭合输入链；库边界已验证/面板已承接 = 通过库封装边界生效；模型已引用/待开放 = 真实模型变量但当前只读；未引用/工作区辅助 = 当前不参与模型行为；platform_default 源目录 = 默认参数叶项，不是独立面板输入；未接入审查 = 已登记但尚未绑定活动块参数；异常 = 面板映射或写入目标未被模型引用，需要修复。

## 面板输入与模型写入链

| 面板参数 | 页签 | 单位 | 范围 | 工作区变量 | 时序字段 | 实际写入目标 | 派生写入目标 | 写入方式 | 引用状态 |
|---|---|---|---|---|---|---|---|---|---|
| electrical.mode | 基础页可编辑 | - | 结构化数据/由专用校验器约束 | - | - | - | - | collect_and_validate | 非工作区输入 / 运行配置 |
| electrical.current.profile | 基础页可编辑 | A | [0, 392] | drive_cycle_current | - | drive_cycle_current | drive_cycle_time | collect_and_validate | 库边界已验证 / 面板已承接 |
| electrical.power.profile | 基础页可编辑 | kW | [0, 150] | drive_cycle_power | - | drive_cycle_power | drive_cycle_time | collect_and_validate | 库边界已验证 / 面板已承接 |
| electrical.voltage.profile | 基础页可编辑 | V | [0, 500] | drive_cycle_voltage | - | drive_cycle_voltage | drive_cycle_time | collect_and_validate | 模型写入目标已引用 |
| electrical.voltageController.Kp_A_V | 高级页可编辑 | A/V | [0, Inf] | routeA_voltage_pi_Kp | - | routeA_voltage_pi_Kp | - | compile_and_smoke | 模型写入目标已引用 |
| electrical.voltageController.Ki_A_V_s | 高级页可编辑 | A/V/s | [0, Inf] | routeA_voltage_pi_Ki | - | routeA_voltage_pi_Ki | - | compile_and_smoke | 模型写入目标已引用 |
| electrical.voltageController.currentMin_A | 高级页可编辑 | A | [0, 392] | routeA_voltage_current_min_A | - | routeA_voltage_current_min_A | - | compile_and_smoke | 模型写入目标已引用 |
| electrical.voltageController.currentMax_A | 高级页可编辑 | A | [0, 392] | routeA_voltage_current_max_A | - | routeA_voltage_current_max_A | - | compile_and_smoke | 模型写入目标已引用 |
| cathode.airControlMode | 基础页可编辑 | - | [1, 3] | routeA_air_control_mode_id | - | routeA_air_control_mode_id | - | compile_and_smoke | 模型写入目标已引用 |
| cathode.targetOer | 基础页可编辑 | - | [1.5, 5] | routeA_command_profile | air_target_oer | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.targetMdot_kg_s | 基础页可编辑 | kg/s | [0, Inf] | routeA_command_profile | air_target_mdot_kg_s | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.directCommand | 基础页可编辑 | - | [0, 1] | routeA_command_profile | air_direct_command | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.sourcePressure_MPa_abs | 高级页可编辑 | MPa(abs) | [0.1, 0.5] | routeA_command_profile | cathode_source_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.sourceTemperature_C | 高级页可编辑 | degC | [10, 60] | routeA_command_profile | cathode_source_temperature_C | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.outletPressure_MPa_abs | 基础页可编辑 | MPa(abs) | [0.1, 0.3] | routeA_command_profile | cathode_outlet_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.humidifierRH | 基础页可编辑 | - | [0, 1] | routeA_command_profile | cathode_humidifier_rh | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.humidifierEnabled | 基础页可编辑 | - | [0, 1] | routeA_command_profile | cathode_humidifier_gain | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cathode.o2MoleFraction | 高级页可编辑 | - | [0.15, 0.21] | env_yO2 | - | env_yO2 | - | compile_and_smoke | 模型写入目标已引用 |
| cathode.h2oMoleFraction | 高级页可编辑 | - | [0.005, 0.04] | env_yH20 | - | env_yH20 | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.enabled | 基础页可编辑 | - | [0, 1] | routeA_cegr_enabled | - | routeA_cegr_enabled | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.targetRatio | 基础页可编辑 | - | [0, 0.5] | routeA_command_profile | cegr_ratio | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| cegr.valveMode | 高级页可编辑 | - | [1, 2] | routeA_cegr_valve_mode_id | - | routeA_cegr_valve_mode_id | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.controlMode | 高级页可编辑 | - | [1, 2] | routeA_egr_control_mode_id | - | routeA_egr_control_mode_id | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.targetInputMode | 高级页可编辑 | - | [1, 1] | routeA_egr_target_input_mode_id | - | routeA_egr_target_input_mode_id | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.controller.Kp_area | 高级页可编辑 | m^2 | [2.220446e-16, Inf] | routeA_egr_control_Kp_area | - | routeA_egr_control_Kp_area | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.controller.Ki_area | 高级页可编辑 | m^2/s | [2.220446e-16, Inf] | routeA_egr_control_Ki_area | - | routeA_egr_control_Ki_area | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.actuatorTau_s | 设备页可编辑 | s | [2.220446e-16, Inf] | routeA_egr_valve_actuator_tau | - | routeA_egr_valve_actuator_tau | - | compile_and_smoke | 模型写入目标已引用 |
| anode.sourcePressure_MPa_abs | 高级页可编辑 | MPa(abs) | [0.2, 0.5] | routeA_command_profile | anode_source_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.sourceTemperature_C | 高级页可编辑 | degC | [10, 60] | routeA_command_profile | anode_source_temperature_C | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.h2MoleFraction | 高级页可编辑 | - | [0.9, 1] | tank_yH2 | anode_source_h2_mole_fraction | routeA_command_profile | tank_yH2 | compile_and_smoke | 模型写入目标已引用 |
| anode.inletPressure_MPa_abs | 高级页可编辑 | MPa(abs) | [0.1, 0.3] | routeA_command_profile | anode_inlet_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.humidifierRH | 高级页可编辑 | - | [0, 1] | routeA_command_profile | anode_humidifier_rh | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.recirculationBaseCommand | 高级页可编辑 | - | [0, 1] | routeA_command_profile | anode_recirculation_base | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.recirculationCurrentGain_A_inv | 高级页可编辑 | 1/A | [0, 1] | routeA_command_profile | anode_recirculation_current_gain_A_inv | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.purgeEnabled | 高级页可编辑 | - | [0, 1] | routeA_command_profile | anode_purge_enable | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.purgeOnN2MoleFraction | 高级页可编辑 | - | [0, 1] | routeA_command_profile | anode_purge_on_n2_mole_fraction | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| anode.purgeOffN2MoleFraction | 高级页可编辑 | - | [0, 1] | routeA_command_profile | anode_purge_off_n2_mole_fraction | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| stack.numCells | 设备页可编辑 | - | [1, 1000] | stack_num_cells | - | stack_num_cells | - | compile_and_smoke | 模型写入目标已引用 |
| stack.area_cm2 | 设备页可编辑 | cm^2 | [1, 1000] | stack_area | - | stack_area | - | compile_and_smoke | 模型写入目标已引用 |
| stack.iL_A_cm2 | 设备页可编辑 | A/cm^2 | [0.001, 5] | stack_iL | - | stack_iL | - | compile_and_smoke | 模型写入目标已引用 |
| stack.io_A_cm2 | 设备页可编辑 | A/cm^2 | [1e-08, 0.1] | stack_io | - | stack_io | - | compile_and_smoke | 模型写入目标已引用 |
| device.stack.alpha | 设备页可编辑 | - | [0.1, 1.5] | stack_alpha | - | stack_alpha | - | compile_and_smoke | 模型写入目标已引用 |
| device.stack.meaCp_J_kgK | 设备页可编辑 | J/(kg*K) | [100, 5000] | stack_mea_cp | - | stack_mea_cp | - | compile_and_smoke | 模型写入目标已引用 |
| device.stack.meaRho_kg_m3 | 设备页可编辑 | kg/m^3 | [100, 5000] | stack_mea_rho | - | stack_mea_rho | - | compile_and_smoke | 模型写入目标已引用 |
| device.stack.gdlThickness_um | 设备页可编辑 | um | [1, 2000] | stack_t_gdl | - | stack_t_gdl | - | compile_and_smoke | 模型写入目标已引用 |
| device.stack.membraneThickness_um | 设备页可编辑 | um | [1, 1000] | stack_t_membrane | - | stack_t_membrane | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.intercoolerMdotNominal_kg_s | 设备页可编辑 | kg/s | [2.220446e-16, 1] | intercooler_mdot_nominal | - | intercooler_mdot_nominal | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.intercoolerDpNominal_MPa | 设备页可编辑 | MPa | [0, 0.1] | intercooler_dp_nominal | - | intercooler_dp_nominal | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.intercoolerArea_m2 | 设备页可编辑 | m^2 | [1e-08, 0.1] | intercooler_area | - | intercooler_area | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.intercoolerLaminarFraction | 设备页可编辑 | - | [0, 1] | intercooler_laminar_fraction | - | intercooler_laminar_fraction | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.separatorMdotNominal_kg_s | 设备页可编辑 | kg/s | [2.220446e-16, 1] | cathode_separator_mdot_nominal | - | cathode_separator_mdot_nominal | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.separatorDpNominal_MPa | 设备页可编辑 | MPa | [0, 0.1] | cathode_separator_dp_nominal | - | cathode_separator_dp_nominal | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.separatorArea_m2 | 设备页可编辑 | m^2 | [1e-08, 0.1] | cathode_separator_area | - | cathode_separator_area | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.separatorLaminarFraction | 设备页可编辑 | - | [0, 1] | cathode_separator_laminar_fraction | - | cathode_separator_laminar_fraction | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.mixerVolume_L | 设备页可编辑 | L | [2.220446e-16, 1000] | comp_inlet_mixer_V | - | comp_inlet_mixer_V | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.outletChamberVolume_L | 设备页可编辑 | L | [2.220446e-16, 1000] | cathode_outlet_chamber_V | - | cathode_outlet_chamber_V | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.compressorMap.rpm_TLU | 设备页可编辑 | rpm | 结构化数据/由专用校验器约束 | comp_rpm_TLU | - | comp_rpm_TLU | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.compressorMap.p_ratio_TLU | 设备页可编辑 | - | 结构化数据/由专用校验器约束 | comp_p_ratio_TLU | - | comp_p_ratio_TLU | - | compile_and_smoke | 模型写入目标已引用 |
| device.cathode.compressorMap.mdot_corr_TLU | 设备页可编辑 | kg/s | 结构化数据/由专用校验器约束 | comp_mdot_corr_TLU | - | comp_mdot_corr_TLU | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.valveMaxArea_m2 | 设备页可编辑 | m^2 | [2.220446e-16, 1] | cegr_valve_max_area | - | cegr_valve_max_area | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.pipeLength_m | 设备页可编辑 | m | [0.0001, 100] | cegr_pipe_length | - | cegr_pipe_length | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.pipeDiameter_m | 设备页可编辑 | m | [0.0001, 1] | cegr_pipe_D | - | cegr_pipe_D | cegr_pipe_area | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.pipeRoughness_m | 设备页可编辑 | m | [0, 0.01] | cegr_pipe_roughness | - | cegr_pipe_roughness | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.condensationTau_s | 设备页可编辑 | s | [2.220446e-16, 1000] | cegr_cond_tau | - | cegr_cond_tau | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.inletMixerPressure_MPa_abs | 设备页可编辑 | MPa(abs) | [0.01, 1] | cegr_inlet_mixer_p0 | - | cegr_inlet_mixer_p0 | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.outletChamberPressure_MPa_abs | 设备页可编辑 | MPa(abs) | [0.01, 1] | cegr_outlet_chamber_p0 | - | cegr_outlet_chamber_p0 | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.pipeExtraLength_m | 设备页可编辑 | m | [0, 100] | cegr_pipe_extra_length | - | cegr_pipe_extra_length | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.pipePressure_MPa_abs | 设备页可编辑 | MPa(abs) | [0.01, 1] | cegr_pipe_p0 | - | cegr_pipe_p0 | - | compile_and_smoke | 模型写入目标已引用 |
| device.cegr.valveOpenMinArea_m2 | 设备页可编辑 | m^2 | [1e-12, 1] | cegr_valve_open_min_area | - | cegr_valve_open_min_area | - | compile_and_smoke | 模型写入目标已引用 |
| device.anode.tankPressure_MPa | 设备页可编辑 | MPa | [0.1, 100] | tank_p | - | tank_p | - | compile_and_smoke | 模型写入目标已引用 |
| device.anode.tankVolume_L | 设备页可编辑 | L | [2.220446e-16, 100000] | tank_V | - | tank_V | - | compile_and_smoke | 模型写入目标已引用 |
| device.anode.tankTemperature_C | 设备页可编辑 | degC | [-50, 150] | tank_T | - | tank_T | - | compile_and_smoke | 模型写入目标已引用 |
| device.anode.separatorArea_m2 | 设备页可编辑 | m^2 | [1e-08, 0.1] | anode_separator_area | - | anode_separator_area | - | compile_and_smoke | 模型写入目标已引用 |
| device.anode.separatorLaminarFraction | 设备页可编辑 | - | [0, 1] | anode_separator_laminar_fraction | - | anode_separator_laminar_fraction | - | compile_and_smoke | 模型写入目标已引用 |
| device.anode.separatorMdotNominal_kg_s | 设备页可编辑 | kg/s | [2.220446e-16, 1] | anode_separator_mdot_nominal | - | anode_separator_mdot_nominal | - | compile_and_smoke | 模型写入目标已引用 |
| device.anode.separatorDpNominal_MPa | 设备页可编辑 | MPa | [0, 0.1] | anode_separator_dp_nominal | - | anode_separator_dp_nominal | - | compile_and_smoke | 模型写入目标已引用 |
| environment.ambientTemperature_C | 高级页可编辑 | degC | [-50, 100] | env_T | - | env_T | - | compile_and_smoke | 模型写入目标已引用 |
| environment.ambientPressure_MPa_abs | 固定平台边界 / 只读 | MPa(abs) | [0.101325, 0.101325] | env_p | - | env_p | - | fixed_platform_default | 模型写入目标已引用 |
| cathode.airController.Kp | 高级页可编辑 | - | [2.220446e-16, Inf] | routeA_air_pid_Kp | - | routeA_air_pid_Kp | - | compile_and_smoke | 模型写入目标已引用 |
| cathode.airController.Ki | 高级页可编辑 | 1/s | [2.220446e-16, Inf] | routeA_air_pid_Ki | - | routeA_air_pid_Ki | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.directValveArea_m2 | 高级页可编辑 | m^2 | [1e-12, 1] | routeA_egr_valve_area_direct | - | routeA_egr_valve_area_direct | - | compile_and_smoke | 模型写入目标已引用 |
| cegr.directTargetRatio | 高级页可编辑 | - | [0, 0.5] | routeA_target_egr_ratio_comp_in | - | routeA_target_egr_ratio_comp_in | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.coolantGeometry.channelWidth_cm | 设备页可编辑 | cm | [0.2, 2] | coolant_w_channels | - | coolant_w_channels | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.coolantGeometry.numLayers | 设备页可编辑 | - | [1, 100] | coolant_num_layers | - | coolant_num_layers | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.coolantGeometry.numPasses | 设备页可编辑 | - | [1, 50] | coolant_num_passes | - | coolant_num_passes | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.coolantGeometry.tubeDiameter_m | 设备页可编辑 | m | [0.01, 0.1] | coolant_tube_D | - | coolant_tube_D | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.length_m | 设备页可编辑 | m | [0.2, 2] | radiator_L | - | radiator_L | radiator_tube_Leq | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.width_m | 设备页可编辑 | m | [0.005, 0.1] | radiator_W | - | radiator_W | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.height_m | 设备页可编辑 | m | [0.1, 1] | radiator_air_area_primary | - | radiator_air_area_primary | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.tubeCount | 设备页可编辑 | - | [2, 100] | radiator_N_tubes | - | radiator_N_tubes | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.tubeHeight_m | 设备页可编辑 | m | [0.0005, 0.01] | radiator_tube_H | - | radiator_tube_H | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.finSpacing_m | 设备页可编辑 | m | [0.0005, 0.01] | radiator_air_area_fins | - | radiator_air_area_fins | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.finEfficiency | 设备页可编辑 | - | [0.3, 1] | radiator_eta_fin | - | radiator_eta_fin | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.wallThickness_m | 设备页可编辑 | m | [1e-05, 0.001] | radiator_t_wall | - | radiator_t_wall | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.density_kg_m3 | 设备页可编辑 | kg/m^3 | [500, 5000] | radiator_rho | - | radiator_rho | - | compile_and_smoke | 模型写入目标已引用 |
| device.thermal.radiatorCore.specificHeat_J_kgK | 设备页可编辑 | J/(kg*K) | [300, 1500] | radiator_cp | - | radiator_cp | - | compile_and_smoke | 模型写入目标已引用 |
| thermal.stackTemperatureSet_C | 基础页可编辑 | degC | [60, 100] | routeA_stack_temperature_set_C | stack_temperature_set_C | routeA_command_profile | - | collect_and_validate | 模型写入目标已引用 |
| solver.stopTime_s | 基础页可编辑 | s | [0, Inf] | - | - | - | - | collect_and_validate | 非工作区输入 / 运行配置 |
| solver.solver | 高级页可编辑 | - | 结构化数据/由专用校验器约束 | - | - | - | - | collect_and_validate | 非工作区输入 / 运行配置 |
| solver.relTol | 高级页可编辑 | - | [2.220446e-16, 1] | - | - | - | - | collect_and_validate | 非工作区输入 / 运行配置 |
| solver.absTol | 高级页可编辑 | - | [2.220446e-16, Inf] | - | - | - | - | collect_and_validate | 非工作区输入 / 运行配置 |
| solver.maxStep_s | 高级页可编辑 | s | [0, Inf] | - | - | - | - | collect_and_validate | 非工作区输入 / 运行配置 |

## 模型工作区参数

| 变量 | 默认值摘要 | 类型/尺寸 | 物理含义/功能 | 开放处置 | 模型引用状态 | 所属子系统/块 | 面板承接参数 | 面板权限 |
|---|---|---|---|---|---|---|---|---|
| Gas_properties_block | PEMFuelCellSystem_Before_v01/Anode_Hydrogen_BOP/Gas Mixture<br>Properties | char [1 70] | 气体混合物属性配置或候选列表 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| Gas_properties_candidates | cell[1 1] | cell [1 1] | 气体混合物属性配置或候选列表 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| T_TLU | double[1 115] | double [1 115] | 水蒸气饱和性质查表数据 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| anode_separator_D | 0.02 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| anode_separator_T0 | 20 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| anode_separator_area | 0.00031415927 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | device.anode.separatorArea_m2 | 设备页可编辑 |
| anode_separator_dp_nominal | 0.0005 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | device.anode.separatorDpNominal_MPa | 设备页可编辑 |
| anode_separator_extra_length | 0.04 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| anode_separator_laminar_fraction | 0.001 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | device.anode.separatorLaminarFraction | 设备页可编辑 |
| anode_separator_length | 0.12 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| anode_separator_mdot_nominal | 0.01 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | device.anode.separatorMdotNominal_kg_s | 设备页可编辑 |
| anode_separator_p0 | 0.101325 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| anode_separator_roughness | 1.5e-05 | double [1 1] | 阳极分离器流阻与初始状态参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| anode_tube_D | 0.02 | double [1 1] | 模型内部配置或辅助参数 | 只读：多块共享的内部管路几何；需结构一致性验证后再考虑开放 | 模型已引用 / 待开放 | Anode_Hydrogen_BOP/Anode Exhaust/Convective Heat<br>Transfer; Anode_Hydrogen_BOP/Anode Exhaust/Environment; Anode_Hydrogen_BOP/Anode Exhaust/Max Area; ... (+5) | - | - |
| cathode_outlet_chamber_V | 0.2 | double [1 1] | 模型内部配置或辅助参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/CathodeOutletChamber | device.cathode.outletChamberVolume_L | 设备页可编辑 |
| cathode_separator_D | 0.05 | double [1 1] | 阴极分离边界的流阻/初始状态代理；不等同于分离器几何实物 | 暂不作为工程分离效率参数；需完成官方模块来源、写入和响应审查 | 未引用 / 工作区辅助 | - | - | - |
| cathode_separator_T0 | 20 | double [1 1] | 阴极分离边界的温度代理；不等同于液水分离器温度 | 暂不作为工程设备参数；需完成边界语义审查 | 未引用 / 工作区辅助 | - | - | - |
| cathode_separator_area | 0.0019634954 | double [1 1] | 阴极分离边界流阻代理面积；不代表分离效率或允许含液率 | 模型已引用 / 面板已承接；仅作 L2 代理，不得用于工程分离结论 | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorArea_m2 | 设备页可编辑 |
| cathode_separator_dp_nominal | 0.0005 | double [1 1] | 阴极分离边界名义压降代理 | 模型已引用 / 面板已承接；需标记为流阻代理，不得解释为真实分离器压损 | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorDpNominal_MPa | 设备页可编辑 |
| cathode_separator_extra_length | 0.05 | double [1 1] | 阴极分离边界附加长度代理 | 暂不作为工程设备几何参数 | 未引用 / 工作区辅助 | - | - | - |
| cathode_separator_laminar_fraction | 0.001 | double [1 1] | 阴极分离边界流阻模型的层流分数代理 | 模型已引用 / 面板已承接；不代表液滴分离特性 | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorLaminarFraction | 设备页可编辑 |
| cathode_separator_length | 0.15 | double [1 1] | 阴极分离边界长度代理 | 暂不作为工程设备几何参数 | 未引用 / 工作区辅助 | - | - | - |
| cathode_separator_mdot_nominal | 0.1 | double [1 1] | 阴极分离边界名义质量流量代理 | 模型已引用 / 面板已承接；不代表分离器处理能力 | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorMdotNominal_kg_s | 设备页可编辑 |
| cathode_separator_p0 | 0.101325 | double [1 1] | 阴极分离边界初始压力代理 | 暂不作为工程设备参数 | 未引用 / 工作区辅助 | - | - | - |
| cathode_separator_roughness | 1.5e-05 | double [1 1] | 阴极分离边界粗糙度代理 | 暂不作为工程设备几何参数 | 未引用 / 工作区辅助 | - | - | - |
| cathode_tube_D | 0.05 | double [1 1] | 模型内部配置或辅助参数 | 只读：多块共享的内部管路几何；需结构一致性验证后再考虑开放 | 模型已引用 / 待开放 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor<br>Volume; Cathode_Exhaust_Backpressure_Water/Cathode Exhaust/Convective Heat<br>Transfer1; ... (+3) | - | - |
| cegr_comp_map_t_denom_epsilon | 1e-09 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 只读：压缩机图谱数值保护量，不代表设备性能设定 | 模型已引用 / 待开放 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/TDenGuardBias | - | - |
| cegr_cond_tau | 1 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRPipe; Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer; Stack_Core/CathodeOutletChamber | device.cegr.condensationTau_s | 设备页可编辑 |
| cegr_inlet_mixer_p0 | 0.101325 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer | device.cegr.inletMixerPressure_MPa_abs | 设备页可编辑 |
| cegr_outlet_chamber_p0 | 0.101325 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/CathodeOutletChamber | device.cegr.outletChamberPressure_MPa_abs | 设备页可编辑 |
| cegr_pipe_D | 0.05 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipeDiameter_m | 设备页可编辑 |
| cegr_pipe_area | 0.0019634954 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRPipe; Cathode_Air_cEGR_BOP/EGRValveRestriction/Open/LocalRestriction; Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer; ... (+2) | device.cegr.pipeDiameter_m | 设备页可编辑 |
| cegr_pipe_extra_length | 0.1 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipeExtraLength_m | 设备页可编辑 |
| cegr_pipe_length | 0.5 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipeLength_m | 设备页可编辑 |
| cegr_pipe_p0 | 0.101325 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipePressure_MPa_abs | 设备页可编辑 |
| cegr_pipe_roughness | 1.5e-05 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipeRoughness_m | 设备页可编辑 |
| cegr_valve_max_area | 0.00019634954 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRValveRestriction/Open/LocalRestriction; System_Control_Observability/FCU_BoP_Control/EGR Area Limit; System_Control_Observability/FCU_BoP_Control/EGR Ratio PI; ... (+1) | device.cegr.valveMaxArea_m2 | 设备页可编辑 |
| cegr_valve_open_min_area | 1e-10 | double [1 1] | cEGR 回流管、阀或支路控制参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRValveRestriction/Open/LocalRestriction; System_Control_Observability/FCU_BoP_Control/EGR Area Limit; System_Control_Observability/FCU_BoP_Control/EGR Ratio PI | device.cegr.valveOpenMinArea_m2 | 设备页可编辑 |
| comp_inlet_mixer_V | 0.1 | double [1 1] | 阴极空压机入口容积或特性图谱参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer | device.cathode.mixerVolume_L | 设备页可编辑 |
| comp_mdot_corr_TLU | double[5 3] | double [5 3] | 阴极空压机入口容积或特性图谱参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/Corrected Flow<br>Table | device.cathode.compressorMap.mdot_corr_TLU | 设备页可编辑 |
| comp_p_ratio_TLU | [1;1.25;1.5;1.75;2] | double [5 1] | 阴极空压机入口容积或特性图谱参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/Corrected Flow<br>Table | device.cathode.compressorMap.p_ratio_TLU | 设备页可编辑 |
| comp_rpm_TLU | [0 1800 3600] | double [1 3] | 阴极空压机入口容积或特性图谱参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/A98_CompressorRpmCmd; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/Corrected Flow<br>Table; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Max rpm | device.cathode.compressorMap.rpm_TLU | 设备页可编辑 |
| coolant_num_layers | 20 | double [1 1] | 冷却回路几何、流阻或通道参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Fuel Cell<br>Coolant Channels | device.thermal.coolantGeometry.numLayers | 设备页可编辑 |
| coolant_num_passes | 12 | double [1 1] | 冷却回路几何、流阻或通道参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Fuel Cell<br>Coolant Channels | device.thermal.coolantGeometry.numPasses | 设备页可编辑 |
| coolant_tube_D | 0.05 | double [1 1] | 冷却回路几何、流阻或通道参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Flow Resistance (TL); Thermal_Management_BOP/Cooling System/Pump | device.thermal.coolantGeometry.tubeDiameter_m | 设备页可编辑 |
| coolant_w_channels | 1 | double [1 1] | 冷却回路几何、流阻或通道参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Fuel Cell<br>Coolant Channels | device.thermal.coolantGeometry.channelWidth_cm | 设备页可编辑 |
| drive_cycle_current | [0;0;100;100] | double [4 1] | 电边界命令时序或其辅助字段 | 可进入开放审查；需完成写入、范围和响应验证 | 库边界已验证 / 面板已承接 | - | electrical.current.profile | 基础页可编辑 |
| drive_cycle_power | [0;0;40;40] | double [4 1] | 电边界命令时序或其辅助字段 | 可进入开放审查；需完成写入、范围和响应验证 | 库边界已验证 / 面板已承接 | - | electrical.power.profile | 基础页可编辑 |
| drive_cycle_time | [0;0.5;60.5;600] | double [4 1] | 电边界命令时序或其辅助字段 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage Reference | electrical.current.profile, electrical.power.profile, electrical.voltage.profile | 基础页可编辑 |
| drive_cycle_voltage | [427.6;427.6;410;410] | double [4 1] | 电边界命令时序或其辅助字段 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage Reference | electrical.voltage.profile | 基础页可编辑 |
| env_RH | 0.5 | double [1 1] | 环境压力、温度、湿度或气体组分边界 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| env_T | 20 | double [1 1] | 环境压力、温度、湿度或气体组分边界 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Anode<br>Humidifier/Pipe (N Gas); Anode_Hydrogen_BOP/Anode Exhaust/Environment; Anode_Hydrogen_BOP/Anode Exhaust/Environment<br>Temperature; ... (+22) | environment.ambientTemperature_C | 高级页可编辑 |
| env_p | 0.101325 | double [1 1] | 环境压力、温度、湿度或气体组分边界 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Anode<br>Humidifier/Pipe (N Gas); Anode_Hydrogen_BOP/Anode Exhaust/Environment; Anode_Hydrogen_BOP/Anode Exhaust/Pipe (FC); ... (+11) | environment.ambientPressure_MPa_abs | 固定平台边界 / 只读 |
| env_pSat_H2O | 0.0023393182 | double [1 1] | 环境压力、温度、湿度或气体组分边界 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| env_yH20 | 0.011543638 | double [1 1] | 环境压力、温度、湿度或气体组分边界 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Anode Exhaust/Environment; Cathode_Air_cEGR_BOP/Cathode<br>Humidifier/Pipe (FC); Cathode_Air_cEGR_BOP/EGRPipe; ... (+7) | cathode.h2oMoleFraction | 高级页可编辑 |
| env_yO2 | 0.21 | double [1 1] | 环境压力、温度、湿度或气体组分边界 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Anode Exhaust/Environment; Cathode_Air_cEGR_BOP/Cathode<br>Humidifier/Pipe (FC); Cathode_Air_cEGR_BOP/EGRPipe; ... (+7) | cathode.o2MoleFraction | 高级页可编辑 |
| humidifier_bypass_mode | command_gain | string [1 1] | 加湿器工作状态或旁路配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| intercooler_Dh | 0.05 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| intercooler_T0 | 20 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| intercooler_area | 0.0019634954 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | device.cathode.intercoolerArea_m2 | 设备页可编辑 |
| intercooler_cond_tau | 1 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| intercooler_dp_nominal | 0.001 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | device.cathode.intercoolerDpNominal_MPa | 设备页可编辑 |
| intercooler_extra_length | 0.05 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| intercooler_laminar_fraction | 0.001 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | device.cathode.intercoolerLaminarFraction | 设备页可编辑 |
| intercooler_length | 0.25 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| intercooler_mdot_nominal | 0.1 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | device.cathode.intercoolerMdotNominal_kg_s | 设备页可编辑 |
| intercooler_p0 | 0.101325 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| intercooler_roughness | 1.5e-05 | double [1 1] | 阴极中冷器几何、流阻或换热参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| pSat_H2O_TLU | double[1 115] | double [1 115] | 水蒸气饱和性质查表数据 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| pSat_TLU | double[4 115] | double [4 115] | 水蒸气饱和性质查表数据 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| radiator_H | 0.5 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| radiator_L | 1 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Radiator | device.thermal.radiatorCore.length_m | 设备页可编辑 |
| radiator_N_fins | 12000 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| radiator_N_tubes | 25 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Radiator | device.thermal.radiatorCore.tubeCount | 设备页可编辑 |
| radiator_W | 0.025 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Radiator | device.thermal.radiatorCore.width_m | 设备页可编辑 |
| radiator_air_area_fins | 11.5625 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Convective Heat<br>Transfer; Thermal_Management_BOP/Cooling System/Thermal Mass | device.thermal.radiatorCore.finSpacing_m | 设备页可编辑 |
| radiator_air_area_primary | 1.223125 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Convective Heat<br>Transfer; Thermal_Management_BOP/Cooling System/Thermal Mass | device.thermal.radiatorCore.height_m | 设备页可编辑 |
| radiator_cp | 910 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Thermal Mass | device.thermal.radiatorCore.specificHeat_J_kgK | 设备页可编辑 |
| radiator_eta_fin | 0.7 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Convective Heat<br>Transfer | device.thermal.radiatorCore.finEfficiency | 设备页可编辑 |
| radiator_fin_spacing | 0.002 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| radiator_gap_H | 0.019270833 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| radiator_rho | 2700 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Thermal Mass | device.thermal.radiatorCore.density_kg_m3 | 设备页可编辑 |
| radiator_t_wall | 0.0001 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Thermal Mass | device.thermal.radiatorCore.wallThickness_m | 设备页可编辑 |
| radiator_tube_H | 0.0015 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Radiator | device.thermal.radiatorCore.tubeHeight_m | 设备页可编辑 |
| radiator_tube_Leq | 2.5 | double [1 1] | 散热器换热几何、材料或热容量参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Thermal_Management_BOP/Cooling System/Radiator | device.thermal.radiatorCore.length_m | 设备页可编辑 |
| routeA_air_control_mode_id | 2 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/A98_AirModeDirectCmd; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/A98_AirModeTargetMdot | cathode.airControlMode | 基础页可编辑 |
| routeA_air_pid_Ki | 0.5 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/PID Controller | cathode.airController.Ki | 高级页可编辑 |
| routeA_air_pid_Kp | 5 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/PID Controller | cathode.airController.Kp | 高级页可编辑 |
| routeA_anode_inlet_pressure_MPa_abs | 0.161325 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_anode_purge_enable | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_anode_purge_off_n2_mole_fraction | 0.1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_anode_purge_on_n2_mole_fraction | 0.5 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_anode_recirculation_base_command | 0.2 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_anode_recirculation_current_gain_A_inv | 0.0020408163 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_anode_rh_setpoint | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_backpressure_control_mode_id | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_cathode_humidifier_gain | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_cathode_rh_setpoint | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_cegr_enabled | 1 | logical [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | cEGR_Mode_Selector | cegr.enabled | 基础页可编辑 |
| routeA_cegr_valve_mode_id | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/EGRValveRestriction | cegr.valveMode | 高级页可编辑 |
| routeA_command_profile | double[4 23] | double [4 23] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/RouteA_Command_Profile/Command_Profile_Input | cathode.targetOer, cathode.targetMdot_kg_s, cathode.directCommand, cathode.sourcePressure_MPa_abs, cathode.sourceTemperature_C, cathode.outletPressure_MPa_abs, cathode.humidifierRH, cathode.humidifierEnabled, cegr.targetRatio, anode.sourcePressure_MPa_abs, anode.sourceTemperature_C, anode.h2MoleFraction, anode.inletPressure_MPa_abs, anode.humidifierRH, anode.recirculationBaseCommand, anode.recirculationCurrentGain_A_inv, anode.purgeEnabled, anode.purgeOnN2MoleFraction, anode.purgeOffN2MoleFraction, thermal.stackTemperatureSet_C | basic, advanced |
| routeA_command_profile_baseline | double[1 22] | double [1 22] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_command_profile_fields | cathode_source_pressure_MPa_abs       cathode_source_temperature_C          cathode_source_o2_mole_fraction       cathode_source_h2o_mole_fraction      air_target_mdot_kg_s                  air_target_oer                        air_direct_command                    cathode_outlet_pressure_MPa_abs       cathode_humidifier_rh                 cathode_humidifier_gain               cegr_ratio                            anode_source_pressure_MPa_abs         anode_source_temperature_C            anode_source_h2_mole_fraction         anode_inlet_pressure_MPa_abs          anode_humidifier_rh                   anode_recirculation_base              anode_recirculation_current_gain_A_invanode_purge_enable                    anode_purge_on_n2_mole_fraction       anode_purge_off_n2_mole_fraction      stack_temperature_set_C                | string [1 22] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_command_profile_schema | RouteA_Command_Profile_v10 | string [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_current_default_ref_A | 28 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_egr_control_Ki_area | 3.9269908e-05 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/EGR Ratio PI | cegr.controller.Ki_area | 高级页可编辑 |
| routeA_egr_control_Kp_area | 0.00019634954 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/EGR Ratio PI | cegr.controller.Kp_area | 高级页可编辑 |
| routeA_egr_control_mode_id | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/EGR Direct Mode Enable | cegr.controlMode | 高级页可编辑 |
| routeA_egr_target_input_mode_id | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/EGR_Target_Ratio_Profile_Mode | cegr.targetInputMode | 高级页可编辑 |
| routeA_egr_valve_actuator_tau | 0.5 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/EGR Area Actuator | cegr.actuatorTau_s | 设备页可编辑 |
| routeA_egr_valve_area_direct | 3.9269908e-06 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/Direct EGR Area | cegr.directValveArea_m2 | 高级页可编辑 |
| routeA_external_case_enabled | 0 | logical [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_parameter_layer | platform_default | string [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_stack_temperature_set_C | 80 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_target_egr_ratio_comp_in | 0.02 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/FCU_BoP_Control/Target EGR Ratio | cegr.directTargetRatio | 高级页可编辑 |
| routeA_voltage_current_max_A | 392 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.currentMax_A | 高级页可编辑 |
| routeA_voltage_current_min_A | 0 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.currentMin_A | 高级页可编辑 |
| routeA_voltage_default_ref_V | 394.9 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| routeA_voltage_pi_Ki | 0.05 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Raw PI Diagnostic; System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.Ki_A_V_s | 高级页可编辑 |
| routeA_voltage_pi_Kp | 1 | double [1 1] | Route A 运行、控制或接口配置 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Raw PI Diagnostic; System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.Kp_A_V | 高级页可编辑 |
| separator_condensation_enabled | 1 | logical [1 1] | L2 冷凝/分离能力配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| separator_l2_efficiency | 0.5 | double [1 1] | L2 冷凝/分离能力配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| separator_l2_source | l2_saturation_excess_estimator | string [1 1] | L2 冷凝/分离能力配置 | 可进入开放审查；需完成写入、范围和响应验证 | 未引用 / 工作区辅助 | - | - | - |
| stack_alpha | 0.7 | double [1 1] | 电堆 / MEA 性能或几何参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/Membrane Electrode<br>Assembly | device.stack.alpha | 设备页可编辑 |
| stack_area | 280 | double [1 1] | 每个单体有效活性面积 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/Constant; Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; ... (+3) | stack.area_cm2 | 设备页可编辑 |
| stack_iL | 1.4 | double [1 1] | 电化学极限电流密度 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/Constant; Stack_Core/Membrane Electrode<br>Assembly | stack.iL_A_cm2 | 设备页可编辑 |
| stack_io | 0.0001 | double [1 1] | 电化学交换电流密度 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/Membrane Electrode<br>Assembly | stack.io_A_cm2 | 设备页可编辑 |
| stack_mea_cp | 870 | double [1 1] | 电堆 / MEA 性能或几何参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/MEA<br>Thermal Mass | device.stack.meaCp_J_kgK | 设备页可编辑 |
| stack_mea_rho | 1800 | double [1 1] | 电堆 / MEA 性能或几何参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/MEA<br>Thermal Mass | device.stack.meaRho_kg_m3 | 设备页可编辑 |
| stack_num_cells | 400 | double [1 1] | 电堆串联单体数量 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/M_set; Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; ... (+4) | stack.numCells | 设备页可编辑 |
| stack_num_channels | 8 | double [1 1] | 电堆 / MEA 性能或几何参数 | 只读：通道结构/拓扑参数；改变可能影响编译、初始化和几何一致性 | 模型已引用 / 待开放 | Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; Stack_Core/Convective Heat<br>Transfer1; ... (+1) | - | - |
| stack_t_gdl | 250 | double [1 1] | 电堆 / MEA 性能或几何参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/MEA<br>Thermal Mass | device.stack.gdlThickness_um | 设备页可编辑 |
| stack_t_membrane | 125 | double [1 1] | 电堆 / MEA 性能或几何参数 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Stack_Core/MEA<br>Thermal Mass; Stack_Core/Membrane Electrode<br>Assembly | device.stack.membraneThickness_um | 设备页可编辑 |
| stack_w_channels | 1 | double [1 1] | 电堆 / MEA 性能或几何参数 | 只读：通道结构/拓扑参数；改变可能影响编译、初始化和几何一致性 | 模型已引用 / 待开放 | Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; Stack_Core/Convective Heat<br>Transfer1; ... (+1) | - | - |
| tank_T | 20 | double [1 1] | 阳极储氢罐状态或气体组分 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | device.anode.tankTemperature_C | 设备页可编辑 |
| tank_V | 120 | double [1 1] | 阳极储氢罐状态或气体组分 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | device.anode.tankVolume_L | 设备页可编辑 |
| tank_p | 70 | double [1 1] | 阳极储氢罐状态或气体组分 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | device.anode.tankPressure_MPa | 设备页可编辑 |
| tank_yH2 | 0.9997 | double [1 1] | 阳极储氢罐状态或气体组分 | 可进入开放审查；需完成写入、范围和响应验证 | 模型已引用 / 面板已承接 | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | anode.h2MoleFraction | 高级页可编辑 |

## 命名与冗余审计

该审计区分“同一物理量的重复写入”与“不同部件恰好同值”。只有前者才会合并或建立派生关系；相同的环境初值、两侧分离器参数等不视为冗余。

| 分类 | 规范输入 | 工作区变量 | 状态 | 证据 |
|---|---|---|---|---|
| active_derived_geometry | device.cegr.pipeDiameter_m | cegr_pipe_D; cegr_pipe_area | resolved | SimulationInput writes D and derives area=pi*D^2/4. |
| legacy_unbound_geometry | device.cathode.separatorArea_m2 | cathode_separator_D; cathode_separator_area | legacy_workspace_only_excluded | D is workspace-only; active FC block uses area. |
| legacy_unbound_geometry | device.anode.separatorArea_m2 | anode_separator_D; anode_separator_area | legacy_workspace_only_excluded | D is workspace-only; active FC block uses area. |
| legacy_unbound_geometry | - | intercooler_Dh; intercooler_area | legacy_workspace_only_excluded | Dh is workspace-only; active FC block uses area. |
| legacy_profile_shadow | routeA_command_profile | routeA_anode_*; routeA_cathode_*; routeA_backpressure_control_mode_id | workspace_only_excluded | The active control path reads the 22-column command profile, not these legacy scalars. |
| unbound_thermal_metadata | - | radiator_H; radiator_N_fins; radiator_fin_spacing; radiator_gap_H | workspace_only_no_platform_default | No active block references these items; H and N_fins were removed from platform defaults. |

## 维护规则

1. 新增面板输入前，必须先在本表中确认其“实际写入目标”为 `write_target_referenced`。
2. 模型引用但未开放的参数先在“系统模型参数”页保持只读目录状态，并进入开放审查；补足参数来源、范围、验证器和响应证据后转为可写，只有明确属于内部建模或初始化的变量继续只读。
3. `workspace_only` 变量不得被称为当前设备性能，除非后续确认对活动模型/面板计算链有用途、补齐块接线并重新审计；无用途的历史变量移除或归档。
4. 同一几何量若模型需同时使用直径与面积，只保留一个可编辑规范输入，其余变量必须在 `SimulationInput` 中由它推导。
5. 面板最终闭环必须保持为“输入基础/高级/设备参数 -> 运行统一模型 -> 返回结果”；“系统模型参数”只承担完整参数的只读解释和追溯。
