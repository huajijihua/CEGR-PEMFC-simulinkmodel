# Route A cEGR-PEMFC 官方引射器被动式结构系统实施计划

文件类型：当前指导、官方引射器架构实施计划
日期：2026-08-14
状态：E0-E4 首轮已实施；官方 Gas 基准和 FuelCell 域结构副本已建立。2026-08-17 根因诊断确认高层 A/S/B 接线正确，但当前 FuelCell 域引射器本构方程不具备可解的被动吸入压力耦合；后压缩机引射架构本身保留为“有压力裕度条件下可行”，当前副本工况尚不可行。2026-08-17 增量已完成 Ejector 参数合同、模型工作区默认值和唯一 runner 写入链；开启模式仍不得进入参数标定或性能研究，关闭基线仍是正式可执行状态。

## 1.1 当前执行状态（2026-08-17）

- 已建立副本：`PEMFuelCellSystem_Cathode_cEGR_Ejector_SelfHumidifying_v01.slx`；源阀门自增湿模型未修改。
- 已建立官方基准：`RouteA_Ejector_Gas_Benchmark_v01.slx`，使用官方 `Ejector (G)` 和 A/S/B 流量观测，结构检查 healthy；唯一官方 Gas 压力窗口 runner 已完成 11 点、1 s/点扫描。
- 已建立 FuelCell 域组件：`RouteAEjector_lib/Ejector (FC)`，源文件为 `+RouteAEjector/EjectorFC.ssc`，`ssc_build` 已通过。
- 副本最终默认：`ejector_enabled=false`；既有 5 A、180 s、尾窗 150--180 s 基线保持有效；本次参数化后新增 10 s 关闭基线 smoke 仍返回 `study.passed=1`、`matrixComplete=1`、`simCompleted=1`。
- 开启模式 392 A smoke 已执行但发生 `NE_DAE_IC_Failure`，不能标记为行为验证或工程验证。
- 同一冷态输入下，5 A 和 392 A 均表现为 `ejector_enabled=false` 可执行、`true` 初始化失败；392 A 下将 `pressure_recovery` 从 1.05 扫至 2.0 仍失败，极大通流面积/近似无压升参数也仍失败。
- 根因状态：`Cathode_Air_cEGR_BOP/B -> A`、`Cathode_Exhaust_Backpressure_Water/Conn1 -> S`、`B -> CathodeInletMassFlowSensor_FC -> Stack_Core` 的模型读回正确；失败来自 `EjectorFC.ssc` 的本构压力关系和缺少主流喷射-次流吸入动量耦合，不是端口 A/S/B 互换。
- 参数链状态：`routeA_focused_parameter_defaults`、`routeA_focused_case_template`、`routeA_focused_parameter_bridge` 和 `run_routeA_focused_study` 已纳入 `ejector_enabled`、几何、效率、压力恢复和平滑参数；模型块 `Cathode_Ejector_FC` 已读回为工作区变量引用，模型工作区已保存 15 项默认值。该链只证明参数可追踪和关闭模式可执行，不证明开启本构正确。
- 官方 Gas 域边界扫频已由 `run_routeA_ejector_g_pressure_window_scan.m` 正式执行：`pA=0.25 MPa、pS=0.104336 MPa` 时，`pB=0.20/0.19/0.18 MPa` 为次流反向，`pB=0.17 MPa` 出现正向吸入，`pB=0.16 MPa` 的实测引射比为 `0.150025`；`pA=0.183437 MPa` 时 `pB=0.14 MPa` 仅得到 `mdot_S=0.002418968 kg/s`、引射比 `0.05815512`。结果保存为 `RouteA_Ejector_Gas_PressureWindowScan_20260817_v01.mat`。
- 物理可行性裁决：`Passive_Ejector_PostSeparatorGas_PostCompressorCathodeInlet` 不予否决，但必须满足 `pA > pB` 的主流压力裕度、足够的 `pA/pS` 吸入窗口、压缩机工作点和反向流保护；当前 `pA≈pB≈0.183 MPa` 不能作为正向回流基线。
- 当前剩余工作：首轮官方 Gas 压力/流量可行域已冻结为参考边界；下一步重建或受控替换 FuelCell 域引射器本构、补齐独立组件守恒/临界/反向流测试，随后加入冷态旁通和 S 端隔离保护，最后才进行几何参数校准、真实液水分离和开启模式验证。
- 2026-08-17 最新本构诊断：`EjectorFC.ssc` 的端口方程计数已收敛，最终 `ssc_build('RouteAEjector')` 通过；但正确写入 `ejector_enabled=true` 后，5 A/180 s、0 A、直接起步、压力恢复软化和仅压力诊断闭合均在整机冷态初值求解处 `NE_DAE_IC_Failure`。关闭模式 5 A/180 s 回归仍通过。当前阻塞收敛为 FuelCell 三端压力网络与现有冷态初值边界不相容，开启模式继续保持 `not_validated`。

## 1. 计划目的

本计划将 MathWorks 官方引射器模块正式纳入 Route A 后续被动式 cEGR 架构，并回答三个实施问题：

1. 官方 `Ejector (G)` 和 `Ejector (MA)` 如何用于引射器方案的标准可行性验证；
2. 官方 `Gas`/`Moist Air` 引射器与当前 `FuelCell.FuelCell` 四物种网络如何分工和适配；
3. 如何在不干扰当前阀门被动式工作的前提下，建立后压缩机引射式被动 cEGR 结构系统。

本计划只建设引射器结构和接口，不提前进行 cEGR 最优比例、控制器整定、设备优劣排序或净功率结论。

## 2. 官方能力结论

### 2.1 已确认的官方模块

| 模块 | 官方路径 | 域 | 端口 |
|---|---|---|---|
| `Ejector (G)` | `SimscapeFluids_lib/Gas/Turbomachinery/Ejector (G)` | Gas | `A` primary、`S` secondary、`B` outlet |
| `Ejector (MA)` | `SimscapeFluids_lib/Moist Air/Turbomachinery/Ejector (MA)` | Moist Air | `A` primary、`S` secondary、`B` outlet |

官方模块已在 MATLAB R2025b 本机安装库中读回：

```text
D:\matlab2025b\toolbox\physmod\fluids\library\m\SimscapeFluids_lib.slx
```

官方文档和示例入口：

- `Ejector (G)`：<https://www.mathworks.com/help/hydro/ref/ejectorg.html>
- `Ejector (MA)`：<https://www.mathworks.com/help/hydro/ref/ejectorma.html>
- `EjectorGExample`
- `EjectorMAExample`

### 2.2 官方模块的使用定位

官方模块必须进入本项目的引射器实施链，但使用分为两层：

| 层级 | 官方模块使用方式 | 结论用途 |
|---|---|---|
| 标准可行性层 | 直接使用 `Ejector (G/MA)` | 验证压力窗口、引射比、临界/亚临界状态和几何参数范围 |
| Route A 集成层 | 使用官方模块的结构、方程、参数和测试结果作为基准，建立 `FuelCell` 域适配组件或受控代理 | 保留四物种 `FuelCell` 主网络和 cEGR 组分守恒 |

官方块不能直接跨域连接到当前 `FuelCell.FuelCell` conserving ports。不能为了“直接使用官方块”而把当前四物种网络强行改成 `Gas` 或 `Moist Air` 主线。

## 3. 推荐的引射器系统拓扑

### 3.1 共同目标拓扑

```text
新鲜空气
 -> 空压机
 -> 中冷器
 -> 引射器 A：动力流入口

阴极出口
 -> 公共背压边界
 -> 水汽分离气相边界
 -> 回流/排放分流
      -> 引射器 S：吸入流入口
      -> 外界排放出口

引射器 B：混合扩压出口
 -> 阴极入口或膜加湿器干侧
```

这里的引射器是后压缩机回流，不返回空压机入口。空压机出口高压空气提供动力，阴极尾气是低压 secondary flow。

推荐的初始取力位置为：

```text
空压机 -> 中冷器 -> Ejector A
```

如果中冷器压降导致动力压力不足，再把“中冷器前取力”作为显式备选配置，不在默认配置中同时混合两种取力位置。

### 3.2 自增湿配置

```text
Ejector B -> 阴极入口 -> 自增湿电堆
```

不启用外部膜加湿器水注入。电堆水管理由 MEA 产水、阴极气相水、尾气回流和冷凝共同决定。

### 3.3 外部膜加湿配置

```text
Ejector B -> 膜加湿器干侧 -> 阴极入口
阴极出口 -> 公共背压 -> 膜加湿器湿侧 -> 分离边界 -> Ejector S/排放分流
```

膜加湿器仍需具备独立干侧和湿侧，不能用单侧 `MIn` 水质量注入替代。

## 4. 引射器与阀门被动式的关系

阀门被动式和引射器被动式都没有独立回流泵，但不是同一个架构：

| 架构 | 动力来源 | 回流位置 | 主要限制 |
|---|---|---|---|
| 阀门被动式 | 阴极出口与空压机入口压差 | 空压机入口 | 尾气进入压缩机，低压差和液滴风险重要 |
| 引射器被动式 | 空压机出口高压主流 | 压缩机出口之后 | 需要动力压力、引射器压降和足够背压裕度 |

两者不能共用同一个回流支路模型。正式架构标识为：

```text
Passive_Valve_PostSeparatorGas_CompressorInlet
Passive_Ejector_PostSeparatorGas_PostCompressorCathodeInlet
```

固定几何引射器本身不需要 CEGR 泵。允许增加隔离阀、旁通阀或吸入侧微调阀，但这些属于控制和保护层，不改变引射器的被动能量拓扑。

## 5. 官方标准可行性模型

### E0：官方 Gas 引射器基准

使用：

```text
SimscapeFluids_lib/Gas/Turbomachinery/Ejector (G)
```

输入：

- primary 压力、温度和质量流量；
- secondary 压力、温度和质量流量边界；
- outlet 背压边界。

输出：

- primary flow；
- secondary suction flow；
- outlet flow；
- outlet pressure；
- critical/subcritical 状态；
- secondary throat area warning/error；
- 引射比 `omega = m_secondary / m_primary`。

用途：验证干气体压力和几何参数关系，不作为四物种 PEMFC 结果。

### E1：官方 Moist Air 引射器基准

使用：

```text
SimscapeFluids_lib/Moist Air/Turbomachinery/Ejector (MA)
```

用途：验证湿空气组成差异和 R2024b 夹带水滴建模能力，重点观察：

- secondary 湿度和水滴状态；
- 引射器出口湿度；
- 高湿/低温下的反向流和失效边界；
- 湿气对引射比和出口压力的影响。

E1 仍然是 Moist Air 域模型，不替代 `FuelCell` 四物种域验证。

### E2：标准块参数筛选

扫描官方块已有参数：

```text
area_throat
area_ratio_nozzle
area_ratio_mixing
min_area_ratio_secondary
loss_primary
loss_secondary
loss_expansion
loss_mixing
area_A
area_B
area_S
```

筛选输出：

- primary/secondary/outlet 压力；
- 引射比；
- 出口压力恢复；
- primary 和 secondary 是否堵塞；
- secondary throat 是否触及最小面积；
- 反向流和 subcritical 失效区。

## 6. FuelCell 域集成路线

### 6.1 首选路线：FuelCell 域 Ejector 适配组件

在官方标准模型通过后，建立同一三端口语义的 `FuelCell` 域组件：

```text
FuelCell Ejector A：primary motive gas
FuelCell Ejector S：secondary cathode exhaust gas
FuelCell Ejector B：mixed diffuser outlet
```

适配组件采用官方 `Ejector (G)` 的一维喷嘴、吸入、混合和扩压方法，但将气体属性、组分和能量流改为 FuelCell 域接口。

组件必须保留：

- N2/O2/H2/H2O 组分传递；
- 质量、能量和组分守恒；
- primary nozzle、secondary suction 和 diffuser 的压力关系；
- 喉部堵塞、临界/亚临界模式；
- 反向流诊断和失效状态；
- 与官方 `Ejector (G)` 的单组件对照接口。

该组件必须使用 Simscape 物理组件实现，不能使用 MATLAB Function 替代核心气体物理。

### 6.2 受控代理路线

如果 FuelCell 域组件暂时无法完成，可以把官方 `Ejector (G/MA)` 作为边界驱动代理：

```text
FuelCell 模型边界 P/T/组分/流量
 -> official Ejector G/MA surrogate
 -> outlet P/T/流量/引射比
 -> FuelCell 模型边界
```

这条路线只能用于架构预筛选，结果必须标记为：

```text
official_domain_surrogate_not_fuelcell_closed_loop
```

它不能作为最终四物种 cEGR 物理验证。

### 6.3 不采用的路线

不采用以下做法：

- 把 `Ejector (G)` 直接连接到 `FuelCell` conserving port；
- 把 `Ejector (MA)` 当作四物种 FuelCell 引射器；
- 用几个 `Local Restriction (FC)` 和 Pipe 拼成“等效引射器”；
- 用 MATLAB Function 计算 secondary flow 代替喷嘴和扩压器；
- 为了使用官方块而把 Route A 主模型整体迁移到 Moist Air 域。

## 7. 结构改造对象

### 7.1 阴极出口支路

当前 `Cathode_Exhaust_Backpressure_Water` 先改成：

```text
CathodeOutletChamber
 -> Common Backpressure
 -> Gas-phase Separator Boundary
 -> Split
      -> Ejector secondary branch
      -> Exhaust branch
```

回流支路不再连接空压机入口，而是连接 Ejector `S` 端口。

### 7.2 空气供给支路

当前 `Cathode_Air_cEGR_BOP` 保留：

- `CompressorInletMixer`，用于阀门基线；
- Compressor/Map/Volume；
- Intercooler L2 interface；
- Stack inlet and humidification interface。

引射器配置新增：

```text
Intercooler outlet -> Ejector A
Ejector B -> cathode inlet or membrane humidifier dry side
```

阀门基线和引射器配置使用 Variant 或明确的架构配置切换，不复制第二个正式 `.slx`。

### 7.3 观测和指标

必须增加或确认：

| 位置 | 观测 |
|---|---|
| Ejector A | P、T、组分、primary mass flow |
| Ejector S | P、T、RH、组分、secondary mass flow |
| Ejector B | P、T、RH、组分、outlet mass flow |
| 分离后分流点 | return mass flow、exhaust mass flow、`r_split` |
| 引射器状态 | critical/subcritical、reverse flow、secondary throat warning |

引射比定义为：

```text
omega_ejector = m_secondary / m_primary
```

它不能替代 cEGR 分流点的 `r_split`。

## 8. 参数合同

引射器进入 FuelCell 域前，建立以下参数合同：

| 参数组 | 参数 |
|---|---|
| 几何 | 喉部面积、喷嘴出口面积比、混合腔面积比、A/B/S 截面积 |
| 效率 | primary nozzle、secondary suction、primary expansion、mixing |
| 动力边界 | primary 取力位置、P、T、组分、流量 |
| 吸入边界 | separator 后 P、T、组分、RH、允许含液率 |
| 出口边界 | cathode inlet 或 dry-side P/T、下游压降和背压 |
| 保护 | 隔离、旁通、反向流切除、冷凝保护 |
| 状态 | critical、subcritical、choked、reverse flow、invalid geometry |

所有没有几何、供应商或实验来源的参数只能进入 `external_case` 或 `assumption` 层，不能覆盖 `platform_default`。

## 9. 分阶段实施

### E0：官方模块和官方示例入口确认

产物：官方路径、端口、参数、示例和版本信息。

出口门：MATLAB 能加载 `SimscapeFluids_lib` 并读回 `Ejector (G/MA)`；本地示例若不可解析，记录为环境限制，不伪造运行证据。

### E1：官方域独立引射器基准

产物：Gas 和/或 Moist Air 官方引射器基准模型。

出口门：primary、secondary、outlet 质量流量和压力方向正确，critical/subcritical 状态可识别，无持续反向流。

### E2：压力窗口和几何筛选

产物：引射器几何参数范围、引射比范围、压力恢复范围和失效工况。

出口门：覆盖低负荷、名义负荷和高负荷边界，明确是否需要中冷器前取力。

### E3：FuelCell 域适配决策

产物：FuelCell 域组件合同，或带明确状态的官方域代理合同。

出口门：域、端口、组分、能量、初始状态和失败状态均有明确写入/读回位置。

### E4：后压缩机引射式结构接入

产物：共享 Route A 平台上的引射器 Variant/配置。

最低验证：

- 阴极出口公共背压、分离和分流拓扑正确；
- Ejector A/S/B 端口连接正确；
- 回流不再错误进入压缩机入口；
- 质量流量、组分和能量闭合；
- 无回流、低引射和名义引射工况可运行。

### E5：结构建成门

必须满足：

1. 官方 Ejector G/MA 基准结果可追溯；
2. FuelCell 域适配或代理状态明确；
3. `model_read` 证明引射器三端口和管路拓扑；
4. `model_check` 无 error severity；
5. 反向流、堵塞、分离后液水风险有状态输出；
6. 未新增 MATLAB Function 承担引射器核心物理。

通过 E5 后，才进入引射器 cEGR 性能和设备控制研究。

## 10. 后续研究准入

结构建成后，统一比较：

- 阀门被动式空压机入口回流；
- 引射器被动式后压缩机回流；
- 自增湿电堆；
- 外部膜加湿电堆。

性能研究必须分开报告：

- `r_split`；
- `omega_ejector`；
- 空压机工作点和功耗；
- 引射器压力恢复和压降；
- 阴极入口 RH/O2；
- 冷凝和液滴风险；
- 控制范围和失效边界。

## 11. 关联文件

- `RouteA_cEGR_PEMFC_官方引射器模块审计与FuelCell域适配裁决_v01.md`
- `RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md`
- `RouteA_cEGR_PEMFC_两种阀门被动式架构与控制边界裁决_v01.md`
- `RouteA_cEGR_PEMFC_工程化架构决策与聚焦模型总体规划_v01.md`
- `PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`
