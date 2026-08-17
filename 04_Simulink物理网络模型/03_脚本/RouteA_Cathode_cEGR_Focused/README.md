# Route A 阴极 cEGR 聚焦 runner

本目录只服务 `RouteA_Cathode_cEGR_Focused` 轻量研究模型，不修改或替代
`RouteA_GasMixture_Derived` 的完整系统 runner。

## 正式入口

| 文件 | 职责 |
|---|---|
| `routeA_focused_paths.m` | 解析轻量模型、源模型和共享脚本路径 |
| `routeA_focused_parameter_defaults.m` | 提供固定阳极边界和恒温边界默认值 |
| `routeA_focused_case_template.m` | 返回轻量模型 case 输入模板 |
| `routeA_focused_case_adapter.m` | 接受聚焦 case 或标准 Route A `simCase` 并统一到 runner 输入 |
| `routeA_focused_parameter_bridge.m` | 将标准阳极/热管理输入映射到简化后的真实模型写入点 |
| `run_routeA_focused_study.m` | 通过 `SimulationInput` 串行执行一组同类 I/P/V case |
| `routeA_focused_assess_outputs.m` | 复用阴极/电边界审计并取消不适用的阳极吹扫门 |
| `routeA_focused_performance_metrics.m` | 计算电流密度、功率密度、分流点主回流率、空压机入口混合比例、新鲜空气基回流率和混合点氧分压 |
| `routeA_focused_performance_analysis.m` | 汇总多 case 性能比较准入和排除原因 |
| `routeA_focused_pressure_observations.m` | 读回压缩机入口、压缩机排出、中冷器后、堆阴极通道、阴极出口及公共背压阀后气相节点；背压阀后读数包含公共气相边界压损 |
| `routeA_focused_anti_condensation_analysis.m` | 计算混合点露点、露点裕度、升温筛选量和液水去除代理 |
| `routeA_focused_water_observations.m` | 提取气相冷凝和饱和度证据，不声称液水闭合 |

## 输入接口

- 标准 `Route A simCase`：`controls.electrical`、`controls.cathode`、`controls.cegr`、`controls.anode`、`controls.thermal`、`controls.stack` 和 `controls.devices` 可直接传入；建议先用 `routeA_simCase_template` 和 `routeA_validate_case`。
- 原生聚焦 case：使用 `boundary`、`air`、`cathode`、`cegr`、`anode`、`thermal`、`stack`、`devices` 和 `focused` 字段。
- `thermal.stackTemperatureSet_C` 映射到 `focused_stack_temperature_C`；`anode.sourcePressure_MPa_abs`、`anode.sourceTemperature_C` 和 `anode.h2MoleFraction` 分别映射到聚焦氢源压力、边界温度和组分。
- `cathode.sourceTemperature_C` 通过 `env_T` 写入实际 Air Intake/气路初态；实际压缩机入口压力默认以 `environment.ambientPressure_MPa_abs` 为唯一真源，并同步 `cegr_inlet_mixer_p0` 和 `cegr_pipe_p0`。标准 `cathode.sourcePressure_MPa_abs` 的旧命令列在当前模型中未连接，不能直接当作压缩机入口压力结果。
- 阳极入口由 `focused.anodeInletMdot_kg_s` 控制；标准 `anode.inletPressure_MPa_abs`、阳极加湿、阳极回流、阳极吹扫以及冷却液/散热器参数会保留在桥接报告中，但标记为 `not_applicable`，不会伪装成已接入的物理量。

## 输出接口

- `study.cases(k).performance.electrical`：I/V/P、单电池电压、电流密度和功率密度。
- `study.cases(k).performance.cegr`：目标值、分流点 `r_split=m_return/(m_return+m_exhaust)`、空压机入口 `x_comp_in=m_return/(m_return+m_fresh)`、`r_fresh=m_return/m_fresh`、回流/排放流量、阀面积和压差。旧 `actualRatioMixBasis` 保留为兼容字段，不再作为架构回流能力主指标。
- `study.cases(k).performance.cathode`：压缩机入口混合点压力、温度、组分、氧过量系数、氧分压，以及新鲜空气/入堆/出口 `m_H2O`。RH 仅作展示，不用于质量、水账本或稳态判据。
- `study.cases(k).performance.thermal`：固定温度设定、实际堆温和温差；固定温度边界不等同于冷却系统热流结果。
- `study.cases(k).performance.water`：混合点气相冷凝率和饱和度；液水库存、输运、排液、分离效率和空压机寄生功率仍未闭合。
- `study.cases(k).performance.pressure`：压缩机入口、压缩机容积排出、中冷器后、阴极通道容积、阴极出口及公共背压阀后气相节点。公共背压阀后读数包含后续 `CommonGasPhaseBoundary_FC` 的压损，不能单独归因于阀。外部压力测点位置未确认时，五个外部压力锚点只用于筛选设定和观察，不可作为流阻验收依据。
- `study.cases(k).performance.antiCondensation`：混合点水蒸气分压、露点、露点裕度、所需升温、理论蒸汽降低比例和液水去除筛选量；不代表真实加热器或分离器。
- `study.cases(k).parameterBridge`：每个参数的真实写入点、映射状态和不适用原因。
- `study.architectureId` / `study.targetArchitectureId` / `study.architecture`：当前实现和目标架构决策向量。`self_humidifying` 外部案例使用 `Passive_SelfHumidifying_PostSeparatorGas_CompressorInlet`，无外部水注入；旧 `Passive_ExternalHumidifier_*` 仅是历史 L2 注水接口记录。

## 外部 240 kW 自增湿案例

`PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01` 仅属于 `external_case`，不改变 `platform_default`。其 240 kW 基线为 `606 x 380 cm2`、无 CEGR、`0.1--1.9 A/cm2`；MEA 掩码直接引用模型工作区 `stack_io=2e-14 A/cm2`、`stack_alpha=1`，并固定 `stack_iL=2.5 A/cm2`、膜厚 `125 um` 与 2.5 倍导电率表。runner 保留对 `stack_io/stack_alpha` 的 `SimulationInput` 覆盖能力，只能用于明确记录的新一轮外部案例标定。低负荷工况的阴极气体温度由模型中的 `Cathode_Gas_Temperature_Boundary` 写入，CSV 只提供气体入口温度参考，不输入其 RH。

外部案例的后续 CEGR 研究必须先运行无 CEGR 基准与候选回流工况，再比较 `m_H2O`、`m_cegr`、`r_split`、氧计量比、氧分压、压力链和露点裕度。修复气体温度边界前的 CEGR 筛选结果不可用于湿化或性能结论。

第一阶段已完成聚焦模型本身的 I/P/V、空气控制模式和低负荷代表性验证；四问题研究的正式量化结果见 `04_说明/RouteA_Cathode_cEGR_Focused/03_审计与研究/RouteA_Cathode_cEGR_Focused_四个问题研究结论_v01.md`；完整模型逐信号等价对照仍是独立门槛。当前架构和后续主动式、自增湿式对照的总规划见 `RouteA_cEGR_PEMFC_工程化架构决策与聚焦模型总体规划_v01.md`。
