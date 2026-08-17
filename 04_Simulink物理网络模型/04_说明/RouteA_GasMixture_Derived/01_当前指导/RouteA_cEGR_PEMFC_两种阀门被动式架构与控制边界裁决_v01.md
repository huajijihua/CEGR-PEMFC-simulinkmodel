# Route A cEGR-PEMFC 两种阀门被动式架构与控制边界裁决

文件类型：当前指导、用户简图到 Simulink/Simscape 的架构映射
日期：2026-08-14
状态：已完成图示理解、当前模型读回和第一阶段配置裁决。2026-08-14 复核发现单一模型内的湿侧 L2 流阻会混淆两种湿化方式；用户确认改为两个独立 `.slx`，原单一模型仅作为已审计气路基线和历史接口试验。

## 1. 用户确认的第一阶段对象

第一阶段先建立两种**阀门被动式、空压机入口回流**配置，不进入独立循环泵或风机方案：

| 配置 | 完整架构标识 | 湿化方式 | 第一阶段目的 |
|---|---|---|---|
| A | `Passive_SelfHumidifying_PostSeparatorGas_CompressorInlet` | 自增湿电堆，不设外部膜加湿器 | 研究电堆产水、阴极尾气回流、低负荷保湿和高负荷排水之间的权衡 |
| B | `Passive_ExternalMembraneHumidifier_PostSeparatorGas_CompressorInlet` | 外部膜加湿器 | 研究膜加湿器与 cEGR 协同、回流增湿、氧稀释和设备压降 |

两种配置只改变电堆湿化方式，但因端口和物理方程不同，分别建立为模型 A 和模型 B。循环驱动、回流接入位置、公共出口处理、控制变量、结果指标和工况矩阵必须保持一致，才能形成单轴对照；正式 runner 每次 study 只锁定其中一个模型。

模型 A 为 `PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01.slx`，不含外部加湿器、`MIn` 注水或湿侧 L2 代理。模型 B 为 `PEMFuelCellSystem_Cathode_cEGR_ExternalMembraneHumidifier_v01.slx`，必须含干侧、湿侧、跨膜水蒸气传递、跨膜热传递和两侧压降。现有 `MembraneHumidifierWet_L2_FC` 实际为 `Flow Resistance (FC)`，仅保留为历史 L2 接口试验，不得标记为配置 B 或参与 A/B 对比。

## 2. 两张简图对应的目标气路

### 2.1 配置 A：阀门被动式自增湿电堆

```text
外界环境
 -> 空压机前混合室
 -> 空压机
 -> 中冷器
 -> 电堆阴极入口
 -> 电堆阴极
 -> 阴极出口
 -> 公共背压边界
 -> 水汽分离边界
 -> 回流/排放分流
       -> CEGR 阀 -> 回流管路 -> 空压机前混合室
       -> 外界排放出口
```

这里的“自增湿”不是一个额外的设备块。它必须由以下物理共同产生：

1. MEA 反应生成水；
2. 阳极/阴极气体网络中的水蒸气传输和库存；
3. 阴极尾气经分离后的气相回流；
4. 混合、温度、压力和冷凝共同决定电堆入口湿度。

因此，配置 A 不应继续用外部加湿器质量注入作为默认水源。现有外部加湿器应处于旁路或禁用状态，但不能把“加湿器增益设为零”直接当成自增湿物理已经实现；还要核对 MEA 产水、回流水蒸气和气相水账本。

### 2.2 配置 B：阀门被动式外部膜加湿电堆

```text
外界环境
 -> 空压机前混合室
 -> 空压机
 -> 中冷器
 -> 外部膜加湿器干侧
 -> 电堆阴极入口
 -> 电堆阴极
 -> 阴极出口
 -> 公共背压边界
 -> 外部膜加湿器湿侧
 -> 水汽分离边界
 -> 回流/排放分流
       -> CEGR 阀 -> 回流管路 -> 空压机前混合室
       -> 外界排放出口
```

配置 B 的湿侧是阴极尾气侧，干侧是进入电堆的压缩空气/回流混合气侧。膜加湿器必须至少表达干侧和湿侧的气体端口、跨膜水传递、必要的热交换和两侧压降。湿侧出口再进入分离边界，不能把当前单侧加水质量流量的 `Cathode Humidifier` 直接改名为膜加湿器。

## 3. 当前 R2025b 模型读回与图示差异

当前正式聚焦模型：

```text
04_Simulink物理网络模型/01_模型/RouteA_Cathode_cEGR_Focused/
PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx
```

MATLAB/Simulink R2025b 和 `FuelCell_lib` 当前已经具备：

| 当前模块 | 实际读回 | 对两种配置的结论 |
|---|---|---|
| 空压机前混合室 | `Oxygen Source/CompressorInletMixer`，官方 `Constant Volume Chamber (FC)` | 可作为两种配置的共同回流混合点 |
| 空压机 | `Compressor` 为 `Mass Flow Rate Source (FC)`，配合 `Compressor Map`、`Compressor Volume` | 有 OER、目标质量流量和直接命令控制；目前不是完整电机/效率/功耗压缩机 |
| 中冷器 | `Intercooler_L2_Interface` 为官方 `Flow Resistance (FC)`，有出口 P/T/RH/组分观测 | 目前只有压损接口，不是带冷却液、换热量和旁通阀的受控中冷器 |
| 当前阴极加湿器 | `Cathode Humidifier` 内为 `Pipe (FC)`、`Composition and Humidity Sensor (FC)`、RH 比例控制和 `MIn` 水质量注入 | 是单侧 L2 加湿接口，不是膜加湿器干/湿两侧模型 |
| 电堆/MEA | `Stack_Core/Membrane Electrode Assembly` 为官方 `FuelCell_lib` MEA；具有温度、RH 和膜电导查表参数，官方示例说明包含水生成及跨膜水蒸气传输 | 可作为两种配置的共同电堆内核；当前固定 `80 degC`，膜水状态未作为正式结果接口闭合 |
| 阴极出口 | `CathodeOutletChamber` 为官方 `Constant Volume Chamber (FC)` | 可作为共同出口库存和分流上游容腔 |
| 背压阀 | 当前 `Pressure Relief Valve` 位于排放支路 | 与两张图的“分流前公共背压阀”不等价，需要重构或明确为代理 |
| 水汽分离器 | `CathodeWaterSeparator_FC` 实际为官方 `Flow Resistance (FC)`，只位于 EGR 支路；`SeparatorOrCondensation` 是 MATLAB Function 观测器 | 不是公共分流前的真实分离器；没有分离效率、液水出口、液滴携带和排液控制 |
| cEGR 阀 | `EGRValveRestriction/Open/LocalRestriction (FC)`，由面积命令、PI/直接面积、执行器和限幅驱动 | 可作为两种配置的共同被动回流阀；实际流量仍由压差和阻力产生 |
| 电负载 | `Electrical Load`，支持 Current、Power、Voltage 边界 | 可作为共同控制输入和工况轴 |

当前模型的真实主线仍是：

```text
Air Intake
 -> CompressorInletMixer
 -> Compressor / Compressor Volume / Intercooler_L2_Interface
 -> Cathode Humidifier
 -> Stack cathode
 -> CathodeOutletChamber
      -> Pressure Relief Valve -> exhaust
      -> EGR flow sensor -> Flow Resistance (FC) -> EGR valve -> EGR pipe -> mixer
```

因此当前模型可以证明已有气路和控制接口，但尚不能证明用户简图中的“公共背压阀 -> 公共分离器 -> 分流”拓扑。

## 4. 绿色设备的控制裁决

绿色框不应全部解释为“当前都已有控制器”。本项目按“控制对象、控制量、被动设备和观测量”分开定义：

| 设备/模块 | 配置 A | 配置 B | 当前 MATLAB 状态和裁决 |
|---|---|---|---|
| 电负载 | 控制电流/功率/电压 | 控制电流/功率/电压 | 已有。属于工况和负载控制，不是气路执行器 |
| 空压机 | 控制目标 OER、目标质量流量或直接命令 | 相同 | 已有。正式结果还需补齐压缩机功率、效率、温升和工作点边界 |
| 中冷器 | 初期作为压损和温度观测边界 | 相同 | 当前不应标成可调设备。若要控制，必须增加热侧/冷却侧或旁通执行器及参数合同 |
| 公共背压阀 | 控制阴极出口公共压力 | 相同 | 必须先把当前排放支路阀与目标公共主干语义分开；不能只改名字 |
| 水汽分离器 | 初期为被动分离边界和压损 | 相同 | 首先不闭环控制。需要分离效率、允许含液率、液水出口、排液和压损参数后，才考虑排液/液位控制 |
| CEGR 阀 | 控制回流开度或回流目标 | 相同 | 已有面积命令、PI/直接模式、执行器和阀前后压力观测，可优先复用 |
| 外部膜加湿器 | 不应存在或必须旁路 | 控制/参数化干湿侧换湿能力 | 配置 B 的核心缺口。当前单侧 `MIn` 注水不是膜加湿器；需要双气侧、跨膜水/热传递和压损接口 |
| 回流管路 | 被动压降、库存、温度和冷凝 | 相同 | 可用官方 `Pipe (FC)`；不增加独立泵或质量流量源来制造“被动回流” |
| 电堆温度 | 初期固定温度边界，只做气相筛选 | 相同 | 当前 `80 degC` 是固定热边界，不是热管理控制。自增湿结论不得扩大为热稳态结论 |

### 4.1 配置 A 的最小控制集

```text
电负载：Current / Power / Voltage
空压机：target OER 或 target mdot 或 direct command
公共背压：cathode outlet pressure target
CEGR 阀：target r_split 或 direct valve area
```

配置 A 不把 `humidifierRH`、`humidifierGain` 作为有效控制量。它们应在 case 中标记为 `not_applicable` 或旁路状态，并新增/核对以下观测：阴极入口 RH、阴极出口水蒸气、MEA 产水、回流水蒸气、混合点露点、冷凝和水量闭合。

### 4.2 配置 B 的最小控制集

配置 B 在配置 A 的共同控制集上增加外部膜加湿器接口。第一版不直接假定可以闭环控制“膜加湿量”，优先暴露：

1. 干侧入口/出口 P、T、RH、组分和质量流量；
2. 湿侧入口/出口 P、T、RH、组分和质量流量；
3. 膜加湿器水传递量、热传递量和压降；
4. 若设备有旁通阀，再将旁通开度作为控制量。

只有在上述端口和参数真实存在后，才把干侧 RH 或旁通开度接入控制器。不能把当前 `routeA_cathode_humidifier_gain` 继续当作膜加湿器控制命令。

## 5. 统一结果和控制接口

两种配置共用以下主指标：

```text
r_split = m_return / (m_return + m_exhaust)
x_comp_in = m_return / (m_return + m_fresh)
r_fresh = m_return / m_fresh
```

每个 case 必须同时记录：

- 电负载目标和实际 I/V/P；
- 空压机控制模式、目标 OER/质量流量、实际流量和可用的功率代理；
- 公共背压目标、公共出口压力和阀前后压力；
- 分离边界前后 P/T/RH/组分；
- 回流与排放支路质量流量及闭合状态；
- `r_split` 的真实物理位置和状态；
- 配置 A 的 MEA/回流自增湿证据，或配置 B 的膜加湿器干湿侧换湿证据；
- 混合点、压缩机入口和电堆入口的露点、饱和度和冷凝风险。

目标值、执行器命令、实际 `r_split`、`x_comp_in` 和 `r_fresh` 不能混称。

## 6. 推荐实施顺序

1. **公共出口拓扑先收口**：将“阴极出口 -> 公共背压边界 -> 分离气相边界 -> 回流/排放分流”定义为正式目标；先读回官方阀、分离边界和支路端口语义，再决定最小结构补丁。
2. **先实现配置 A**：旁路当前外部加湿器质量注入，保留官方 MEA、四物种气路、回流阀、回流管路和统一指标，先通过 `cEGR=0`、小回流和目标回流。
3. **再实现配置 B**：在同一平台和同一 runner 中接入双侧膜加湿器；如果官方 `FuelCell_lib` 没有可复用的双侧 FC 域模块，则先登记自定义 Simscape 组件能力缺口，不用 MATLAB Function 替代膜传质。
4. **统一对照**：两种配置使用相同负荷、环境、空压机、背压、CEGR 阀、分离边界和评价窗口，只改变湿化配置。
5. **最后才做主动式对照**：主动泵不进入本轮两种被动配置的实现和验收。

## 7. 最低验收门

| 门 | 配置 A | 配置 B |
|---|---|---|
| 结构 | 自增湿配置没有有效外部水质量注入；公共背压/分离/分流拓扑读回正确 | 干侧/湿侧端口和 wet-side -> separator -> split 顺序读回正确 |
| 控制 | 空压机、背压阀、CEGR 阀和电负载写入点可读回 | 在共同控制点之外，膜加湿器的真实控制/参数写入点可读回 |
| 行为 | 无回流、小回流、目标回流方向和气相水账本通过 | 两侧流量、压降、温湿度和水传递方向通过 |
| 物理边界 | 未把 RH 设定值、冷凝代理或固定堆温扩大为工程自增湿结论 | 未把单侧注水代理扩大为膜加湿器工程验证 |

当前结论状态：两种配置的架构和控制边界已定义；公共背压/分离/分流拓扑、配置 A 的正式自增湿闭合、配置 B 的双侧膜加湿器仍为 `not_implemented` 或 `not_validated`。

## 8. 关联资产

- `RouteA_cEGR_PEMFC_工程化架构决策与聚焦模型总体规划_v01.md`
- `RouteA_Cathode_cEGR_Focused_模型边界与实施契约_v01.md`
- `RouteA_Cathode_cEGR_Focused_v01.slx`
- `run_routeA_focused_study.m`
- `routeA_focused_case_adapter.m`
- `routeA_focused_performance_metrics.m`
- `00_支撑材料/MathWorks_Official_Examples_R2025b/01_GasMixture_PEMFuelCellSystemWithCustomLibrary/PEMFuelCellSystemWithACustomLibraryExample.m`
