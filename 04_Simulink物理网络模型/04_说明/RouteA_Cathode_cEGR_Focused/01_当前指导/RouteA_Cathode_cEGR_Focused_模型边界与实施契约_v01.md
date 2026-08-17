# Route A 阴极 cEGR 聚焦模型边界与实施契约

日期：2026-08-14
状态：结构副本、正式 runner、参数桥接、I/P/V 控制和性能分析契约已完成首轮收口；当前实现为 `Passive / ExternalHumidifier / CathodeOutletBranchFlowProxy / CompressorInlet`，其中 `ExternalHumidifier` 目前仅表示单侧 L2 注水接口，不等价于膜加湿器；目标架构为 `Passive / ExternalMembraneHumidifier / PostSeparatorGas / CompressorInlet`；两种阀门被动式配置的总裁决见 `RouteA_cEGR_PEMFC_两种阀门被动式架构与控制边界裁决_v01.md`；不构成工程方案验证。
源模型：`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
聚焦模型：`04_Simulink物理网络模型/01_模型/RouteA_Cathode_cEGR_Focused/PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`

## 1. 研究目的

聚焦模型目标用于研究当前被动式、普通外部加湿电堆、分离后气相回流至空压机入口的完整阴极气路、cEGR、阴极背压、气体温度、气相冷凝和电堆性能之间的关系；当前实现仍是出口分支流阻代理。它不是当前完整系统模型的替代品，也不用于表达主动泵方案。

## 2. 保留边界

- `Cathode_Air_cEGR_BOP` 完整保留，包括新鲜空气、压缩机入口混合器、压缩机图谱/容积、当前单侧 L2 加湿接口、cEGR 阀和 EGR 管；该加湿接口不作为配置 B 的膜加湿器实现证据。
- `Cathode_Exhaust_Backpressure_Water` 完整保留，包括出口腔体、cEGR 分流、排放支路背压阀和当前 L2 水观测器；模型读回确认 `CathodeWaterSeparator_FC` 是 EGR 支路上的官方 `Flow Resistance (FC)`，排放支路从出口腔体另行取流，当前尚未实现用户简图中的公共背压、公共分离后再分流。
- `Stack_Core` 完整保留，包括 MEA、阴极气体通道、阳极气体通道、MEA 热容和电气端口。
- 空气侧控制、当前单侧加湿器控制、cEGR 比例控制、阴极排放支路背压调节和 I/P/V 电负载保留；公共背压阀、配置 A 自增湿水账本和配置 B 双侧膜加湿器仍需单独实现。
- 阳极气体通道入口采用上游氢气 Reservoir + Mass Flow Rate Source，出口采用最小 Pipe + 定压 Reservoir，并保留 Gas Mixture Properties。
- 热管理 BOP 移除；MEA 热端口通过 Heat Flow Rate Sensor 接入电堆固定温度节点，恒温源默认 `80 degC`。

## 3. 固定边界

| 量 | 默认值 | 模型写入点 |
|---|---:|---|
| 堆固定温度 | 80 degC | `focused_stack_temperature_C` |
| 阳极供氢储库压力 | 0.3 MPa(abs) | `focused_anode_feed_p_MPa_abs` |
| 阳极入口质量流量 | 0.001 kg/s 假设值 | `focused_anode_inlet_mdot_kg_s` |
| 阳极出口压力 | 0.101325 MPa(abs) | `focused_anode_outlet_p_MPa_abs` |
| 阳极边界温度 | 20 degC | `focused_anode_boundary_T_C` |
| 氢气摩尔分数 | 0.9997 | `focused_anode_yH2` |
| 阳极 Pipe 长度 | 1 m | `focused_anode_pipe_length` |
| 阳极 Pipe 面积 | pi*0.02^2/4 m^2 | `focused_anode_pipe_area` |

所有固定边界仍通过 `SimulationInput` 写入；气路内部温度、压力、组分和冷凝量不由后处理常数替代。

## 4. 结果边界

允许输出堆 I/V/P、分流点 `r_split`、空压机入口 `x_comp_in`、`r_fresh`、阀压差、背压、阴极入口 RH/O2/lambda、气相闭合、混合点和回流管路冷凝流率。当前模型不闭合液水库存、液滴携带、排液、分离效率、压缩机进液损伤或空压机寄生功率。

## 5. 实施顺序

1. 轻量模型与完整模型在相同冷态输入下做结构和行为对照。
2. 固化 I/P/V 分模式的聚焦 runner 和结果契约。
3. 单独修复冷凝位置、氧分压、分流点回流率、空压机入口混合比例和其他已识别缺陷。
4. 修复后的结果重新与未修复副本和完整模型进行对照。

不得把一次结构复制、smoke 或数值完成表述为 cEGR 工程方案已验证。

## 6. 控制、性能和参数桥接收口

### 6.1 已闭合的阴极和电堆控制

- 电气边界保留 Current、Power、Voltage 三种模式，仍由同一个 `I_cmd`/电负载拓扑执行。
- 阴极空气控制保留目标质量流量、目标 OER 和直接空压机命令三种模式。
- 阴极源压力、源温度、新鲜空气 O2/H2O 组分、加湿器 RH/启用、阴极出口背压均通过统一 case 适配器进入命令 profile。
- cEGR 保留启用、目标比例、PI/直接面积模式、阀面积限幅、执行器时间常数和阀前后压力观测。
- 电堆性能输出统一提供 I/V/P、堆温、单电池电压、电流密度、功率密度、氧过量系数和气相闭合结果。

### 6.2 简化阳极和热边界桥接

标准 Route A `simCase` 可以直接通过 `routeA_focused_case_adapter` 接入聚焦 runner。当前真实写入点为：

| 标准输入 | 聚焦写入点 | 状态 |
|---|---|---|
| `thermal.stackTemperatureSet_C` | `focused_stack_temperature_C` | 已映射到恒温源 |
| `anode.sourcePressure_MPa_abs` | `focused_anode_feed_p_MPa_abs` | 已映射到氢气 Reservoir |
| `anode.sourceTemperature_C` | `focused_anode_boundary_T_C` | 已映射到氢气边界/最小阳极管路 |
| `anode.h2MoleFraction` | `focused_anode_yH2` | 已映射到最小阳极边界组分 |
| `focused.anodeInletMdot_kg_s` | `focused_anode_inlet_mdot_kg_s` | 质量流量边界的唯一入口控制 |
| `anode.inletPressure_MPa_abs` | 无 | 明确标记 `not_applicable`，不与质量流量源并用 |
| 阳极加湿、回流、吹扫参数 | 无 | 明确标记 `not_applicable`，不伪造阳极 BOP |
| 冷却通道、泵、散热器参数 | 无 | 明确标记 `not_applicable`，固定温度边界不等同于热管理 BOP |

所有 case 的实际映射写入 `study.cases(k).parameterBridge`，不适用参数不会静默丢弃。

### 6.3 性能分析口径

- `r_split = m_return/(m_return+m_exhaust)`，即目标架构的分流点回流率；当前 runner 已按回流/排放支路总质量流量计算一个 `r_split` 代理，但因当前分离后位置未实现，必须携带 `post_separator_unverified` 状态。
- `x_comp_in = m_return/(m_return+m_fresh)`，即空压机入口混合比例；旧字段 `r_mix` 作为兼容别名保留。
- `r_fresh = m_return/m_fresh`，即新鲜空气基回流率。
- `pO2` 当前只在 `compressor_inlet_mixer` 位置计算，采用质量分数到摩尔分数换算；不得写成电堆阴极入口直接测量值。
- 冷凝输出仅为气相冷凝率和饱和度代理；液水库存、液滴输运、排液、分离效率和压缩机寄生功率均不纳入性能排序。

### 6.4 首轮行为证据

同一聚焦模型和正式 runner 下，`80 degC`、阳极 `0.001 kg/s`、冷态启动的代表性结果：

| 模式 | 工况 | 结果 |
|---|---|---|
| Current | `100 A, cEGR=0.3, OER=3.0, 120 s` | `passed=1`；`V=406.4588 V`；历史结果按 `r_mix=0.2999` 和 `r_fresh=0.4284` 记录；`r_split` 尚未在该历史结果中重算 |
| Power | `40 kW, cEGR=0.3, OER=3.0, 120 s` | `passed=1`；`V=406.7343 V`；`I=98.3443 A` |
| Voltage | `410 V, cEGR=0.3, 600 s` | `passed=1`；`V=410.1326 V`；`I=78.9043 A` |
| Air mdot | `100 A, target mdot=0.045 kg/s, cEGR=0` | `passed=1`；实际流量 `0.045 kg/s` |
| Air direct | `100 A, direct command=0.5, cEGR=0` | `passed=1`；实际流量约 `0.0753 kg/s` |
| Low load | `5 A, cEGR=0 / 0.3, 600 s` | 两例均 `passed=1`；cEGR=0.3 时混合点冷凝约 `7.62e-7 kg/s`、饱和度约 `1.1531` |

上述结果属于 focused model 的范围内行为验证，不构成完整模型等价、被动工程方案或产品性能验证。

2026-08-14 新结果契约 smoke 使用同一聚焦模型、Current=100 A、目标 cEGR=0.3、冷态启动、600 s 和尾窗 `[540,600] s`，`passed=1`。当前分支总质量流量基 `r_split` 代理为 `0.2694`，回流流量 `0.0128 kg/s`，排放流量 `0.0346 kg/s`，支路总流量 `0.0474 kg/s`；旧空压机入口 `r_mix=0.3000`，新鲜空气基 `r_fresh=0.4286`。该结果只证明指标可以从当前输出结构计算，不能证明当前传感器位置是物理意义上的分离后分流点；干基 `r_split` 仍未闭合。

## 7. 四个会议问题的研究准入与结果边界

### 7.1 模型能力裁决

| 问题 | 当前模型能力 | 本轮处置 | 结论边界 |
|---|---|---|---|
| 被动 cEGR 阀/阴极背压如何控制回流 | 已有出口腔体的回流/排放支路、EGR 阀/Local Restriction、EGR Pipe、压缩机入口混合器、EGR 流量和阀前后压力；当前分离后语义未闭合 | 补齐压力链和结果摘要，增加分流总质量基回流率代理 | 可回答当前出口分支代理下的控制可达性、压差和气相回流量；不能回答真实分离效率、阀件耐久和液滴冲蚀 |
| 压缩机增压压力与阴极出口压力 | Simscape log 已有 Compressor Volume、IntercoolerOutletPTSensor 和 CathodeOutletChamber；官方案例使用 FC 域集总气路组件 | 新增压力观测，并将 `CathodeOutletResistance` 参数化 | 可用等效 Flow Resistance 标定入口/出口压差；不能直接当作分布式电堆总压降或替代硬件压比/喘振/系统压损设计 |
| 空压机前冷凝判断和计算 | 混合器有 `mdot_cond`、`Q_cond`、`p_I`、`T_I`、`y_I_i` 和 `is_cond` | 新增露点、饱和度、冷凝率和积分结果 | 是气相 L2 相态筛选；不等于液水库存、液滴携带或压缩机进液量 |
| 升温/分离器等防冷凝方案 | 当前无真实加热器、换热器、蒸汽干燥器或分离效率模型 | 新增升温/蒸汽降低/液水去除筛选代理，不添加伪物理块 | 可给出设计方向和门槛；工程定型需另立设备参数合同 |

### 7.2 输入边界修正

结构读回发现，旧 `cathode.sourcePressure_MPa_abs`、`cathode.sourceTemperature_C` 命令列中，压力和温度信号曾被 `Terminator` 吸收，不能据此声称已经写入模型。当前聚焦 runner 已做最小修正：

- `cathode.sourceTemperature_C` -> `env_T`，实际作用于 Air Intake 和当前气路初态；
- 实际压缩机入口压力默认由 `environment.ambientPressure_MPa_abs=0.101325 MPa(abs)` 提供，并同步 `cegr_inlet_mixer_p0`、`cegr_pipe_p0`；
- `cathode.sourcePressure_MPa_abs=0.15 MPa(abs)` 不再作为默认压缩机入口压力真源，非环境压力的显式 override 尚未通过冷态初始化和工程适用性门；
- 阴极 O2/H2O 组分仍通过 `env_yO2/env_yH20` 接入。

### 7.3 研究工况与结果

所有正式 case 使用同一聚焦模型、同一 `run_routeA_focused_study`、`cold_start_only`、`VariableStepAuto`、`RelTol=AbsTol=1e-3`、`MaxStep=5 s`、`600 s` 总时长和 `[540,600] s` 尾窗。正式 cEGR、背压、温度阈值、低负荷和标准 simCase 接入 case 均完成仿真并通过聚焦范围内验收。

代表性量化结果：

- `40 kW / cEGR=0.3 / 背压=0.1613 MPa(abs) / 源温度=20 degC`：历史结果记录 `r_mix=0.30000`、`r_fresh=0.42857`、`m_cegr=0.0125449 kg/s`、阀面积分数 `0.28235`、阀压差 `0.060620 MPa`；该结果不能直接当作新的分流点 `r_split`。
- 同一 case：压缩机容积排出压力 `0.162401 MPa(abs)`，冷却器后 `0.162226 MPa(abs)`，阴极出口 `0.161966 MPa(abs)`，压缩机后到阴极出口裕度 `0.000261 MPa`。
- 同一 case：电堆阴极通道容积平均压力 `0.162183 MPa(abs)`；通道容积平均压力到阴极出口读回差值 `0.0002169 MPa`，冷却器后供气到阴极出口读回差值 `0.0002605 MPa`。当前等效 Flow Resistance 默认值为 `0.001 MPa @ 0.1 kg/s`，这些读回值需要通过 `cathode_channel_dp_nominal_MPa` 等参数标定，不能直接解释为真实分布式电堆总流阻。
- 同一 case：混合点约 `41.692 degC`，露点 `49.583 degC`，露点裕度 `-7.891 degC`，冷凝率 `2.856e-6 kg/s`，气相积分 `0.000171 kg`/尾窗。
- `5 A / cEGR=0.3`：`m_cegr=0.00500038 kg/s`，露点裕度 `-2.676 degC`，冷凝率 `7.622e-7 kg/s`；无回流 case 冷凝率为 `0`。
- 源温度筛选中，`35 degC` 时露点裕度 `-0.299 degC` 且仍有 `1.582e-7 kg/s` 冷凝；`37 degC` 时裕度 `+0.738 degC` 且冷凝率为 `0`；`40 degC` 时裕度 `+2.341 degC` 且冷凝率为 `0`。

上述数值只代表当前 focused model 的气相网络和 L2 代理，不构成完整模型等价或设备工程验证。

### 7.4 当前设计结论

1. 被动回流应优先接入压缩机前。当前阴极出口到压缩机入口混合点约有 `0.0606 MPa` 驱动压差；压缩机后到阴极出口的默认 `0.00026 MPa` 是等效流阻未标定时的读回值，不能作为压缩机后被动回流工程余量。标定参数应先通过阴极入口/出口压差观测确定。
2. 升温是当前模型筛选出的首要防冷凝方向。默认 case 至少需要约 `8 degC` 的混合点升温才能达到无冷凝，设计筛选建议保留不低于 `2 degC` 的露点裕度；当前 `40 degC` 源温度仅是边界代理，不是实际加热器额定功率。
3. 分离器不能替代蒸汽控制。分离器只能在冷凝发生后移除液水；要避免空压机前液滴风险，还需 EGR 支路升温/保温、低点排液、液滴捕集和失效时 cEGR 条件切除。
4. 在获得加热器 UA/功率、分离效率/允许含液率、压损和排液控制数据前，不新增主动泵、真实分离器或换热器物理块；当前结果用于方案筛选和试验门槛定义。后续新增物理必须优先使用官方 Simscape/Simulink 模块，不使用自建 MATLAB Function 替代物理网络。

阴极流阻补全需要先冻结入口/出口歧管、有效流道长度、截面/水力直径、并联流道数、粗糙度和目标压降/原始数据；不得直接用“几十 kPa”替换当前 `CathodeOutletResistance` 的参数。

当前状态：`implemented_structurally_verified_executed_behavior_verified_for_focused_scope_not_validated_for_engineering`。
