# Route A 模型-面板参数汇总表 v01

本表由 `routeA_audit_parameter_inventory.m` 从当前 `.slx` 的模型工作区和 `Simulink.findVars` 生成。模型引用是参数有效性的唯一依据；面板可写项必须指向实际被模型引用的写入目标。

- 模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01`
- 生成时间：2026-08-11 13:24:24
- 模型 Dirty：`off`

## 覆盖摘要

| 项目 | 数量 | 含义 |
|---|---:|---|
| 模型工作区变量 | 138 | 当前 `.slx` 保存的变量 |
| 被模型实际引用的工作区变量 | 86 | `Simulink.findVars` 在模型范围内检出 |
| 面板活动参数 | 72 | 通过统一 `simCase -> SimulationInput` 链路应用 |
| 面板写入目标未被模型引用 | 0 | 必须移出可写面板或补齐模型接线 |
| 模型已引用但尚未开放为面板活动参数 | 37 | 保留目录并按验证准入决定是否开放 |

状态解释：`model_referenced_panel_contract` 为已闭环；`library_boundary_verified` 为库封装边界、通过实际仿真验证；`model_referenced_no_active_panel_entry` 为模型真实参数但目前只读；`workspace_only` 为工作区闲置/辅助变量；`panel_entry_without_model_reference` 或 `write_target_not_referenced` 为不允许保留的失配。

## 面板输入与模型写入链

| 面板参数 | 页签 | 单位 | 范围 | 工作区变量 | 时序字段 | 实际写入目标 | 派生写入目标 | 写入方式 | 引用状态 |
|---|---|---|---|---|---|---|---|---|---|
| electrical.mode | basic | - | 结构化数据/由专用校验器约束 | - | - | - | - | collect_and_validate | non_workspace_input |
| electrical.current.profile | basic | A | [0, 392] | drive_cycle_current | - | drive_cycle_current | - | collect_and_validate | write_target_library_boundary_verified |
| electrical.power.profile | basic | kW | [0, 150] | drive_cycle_power | - | drive_cycle_power | - | collect_and_validate | write_target_library_boundary_verified |
| electrical.voltage.profile | basic | V | [0, 500] | drive_cycle_voltage | - | drive_cycle_voltage | - | collect_and_validate | write_target_referenced |
| electrical.voltageController.Kp_A_V | advanced | A/V | [0, Inf] | routeA_voltage_pi_Kp | - | routeA_voltage_pi_Kp | - | compile_and_smoke | write_target_referenced |
| electrical.voltageController.Ki_A_V_s | advanced | A/V/s | [0, Inf] | routeA_voltage_pi_Ki | - | routeA_voltage_pi_Ki | - | compile_and_smoke | write_target_referenced |
| electrical.voltageController.currentMin_A | advanced | A | [0, 392] | routeA_voltage_current_min_A | - | routeA_voltage_current_min_A | - | compile_and_smoke | write_target_referenced |
| electrical.voltageController.currentMax_A | advanced | A | [0, 392] | routeA_voltage_current_max_A | - | routeA_voltage_current_max_A | - | compile_and_smoke | write_target_referenced |
| cathode.airControlMode | basic | - | [1, 3] | routeA_air_control_mode_id | - | routeA_air_control_mode_id | - | compile_and_smoke | write_target_referenced |
| cathode.targetOer | basic | - | [1.5, 5] | routeA_command_profile | air_target_oer | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.targetMdot_kg_s | basic | kg/s | [0, Inf] | routeA_command_profile | air_target_mdot_kg_s | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.directCommand | basic | - | [0, 1] | routeA_command_profile | air_direct_command | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.sourcePressure_MPa_abs | advanced | MPa(abs) | [0.1, 0.5] | routeA_command_profile | cathode_source_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.sourceTemperature_C | advanced | degC | [10, 60] | routeA_command_profile | cathode_source_temperature_C | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.outletPressure_MPa_abs | basic | MPa(abs) | [0.1, 0.3] | routeA_command_profile | cathode_outlet_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.humidifierRH | basic | - | [0, 1] | routeA_command_profile | cathode_humidifier_rh | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.humidifierEnabled | basic | - | [0, 1] | routeA_command_profile | cathode_humidifier_gain | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cathode.o2MoleFraction | advanced | - | [0.15, 0.21] | env_yO2 | - | env_yO2 | - | compile_and_smoke | write_target_referenced |
| cathode.h2oMoleFraction | advanced | - | [0.005, 0.04] | env_yH20 | - | env_yH20 | - | compile_and_smoke | write_target_referenced |
| cegr.enabled | basic | - | [0, 1] | routeA_cegr_enabled | - | routeA_cegr_enabled | - | compile_and_smoke | write_target_referenced |
| cegr.targetRatio | basic | - | [0, 0.5] | routeA_command_profile | cegr_ratio | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| cegr.valveMode | advanced | - | [1, 2] | routeA_cegr_valve_mode_id | - | routeA_cegr_valve_mode_id | - | compile_and_smoke | write_target_referenced |
| cegr.controlMode | advanced | - | [1, 1] | routeA_egr_control_mode_id | - | routeA_egr_control_mode_id | - | compile_and_smoke | write_target_referenced |
| cegr.targetInputMode | advanced | - | [1, 1] | routeA_egr_target_input_mode_id | - | routeA_egr_target_input_mode_id | - | compile_and_smoke | write_target_referenced |
| cegr.controller.Kp_area | advanced | m^2 | [2.220446e-16, Inf] | routeA_egr_control_Kp_area | - | routeA_egr_control_Kp_area | - | compile_and_smoke | write_target_referenced |
| cegr.controller.Ki_area | advanced | m^2/s | [2.220446e-16, Inf] | routeA_egr_control_Ki_area | - | routeA_egr_control_Ki_area | - | compile_and_smoke | write_target_referenced |
| cegr.actuatorTau_s | device_settings | s | [2.220446e-16, Inf] | routeA_egr_valve_actuator_tau | - | routeA_egr_valve_actuator_tau | - | compile_and_smoke | write_target_referenced |
| anode.sourcePressure_MPa_abs | advanced | MPa(abs) | [0.2, 0.5] | routeA_command_profile | anode_source_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.sourceTemperature_C | advanced | degC | [10, 60] | routeA_command_profile | anode_source_temperature_C | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.h2MoleFraction | advanced | - | [0.9, 1] | tank_yH2 | anode_source_h2_mole_fraction | routeA_command_profile | - | compile_and_smoke | write_target_referenced |
| anode.inletPressure_MPa_abs | advanced | MPa(abs) | [0.1, 0.3] | routeA_command_profile | anode_inlet_pressure_MPa_abs | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.humidifierRH | advanced | - | [0, 1] | routeA_command_profile | anode_humidifier_rh | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.recirculationBaseCommand | advanced | - | [0, 1] | routeA_command_profile | anode_recirculation_base | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.recirculationCurrentGain_A_inv | advanced | 1/A | [0, 1] | routeA_command_profile | anode_recirculation_current_gain_A_inv | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.purgeEnabled | advanced | - | [0, 1] | routeA_command_profile | anode_purge_enable | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.purgeOnN2MoleFraction | advanced | - | [0, 1] | routeA_command_profile | anode_purge_on_n2_mole_fraction | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| anode.purgeOffN2MoleFraction | advanced | - | [0, 1] | routeA_command_profile | anode_purge_off_n2_mole_fraction | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| stack.numCells | device_settings | - | [1, 1000] | stack_num_cells | - | stack_num_cells | - | compile_and_smoke | write_target_referenced |
| stack.area_cm2 | device_settings | cm^2 | [1, 1000] | stack_area | - | stack_area | - | compile_and_smoke | write_target_referenced |
| stack.iL_A_cm2 | device_settings | A/cm^2 | [0.001, 5] | stack_iL | - | stack_iL | - | compile_and_smoke | write_target_referenced |
| stack.io_A_cm2 | device_settings | A/cm^2 | [1e-08, 0.1] | stack_io | - | stack_io | - | compile_and_smoke | write_target_referenced |
| device.stack.alpha | device_settings | - | [0.1, 1.5] | stack_alpha | - | stack_alpha | - | compile_and_smoke | write_target_referenced |
| device.stack.meaCp_J_kgK | device_settings | J/(kg*K) | [100, 5000] | stack_mea_cp | - | stack_mea_cp | - | compile_and_smoke | write_target_referenced |
| device.stack.meaRho_kg_m3 | device_settings | kg/m^3 | [100, 5000] | stack_mea_rho | - | stack_mea_rho | - | compile_and_smoke | write_target_referenced |
| device.stack.gdlThickness_um | device_settings | um | [1, 2000] | stack_t_gdl | - | stack_t_gdl | - | compile_and_smoke | write_target_referenced |
| device.stack.membraneThickness_um | device_settings | um | [1, 1000] | stack_t_membrane | - | stack_t_membrane | - | compile_and_smoke | write_target_referenced |
| device.cathode.intercoolerMdotNominal_kg_s | device_settings | kg/s | [2.220446e-16, 1] | intercooler_mdot_nominal | - | intercooler_mdot_nominal | - | compile_and_smoke | write_target_referenced |
| device.cathode.intercoolerDpNominal_MPa | device_settings | MPa | [0, 0.1] | intercooler_dp_nominal | - | intercooler_dp_nominal | - | compile_and_smoke | write_target_referenced |
| device.cathode.separatorMdotNominal_kg_s | device_settings | kg/s | [2.220446e-16, 1] | cathode_separator_mdot_nominal | - | cathode_separator_mdot_nominal | - | compile_and_smoke | write_target_referenced |
| device.cathode.separatorDpNominal_MPa | device_settings | MPa | [0, 0.1] | cathode_separator_dp_nominal | - | cathode_separator_dp_nominal | - | compile_and_smoke | write_target_referenced |
| device.cathode.separatorArea_m2 | device_settings | m^2 | [1e-08, 0.1] | cathode_separator_area | - | cathode_separator_area | - | compile_and_smoke | write_target_referenced |
| device.cathode.separatorLaminarFraction | device_settings | - | [0, 1] | cathode_separator_laminar_fraction | - | cathode_separator_laminar_fraction | - | compile_and_smoke | write_target_referenced |
| device.cathode.mixerVolume_L | device_settings | L | [2.220446e-16, 1000] | comp_inlet_mixer_V | - | comp_inlet_mixer_V | - | compile_and_smoke | write_target_referenced |
| device.cathode.outletChamberVolume_L | device_settings | L | [2.220446e-16, 1000] | cathode_outlet_chamber_V | - | cathode_outlet_chamber_V | - | compile_and_smoke | write_target_referenced |
| device.cathode.compressorMap.rpm_TLU | device_settings | rpm | 结构化数据/由专用校验器约束 | comp_rpm_TLU | - | comp_rpm_TLU | - | compile_and_smoke | write_target_referenced |
| device.cathode.compressorMap.p_ratio_TLU | device_settings | - | 结构化数据/由专用校验器约束 | comp_p_ratio_TLU | - | comp_p_ratio_TLU | - | compile_and_smoke | write_target_referenced |
| device.cathode.compressorMap.mdot_corr_TLU | device_settings | kg/s | 结构化数据/由专用校验器约束 | comp_mdot_corr_TLU | - | comp_mdot_corr_TLU | - | compile_and_smoke | write_target_referenced |
| device.cegr.valveMaxArea_m2 | device_settings | m^2 | [2.220446e-16, 1] | cegr_valve_max_area | - | cegr_valve_max_area | - | compile_and_smoke | write_target_referenced |
| device.cegr.pipeLength_m | device_settings | m | [0.0001, 100] | cegr_pipe_length | - | cegr_pipe_length | - | compile_and_smoke | write_target_referenced |
| device.cegr.pipeDiameter_m | device_settings | m | [0.0001, 1] | cegr_pipe_D | - | cegr_pipe_D | cegr_pipe_area | compile_and_smoke | write_target_referenced |
| device.cegr.pipeRoughness_m | device_settings | m | [0, 0.01] | cegr_pipe_roughness | - | cegr_pipe_roughness | - | compile_and_smoke | write_target_referenced |
| device.anode.tankPressure_MPa | device_settings | MPa | [0.1, 100] | tank_p | - | tank_p | - | compile_and_smoke | write_target_referenced |
| device.anode.tankVolume_L | device_settings | L | [2.220446e-16, 100000] | tank_V | - | tank_V | - | compile_and_smoke | write_target_referenced |
| device.anode.tankTemperature_C | device_settings | degC | [-50, 150] | tank_T | - | tank_T | - | compile_and_smoke | write_target_referenced |
| device.anode.separatorArea_m2 | device_settings | m^2 | [1e-08, 0.1] | anode_separator_area | - | anode_separator_area | - | compile_and_smoke | write_target_referenced |
| device.anode.separatorLaminarFraction | device_settings | - | [0, 1] | anode_separator_laminar_fraction | - | anode_separator_laminar_fraction | - | compile_and_smoke | write_target_referenced |
| thermal.stackTemperatureSet_C | basic | degC | [60, 100] | routeA_stack_temperature_set_C | stack_temperature_set_C | routeA_command_profile | - | collect_and_validate | write_target_referenced |
| solver.stopTime_s | basic | s | [0, Inf] | - | - | - | - | collect_and_validate | non_workspace_input |
| solver.solver | advanced | - | 结构化数据/由专用校验器约束 | - | - | - | - | collect_and_validate | non_workspace_input |
| solver.relTol | advanced | - | [2.220446e-16, 1] | - | - | - | - | collect_and_validate | non_workspace_input |
| solver.absTol | advanced | - | [2.220446e-16, Inf] | - | - | - | - | collect_and_validate | non_workspace_input |
| solver.maxStep_s | advanced | s | [0, Inf] | - | - | - | - | collect_and_validate | non_workspace_input |

## 模型工作区参数

| 变量 | 默认值摘要 | 类型/尺寸 | 物理角色 | 模型引用状态 | 代表模块 | 面板活动参数 | 页签 |
|---|---|---|---|---|---|---|---|
| Gas_properties_block | PEMFuelCellSystem_Before_v01/Anode_Hydrogen_BOP/Gas Mixture<br>Properties | char [1 70] | 模型内部配置或辅助参数 | workspace_only | - | - | - |
| Gas_properties_candidates | cell[1 1] | cell [1 1] | 模型内部配置或辅助参数 | workspace_only | - | - | - |
| T_TLU | double[1 115] | double [1 115] | 水蒸气饱和性质查表数据 | workspace_only | - | - | - |
| anode_separator_D | 0.02 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| anode_separator_T0 | 20 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| anode_separator_area | 0.00031415927 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | device.anode.separatorArea_m2 | device_settings |
| anode_separator_dp_nominal | 0.0005 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | model_referenced_no_active_panel_entry | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | - | - |
| anode_separator_extra_length | 0.04 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| anode_separator_laminar_fraction | 0.001 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | device.anode.separatorLaminarFraction | device_settings |
| anode_separator_length | 0.12 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| anode_separator_mdot_nominal | 0.01 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | model_referenced_no_active_panel_entry | Anode_Hydrogen_BOP/AnodeWaterSeparator_FC | - | - |
| anode_separator_p0 | 0.101325 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| anode_separator_roughness | 1.5e-05 | double [1 1] | 阳极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| anode_tube_D | 0.02 | double [1 1] | 模型内部配置或辅助参数 | model_referenced_no_active_panel_entry | Anode_Hydrogen_BOP/Anode Exhaust/Convective Heat<br>Transfer; Anode_Hydrogen_BOP/Anode Exhaust/Environment; Anode_Hydrogen_BOP/Anode Exhaust/Max Area; ... (+5) | - | - |
| cathode_outlet_chamber_V | 0.2 | double [1 1] | 模型内部配置或辅助参数 | model_referenced_panel_contract | Stack_Core/CathodeOutletChamber | device.cathode.outletChamberVolume_L | device_settings |
| cathode_separator_D | 0.05 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| cathode_separator_T0 | 20 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| cathode_separator_area | 0.0019634954 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorArea_m2 | device_settings |
| cathode_separator_dp_nominal | 0.0005 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorDpNominal_MPa | device_settings |
| cathode_separator_extra_length | 0.05 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| cathode_separator_laminar_fraction | 0.001 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorLaminarFraction | device_settings |
| cathode_separator_length | 0.15 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| cathode_separator_mdot_nominal | 0.1 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Cathode_Exhaust_Backpressure_Water/CathodeWaterSeparator_FC | device.cathode.separatorMdotNominal_kg_s | device_settings |
| cathode_separator_p0 | 0.101325 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| cathode_separator_roughness | 1.5e-05 | double [1 1] | 阴极分离器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| cathode_tube_D | 0.05 | double [1 1] | 模型内部配置或辅助参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor<br>Volume; Cathode_Exhaust_Backpressure_Water/Cathode Exhaust/Convective Heat<br>Transfer1; ... (+3) | - | - |
| cegr_comp_map_t_denom_epsilon | 1e-09 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/TDenGuardBias | - | - |
| cegr_cond_tau | 1 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/EGRPipe; Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer; Stack_Core/CathodeOutletChamber | - | - |
| cegr_inlet_mixer_p0 | 0.101325 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer | - | - |
| cegr_outlet_chamber_p0 | 0.101325 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | Stack_Core/CathodeOutletChamber | - | - |
| cegr_pipe_D | 0.05 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipeDiameter_m | device_settings |
| cegr_pipe_area | 0.0019634954 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/EGRPipe; Cathode_Air_cEGR_BOP/EGRValveRestriction/Open/LocalRestriction; Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer; ... (+2) | device.cegr.pipeDiameter_m | device_settings |
| cegr_pipe_extra_length | 0.1 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/EGRPipe | - | - |
| cegr_pipe_length | 0.5 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipeLength_m | device_settings |
| cegr_pipe_p0 | 0.101325 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/EGRPipe | - | - |
| cegr_pipe_roughness | 1.5e-05 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/EGRPipe | device.cegr.pipeRoughness_m | device_settings |
| cegr_valve_max_area | 0.00019634954 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/EGRValveRestriction/Open/LocalRestriction; System_Control_Observability/FCU_BoP_Control/EGR Area Limit; System_Control_Observability/FCU_BoP_Control/EGR Ratio PI; ... (+1) | device.cegr.valveMaxArea_m2 | device_settings |
| cegr_valve_open_min_area | 1e-10 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/EGRValveRestriction/Open/LocalRestriction; System_Control_Observability/FCU_BoP_Control/EGR Area Limit; System_Control_Observability/FCU_BoP_Control/EGR Ratio PI | - | - |
| comp_inlet_mixer_V | 0.1 | double [1 1] | 阴极空压机图谱、转速边界或入口混合容积 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/CompressorInletMixer | device.cathode.mixerVolume_L | device_settings |
| comp_mdot_corr_TLU | double[5 3] | double [5 3] | 阴极空压机图谱、转速边界或入口混合容积 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/Corrected Flow<br>Table | device.cathode.compressorMap.mdot_corr_TLU | device_settings |
| comp_p_ratio_TLU | [1;1.25;1.5;1.75;2] | double [5 1] | 阴极空压机图谱、转速边界或入口混合容积 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/Corrected Flow<br>Table | device.cathode.compressorMap.p_ratio_TLU | device_settings |
| comp_rpm_TLU | [0 1800 3600] | double [1 3] | 阴极空压机图谱、转速边界或入口混合容积 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/A98_CompressorRpmCmd; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Map/Corrected Flow<br>Table; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Max rpm | device.cathode.compressorMap.rpm_TLU | device_settings |
| coolant_num_layers | 20 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Fuel Cell<br>Coolant Channels | - | - |
| coolant_num_passes | 12 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Fuel Cell<br>Coolant Channels | - | - |
| coolant_tube_D | 0.05 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Flow Resistance (TL); Thermal_Management_BOP/Cooling System/Pump | - | - |
| coolant_w_channels | 1 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Fuel Cell<br>Coolant Channels | - | - |
| drive_cycle_current | [0;0;100;100] | double [4 1] | 电边界时序命令 | library_boundary_verified | - | electrical.current.profile | basic |
| drive_cycle_power | [0;0;40;40] | double [4 1] | 电边界时序命令 | library_boundary_verified | - | electrical.power.profile | basic |
| drive_cycle_time | [0;0.5;60.5;600] | double [4 1] | 电边界时序命令 | model_referenced_no_active_panel_entry | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage Reference | - | - |
| drive_cycle_voltage | [427.6;427.6;410;410] | double [4 1] | 电边界时序命令 | model_referenced_panel_contract | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage Reference | electrical.voltage.profile | basic |
| env_RH | 0.5 | double [1 1] | 环境与气体初始边界 | workspace_only | - | - | - |
| env_T | 20 | double [1 1] | 环境与气体初始边界 | model_referenced_no_active_panel_entry | Anode_Hydrogen_BOP/Anode<br>Humidifier/Pipe (N Gas); Anode_Hydrogen_BOP/Anode Exhaust/Environment; Anode_Hydrogen_BOP/Anode Exhaust/Environment<br>Temperature; ... (+21) | - | - |
| env_p | 0.101325 | double [1 1] | 环境与气体初始边界 | model_referenced_no_active_panel_entry | Anode_Hydrogen_BOP/Anode<br>Humidifier/Pipe (N Gas); Anode_Hydrogen_BOP/Anode Exhaust/Environment; Anode_Hydrogen_BOP/Anode Exhaust/Pipe (FC); ... (+10) | - | - |
| env_pSat_H2O | 0.0023393182 | double [1 1] | 环境与气体初始边界 | workspace_only | - | - | - |
| env_yH20 | 0.011543638 | double [1 1] | 环境与气体初始边界 | model_referenced_panel_contract | Anode_Hydrogen_BOP/Anode Exhaust/Environment; Cathode_Air_cEGR_BOP/Cathode<br>Humidifier/Pipe (FC); Cathode_Air_cEGR_BOP/EGRPipe; ... (+7) | cathode.h2oMoleFraction | advanced |
| env_yO2 | 0.21 | double [1 1] | 环境与气体初始边界 | model_referenced_panel_contract | Anode_Hydrogen_BOP/Anode Exhaust/Environment; Cathode_Air_cEGR_BOP/Cathode<br>Humidifier/Pipe (FC); Cathode_Air_cEGR_BOP/EGRPipe; ... (+7) | cathode.o2MoleFraction | advanced |
| humidifier_bypass_mode | command_gain | string [1 1] | 模型内部配置或辅助参数 | workspace_only | - | - | - |
| intercooler_Dh | 0.05 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| intercooler_T0 | 20 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| intercooler_area | 0.0019634954 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | - | - |
| intercooler_cond_tau | 1 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| intercooler_dp_nominal | 0.001 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | device.cathode.intercoolerDpNominal_MPa | device_settings |
| intercooler_extra_length | 0.05 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| intercooler_laminar_fraction | 0.001 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | - | - |
| intercooler_length | 0.25 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| intercooler_mdot_nominal | 0.1 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Intercooler_L2_Interface | device.cathode.intercoolerMdotNominal_kg_s | device_settings |
| intercooler_p0 | 0.101325 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| intercooler_roughness | 1.5e-05 | double [1 1] | 阴极中冷器 L2 流阻与初始状态参数 | workspace_only | - | - | - |
| pSat_H2O_TLU | double[1 115] | double [1 115] | 水蒸气饱和性质查表数据 | workspace_only | - | - | - |
| pSat_TLU | double[4 115] | double [4 115] | 水蒸气饱和性质查表数据 | workspace_only | - | - | - |
| radiator_H | 0.5 | double [1 1] | 热管理 BOP 几何或热容参数 | workspace_only | - | - | - |
| radiator_L | 1 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Radiator | - | - |
| radiator_N_fins | 12000 | double [1 1] | 热管理 BOP 几何或热容参数 | workspace_only | - | - | - |
| radiator_N_tubes | 25 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Radiator | - | - |
| radiator_W | 0.025 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Radiator | - | - |
| radiator_air_area_fins | 11.5625 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Convective Heat<br>Transfer; Thermal_Management_BOP/Cooling System/Thermal Mass | - | - |
| radiator_air_area_primary | 1.223125 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Convective Heat<br>Transfer; Thermal_Management_BOP/Cooling System/Thermal Mass | - | - |
| radiator_cp | 910 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Thermal Mass | - | - |
| radiator_eta_fin | 0.7 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Convective Heat<br>Transfer | - | - |
| radiator_fin_spacing | 0.002 | double [1 1] | 热管理 BOP 几何或热容参数 | workspace_only | - | - | - |
| radiator_gap_H | 0.019270833 | double [1 1] | 热管理 BOP 几何或热容参数 | workspace_only | - | - | - |
| radiator_rho | 2700 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Thermal Mass | - | - |
| radiator_t_wall | 0.0001 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Thermal Mass | - | - |
| radiator_tube_H | 0.0015 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Radiator | - | - |
| radiator_tube_Leq | 2.5 | double [1 1] | 热管理 BOP 几何或热容参数 | model_referenced_no_active_panel_entry | Thermal_Management_BOP/Cooling System/Radiator | - | - |
| routeA_air_control_mode_id | 2 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/A98_AirModeDirectCmd; Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/A98_AirModeTargetMdot | cathode.airControlMode | basic |
| routeA_air_pid_Ki | 0.5 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/PID Controller | - | - |
| routeA_air_pid_Kp | 5 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_no_active_panel_entry | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/PID Controller | - | - |
| routeA_anode_inlet_pressure_MPa_abs | 0.161325 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_anode_purge_enable | 1 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_anode_purge_off_n2_mole_fraction | 0.1 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_anode_purge_on_n2_mole_fraction | 0.5 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_anode_recirculation_base_command | 0.2 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_anode_recirculation_current_gain_A_inv | 0.0020408163 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_anode_rh_setpoint | 1 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_backpressure_control_mode_id | 1 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_cathode_humidifier_gain | 1 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_cathode_rh_setpoint | 1 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_cegr_enabled | 1 | logical [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | cEGR_Mode_Selector | cegr.enabled | basic |
| routeA_cegr_valve_mode_id | 1 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/EGRValveRestriction | cegr.valveMode | advanced |
| routeA_command_profile | double[4 23] | double [4 23] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | System_Control_Observability/FCU_BoP_Control/RouteA_Command_Profile/Command_Profile_Input | cathode.targetOer, cathode.targetMdot_kg_s, cathode.directCommand, cathode.sourcePressure_MPa_abs, cathode.sourceTemperature_C, cathode.outletPressure_MPa_abs, cathode.humidifierRH, cathode.humidifierEnabled, cegr.targetRatio, anode.sourcePressure_MPa_abs, anode.sourceTemperature_C, anode.inletPressure_MPa_abs, anode.humidifierRH, anode.recirculationBaseCommand, anode.recirculationCurrentGain_A_inv, anode.purgeEnabled, anode.purgeOnN2MoleFraction, anode.purgeOffN2MoleFraction | basic, advanced |
| routeA_command_profile_baseline | double[1 22] | double [1 22] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_command_profile_fields | cathode_source_pressure_MPa_abs       cathode_source_temperature_C          cathode_source_o2_mole_fraction       cathode_source_h2o_mole_fraction      air_target_mdot_kg_s                  air_target_oer                        air_direct_command                    cathode_outlet_pressure_MPa_abs       cathode_humidifier_rh                 cathode_humidifier_gain               cegr_ratio                            anode_source_pressure_MPa_abs         anode_source_temperature_C            anode_source_h2_mole_fraction         anode_inlet_pressure_MPa_abs          anode_humidifier_rh                   anode_recirculation_base              anode_recirculation_current_gain_A_invanode_purge_enable                    anode_purge_on_n2_mole_fraction       anode_purge_off_n2_mole_fraction      stack_temperature_set_C                | string [1 22] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_command_profile_schema | RouteA_Command_Profile_v10 | string [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_current_default_ref_A | 28 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_egr_control_Ki_area | 3.9269908e-05 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | System_Control_Observability/FCU_BoP_Control/EGR Ratio PI | cegr.controller.Ki_area | advanced |
| routeA_egr_control_Kp_area | 0.00019634954 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | System_Control_Observability/FCU_BoP_Control/EGR Ratio PI | cegr.controller.Kp_area | advanced |
| routeA_egr_control_mode_id | 1 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | System_Control_Observability/FCU_BoP_Control/EGR Direct Mode Enable | cegr.controlMode | advanced |
| routeA_egr_target_input_mode_id | 1 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | System_Control_Observability/FCU_BoP_Control/EGR_Target_Ratio_Profile_Mode | cegr.targetInputMode | advanced |
| routeA_egr_valve_actuator_tau | 0.5 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_panel_contract | System_Control_Observability/FCU_BoP_Control/EGR Area Actuator | cegr.actuatorTau_s | device_settings |
| routeA_egr_valve_area_direct | 3.9269908e-06 | double [1 1] | 被动 cEGR 支路几何、阀或控制参数 | model_referenced_no_active_panel_entry | System_Control_Observability/FCU_BoP_Control/Direct EGR Area | - | - |
| routeA_external_case_enabled | 0 | logical [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_parameter_layer | platform_default | string [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_stack_temperature_set_C | 80 | double [1 1] | Route A 运行工况、控制或命令配置 | panel_entry_without_model_reference | - | thermal.stackTemperatureSet_C | basic |
| routeA_target_egr_ratio_comp_in | 0.02 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_no_active_panel_entry | System_Control_Observability/FCU_BoP_Control/Target EGR Ratio | - | - |
| routeA_voltage_current_max_A | 392 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.currentMax_A | advanced |
| routeA_voltage_current_min_A | 0 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.currentMin_A | advanced |
| routeA_voltage_default_ref_V | 394.9 | double [1 1] | Route A 运行工况、控制或命令配置 | workspace_only | - | - | - |
| routeA_voltage_pi_Ki | 0.05 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Raw PI Diagnostic; System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.Ki_A_V_s | advanced |
| routeA_voltage_pi_Kp | 1 | double [1 1] | Route A 运行工况、控制或命令配置 | model_referenced_panel_contract | System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Raw PI Diagnostic; System_Control_Observability/Electrical Load/Inputs/Voltage Demand/Voltage PI | electrical.voltageController.Kp_A_V | advanced |
| separator_condensation_enabled | 1 | logical [1 1] | L2 冷凝/分离功能标记 | workspace_only | - | - | - |
| separator_l2_efficiency | 0.5 | double [1 1] | L2 冷凝/分离功能标记 | workspace_only | - | - | - |
| separator_l2_source | l2_saturation_excess_estimator | string [1 1] | L2 冷凝/分离功能标记 | workspace_only | - | - | - |
| stack_alpha | 0.7 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Stack_Core/Membrane Electrode<br>Assembly | device.stack.alpha | device_settings |
| stack_area | 280 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/Constant; Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; ... (+3) | stack.area_cm2 | device_settings |
| stack_iL | 1.4 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/Constant; Stack_Core/Membrane Electrode<br>Assembly | stack.iL_A_cm2 | device_settings |
| stack_io | 0.0001 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Stack_Core/Membrane Electrode<br>Assembly | stack.io_A_cm2 | device_settings |
| stack_mea_cp | 870 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Stack_Core/MEA<br>Thermal Mass | device.stack.meaCp_J_kgK | device_settings |
| stack_mea_rho | 1800 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Stack_Core/MEA<br>Thermal Mass | device.stack.meaRho_kg_m3 | device_settings |
| stack_num_cells | 400 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Cathode_Air_cEGR_BOP/Oxygen<br>Source/Compressor Control/M_set; Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; ... (+4) | stack.numCells | device_settings |
| stack_num_channels | 8 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_no_active_panel_entry | Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; Stack_Core/Convective Heat<br>Transfer1; ... (+1) | - | - |
| stack_t_gdl | 250 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Stack_Core/MEA<br>Thermal Mass | device.stack.gdlThickness_um | device_settings |
| stack_t_membrane | 125 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_panel_contract | Stack_Core/MEA<br>Thermal Mass; Stack_Core/Membrane Electrode<br>Assembly | device.stack.membraneThickness_um | device_settings |
| stack_w_channels | 1 | double [1 1] | 电堆 / MEA 电化学、几何或热容参数 | model_referenced_no_active_panel_entry | Stack_Core/Anode Gas<br>Channels/Anode; Stack_Core/Cathode Gas<br>Channels/Cathode; Stack_Core/Convective Heat<br>Transfer1; ... (+1) | - | - |
| tank_T | 20 | double [1 1] | 阳极储氢罐初始状态/容积 | model_referenced_panel_contract | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | device.anode.tankTemperature_C | device_settings |
| tank_V | 120 | double [1 1] | 阳极储氢罐初始状态/容积 | model_referenced_panel_contract | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | device.anode.tankVolume_L | device_settings |
| tank_p | 70 | double [1 1] | 阳极储氢罐初始状态/容积 | model_referenced_panel_contract | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | device.anode.tankPressure_MPa | device_settings |
| tank_yH2 | 0.9997 | double [1 1] | 阳极储氢罐初始状态/容积 | model_referenced_panel_contract | Anode_Hydrogen_BOP/Hydrogen<br>Source/Fuel Tank | anode.h2MoleFraction | advanced |

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
2. 模型引用但未开放的参数先在“系统模型参数”页保持只读目录状态；只有补足参数来源、范围、验证器和响应证据后才可转为可写。
3. `workspace_only` 变量不得被称为当前设备性能，除非后续补齐块接线并重新审计。
4. 同一几何量若模型需同时使用直径与面积，只保留一个可编辑规范输入，其余变量必须在 `SimulationInput` 中由它推导。
