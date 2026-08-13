# Route A 阴极 cEGR 聚焦模型边界与实施契约

日期：2026-08-13  
状态：结构副本、正式 runner、参数桥接、I/P/V 控制和性能分析契约已完成首轮收口；不构成工程方案验证。  
源模型：`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
聚焦模型：`04_Simulink物理网络模型/01_模型/RouteA_Cathode_cEGR_Focused/PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`

## 1. 研究目的

聚焦模型用于研究完整阴极气路、cEGR、阴极背压、气体温度、气相冷凝和电堆性能之间的关系。它不是当前完整系统模型的替代品，也不用于表达主动泵方案。

## 2. 保留边界

- `Cathode_Air_cEGR_BOP` 完整保留，包括新鲜空气、压缩机入口混合器、压缩机图谱/容积、加湿器、cEGR 阀和 EGR 管。
- `Cathode_Exhaust_Backpressure_Water` 完整保留，包括出口腔体、cEGR 分流、背压阀和当前 L2 水观测器。
- `Stack_Core` 完整保留，包括 MEA、阴极气体通道、阳极气体通道、MEA 热容和电气端口。
- 空气侧控制、加湿器控制、cEGR 比例控制、阴极背压调节和 I/P/V 电负载保留。
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

允许输出堆 I/V/P、cEGR 实际比例、阀压差、背压、阴极入口 RH/O2/lambda、气相闭合、混合点和回流管路冷凝流率。当前模型不闭合液水库存、液滴携带、排液、分离效率、压缩机进液损伤或空压机寄生功率。

## 5. 实施顺序

1. 轻量模型与完整模型在相同冷态输入下做结构和行为对照。
2. 固化 I/P/V 分模式的聚焦 runner 和结果契约。
3. 单独修复冷凝位置、氧分压、回流率双口径和其他已识别缺陷。
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

- `r_mix = m_cegr/m_compressor_inlet`，即混合基回流率。
- `r_fresh = m_cegr/(m_compressor_inlet-m_cegr)`，即新鲜空气基回流率。
- `pO2` 当前只在 `compressor_inlet_mixer` 位置计算，采用质量分数到摩尔分数换算；不得写成电堆阴极入口直接测量值。
- 冷凝输出仅为气相冷凝率和饱和度代理；液水库存、液滴输运、排液、分离效率和压缩机寄生功率均不纳入性能排序。

### 6.4 首轮行为证据

同一聚焦模型和正式 runner 下，`80 degC`、阳极 `0.001 kg/s`、冷态启动的代表性结果：

| 模式 | 工况 | 结果 |
|---|---|---|
| Current | `100 A, cEGR=0.3, OER=3.0, 120 s` | `passed=1`；`V=406.4588 V`；`r_mix=0.2999`；`r_fresh=0.4284` |
| Power | `40 kW, cEGR=0.3, OER=3.0, 120 s` | `passed=1`；`V=406.7343 V`；`I=98.3443 A` |
| Voltage | `410 V, cEGR=0.3, 600 s` | `passed=1`；`V=410.1326 V`；`I=78.9043 A` |
| Air mdot | `100 A, target mdot=0.045 kg/s, cEGR=0` | `passed=1`；实际流量 `0.045 kg/s` |
| Air direct | `100 A, direct command=0.5, cEGR=0` | `passed=1`；实际流量约 `0.0753 kg/s` |
| Low load | `5 A, cEGR=0 / 0.3, 600 s` | 两例均 `passed=1`；cEGR=0.3 时混合点冷凝约 `7.62e-7 kg/s`、饱和度约 `1.1531` |

上述结果属于 focused model 的范围内行为验证，不构成完整模型等价、被动工程方案或产品性能验证。
