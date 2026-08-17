# Route A cEGR-PEMFC 聚焦模型 P2 公共气相边界与分流重构

日期：2026-08-14
状态：公共气相 L2 边界和分流子任务已实现、结构读回并执行短时 smoke；公共主干背压控制未实现，P2 出口门未通过。

## 前置决策

- [两种阀门被动架构聚焦模型改造实施方案](../../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md) 的 P0.5 和 P1 已完成。
- 本轮仍为 L2 气相热湿-压力筛选。`CommonGasPhaseBoundary_FC` 不移除水蒸气、不修改气相组分，也不表示真实液水分离器。
- 仅执行 10 s 结构 smoke，不建立低负荷研究 case、性能排序或阀门控制结论。

## 实际完成的工作

实施对象：

- 正式模型：`04_Simulink物理网络模型/01_模型/RouteA_Cathode_cEGR_Focused/PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`
- 正式 runner：`04_Simulink物理网络模型/03_脚本/RouteA_Cathode_cEGR_Focused/run_routeA_focused_study.m`

实际气体连接读回如下：

```text
CathodeOutletChamber.Conn10
 -> CommonGasPhaseBoundary_FC (Flow Resistance (FC))
 -> EGR Mass Flow Rate Sensor -> CEGR Local Restriction -> EGR Pipe -> CompressorInletMixer
 -> Exhaust Mass Flow Rate Sensor -> Pressure Relief Valve -> exhaust Reservoir

CathodeOutletChamber.Conn11 -> CathodeOutletUnusedPortCap_FC (Cap (FC))
```

具体改动：

- 原 `CathodeWaterSeparator_FC`（官方 `Flow Resistance (FC)`）重命名为 `CommonGasPhaseBoundary_FC`，只承担共享气相压损和 L2 观察位置。
- 新增官方 `FuelCell_lib/elements/Cap (FC)`，名称为 `CathodeOutletUnusedPortCap_FC`，封止未使用的出口腔第二气体端口。
- 保持排放支路的 `Pressure Relief Valve` 原位置和语义。它不构成公共主干背压控制。
- runner 的异常记录由仅保存 `exception.message` 改为保存 `getReport(..., 'extended', 'hyperlinks', 'off')`，用于保留 Simscape DAE 首因证据。

## 验证证据

模型检查和保存：

- P2 作用域的 `model_check` 仅报告 5 项既有 `Cathode Exhaust/Pipe` 端口警告；未报告 `CommonGasPhaseBoundary_FC` 或 `CathodeOutletUnusedPortCap_FC` 的新增 error。
- 根模型 `model_check(all)`：0 error，63 个 warning，与 P1 基线同量级；这些 warning 不能视为结构健康通过。
- MATLAB 读回：`Dirty=off`，`StopTime=100`，`Solver=VariableStepAuto`。

正式 runner 使用 `SimulationInput -> sim` 串行执行两项 10 s、5 A smoke，启动斜坡 1 s、指令偏置 0.5 s、尾段为 5--10 s：

| case | CEGR 目标 | 执行状态 | 关键读回 | 结论边界 |
|---|---:|---|---|---|
| `p2_common_boundary_zero_cegr_10s` | 0 | `matrixComplete=1`，`simCompleted=1` | `m_return=2.4888e-08 kg/s`，`m_exhaust=1.63445e-02 kg/s`，`r_split=1.5228e-06` | 零回流链路可执行；未稳态 |
| `p2_common_boundary_small_cegr_10s` | 0.05 | `matrixComplete=1`，`simCompleted=1` | `m_return=6.9639e-04 kg/s`，`m_exhaust=1.56788e-02 kg/s`，`r_split=0.042527`，阀压差 `0.060243 MPa`，阀有效面积 `2.8890e-06 m^2` | 小回流的压差、开度和支路流量可读；未稳态 |

两项 case 的 `passed=0`，失败分类均为 `compressor_mdot_tracking;not_steady`，无 `errorId`。因此只证明结构和结果通道可执行，不能证明目标分流精度、压缩机控制性能、压力裕度或热湿状态正确。两项结果文件为：

- `04_Simulink物理网络模型/02_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_P2_common_gas_boundary_zero_cegr_smoke_20260814.mat`
- `04_Simulink物理网络模型/02_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_P2_common_gas_boundary_small_cegr_smoke_20260814.mat`

快速加速模式发出已有 `To Workspace` timeseries 和 Simscape logging 不记录的警告。本轮数值来自 runner 的正式结果字段，不将这些未记录的工作区信号或 Simscape log 当作证据。

## 阻塞点和根因

首次尝试将 `CathodeOutletChamber.Conn10` 与 `Conn11` 同时并接至一个 `Flow Resistance (FC)` 后再分流，零回流 smoke 在初始化阶段发生 `NE_DAE_IC_Failure`。扩展报告显示 EGR 管、压力释放阀、出口腔和公共边界附近的 DAE 线性代数/迭代矩阵近奇异。恢复 P2 前拓扑并运行相同 10 s、零回流 case 后仿真可执行，表明该并接方案破坏了出口腔端口约束。最终方案只使用 `Conn10`，并以官方 `Cap (FC)` 封止 `Conn11`。

## 完成状态和未决项

- `implemented`：公共气相 L2 边界、显式回流/排放分支、两支路质量流量读回和未使用端口封止。
- `structurally_verified`：官方块来源和物理连接已读回；模型无 error severity。
- `executed`：零回流和小回流短时 smoke 已执行。
- `behavior_verified`：未完成，因两项 smoke 均未稳态且压缩机质量流量跟踪未通过。
- `not_validated`：公共背压控制、真实水汽分离/液水、分离后支路组分、关键温湿状态、气相质量闭合、配置 A 和配置 B。

下一步仍在 P2：先以已审计的阀端口语义建立公共主干背压控制，并在不引入独立质量流量源的前提下复验零/小回流。P2 出口门通过前，不进入 P3。

## 增量：公共背压控制与 P2 出口门（2026-08-14）

在 P2 初始分流结构上完成以下实际修改：

- 排放支路 `Cathode Exhaust/Pressure Relief Valve` 的压力命令由 `RouteA_CMD_cathode_outlet_pressure_MPa_abs` 改为 `env_p`。该阀仍是排放到环境的泄放边界，不承担公共主干节流。
- 在 `CathodeOutletChamber.Conn10` 与 `CommonGasPhaseBoundary_FC` 间新增官方 `CommonBackpressureValve_FC`，ReferenceBlock 为 `FuelCell_lib/elements/Local Restriction (FC)`。
- 新阀的面积物理信号连接为：`routeA_p_outlet (Pa) -> 1e-6 -> (p_actual_MPa - p_target_MPa) -> 20*cegr_valve_max_area -> actuator -> 0.5*cegr_valve_max_area bias -> [cegr_valve_open_min_area, cegr_valve_max_area] -> Simulink-PS (m^2) -> AR`。`p_target_MPa` 读自既有全局 Goto `RouteA_CMD_cathode_outlet_pressure_MPa_abs`，没有新增质量流量源、回流泵或用户侧命令字段。
- 面积上限、下限和执行器时间常数暂复用现有 CEGR 阀变量，仅作为结构 smoke 的内部原型；其数值并非公共背压阀的设备标定值。

改造后 `model_read` 读回的主气路为：

```text
CathodeOutletChamber.Conn10
 -> CommonBackpressureValve_FC
 -> CommonGasPhaseBoundary_FC
 -> Return Mass Flow Sensor -> CEGR valve -> EGR Pipe -> CompressorInletMixer
 -> Exhaust Mass Flow Sensor -> exhaust pipe -> Pressure Relief Valve(env_p) -> Reservoir
```

`model_check` 在出口作用域仅保留既有排放管口警告；根模型为 0 error、63 个 warning。模型由 MATLAB 保存，读回 `Dirty=off`。

### 正式 smoke 证据

正式 runner `run_routeA_focused_study` 使用 `SimulationInput -> sim` 串行执行三项冷态 5 A、10 s 工况，尾窗为 5--10 s。结果文件：

`04_Simulink物理网络模型/02_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_P2_common_backpressure_gain20_smoke_20260814.mat`

| case | 压力设定 MPa(abs) | CEGR 目标 | 实际出口压力 MPa(abs) | 实际回流 kg/s | 实际排放 kg/s | 总质量基分流比 |
|---|---:|---:|---:|---:|---:|---:|
| `p2_common_bp_gain20_zero_cegr_10s` | 0.1613 | 0 | 0.154681 | `3.6450e-09` | `1.61570e-02` | `2.2490e-07` |
| `p2_common_bp_gain20_small_cegr_10s` | 0.1613 | 0.05 | 0.154774 | `4.55764e-04` | `1.57038e-02` | 0.027199 |
| `p2_common_bp_gain20_low_target_10s` | 0.1500 | 0 | 0.145464 | `3.6797e-09` | `1.65194e-02` | `2.2242e-07` |

压力设定由 `0.1613` 降至 `0.1500 MPa(abs)` 时，实际出口压力由 `0.154681` 降至 `0.145464 MPa(abs)`，证明公共阀控制方向正确。默认设定仍有约 `-6.6 kPa` 的尾窗偏差；三项均为 `not_steady`，小回流工况另有 `cegr_tracking` 未通过。因此只将方向响应列为 `behavior_verified`，不将压力或 CEGR 目标跟踪列为通过。

三项 `gasClosure.passed=1`，小回流的回流混合残差最大绝对值为 `5.4405e-06 kg/s`。小回流工况的出口至压缩机入口压力裕度为 `0.0534 MPa`，为正；七个 L2 气相湿度测点均被采集，饱和度最大值为 `0.8899`。这些数据只支持气相压力方向、混合闭合和超饱和风险筛查，不支持液水、真实分离或压缩机湿气耐受结论。

## P2 完成状态和后续边界

- `implemented`、`structurally_verified`、`executed`：公共背压两端节流、固定下游环境边界、L2 气相边界、显式分流和正式 smoke。
- `behavior_verified`：压力设定扰动方向、回流/排放支路流量可读、气相混合闭合。
- `not_validated`：稳态压力和 CEGR 目标跟踪、公共阀标定、真实水汽分离、液水、分流后支路组分、压缩机湿气耐受和配置 B 跨膜传质/传热。

P2 出口门按结构、读回、短时执行、分流流量、混合闭合和气相风险观测要求通过。P3 可以开始，但其配置 A 验证必须保留本节全部 `not_validated` 边界，且不能把 10 s smoke 用作低负荷工程性能结论。
