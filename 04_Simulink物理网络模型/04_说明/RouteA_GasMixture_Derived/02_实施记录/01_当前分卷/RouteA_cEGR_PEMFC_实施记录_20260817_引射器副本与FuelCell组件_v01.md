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

## 4. 开启回流不收敛的根因诊断

### 4.1 隔离实验

所有以下实验均针对同一副本、同一冷态 `SimulationInput` 输入链执行，未保存模型参数覆盖：

| 实验 | 结果 | 证据用途 |
|---|---|---|
| 5 A，`ejector_enabled=false` | `SUCCESS` | 关闭模式基线可初始化 |
| 5 A，`ejector_enabled=true` | `NE_DAE_IC_Failure` | 开启本构在低负荷即触发失败 |
| 392 A，`ejector_enabled=false` | `SUCCESS` | 高负荷主模型和高层连线可初始化 |
| 392 A，`ejector_enabled=true` | `NE_DAE_IC_Failure` | 失败由开启本构触发，不是 392 A 单独造成 |
| 392 A，开启且极大端口/喉部面积、`pressure_recovery=1.000001` | `NE_DAE_IC_Failure` | 将压降参数软化仍不能初始化 |
| 392 A，开启，`pressure_recovery=1.05/1.5/1.75/1.8/2.0` | 全部 `NE_DAE_IC_Failure` | 不是单一 `pressure_recovery` 数值造成 |

### 4.2 高层拓扑读回

`model_read` 读回的实际连接为：

```text
blk_667.B  <->  blk_1174.A
blk_810.Conn1  <->  blk_1174.S
blk_1174.B  <->  blk_664.A  <->  blk_869.B
```

其中 `blk_667` 是空压机/中冷器侧 BOP，`blk_810.Conn1` 是阴极尾气公共背压和 EGR 质量流传感器后的回流支路，`blk_869.B` 是 `Stack_Core` 阴极入口。A/S/B 没有读回互换；压力、温度和湿度传感器均是并联观测支路，不是主流路断接证据。

### 4.3 首个不可满足关系

关闭基线 392 A 末端读数为：

```text
p_A = 183.437 kPa
p_B = 183.437 kPa
p_S = 104.336 kPa
p_S - p_B/1.05 = -70.366 kPa
```

`EjectorFC.ssc` 开启时的核心关系是：

```text
A.p - p_mix == dp_A_model
S.p - p_mix == dp_S_model
p_mix = B.p/pressure_recovery
```

在 `mdot_S > 0` 的正向回流定义下，`dp_S_model` 的符号为正；但基线压力给出的 `S.p - p_mix` 为负。因此当前组件不能表示“低压阴极尾气被高压主流抽吸后在 B 端恢复压力”的引射过程，初态方程在预期回流方向上没有解。`NE_DAE_IC_Failure` 最终显示在回流支路 `Pipe (N Gas)1` 和 `FuelCell.PortConvection`，这是该不满足关系向下游传播后的首个报告位置，不是 Pipe 本身先被证明损坏。

### 4.4 本构实现结论

当前组件只建立了 A/S 到共同 `p_mix` 的两个平方压降关系、三端口质量/组分/能量守恒和统一流出侧焓/组分变量；没有建立主喷嘴、次级喉部、混合腔动量交换、临界/亚临界切换和扩压压力恢复的耦合方程。因而它不能作为已实现的 FuelCell 域引射器性能组件。面积、效率或 `pressure_recovery` 调整只能改变约束窗口，不能替代缺失的主流-次流动量耦合。

### 4.5 参数接口结论

正式 `routeA_focused_parameter_defaults`、`routeA_focused_case_template` 和 `routeA_focused_parameter_bridge` 当前没有写入 `ejector_enabled`、喉部面积、面积比、效率或压力恢复参数。开启诊断使用了临时 `SimulationInput.setBlockParameter`，不属于正式 runner 的可复现 case contract。即使后续本构修复，仍需先补齐唯一参数写入点、单位、范围和观测响应。

**根因裁决：** 高层模块和 A/S/B 连接目前读回正确；开启回流不收敛的主因是 `EjectorFC.ssc` 的 FuelCell 域本构方程不能提供被动引射所需的压力-动量耦合，当前默认压力窗口又直接与正向回流方向矛盾。参数设置和参数接口是次级问题，不能通过简单调参宣称修复。

### 4.6 后压缩机引射架构的物理可行性

架构本身不裁决为绝对不可行。使用同一官方 `Ejector (G)` 基准、仅替换三个 Reservoir 压力，得到以下 Gas 域结果：

| 边界 `pA/pS/pB` | `mdot_A` | `mdot_S` | `mdot_B` | `omega` | 方向结论 |
|---|---:|---:|---:|---:|---|
| `0.183437/0.104336/0.183437 MPa` | 0.001341 | -0.145957 | 0.144616 | 0.0545 | 次流反向 |
| `0.250/0.104336/0.200 MPa` | 0.056894 | -0.093143 | 0.036248 | 0.0045 | 次流反向 |
| `0.250/0.104336/0.180 MPa` | 0.056897 | -0.010880 | -0.046017 | 0.0407 | 接近方向边界 |
| `0.250/0.104336/0.170 MPa` | 0.056897 | 0.000905 | -0.057802 | 0.0955 | 正向吸入 |
| `0.250/0.104336/0.160 MPa` | 0.056896 | 0.008536 | -0.065432 | 0.1687 | 正向吸入 |
| `0.183437/0.104336/0.140 MPa` | 0.041595 | 0.002419 | -0.044014 | 0.1449 | 正向吸入但裕度小 |

这里的正负号采用官方块的端口质量流量约定；`mdot_S>0` 表示次流从 S 端进入引射器。上述结果仅证明官方 Gas 域的方向和压力窗口可行，不是 FuelCell 四物种闭环验证。

物理裁决为“条件可行”：必须提高空压机中冷器后主流压力、降低引射器 B 端所需背压，或同时采取两者，使 `pA-pB` 留出喷嘴/混合/扩压压力裕度；同时需要满足压缩机图谱、喘振裕度、主流质量流量和净功率约束。当前 `pA≈pB≈0.183 MPa` 的副本边界只能得到反向次流，不能作为正向 cEGR 工况。

### 4.7 推荐改造顺序

1. 保留当前高层 A/S/B 位置，不通过交换端口修复失败。
2. 用官方 Gas `Ejector (G)` 对 `pA、pS、pB、mA` 做低/中/高负荷边界扫频，冻结正向吸入、引射比和反向流边界。
3. 重建 FuelCell 域组件：用官方引射器映射或受控查表表达主流喷嘴、次流吸入、混合/扩压和方向状态；不要继续使用两个独立平方压降式 `dp_A_model/dp_S_model` 代替引射器。
4. 组件内部只通过质量、四物种和能量守恒得到 B 端混合状态，并对 `mdot_S` 正向、零流和反向流使用平滑且有状态的边界处理。
5. 在系统层增加 A/B 旁通和 S 端隔离/止回保护：冷态先旁通，只有 `pA-pB` 和 `pA-pS` 达到可行窗口后才渐开引射支路；窗口失效时切回旁通，避免把反向流硬塞入电堆入口。
6. 将引射器几何、效率、压力窗口和启用状态接入正式 runner 参数合同，再进行组件级和整机级验证。

## 5. 未决风险

- 当前 `Ejector (FC)` 是气相、准稳态压力平方关系组件，开启模式尚未完成冷态初值闭合。
- 当前 `Ejector (FC)` 不应进入开启模式性能研究；必须先完成本构重建或明确的官方域代理裁决。
- `ejector_enabled=false` 是当前可执行基线，不代表引射器性能已经实现或验证。
- 61 条 warning 主要来自聚焦模型既有未使用物理接口、变体端口和简化边界，后续需单独建立 warning ledger，不应直接归咎于引射器。
- 当前 `CommonGasPhaseBoundary_FC` 和 `SeparatorOrCondensation` 仍不是液水分离效率、液滴携带或排液模型。
- 当前空压机仍是质量流量源/图谱边界，没有可用于净功率结论的实机效率和功耗模型。

## 6. 下一步准入

1. 暂停当前 `EjectorFC.ssc` 的参数标定和开启模式性能研究。
2. 先用官方 Gas 域结果冻结压力窗口和方向边界。
3. 在不改变副本根级拓扑的前提下，完成 FuelCell 域本构重建或官方 Gas/Moist Air 代理路线裁决。
4. 为候选组件增加独立测试：质量、四物种、能量、临界/亚临界、正向吸入和反向流。
5. 补齐 `ejector_enabled`、几何、效率和压力恢复的正式参数合同及 runner 写入点。
6. 只有组件级测试、旁通切换和开启模式冷态 smoke 通过后，才把 `ejector_enabled=true` 作为研究用例，而不是默认基线。

## 7. 2026-08-17 参数合同增量

前置决策：沿用本记录第 4 节的 A/S/B 拓扑裁决和第 7 节的“先官方 Gas 压力窗口、后 FuelCell 本构”顺序；当前引射器仍不进入开启模式性能研究。

### 7.1 实际完成项

1. 在 `routeA_focused_parameter_defaults.m` 中新增 `designPoint`、`ejector` 和 `bop.design` 合同。额定设计记录为 `j=1.6 A/cm^2`、`608 A`、`241.33344 kW`；压缩机设计流量假设为 `0.330 kg/s`，来源标记为 `external_case`，不是硬件验证结果。
2. 在 `routeA_focused_case_template.m` 中写入 `designPoint`、`ejector` 和 `bopDesign`。
3. 在 `routeA_focused_parameter_bridge.m` 中新增 15 项 Ejector 参数映射，覆盖启用状态、喉部/面积比、四项效率、A/B/S 面积、压力恢复和两项平滑参数。
4. 在 `run_routeA_focused_study.m` 中通过 `SimulationInput.setVariable(..., 'Workspace', model)` 写入上述参数。
5. 使用 MATLAB/Simulink 结构化模型编辑，将 `Cathode_Ejector_FC` 的 15 个 compile-time 参数改为工作区变量引用；在模型工作区保存对应 15 项默认值，避免 runner 写入前的模型 checksum 解析失败。

### 7.2 验证证据

| 对象 | 实际证据 | 结论状态 |
|---|---|---|
| MATLAB Code Analyzer | defaults、runner 无 issue；parameter bridge 仅保留一条既有动态数组扩展 info | `static_checked` |
| case adapter/bridge | `schema=RouteA_Focused_CaseAdapter_v01`；`ejector_enabled=0`；`throat=0.00042 m^2`；`areaA=0.00125 m^2`；`mapping_count=47`；`write_points=37` | `executed`、`contract_verified` |
| 模型块参数读回 | `blk_1174` 的 15 个参数均为 `ejector_*` 工作区变量引用 | `structurally_verified` |
| 模型保存状态 | `save_system` 后 `Dirty=off`，正式 `.slx` 存在 | `saved_and_verified` |
| 参数化后关闭基线 | 10 s；focused runner；`study.passed=1`、`matrixComplete=1`、`simCompleted=1`、无 failed case | `executed`、`behavior_verified_for_disabled_baseline` |

### 7.3 首个阻塞及处置

参数块第一次改为变量引用后，runner 在写入 `SimulationInput` 前计算模型 checksum，因模型工作区没有同名变量而失败。使用 MATLAB Model Workspace API 写入默认值并保存模型后，checksum 阶段通过，随后关闭模式 10 s smoke 通过。该修复只解决参数初始化顺序，不改变 `EjectorFC.ssc` 的开启模式不可解结论。

### 7.4 完成状态与未决项

- 参数合同、模型写入点和关闭基线已完成并验证。
- `ejector_enabled=false` 仍是唯一正式默认；`true` 仍为 `not_validated`。
- 已完成首轮官方 Gas `pA/pS/pB/mA` 联合扫描；FuelCell 本构重建、旁通/S 端隔离保护和开启模式组件级守恒测试仍未完成。

## 8. 2026-08-17 官方 Gas 压力窗口扫描

前置决策：本记录第 6 节第 2 项；使用官方 `Ejector (G)` 冻结压力方向和引射比参考，不把结果解释为 FuelCell 四物种闭环结果。

### 8.1 实际完成项

1. 在 `RouteA_Ejector_Gas_Benchmark_v01.slx` 的 A/S/B 物理支路串入官方 `Flow Rate Sensor (G)`，并增加 PS-Simulink、ToWorkspace 和 PHI 终止链。
2. 传感器加入后，使用两个物理网络的初始连接诊断定位 solver 拓扑问题；最终读回为一个 solver 覆盖完整 Gas 网络，结构检查恢复 `healthy`。
3. 新增唯一 runner：`run_routeA_ejector_g_pressure_window_scan.m`。每个 case 通过 `SimulationInput.setBlockParameter` 写入三个 Reservoir 的压力/温度和 Ejector 几何/损失参数，仿真后从 `SimulationOutput` 读回 `mdot_A/mdot_S/mdot_B`。
4. 默认矩阵包含 11 个 case：`pA=0.25 MPa`、`pS=0.104336 MPa` 的 5 个 `pB` 点；`pA=0.183437 MPa`、`pS=0.104336 MPa` 的 3 个 `pB` 点；以及 `pA=0.270 MPa`、`pS=0.203 MPa` 的 3 个 `pB` 点。

### 8.2 验证证据

| 对象 | 实际证据 | 结论状态 |
|---|---|---|
| 官方 Gas 模型结构 | `model_read` 读回三条传感器支路、A/S/B 方向和 PHI 终止；`model_check(unconnected_ports,unconnected_lines)`=`healthy` | `structurally_verified` |
| 官方 Gas runner | Code Analyzer `code_issues=[]` | `static_checked` |
| 11 点矩阵 | `study.passed=1`、`matrixComplete=1`、`failed=0`；每点 `simCompleted=1`、输出有限 | `executed`、`behavior_verified_in_official_gas_domain` |
| 质量闭合 | 11 点 `mdot_A + mdot_S - mdot_B = 0`（记录值为 0） | `observed` |
| 持久化结果 | `03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Ejector_Gas_PressureWindowScan_20260817_v01.mat` 存在；基准模型 `Dirty=off` | `saved_and_verified` |

关键方向结果：

| `pA/pS/pB` MPa | `mdot_S` kg/s | `omega=mdot_S/mdot_A` | 方向 |
|---|---:|---:|---|
| `0.250/0.104336/0.200` | `-0.09314247` | `-1.637114` | 反向 |
| `0.250/0.104336/0.180` | `-0.01088004` | `-0.1912229` | 反向 |
| `0.250/0.104336/0.170` | `0.0009049643` | `0.01590534` | 正向吸入 |
| `0.250/0.104336/0.160` | `0.008535780` | `0.150025` | 正向吸入 |
| `0.183437/0.104336/0.140` | `0.002418968` | `0.05815512` | 正向吸入 |
| `0.270/0.203/0.235` | `-0.002714708` | `-0.05013328` | 反向 |
| `0.270/0.203/0.225` | `0.02145466` | `0.3951873` | 正向吸入 |

### 8.3 结论边界

- 官方 Gas 域首轮结果支持“后压缩机引射架构条件可行”，并冻结了首轮压力方向边界。
- `pA-pB` 不能只看静态正压差；还必须同时满足 `pA/pS`、几何损失、主流流量和出口背压的联合窗口。
- 负引射比只表示官方传感器读到的次流反向，不应作为 FuelCell 域回流量或 cEGR 性能结果。
- 该结果不解除 `EjectorFC.ssc` 开启模式 `NE_DAE_IC_Failure`，也不允许开启 `ejector_enabled=true` 进入整机标定。

## 9. 2026-08-17 FuelCell 本构方程平衡与开启初值诊断

前置决策：沿用本记录第 6 节和第 8 节的“官方 Gas 冻结窗口、FuelCell 域独立闭合、开启模式未验证”边界。本节只记录已执行的本构修改和诊断结果，不改变默认参数或放宽验收标准。

### 9.1 实际完成项

1. 更新 `+RouteAEjector/EjectorFC.ssc` 的端口对流闭合：A 端作为主流入口，B 端按 A/S/B 正向入口流量计算混合物性并平滑退化到 A 端物性，保留四物种质量、组分和能量守恒。
2. 增加主流激活度 `motive_activation`，使无主流时压力恢复和次流压力约束接近透明状态；该处理只用于冷态数值连续性，尚未通过开启模式行为验证。
3. 重新运行 `ssc_build('RouteAEjector')`，最终版本构建通过；此前“变量数超过方程数”和“方程数超过变量数”均已通过端口方程数量调整消除。

### 9.2 验证证据

| 对象 | 实际证据 | 结论状态 |
|---|---|---|
| FuelCell 本构构建 | 最终 `ssc_build('RouteAEjector')` 通过 | `implemented`、`structurally_verified` |
| 关闭模式回归 | `ejector_enabled=false`、5 A、180 s、尾窗 120--180 s；`study.passed=1`、矩阵完整、无 failed case | `behavior_verified_for_disabled_baseline` |
| 开启模式正确参数写入 | `caseCfg.ejector.enabled=true` 后读回 `ejector_enabled=1`；仿真进入 Simscape 初始条件求解 | `parameter_contract_verified`、`not_validated` |
| 开启模式 5 A/180 s | `NE_DAE_IC_Failure`；不再是方程计数错误 | `not_validated` |
| 开启模式敏感性 | `pressureRecovery=1.001`、`mdotSmoothing=1e-4`、直接起步、0 A 和仅压力诊断闭合均仍 `NE_DAE_IC_Failure` | `root_cause_narrowed` |
| 模型读回 | `blk_1174` 仍引用 15 项 `ejector_*` 工作区变量；`model_check` 仍为既有 61 条 warning、无 error；正式模型 `Dirty=off` | `structurally_verified_with_legacy_warnings` |
| MATLAB runner 静态检查 | `run_routeA_focused_study.m` 无 issue；parameter bridge 保留既有动态数组扩展 info | `static_checked` |

### 9.3 当前裁决

- 当前首个真实阻塞是三端压力网络与现有 FuelCell 冷态初值边界不相容；失败位置随端口物性闭合变化，但 0 A、直接起步和仅压力闭合均不能初始化。
- `ejector_enabled=false` 仍是唯一正式可执行默认；`ejector_enabled=true` 只能标记为 `not_validated`，不得进入性能研究或参数标定。
- 当前源码已保留物理上的 A 主流、S 次流、B 混合出口闭合；诊断性“关闭模式物性闭合”未保留为最终实现。
- 下一步应先建立独立 FuelCell 三端口组件测试或冷态旁通/隔离初始化策略，再回到整机开启 smoke；不能继续通过单独调节 `pressureRecovery` 或平滑参数宣称解决。

## 10. 2026-08-17 独立 FuelCell 三端口组件夹具

前置决策：沿用本记录第 9 节“先独立 FuelCell 三端口闭合，再回到整机”的准入顺序；本节只记录夹具结构和实际仿真证据。

### 10.1 实际完成项

1. 新建正式组件测试模型：`01_模型/RouteA_Cathode_cEGR_Focused/RouteA_Ejector_FuelCell_ComponentTest_v01.slx`。
2. 模型包含三个官方 `Reservoir (FC)`、三个官方 `Pipe (FC)`、三个 `Perfect Insulator`、一个 `Ejector (FC)`、一个 `Gas Mixture Properties (FC)` 和一个 `Solver Configuration`。
3. 读回的主流连接为 `Reservoir A -> Primary Conditioning Pipe -> Ejector A`；次流为 `Reservoir S -> Secondary Conditioning Pipe -> Ejector S`；出口为 `Ejector B -> Outlet Conditioning Pipe -> Reservoir B`。没有保留 Chamber、重复 solver 或重复物性块诊断拓扑。
4. `EjectorFC.ssc` 最终版本重新执行 `ssc_build('RouteAEjector')` 并通过；诊断期间的临时本构改写未保留为最终源码。

### 10.2 验证证据

| 对象 | 实际证据 | 结论状态 |
|---|---|---|
| 组件模型结构 | `model_read` 读回三条 Pipe 的 A/H/B 连接、单一 solver 和 Gas Properties | `structurally_verified` |
| 组件模型保存 | `save_system` 后 `Dirty=off` | `saved_and_verified` |
| 关闭模式 | 320 K、三端 101325 Pa、`ejector_enabled=false`、0.1 s；返回 `simlog` 和 `tout` | `executed`、`behavior_verified_for_disabled_fixture` |
| 结构检查 | `model_check(unconnected_ports,unconnected_lines)` 返回 15 条 Pipe 端口 warning、无 error；与 `model_read` 的物理连接读回并列保留，未将 warning 宣称为 healthy | `structurally_verified_with_checker_warnings` |
| 开启模式代表性 case | `pA=130 kPa`、`pS=100 kPa`、`pB=110 kPa`、出口 Pipe `p0=104.762 kPa`、320 K、`pressure_recovery=1.05`；`NE_DAE_IC_Failure` | `not_validated` |

### 10.3 当前裁决

- 独立夹具已经可以作为关闭模式的 FuelCell 网络边界和保存资产，但还不能作为正向吸入或反向流性能验证夹具。
- 开启失败的首个实际报告位置为 `Outlet Conditioning Pipe`，涉及官方 `FuelCell.elements.Pipe` 的冷凝热、冷凝质量流和 `simscape.function.blend` 方程；这组证据不能证明 Pipe 本身是根因，也不能证明 Ejector 开启方程已经可解。
- `ejector_enabled=false` 继续是唯一正式可执行默认；当前不进入整机开启 smoke、性能研究或参数标定。
- 下一步仍需修复 FuelCell 域本构与端口初态契约，或实施整机冷态旁通/S 端隔离，再重新运行该夹具的零流、正向吸入、反向流和守恒测试。
