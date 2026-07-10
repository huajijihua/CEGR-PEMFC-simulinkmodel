# RouteA A9.7 控制执行器与宏观边界量化关系审计 v01

执行日期：2026-07-10

## 1. 目标与边界

A9.7 用当前 Route A 通用基底模型做“控制执行器 -> 宏观边界条件 -> 电堆响应”的量化审计。本轮不调 PID、不新增控制器、不修改或保存 `.slx` 结构，只通过 `SimulationInput` 临时扰动当前已存在的控制入口和参数。

本轮输出为 MATLAB base workspace 变量 `routeA_a9_7_actuator_boundary_sensitivity_audit` 和命令行摘要；不导出 CSV、图片、全量 timeseries 或模型副本。

## 2. 执行器扫描范围

| 执行器/入口 | 扫描值 | 当前控制语义 |
|---|---:|---|
| 电负载 `drive_cycle_power` | `17.47 / 50.96 / 77.95 kW` | 功率命令链路，不是直接电流密度边界 |
| Oxygen Excess Ratio 常数 | `2.0 / 2.5 / 3.0` | `OER setpoint -> PI cmd -> max rpm/map -> mdot source` |
| cEGR 阀面积比例 | `1e-6 / 5e-4 / 2e-3 / 1e-2 / 2e-2` | 阀面积到 EGR ratio 的开环关系，不是目标 EGR ratio 控制器 |
| `routeA_cathode_humidifier_gain` | `0 / 0.5 / 1` | 加湿器/旁路 gain，液态水机理不在本轮展开 |
| `Stack Temperature` setpoint | `70 / 80 / 90 C` | 冷却短时可运行性检查；30 s 不作为热稳态硬门槛 |

## 3. 验证状态

`run_routeA_a9_7_actuator_boundary_sensitivity_audit.m` 已通过 `checkcode`。完整 17 个工况均完成，均在 `30 s` 达到脚本稳态判据，无工况触发 `60 s` 重跑。

MATLAB MCP 的 `run_matlab_file` 调用两次达到 300 s 工具等待上限，但脚本在 MATLAB 内继续完成；随后通过 base workspace read-back 验证：

| 项目 | 结果 |
|---|---:|
| `generated` | `1` |
| `passed` | `1` |
| completed cases | `17/17` |
| power relation | `1` |
| OER relation | `1` |
| cEGR relation | `1` |
| humidifier relation | `1` |
| cooling advisory relation | `1` |

本轮修正了两个脚本后处理问题：

- `routeA_cathode_humidifier_gain` 必须通过 `SimulationInput.setVariable(..., 'Workspace', model)` 写入模型工作区，否则会掩盖加湿器入口是否实际生效。
- 关系检查中的 `group` 字段是 MATLAB string，需用 `string({results.group}) == groupName` 匹配；旧写法会导致关系检查误报全不通过。

## 4. 关键量化结果

### 4.1 电负载

| target power | actual power | compressor inlet mdot | stack heat KPI | `RH_ca_in` |
|---:|---:|---:|---:|---:|
| `17.47 kW` | `17.47 kW` | `0.014785 kg/s` | `3.4396 kW` | `0.9912` |
| `50.96 kW` | `50.96 kW` | `0.044882 kg/s` | `12.422 kW` | `0.9700` |
| `77.95 kW` | `77.95 kW` | `0.070022 kg/s` | `20.816 kW` | `0.9455` |

结论：功率需求上升会带动实际 stack power、压缩机入口总流量和 stack heat KPI 单调上升。当前模型入口是功率边界，不是直接电流密度边界。

### 4.2 OER setpoint

| OER setpoint | compressor inlet mdot | stack heat KPI | `egr_ratio_comp_in` |
|---:|---:|---:|---:|
| `2.0` | `0.036020 kg/s` | `12.624 kW` | `1.252e-05` |
| `2.5` | `0.044882 kg/s` | `12.422 kW` | `1.019e-05` |
| `3.0` | `0.053767 kg/s` | `12.313 kW` | `8.590e-06` |

结论：`OER setpoint` 上升会提高压缩机入口质量流量。它不是直接 rpm command；当前链路仍是 OER PI 输出驱动压缩机 map 和质量流源。

### 4.3 cEGR 阀面积

| 阀面积比例 | `egr_ratio_comp_in` | compressor inlet O2 | compressor inlet H2O | separated-water KPI |
|---:|---:|---:|---:|---:|
| `1e-6` | `1.019e-05` | `0.21000` | `0.011544` | `0.01124` |
| `5e-4` | `0.005044` | `0.20943` | `0.012778` | `0.011303` |
| `2e-3` | `0.020153` | `0.20767` | `0.016582` | `0.011504` |
| `1e-2` | `0.100004` | `0.19750` | `0.039144` | `0.012722` |
| `2e-2` | `0.198812` | `0.18231` | `0.074563` | `0.014694` |

结论：阀面积上升会单调提高 EGR 比例，同时压缩机入口 O2 降低、H2O 增加。当前是“阀面积 -> EGR ratio”开环关系，不是“目标 EGR ratio -> 阀面积”闭环控制。

### 4.4 加湿器 gain

| humidifier gain | `RH_ca_in` | compressor inlet H2O | separated-water KPI |
|---:|---:|---:|---:|
| `0` | `0.1240` | `0.015055` | `0.007639` |
| `0.5` | `0.9412` | `0.016533` | `0.011370` |
| `1` | `0.9695` | `0.016582` | `0.011504` |

结论：加湿器 gain 上升会显著提高阴极入口 RH，并提高水相关 KPI。本轮只审计 RH/水分离趋势，不展开液态水机理。

### 4.5 冷却 setpoint

`70 / 80 / 90 C` 三个 30 s 工况均完成，当前被记录为 cooling advisory。短时末值中的 stack power、压缩机入口流量和水气 KPI 基本不变，说明本轮只证明冷却 setpoint 扫描链路可运行，不把 30 s 热稳态差异作为硬结论。

## 5. 控制接口缺口

| 缺口 | 当前状态 | 后续动作 |
|---|---|---|
| 直接 rpm command | 当前压缩机链路是 OER PI -> max rpm/map -> mdot source | A9.8 决定是否新增直接 rpm/cmd wrapper |
| target EGR ratio controller | 当前只能设置阀面积 | A9.8 做目标 EGR 到阀面积搜索或控制接口设计 |
| 背压阀/阴极压力控制 | 本轮未使用稳定独立背压执行器 | A9.8 先识别或补最小压力执行接口 |
| cathode mdot 或 stoich target | 未直接暴露 | 先定义氧气充足性和 stoich 后处理 |
| cathode stack inlet p/T KPI | 压缩机入口和阴极出口 p/T 已有，stack inlet p/T 尚未统一 | 控制调参前补最小读回 KPI |

## 6. 后续建议

A9.7 已足够支撑进入 A9.8：优先把 target EGR ratio 与阀面积搜索/控制开放度治理讲清楚，再启动 A10 `Bench_Config_v1` 和 A11 `Vehicle_Config_v1`。不要直接把 A9.7 的开环阀面积扫描解释成已具备目标 EGR ratio 控制器。

A9.8 后迁移说明：`EGRValveRestriction` 已切换为受控面积端口，A9.7 回归入口中的开环阀面积扫描已改为设置 `routeA_egr_control_mode_id=2` 和 `routeA_egr_valve_area_direct`，不再依赖固定 `restriction_area` 作为执行入口。
