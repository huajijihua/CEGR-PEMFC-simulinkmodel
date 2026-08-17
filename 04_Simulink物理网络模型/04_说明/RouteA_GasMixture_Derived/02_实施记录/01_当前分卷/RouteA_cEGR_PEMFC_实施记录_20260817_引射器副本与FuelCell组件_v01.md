# 引射器副本建立与 FuelCell 域组件首轮实施记录

日期：2026-08-17
前置决策：[官方引射器模块审计与 FuelCell 域适配裁决](../../01_当前指导/RouteA_cEGR_PEMFC_官方引射器模块审计与FuelCell域适配裁决_v01.md)；[官方引射器被动式结构系统实施计划](../../01_当前指导/RouteA_cEGR_PEMFC_官方引射器被动式结构系统实施计划_v01.md)
状态：结构已建立；关闭基线已执行通过；开启引射器未验证。

## 1. 实际完成项

1. 使用 MATLAB `save_system` 从 `PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01.slx` 保存副本：
   `PEMFuelCellSystem_Cathode_cEGR_Ejector_SelfHumidifying_v01.slx`。
2. 建立官方 Gas 域基准模型：
   `RouteA_Ejector_Gas_Benchmark_v01.slx`。
3. 建立 `+RouteAEjector/EjectorFC.ssc` 和 `RouteAEjector_lib/Ejector (FC)`，端口为 FuelCell 域 `A/S/B`。
4. 副本根级结构改为：
   `Cathode_Air_cEGR_BOP/B -> Ejector A`；
   `Cathode_Exhaust_Backpressure_Water/Conn1 -> Ejector S`；
   `Ejector B -> CathodeInletMassFlowSensor_FC -> Stack_Core`。
5. 删除副本内旧 `EGRValveRestriction`、`EGRPipe`、阀前后压力传感器和旧 cEGR BOP 接口；没有修改源阀门模型。
6. 增加 Ejector A/S/B 压力温度观测；A/S 压力暂以旧结果链名称 `routeA_p_egr_valve_up/down` 记录，物理含义已改为 primary/secondary pressure。
7. 增加 focused runner 的 `ejector_self_humidifying` 模型入口；既有 `self_humidifying` 入口保持原映射。

## 2. 验证证据

| 对象 | 实际证据 | 结论状态 |
|---|---|---|
| 官方 `Ejector (G)` 基准 | `model_check` healthy；官方 Gas 域 1 s 仿真完成 | `executed` |
| `EjectorFC.ssc` | `ssc_build('RouteAEjector')` 通过 | `implemented`、`structurally_verified` |
| 副本 Simscape update | update 通过；保存后 `Dirty=off` | `structurally_verified` |
| 副本关闭基线 | 5 A、180 s、尾窗 150--180 s；正式 `run_routeA_focused_study` 返回 `study.passed=1`、`simCompleted=1`、`case.passed=1` | `executed`、`behavior_verified_for_disabled_baseline` |
| 副本开启模式 | 392 A smoke，`ejector_enabled=true`；发生 `NE_DAE_IC_Failure` | `not_validated` |
| 最终结构检查 | `model_check(all)`：61 条 warning、无 error；`unconnected_lines` 和 Stateflow lint healthy | `structurally_verified_with_legacy_warnings` |

## 3. 当前参数状态

正式副本最终读回：

```text
ejector_enabled = false
area_throat = 1e-4 m^2
area_ratio_nozzle = 3
area_ratio_mixing = 8
min_area_ratio_secondary = 0.1
pressure_recovery = 1.05
```

开启模式失败期间使用过的窄几何和零容量参数没有保留为正式默认值。

## 4. 未决风险

- 当前 `Ejector (FC)` 是气相、准稳态压力平方关系组件，开启模式尚未完成冷态初值闭合。
- `ejector_enabled=false` 是当前可执行基线，不代表引射器性能已经实现或验证。
- 61 条 warning 主要来自聚焦模型既有未使用物理接口、变体端口和简化边界，后续需单独建立 warning ledger，不应直接归咎于引射器。
- 当前 `CommonGasPhaseBoundary_FC` 和 `SeparatorOrCondensation` 仍不是液水分离效率、液滴携带或排液模型。
- 当前空压机仍是质量流量源/图谱边界，没有可用于净功率结论的实机效率和功耗模型。

## 5. 下一步准入

1. 在不改变副本根级拓扑的前提下，增加冷态旁通/开启切换的正式架构配置。
2. 用高负荷和低负荷边界分别建立 A/S/B 压力窗口与引射比可行域。
3. 为 `Ejector (FC)` 增加独立组件测试：质量、四物种、能量、临界/亚临界和反向流。
4. 通过开启模式冷态 smoke 后，才把 `ejector_enabled=true` 作为研究用例，而不是默认基线。
