# Route A cEGR-PEMFC 实施记录：聚焦控制、性能分析与边界参数桥接

日期：2026-08-13  
范围：聚焦模型 runner 输入契约、标准 simCase 适配、简化阳极/恒温边界参数桥接、阴极/电堆性能指标和低负荷被动回流准入前置。  
源模型：`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
聚焦模型：`04_Simulink物理网络模型/01_模型/RouteA_Cathode_cEGR_Focused/PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`

## 1. 本轮变更

- 新增 `routeA_focused_case_adapter.m`，允许聚焦 case 和标准 Route A `simCase` 共用一个正式 runner。
- 新增 `routeA_focused_parameter_bridge.m`，把标准阳极源压力、源温度、H2 组分和堆温设定映射到聚焦模型实际变量。
- 将阳极质量流量、阳极出口背压、阳极最小管路几何作为聚焦专用边界；标准阳极入口压力、加湿、回流和吹扫参数不再静默丢弃，而是在 bridge 中标记 `not_applicable`。
- 将恒温源作为唯一聚焦热边界；冷却通道、泵和散热器参数在 bridge 中标记为移除的热管理 BOP 参数。
- 新增 `routeA_focused_performance_metrics.m`，统一计算 I/V/P、单电池电压、电流密度、功率密度、`r_mix`、`r_fresh`、混合点氧分压、lambda、RH、压差和气相冷凝指标。
- 新增 `routeA_focused_performance_analysis.m`，提供多 case 性能比较准入和失败分类。
- `run_routeA_focused_study.m` 现在在每个 case 中保存 case adapter 和 parameter bridge，并在 study 顶层输出性能分析摘要。

## 2. 结构和写入点读回

聚焦模型根层仍读回以下保留结构：

- `Cathode_Air_cEGR_BOP`：空气源、压缩机、加湿器、cEGR 阀/管路和控制。
- `Cathode_Exhaust_Backpressure_Water`：出口腔体、背压、cEGR 分流和当前气相水观测器。
- `Stack_Core`：MEA、完整阴极/阳极气体通道、电气端口和 MEA 热容。
- `System_Control_Observability`：I/P/V 电负载、空气控制、cEGR 控制和观测输出。
- 简化阳极：`Focused_Anode_H2_Feed_Reservoir`、质量流量源、最小出口 Pipe/Reservoir 和 Gas Mixture Properties。
- 简化热边界：`Focused_Stack_Temperature_Source` 和 `Focused_Stack_HeatFlow_Sensor`。

关键模型变量读回：

| 变量 | 当前写入点 | 默认值 |
|---|---|---:|
| `focused_stack_temperature_C` | Temperature Source | `80 degC` |
| `focused_anode_feed_p_MPa_abs` | H2 Feed Reservoir | `0.3 MPa(abs)` |
| `focused_anode_inlet_mdot_kg_s` | Mass Flow Rate Source | `0.001 kg/s` |
| `focused_anode_outlet_p_MPa_abs` | H2 Outlet Reservoir/Pipe | `0.101325 MPa(abs)` |
| `focused_anode_boundary_T_C` | H2 Reservoir/Pipe temperature | `20 degC` |
| `focused_anode_yH2` | H2 Reservoir/Pipe composition | `0.9997` |

模型文件读回 `Dirty=off`，checksum：`652D323D-5E96292F-979D5198-5E667C40`。本轮未修改完整源模型。

## 3. 参数桥接验证

- 原生聚焦模板修改 `thermal.stackTemperatureSet_C=84 degC`、阳极源压力 `0.34 MPa(abs)`、源温度 `33 degC`、`yH2=0.997` 后，bridge 读回对应 focused 变量。
- 标准 Route A `simCase` 修改同组参数后能够通过统一 focused runner 装配并执行 Power case。
- 该 case 实际性能读回：目标堆温 `84 degC`，尾窗实际堆温 `84 degC`，温差 `0 degC`，`P=40 kW`，`bridge.status=mapped_with_explicit_fixed_boundaries`。
- 阳极入口压力、阳极加湿、阳极回流、阳极吹扫、冷却通道和散热器字段均在 bridge 中可见，状态为 `not_applicable`，不作为已接入的物理结果。

## 4. 控制和性能行为验证

所有 case 使用同一聚焦模型、同一正式 runner、冷态启动和 `VariableStepAuto`。短 case 使用 `120 s`、尾窗 `[60,120]`；Voltage 正式 case 使用 `600 s`、尾窗 `[540,600]`。

| Case | 结果 | 关键读回 |
|---|---|---|
| Current, `100 A`, cEGR `0.3` | `passed=1` | `V=406.4588 V`，`r_mix=0.2999`，`r_fresh=0.4284`，`lambda=2.5043` |
| Power, `40 kW`, cEGR `0.3` | `passed=1` | `V=406.7343 V`，`I=98.3443 A`，`r_mix=0.2999` |
| Voltage, `410 V`, cEGR `0.3` | `passed=1` | `V=410.1326 V`，`I=78.9043 A`，`P=32.3612 kW` |
| Air target mdot, `100 A`, `0.045 kg/s` | `passed=1` | 实际压缩机入口流量 `0.045 kg/s` |
| Air direct command, `100 A`, command `0.5` | `passed=1` | 实际压缩机入口流量约 `0.0753 kg/s`；流量跟踪仅作诊断 |
| Standard simCase Power bridge | `passed=1` | `40 kW`，阳极/热边界参数映射成功 |

## 5. 低负荷被动回流准入前置

在 `5 A`、`80 degC`、`600 s`、OER 目标 `3.0` 下：

- 无回流：`passed=1`，`V=448.389 V`，`P=2.24195 kW`，`lambda=23.5061`，混合点冷凝率 `0`。
- cEGR `0.3`：`passed=1`，`V=443.317 V`，`P=2.21658 kW`，`r_mix=0.3`，`r_fresh=0.428571`，`lambda=22.2294`，混合点冷凝率约 `7.62196e-7 kg/s`，饱和度约 `1.1531`。

口径后续裁决：本记录形成时使用 `r_mix`/`r_fresh` 口径，数值作为历史执行证据保留。2026-08-14 起，分流点 `r_split=m_return/(m_return+m_exhaust)` 是架构回流能力主指标；历史记录不改标为新口径。

该结果仅说明低负荷 case 可执行并暴露出气相饱和/冷凝代理，不证明被动压缩机前回流的工程可行性。

## 6. 验证状态和剩余风险

- `implemented`：参数适配器、bridge、性能指标和多 case 汇总已实现。
- `structurally_verified`：聚焦模型根层、控制子系统、Stack_Core 和边界变量已读回。
- `executed`：Current/Power/Voltage、空气 mdot/direct 和低负荷 case 已执行。
- `behavior_verified_for_focused_scope`：通过 case 已通过电边界、cEGR、气相闭合、lambda、阀压差/面积、压缩机能力和稳态门。
- `not_validated_for_engineering`：完整模型同边界逐信号等价、液水库存/输运/排液、分离效率、空压机进液损伤、辅机寄生功率和耐久性仍未验证。
- `model_check(root, all)` 仍返回 `63` 条 warning、无 error severity；主要涉及 SATK 对 Simscape conserving ports、Variant 和合法物理边界的读回误报，后续需维护 warning ledger，不在本轮用伪连接消除。
- 模型默认配置仍读回 `StopTime=100 s`、`MaxStep=0.1 s`；正式 runner 通过 `SimulationInput` 使用研究配置 `600 s`、`MaxStep=5 s`。如需允许直接点击模型运行，另行形成模型配置变更切片。

状态：`implemented_structurally_verified_executed_behavior_verified_for_focused_scope_not_validated_for_engineering`。
