# Route A A10 主模型与复用入口收口 v01

对象模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
阶段定位：A10 不再代表台架配置派生，而是 Route A 通用 PEMFC-cEGR 平台的主模型、参数入口、运行入口和可视化入口收口。

## 1. 主模型结构

Route A 当前保持单一主模型，不复制台架版或车载版模型。物理主线和控制入口分工如下：

| 区域 | 作用 |
|---|---|
| `Oxygen Source` | 环境空气、压缩机入口混合、压缩机和空气控制链；空气控制支持 `target_mdot`、`target_oer`、`direct_cmd` |
| `Cathode Gas Channels -> CathodeOutletChamber -> Cathode Exhaust` | 阴极主流道、出口库存、排气和目标压力驱动背压调节 |
| `EGRMassFlowSensor -> CathodeWaterSeparator_FC -> EGRValveRestriction -> EGRPipe -> Oxygen Source.cEGR` | 阴极尾气循环支路 |
| `FCU_BoP_Control` | cEGR ratio/阀面积控制接口；不承担空气压缩机控制和背压压力调节 |
| `Cathode Humidifier` | 阴极加湿器与旁路 gain 接口 |
| `Measurements` 与 Route A KPI 信号 | stack 电流、电压、功率、温度、RH、压力、EGR ratio、分离水等输出 |

## 2. 长期入口

| 文件 | 角色 | 使用场景 |
|---|---|---|
| `PEMFuelCellSystemWithACustomLibraryParameters.m` | 模型工作区默认参数源 | 平台初始化、默认工况、控制接口变量 |
| `run_routeA_platform_demo.m` | 日常仿真入口 | 实验人员或建模人员快速运行名义 PEMFC-cEGR 工况 |
| `run_routeA_a10_entrypoint_audit.m` | A10 收口审计入口 | 检查主模型入口、demo、A9.8/A9.9 最小回归 |
| `run_routeA_a9_parameter_governance_audit.m` | 参数治理回归入口 | 验证 `platform_default`、external-case guard 和 50 kW 参数门槛 |
| `run_routeA_a9_8_fcu_bop_control_audit.m` | FCU/BoP 控制回归入口 | 验证空气/cEGR 控制接口 |
| `run_routeA_a9_9_backpressure_control_audit.m` | 背压接口回归入口 | 验证目标阴极出口压力接口 |

A6-A9.7 脚本保留为阶段证据和排障入口，本轮不移动路径，避免破坏历史引用。

## 3. 操作入口与控制量

日常工况优先通过模型工作区变量设置，不直接改物理模块参数：

| 变量 | 含义 | 默认 |
|---|---|---:|
| `drive_cycle_power` | 功率请求，单位沿用官方示例 kW 量级 | nominal 50.96 kW |
| `routeA_air_control_mode_id` | 空气控制模式：1 target_mdot，2 target_oer，3 direct_cmd | 1 |
| `routeA_target_mdot_comp_inlet` | 压缩机入口总质量流量目标 | 0.045 kg/s |
| `routeA_target_oer` | 阴极氧过量系数目标 | 2.5 |
| `routeA_compressor_cmd_direct` | 空压机开环命令 | 0.5 |
| `routeA_egr_control_mode_id` | cEGR 控制模式：1 target_ratio，2 direct_area | 1 |
| `routeA_target_egr_ratio_comp_in` | EGR 质量流量 / 压缩机入口总质量流量 | 0.02 |
| `routeA_egr_valve_area_direct` | cEGR 阀开环面积 | `2e-3 * cegr_pipe_area` |
| `routeA_target_p_ca_out_MPa` | 阴极出口绝对压力目标 | `env_p + 0.06` |
| `routeA_cathode_humidifier_gain` | 阴极加湿器启用/旁路 gain | 1 |
| `routeA_stack_temperature_set_C` | 冷却系统 stack 温度目标接口 | 80 degC |

## 4. KPI 输出

`run_routeA_platform_demo.m` 默认输出 `routeA_platform_demo_summary`，至少包含：

| KPI | 说明 |
|---|---|
| `actualPowerKW` | 电堆实际输出功率 |
| `compressorCmd` / `compressorRpmCmd` | 空压机控制命令和转速命令 |
| `compInletMdotKgS` | 压缩机入口总质量流量 |
| `egrRatioCompIn` | 压缩机入口 EGR ratio |
| `egrValveAreaCmd` | cEGR 阀面积命令 |
| `pCaOutMPa` | 阴极出口压力 |
| `RHCaIn` / `RHCaOut` | 阴极入口/出口相对湿度 |
| `mWaterSep` | L2 分离水/冷凝水 KPI |

## 5. 当前未做事项

1. A10 不做无加湿器台架配置；该任务顺延为 A11。
2. A10 不做含加湿器车载配置；该任务顺延为 A12。
3. A10 不重新标定空气、cEGR 或背压控制器 PI 增益。
4. A10 不新增阳极 lambda/purge 闭环、阀开度型背压 PI 变体或完整热管理 FCU。
5. A10 不移动 A6-A9 阶段脚本，只在文档中明确它们的长期角色。

## 6. 验收方式

运行：

```matlab
run_routeA_platform_demo
run_routeA_a10_entrypoint_audit
```

通过条件：

- demo runner 完成名义 50.96 kW 工况，`routeA_platform_demo_summary.passed == true`。
- A10 审计中 preflight、demo、A9.8 最小回归、A9.9 名义压力回归均通过。
- `model_read(depth=0/1)` 可读回 Route A 操作注释、`FCU_BoP_Control`、空气控制、背压目标和 EGR 阀受控面积链路。
