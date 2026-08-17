# Route A 被动 cEGR 研究规格与预检计划 v01

日期：2026-08-11；2026-08-14 按工程化架构总规划更新边界和指标口径
状态：S6-W0、S6-P0 与 S6-S1 已完成；S6-S2 单因素扩展待规格化。
前置证据：P3 参数契约收口、P4 cEGR profile、负载 ramp 和 OER step 的 600 s 动态验证均已通过。

## 1. 研究边界

本计划只研究活动 Route A 主模型中的**被动基线**阴极尾气回流：阴极出口分离后气相边界 -> 回流/排放分流 -> 阀阻力 -> EGR pipe -> 空压机入口混合。目标比经 PI、执行器和阀面积转换，实际回流由压差与气路网络决定。工程化架构对照和后续主动/自增湿配置服从 `RouteA_cEGR_PEMFC_工程化架构决策与聚焦模型总体规划_v01.md`。

以下内容不进入本轮：

- 主动循环泵、泵地图、泵功率或文献中的泵速策略；
- 液水库存、分离效率、排液和水淹结论；
- 阳极/冷却 status-only 信号的量化结论；
- 10 kW 外部台架、DQ60 或历史标定参数。

因此本轮结论限定为 `platform_default` 下被动 cEGR 的系统级气相、控制与电堆响应筛选，不能替代主动泵方案比较或产品标定。

## 2. 问题与假设

### 2.1 研究问题

在固定 40 kW Power 边界下，被动 cEGR 目标比和空气 OER 的组合如何改变：

1. 目标/实际回流比、回流流量、阀面积和阀压差；
2. 阴极入口空气流量、压力、温度、湿度与氧组分代理；
3. 电堆电压、功率、电流、氧化学计量比与气相闭合；
4. 可达性限制，包括控制跟踪、阀饱和、压差方向、供气能力和求解失败。

### 2.2 研究假设

- H1：在相同 Power/OER 下，提高目标 cEGR 比会提高实际回流量并改变入口混合气组分与湿度状态。
- H2：较高 OER 可改变可达回流量、阀压差和氧供给裕度，故最优回流比不应脱离 OER 单独宣称。
- H3：被动回流的实际比受阀/管路压差约束，目标比与实际比必须分别报告。

本轮不预设电压、RH 或氧代理的单调方向；只有通过气相闭合与控制验收的结果才可用于比较。

## 3. 工况设计

### 3.1 S6-P0 两例预检

| 项目 | 设置 |
|---|---|
| 电边界 | Power = 40 kW |
| OER | 3.0 |
| cEGR | 0 与 0.3 |
| 初态 | `cold_start_only` |
| 时长/统计窗 | 600 s；540--600 s 尾窗 |
| 求解 | `VariableStepAuto`，`RelTol=AbsTol=1e-3`，稳态 runner 默认 `MaxStep=5 s` |
| runner | `run_routeA_electrical_boundary_study`，Power 单模式、serial、`runWaterLedger=false` |

两例已通过后才开始筛选矩阵；若后续预检任一例为 `not_steady`、`cegr_tracking`、`gas_closure`、`electrical_boundary`、限幅或求解失败，先定位该失败类别，不扩展矩阵。

### 3.2 S6-S1 九例筛选矩阵

固定 Power = 40 kW，采用如下全因子：

| 因子 | 水平 |
|---|---|
| 目标 cEGR 比 | 0, 0.1, 0.3 |
| OER | 2.5, 3.0, 3.5 |
| 背压、RH、堆温、阀/管路几何 | `platform_default` 固定 |

边界固定的原因：先识别被动 cEGR 与空气供给的主效应及可达区域，不将背压、湿度或设备几何同时纳入造成不可解释的交互。S6-S1 已 9/9 通过；下一切片优先选择单独的阴极背压扩展，因为背压直接影响被动回流的压差与可达性。

## 4. KPI 与数据口径

| 域 | 必须记录 | 口径与边界 |
|---|---|---|
| 电边界 | 目标/实际 Power、Voltage、Current、边界误差 | Power 尾窗误差和完整 `logsout` 时序由正式 runner 计算 |
| cEGR 控制 | target、执行器命令、分流点 `r_split`、空压机入口 `x_comp_in`、`r_fresh`、`EGR_mdot_log`、阀面积/面积分数、上下游压力、压差、控制误差 | target 与 actual 不得混称；`EGR_mdot_log` 单位取注册表 `kg/s`，分流点排放流量必须同时可读回 |
| 阴极气路 | 压缩机入口流量/压力/温度、阴极出口压力/温度、入口/出口组分、RH、lambda | 当前已注册信号和气相闭合结果；组分口径必须说明为 registry 的现有质量分数口径 |
| 氧代理 | 阴极入口氧组分与入口压力 | 当前正式结果不把它直接命名为 `pO2`。若后续要报告氧分压，必须明确 mole-basis 换算、湿/干基和单位，并增加 runner 读回证据 |
| 水 | `waterSeparationRate_kg_s`、入口/出口 RH | 仅 L2 气相/饱和过量代理；不报告液水库存、排液或分离效率 |
| 质量与约束 | gas closure、lambda、阀压方向、阀面积限幅、压缩机流量跟踪、purge/free 状态、failure category | 任一硬门失败即排除该工况的性能排序 |

## 5. 准入与排除规则

单工况只有同时满足下列条件才进入横向比较：

1. `simCompleted=true`，观测契约 `passed=true`，22 个 registered signal 可读；
2. `boundaryPassed=true`、`cegrPassed=true`、`gasClosurePassed=true`；
3. `lambdaPassed=true`、`pressureDirectionPassed=true`、`areaPassed=true`、`compressorMdotTrackingPassed=true`；
4. 以 `steadyPassed=true` 为正式稳态排序门。未稳态工况可保留作动态诊断，但不参与“最优”判断；
5. 不因液水 L2 警告排除，但所有结果必须带 `L2_not_closed` 水管理边界。

## 6. 执行纪律与结果表达

- 只调用 `run_routeA_electrical_boundary_study`；不为 S6 再建并行 runner。
- S6-P0 先 serial 执行并保存 compact study 摘要；通过后 S6-S1 可采用 `parsim`，但 case 参数、模型版本和统计窗不变。
- 每个结果表至少同时显示 `target cEGR / actual r_split / x_comp_in / r_fresh / target OER / actual gas-path KPI / I-V-P`，并另列失败或排除原因。
- 研究报告应将“控制可达性”和“性能响应”分开：控制不通过的工况不参与性能优劣比较。
- 增加主动泵方案前，必须按工程化架构总规划另立配置和 interface contract；不得把当前阀面积、压差或压缩机功率代理称为泵性能。

## 7. 当前出口

本计划已完成两例 S6-P0 预检和 9 例 S6-S1 筛选，实际结果见 `02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260811_S6被动cEGR_S1筛选_v01.md`。这些结果继续作为被动基线历史证据；后续扩展不再由本文件单独决定，统一按工程化架构总规划的 Gate 0--Gate 3 和单轴对照顺序执行。
