# 实施记录：工程化架构决策与聚焦模型总体规划

## 记录信息

| 项目 | 内容 |
|---|---|
| 日期 | 2026-08-14 |
| 工作类型 | 架构决策冻结、用户简图映射、控制边界整理、结果契约修正和实施规划 |
| 主要输入 | 用户关于主动/被动、普通/自增湿、取气/接入位置、控制层和官方模块优先原则的确认 |
| 适用模型 | `PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx` |
| 正式 runner | `run_routeA_focused_study.m` |
| 本切片模型结构编辑 | 未执行；工作区已有 `.slx` 改动未回退、未覆盖 |
| 本切片仿真 | 已完成 MATLAB 静态检查、模型读回和 600 s 聚焦结果契约 smoke；无结构模型编辑 |

## 1. 形成的工程判断

阴极尾气循环按“先选工程拓扑、再研究适用场景、最后比较竞争力”推进。当前聚焦模型不代表通用 cEGR 方案，而是以下架构的 L2 筛选基线：

> 被动压力差式循环 + 外部膜加湿器 + 分离后气相取气 + 空压机入口回流。

用户进一步确认第一阶段先做两个阀门被动式配置：`Passive_SelfHumidifying_PostSeparatorGas_CompressorInlet` 和 `Passive_ExternalMembraneHumidifier_PostSeparatorGas_CompressorInlet`。两种配置共享回流、公共出口处理、控制和结果契约，只改变电堆湿化方式。

主被动按是否增加独立循环做功设备定义，控制阀和控制器不改变分类。引射器暂归压力驱动被动式，但单列主气流压降和空压机功耗。

## 2. 当前模型边界裁决

1. 用户目标拓扑为：阴极出口 -> 公共背压边界 -> 水汽分离边界 -> 回流/排放分流 -> 回流支路 -> 空压机入口；配置 B 在阴极入口前增加膜加湿器干侧、在分离前增加湿侧。
2. 模型读回确认当前 `CathodeWaterSeparator_FC` 是 EGR 支路上的官方 `Flow Resistance (FC)`，排放支路从出口腔体另行取流；当前 `Pressure Relief Valve` 也在排放支路，当前实现因此仍是出口分支流阻代理，不是公共背压、分离后再分流。
3. 当前 `Cathode Humidifier` 是单侧 `Pipe (FC)` 加 `MIn` 水质量注入和 RH 控制，不是配置 B 的膜加湿器；配置 A 的自增湿尚未切换到无外部水源的正式 case。
4. 当前固定堆温、简化阳极和气相 L2 水观测继续保留为聚焦模型边界，不提升为完整热管理、液水库存或分离器工程模型。
5. 新增物理优先使用 Simscape/Simulink 官方模块和 MathWorks 官方案例，不使用自建 MATLAB Function 替代核心物理。

## 3. 结果契约裁决

分流点回流率设为主指标：

`r_split = m_return / (m_return + m_exhaust)`

同时报告：

- `x_comp_in = m_return / (m_return + m_fresh)`，空压机入口混合比例；
- `r_fresh = m_return / m_fresh`，新鲜空气基回流率；
- 目标比例、执行器命令和实际比例；
- 回流/排放支路流量、总流量和质量闭合状态。

旧 `r_mix = m_cegr / m_compressor_inlet` 保留为兼容字段和历史结果口径，不再作为架构回流能力的主指标。干基分流率必须等回流和排放支路组分可读回后再增加，当前不得由总质量流量假算。

## 4. 本切片文件变更

| 文件 | 变更 |
|---|---|
| `RouteA_cEGR_PEMFC_工程化架构决策与聚焦模型总体规划_v01.md` | 新增当前架构规划真源，包含决策矩阵、P0--P8 执行顺序、官方模块规则和 Gate |
| `RouteA_cEGR_PEMFC_两种阀门被动式架构与控制边界裁决_v01.md` | 将用户两张简图映射为自增湿/外部膜加湿两种配置，冻结绿色设备的控制、被动和能力缺口边界 |
| `RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md` | 固化结构图修正、当前聚焦模型子系统改动、P0-P6 实施顺序和模型建成门；本轮不修改 `.slx` |
| `RouteA_cEGR_PEMFC_官方引射器模块审计与FuelCell域适配裁决_v01.md` | 记录 R2025b 官方 `Ejector (G/MA)`、官方示例入口、三端口语义和与 `FuelCell.FuelCell` 域不兼容的适配路线 |
| `RouteA_cEGR_PEMFC_官方引射器被动式结构系统实施计划_v01.md` | 将官方引射器纳入后续被动架构，冻结后压缩机拓扑、官方标准基准、FuelCell 域适配路线和 E0-E5 模型建成门 |
| Route A 当前指导 README | 增加规划阅读入口，降级 S6 文件为被动基线专题规格 |
| `RouteA_cEGR_PEMFC_收敛实施路线图_v01.md` | 将 S6 研究扩展改为受架构总规划约束的单轴扩展 |
| `RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md` | 增加分离后气相边界和 `r_split` 主指标语义 |
| `RouteA_cEGR_PEMFC_交流会后路线裁决与研究问题_v01.md` | 更新 D7、G0/G1 和关联规划 |
| `RouteA_cEGR_PEMFC_S6_被动cEGR研究规格与预检计划_v01.md` | 明确其为被动基线专题，后续架构扩展服从总规划 |
| `RouteA_Cathode_cEGR_Focused_模型边界与实施契约_v01.md` | 冻结当前代理实现、目标架构、分流点指标和官方模块约束 |
| `RouteA_Cathode_cEGR_Focused/README.md` | 更新结果输出说明 |
| `RouteA_cEGR_PEMFC_模型-面板参数汇总表_v01.md` | 将阴极 separator 参数明确为 L2 流阻/边界代理，不再表述为已闭合的工程分离器参数 |
| `routeA_focused_assess_outputs.m` | 从回流和排放支路读回量计算分流点总质量基回流率 |
| `routeA_focused_performance_metrics.m` | 增加 `r_split`、支路流量和 dry-basis 未闭合状态，保留旧比例字段 |
| `routeA_focused_performance_analysis.m` | 将分流点比例和支路流量加入跨 case 摘要 |
| `routeA_focused_parameter_defaults.m` / `run_routeA_focused_study.m` | 将当前架构决策向量写入 study 元数据，并将 study schema 升级为 v02 |

## 5. 已执行验证

| 验证项 | 结果 | 证据边界 |
|---|---|---|
| 新增/修改 MATLAB 脚本静态检查 | `routeA_focused_assess_outputs.m`、`routeA_focused_performance_metrics.m`、`routeA_focused_performance_analysis.m` 均无 Code Analyzer issue | 仅说明脚本静态无分析器问题 |
| 模型拓扑读回 | `CathodeWaterSeparator_FC` 的 ReferenceBlock 为官方 `Flow Resistance (FC)`，连接在 EGR 支路；`ExhaustMassFlowSensor` 从出口支路另行取流；`SeparatorOrCondensation` 为 MATLAB Function | 证明当前实现是出口分支流阻代理；不证明分离后再分流 |
| `model_check(root, all)` | `63` 条 warning、无 error severity | 结构 warning 主要是当前 Simscape/容器/观测边界，未因本切片新增结构错误 |
| 用户简图与模型映射 | 第一阶段先做 `Passive_SelfHumidifying_PostSeparatorGas_CompressorInlet` 和 `Passive_ExternalMembraneHumidifier_PostSeparatorGas_CompressorInlet`；当前模型仍是单侧 L2 注水、排放支路背压和 EGR 支路流阻代理 | 两种配置共享 runner 和指标；公共背压/分离/再分流及双侧膜加湿器尚未实现 |
| 聚焦结果契约 smoke | Current=100 A、目标 cEGR=0.3、cold start、600 s、尾窗 `[540,600] s`，`passed=1` | 证明新字段可由现有输出结构计算，不证明分离器物理语义 |
| 架构元数据 | study 写入当前实现 `Passive_ExternalHumidifier_CathodeOutletBranchFlowProxy_CompressorInlet`，目标 `Passive_ExternalHumidifier_PostSeparatorGas_CompressorInlet` | 明确目标和实际实现不得混称 |
| 新分流点指标 | 当前分支总质量流量基 `r_split` 代理 `0.2694`；回流 `0.0128 kg/s`；排放 `0.0346 kg/s`；总分流 `0.0474 kg/s` | `post_separator_unverified`；干基未闭合 |
| 旧指标对照 | `r_mix=0.3000`；`r_fresh=0.4286` | 旧指标保留为辅助/历史口径，不能与 `r_split` 混用 |
| 运行警告 | 保留既有 To Workspace/Simscape logging warning | 未在本切片修改模型 logging 结构 |

## 6. 未解决问题

- 模型读回已确认当前分流点不是“分离器后再分流”：`CathodeWaterSeparator_FC` 只在 EGR 支路，排放支路从出口腔体另行取流；需要用官方模块裁决目标拓扑实现。
- 当前背压阀不在用户简图所示的公共分流前主干；需要先裁决公共背压边界的官方实现方式。
- 当前单侧 L2 注水接口不能作为外部膜加湿器；配置 B 需要双侧 FC 域膜传水/传热/压损组件或明确的 L2 能力缺口。
- 配置 A 需要关闭外部加湿器水注入，并用 MEA 产水、回流水蒸气、阴极入口湿度和气相水账本证明自增湿路径。
- 官方 `Ejector (G/MA)` 已存在，但当前官方块不直接兼容 `FuelCell.FuelCell` 四物种 conserving domain；需先做官方域独立可行性模型，再决定 FuelCell 域适配组件。
- 引射器被动式暂不进入当前阀门模型改造；待官方域基准和 FuelCell 域适配门通过后，作为第三个被动架构轴接入统一平台。
- 当前分离相关块是否只是流阻/相态代理，仍需官方组件和参数语义审计。
- `r_split` 已建立计算接口，但正式历史矩阵尚未全部重算新指标。
- 分流支路干基组分尚未注册，`r_split_dry` 暂不输出有效数值。
- 现有 L2 MATLAB Function 水代理仍是迁移/淘汰对象，不作为新架构物理模块模板。
- 主动泵、自增湿、引射器、真实加热器和真实分离器均未进入当前模型实现。

## 7. 下一执行切片

1. 先在官方模块范围内裁决公共背压、分离气相边界和再分流拓扑。
2. 先实现配置 A 的外部加湿器旁路/禁用、自增湿水账本和无回流/小回流/目标回流验证。
3. 再为配置 B 登记并实现双侧膜加湿器能力，保持同一 runner 和结果契约。
4. 检查两种配置的 `r_split` 与回流/排放流量闭合，确认历史 `r_mix` 和新 `r_split` 不被混用。
5. 对现有 `SeparatorOrCondensation` MATLAB Function 代理提出官方模块替换或删除方案，不在未裁决前新增类似模块。
6. 两种被动配置分别通过 Gate 0--Gate 3 后，再建立只改变循环驱动方式的主动式对照配置。

本次方案明确：先完成结构图修正和公共出口拓扑改造，再建立配置 A 自增湿和配置 B 外部膜加湿；cEGR 性能及设备控制研究冻结到模型建成门 P6 之后。
