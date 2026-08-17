# P4-A 自增湿独立模型建立与冷态 Smoke 记录

日期：2026-08-14  
状态：已完成 P4-A 模型建成门；不代表配置 B 或工程性能结论。

## 前置决策

- [两种阀门被动架构聚焦模型改造实施方案](../../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md) 的 P4-A/P4-B 裁决。
- [总体规划](../../01_当前指导/RouteA_cEGR_PEMFC_工程化架构决策与聚焦模型总体规划_v01.md) 的“一份参数与结果契约、两个物理模型”边界。

## 实际完成项

- 从原聚焦模型派生并保存正式模型：[PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01.slx](../../../../01_模型/RouteA_Cathode_cEGR_Focused/PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01.slx)。
- 删除 `Cathode_Air_cEGR_BOP/Cathode Humidifier`，以现有 BOP 管段直接连通；删除尾气主干的 `MembraneHumidifierWet_L2_FC`，使 `CommonBackpressureValve_FC` 直接连接 `CommonGasPhaseBoundary_FC`。
- 根级增加官方 `Composition and Humidity Sensor (FC)`、PS-Simulink 转换和 signal logging 观察通道，仅用于阴极入口 RH 采集；移除无消费者的 `CathodeHumidifierGain` 和 `CathodeHumidifierRH` Goto。
- 扩展唯一正式 runner 的 `modelId` 路由，使 `self_humidifying` 映射到模型 A；涉及 [routeA_focused_paths.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_paths.m)、[routeA_focused_parameter_defaults.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_parameter_defaults.m) 与 [run_routeA_focused_study.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/run_routeA_focused_study.m)。

## 结构读回与保存

- `find_system` 未发现 `Cathode Humidifier` 或 `MembraneHumidifierWet_L2_FC`；`CommonGasPhaseBoundary_FC` 保留。
- 新湿度传感器位于模型根级，路径为 `PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01/SelfHumidifyingInletHumiditySensor_FC`。
- 模型保存后 `Dirty=off`。静态 `model_check` 未报告 error；Simscape 物理端口的静态 warning 需结合连接读回解释，不作为悬空端口结论。

## 仿真证据

运行方式：唯一正式 runner `run_routeA_focused_study`，`modelId=self_humidifying`，Rapid Accelerator，5 A 恒流，冷态 180 s，尾窗 150--180 s，严格稳态阈值 0.005。结果文件：[RouteA_Focused_P4A_self_humidifying_0_2_5pct_180s_20260814.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_P4A_self_humidifying_0_2_5pct_180s_20260814.mat)。

| cEGR 目标 | 实际 cEGR | 最大相对变化 | 通过状态 | 外部注水使能 | 气相闭合/饱和/压力方向 |
|---:|---:|---:|---|---:|---|
| 0% | 0.00000022 | 3.3903e-07 | `passed=1`，`simCompleted=1`，严格稳态通过 | 0 | 全部通过 |
| 2% | 0.01999935 | 2.8127e-05 | `passed=1`，`simCompleted=1`，严格稳态通过 | 0 | 全部通过 |
| 5% | 0.04999828 | 2.9561e-05 | `passed=1`，`simCompleted=1`，严格稳态通过 | 0 | 全部通过 |

5% case 的 O2 Faraday 残差为 `-8.5669e-09 kg/s`，混合点水蒸气残差为 `-3.8541e-10 kg/s`；阴极入口/出口 RH 为 0.11115/0.17959；压缩机入口混合点的饱和度为 0.4653；阴极出口相对压缩机入口的压力裕度为 0.05320 MPa。

## 阻塞与未决项

- 首次派生后，旧 runner 试图读取被删加湿器的 `routeA_RH_ca_in_ts`，导致结果收集失败；根因是观测点随实体块一同删除。新增官方湿度传感器并改由 signal logging 采集后，runner 正常返回。
- Rapid Accelerator 对既有 `To Workspace/Timeseries` 块给出不记录告警；本研究的正式结果由 `logsout` 采集，未将这些工作区变量作为证据。
- 未建立模型 B。其双侧膜组件仍需膜面积/几何、两侧压降、跨膜传质和传热的参数合同；不得复用本模型已删除的 L2 流阻作为替代。
- 本模型仍是气相系统级筛选模型：液态水输运、储水与排水动态未实现，饱和度只用于潜在冷凝筛查。
