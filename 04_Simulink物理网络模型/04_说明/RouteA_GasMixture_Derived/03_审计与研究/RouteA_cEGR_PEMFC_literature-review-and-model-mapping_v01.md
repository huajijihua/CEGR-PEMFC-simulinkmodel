# RouteA cEGR-PEMFC Literature Review and Model Mapping v01

文件类型：CEGR 文献证据与 RouteA_v2 模型映射
日期：2026-07-24
状态：第一轮精读完成，作为 RouteA_v2 结构调整的准入输入；尚未据此修改 `.slx`。
范围：本地 8 篇直接 cEGR 论文、5 篇外部直接相关论文、1 篇前沿待复核论文和官方 Gas Mixture PEMFC 案例的交叉映射。

## 1. 结论先行

RouteA 当前模型不应被判定为“无效重建”。它已经积累了官方 Gas Mixture/FuelCell 四物种气体域、MEA、电堆热端、阴极尾气回流、BOP、控制接口、runner 和观测审计等有价值资产。当前阻塞的根因是这些资产没有在开始建模前被一个完整的 CEGR 研究问题树和接口契约约束，导致不同目标、不同保真度和不同控制语义逐步叠加到同一结构中。

RouteA_v2 的正确路线是**证据保留式重构**：

1. 官方案例负责提供已经验证过的 PEMFC/Simscape 物理骨架、组件语义、求解器和初始化参考；
2. CEGR 文献负责定义循环的物理机制、控制目标、变量口径、风险边界和验证工况；
3. 当前 RouteA 负责提供已经完成的工程资产、接口尝试、运行证据和失败模式；
4. 三者交叉后，再决定哪些现有模块保留、哪些模块收敛、哪些能力拆为独立模式、哪些暂不开放。

**本轮边界修正：** 氧稀释、自增湿、排水、低负荷高电位、动态饥饿、寄生功耗和冷启动是 cEGR 对系统产生的影响，也是研究工况和验证 KPI，不是 cEGR 在 Simulink 中的物理控制结构。RouteA 的 cEGR 本体仍然是“阴极出口气体分流 -> 阀/泵/阻力设备 -> 阴极入口混合”的气路；回流气体的组分、温度和湿度由阴极出口物理网络决定，控制器只对执行器或上层设定值进行控制。

**本轮核心判断：** cEGR 的气路本体仍然由实际阀/泵/阻力设备控制；`cegr_ratio_cmd` 可以保留为上层设定值，但不能直接等同于实际回流流量。低负荷高电位限制、自增湿、高负荷排水/氧分布、动态反应物饥饿缓解、寄生功耗和冷启动热管理是六类不同的研究问题，它们的安全范围和验证 KPI 可能不同，不能用一个设定值直接替代实际气路反馈和分场景验证。

在文献证据门通过前，不对当前 `.slx` 做大规模结构修改；现有 v09/v10 结果、脚本和 dirty worktree 继续保留为历史和审计证据。

## 2. 研究问题与证据等级

本轮文献研究回答四个问题：

1. CEGR 改变了哪些可观测的气体、热、水和电化学状态？
2. 不同论文使用的循环比、空气过量系数和氧浓度口径是否可以直接比较？
3. 每类研究问题需要哪些物理设备、控制输入和审计量？
4. 这些要求如何映射到当前 RouteA 的模块、接口和最小验证工况？

文献不能自动成为平台默认参数。每一条数值证据都必须同时记录论文、设备规模、工况范围、变量定义和可迁移性。

| 证据等级 | 含义 | RouteA_v2 用法 |
|---|---|---|
| `A` | 直接实验或实验校核的系统/电堆证据 | 约束机制方向、KPI 和可接受趋势；不直接复制额定参数 |
| `B` | 具有明确方程、动态状态和控制对象的系统模型 | 约束状态、方程、接口和控制结构；参数仍需分层 |
| `C` | 局部电化学、阻抗、耐久或窄范围实验 | 约束内部机制和专项指标，不定义整机默认架构 |
| `D` | 概念分析、假设模型或跨尺度推演 | 作为候选场景和风险假设，必须标记为待验证 |
| `O` | 官方案例和官方库资产 | 约束组件语义、物理拓扑和 solver/初始化参考 |

## 3. 第一轮文献矩阵

### 3.1 本地直接 CEGR 文献

| 编号 | 文献 | 等级 | 第一轮可用证据 | 对模型的直接约束 |
|---|---|---|---|---|
| L01 | Cheng et al., 2014, *Air Supply System Model with Exhaust Gas Recirculation for Improving the Life of Fuel Cell*, DOI [10.1109/ITEC-AP.2014.6941250](https://doi.org/10.1109/ITEC-AP.2014.6941250) | B | 用压力容腔、可压缩节流、氧消耗和混合气组分描述空气侧 EGR；模型假设理想气体、定温，并将加湿/冷凝简化 | RouteA 必须保留气体库存、压差和物种混合的物理来源；该文不能替代液水和完整热网络 |
| L02 | Jiang et al., 2017, *Experimental study on dual recirculation of polymer electrolyte membrane fuel cell*, DOI [10.1016/j.ijhydene.2017.04.183](https://doi.org/10.1016/j.ijhydene.2017.04.183) | A | 阴极回流显著提高 RH，但高回流会降低入口/出口 O2 和电压；低新鲜空气过量系数下电压损失更明显 | 必须同时记录新鲜空气流量、回流流量、O2、RH 和电压，不能只扫一个回流比 |
| L03 | Zhang et al., 2020, *Effect of cathode recirculation on high potential limitation and self-humidification of hydrogen fuel cell system*, DOI [10.1016/j.jpowsour.2020.228388](https://doi.org/10.1016/j.jpowsour.2020.228388) | A/B | 回流可以把低负荷高电位限制和自增湿作为控制目标；高负荷时水排出、压力波动和循环泵功耗成为约束 | 低负荷电位控制、高负荷排水和泵功耗必须是不同验证场景；不能把低负荷最优回流值推广到全工况 |
| L04 | Zhang et al., 2021, *Self-humidifying effect of air self-circulation system for proton exchange membrane fuel cell engines*, DOI [10.1016/j.renene.2020.10.105](https://doi.org/10.1016/j.renene.2020.10.105) | A/B | 动态模型包含气相/液相水、凝结、膜含水量、质子拖曳和三通阀；自循环的 RH 上限和响应时间受流量与回流控制影响 | 水蒸气、液水/凝结、膜水状态和阀门动态应在接口上分开；不能把 RH 设定值当作实际入口 RH |
| L05 | Liu et al., 2024, *Optimization strategies to mitigate reactant starvation in a dead-ended hydrogen-oxygen PEMFC during cyclic loading*, DOI [10.1016/j.fuel.2023.129886](https://doi.org/10.1016/j.fuel.2023.129886) | A/C | 回流可缓解水淹引起的反应物饥饿，但过高泵速会引入电压下冲；对象是死端 H2/O2 单电池/通道 | 只作为动态饥饿和水淹风险的窄范围证据，不把其泵速或几何参数迁移为汽车空气侧默认值 |
| L06 | Aggarwal et al., 2024, *Conceptual analysis of cathode exhaust gas recirculation to reduce idling power and enable faster freeze starts in polymer electrolyte membrane fuel cell systems*, DOI [10.1016/j.ijhydene.2024.11.287](https://doi.org/10.1016/j.ijhydene.2024.11.287) | D | 将低负荷/怠速与冷启动分成独立用途，架构包含阀、水分离器、收集罐和隔膜泵；给出显著节氢、降怠速功率和加快冻启动的概念结果 | 只有在水分离、收集、泵功率和冷启动热状态均有明确模型时，才可开放对应场景；文中结果不能作为平台默认性能承诺 |
| L07 | Liu et al., 2024, *Analysis of the influence of cathode recirculation strategy ... internal polarization and external characteristics*, DOI [10.1016/j.jpowsour.2024.234165](https://doi.org/10.1016/j.jpowsour.2024.234165) | A/C | 在固定总阴极入口流量下，回流提高湿度、降低欧姆阻抗，但 O2 稀释会增加传质/反应极化；影响随电流密度变化 | KPI 必须包含入口 O2 分压、RH、电压和流量；cEGR 不能只作为外部混气比例，而要保留电化学损失的可解释输入 |
| L08 | Liu et al., 2024, *Research on PEMFC cathode circulation under low-load conditions and its optimal control in FCV power system for long-term durability*, DOI [10.1016/j.ijhydene.2024.02.254](https://doi.org/10.1016/j.ijhydene.2024.02.254) | B | 空气侧动态模型显式包含供气/回流容腔、压缩机和泵动态、映射关系，并比较 PI、TS-LQG 和 TS-MPC | 泵速不是唯一控制量；容腔、设备动态、O2 分压/电压目标和寄生功耗必须有明确边界 |

本地文件证据位于：

`00_支撑材料/03_cEGR阴极循环技术研究/`

该目录当前实际有 8 篇直接论文。第一轮提取文本暂存于 `tmp/pdfs/cegr_round1/`，仅用于继续精读和逐条回查，不是平台参数真源。

### 3.2 外部直接相关文献与补充证据

| 编号 | 文献 | 等级 | 补充价值 | 当前处理 |
|---|---|---|---|---|
| E01 | Kim & Kim, 2012, *Studies on the cathode humidification by exhaust gas recirculation for PEM fuel cell*, DOI [10.1016/j.ijhydene.2011.11.103](https://doi.org/10.1016/j.ijhydene.2011.11.103) | A/B | 对比有回流鼓风机和无鼓风机两种架构；明确回流会增湿但降低 O2，并给出与膜加湿器的性能差异 | 用于定义主动/被动 cEGR 架构分支和增湿-稀释权衡 |
| E02 | Zhao et al., 2018, *Study on voltage clamping and self-humidification effects ... dual recirculation based on orthogonal test method*, DOI [10.1016/j.ijhydene.2018.06.172](https://doi.org/10.1016/j.ijhydene.2018.06.172) | A | 将电压、RH、HFR、入口/出口 O2 和因素组合用于正交分析 | 用于设计低负荷专项的多指标验证，不复制其具体试验矩阵 |
| E03 | Becker et al., 2018, *Cathode Exhaust Gas Recirculation for Polymer Electrolyte Fuel Cell Stack*, DOI [10.1002/fuce.201700219](https://doi.org/10.1002/fuce.201700219) | A/B | 12 kW 堆实验和增湿现象模型；涉及封闭空气、氧注入和液水淹没风险 | 用于检查 stack 级回流和水管理边界；参数仍保留为文献层 |
| E04 | Rodosik et al., 2019, *Impact of humidification by cathode exhaust gases recirculation on a PEMFC system for automotive applications*, DOI [10.1016/j.ijhydene.2018.11.139](https://doi.org/10.1016/j.ijhydene.2018.11.139) | A | 直接覆盖汽车系统尺度，关注 RH、均匀电压、氧稀释和系统效率损失 | 用于补充系统级效率与均匀性 KPI，不把单一回流区间设为通用默认值 |
| E05 | Liu et al., 2022, *High-potential control for durability improvement ... oxygen partial pressure regulation under low-load conditions*, DOI [10.1016/j.ijhydene.2022.07.142](https://doi.org/10.1016/j.ijhydene.2022.07.142) | A/B | 120 kW 模型和实验校核，采用回流与 O2 分压调节实现低负荷高电位控制 | 用于确定低负荷控制目标应优先看 O2 分压/电压，而不是固定 cEGR 比 |
| E06 | 2025, *Mechanism insights and system-level operation analysis of cathode recirculation for durability enhancement in automotive PEMFC*, DOI [10.1016/j.apenergy.2025.126647](https://doi.org/10.1016/j.apenergy.2025.126647) | C/D | 最新耐久机制方向，涉及电荷转移、O2 扩散、ECSA 和循环泵速优化 | 暂列前沿待复核资料；不进入当前模型默认参数或验收结论 |

## 4. 文献综合得到的物理认识

### 4.1 cEGR 的主要作用不是一个量

| 机制 | 直接变化 | 可能收益 | 可能代价 | RouteA_v2 必须观察 |
|---|---|---|---|---|
| O2 稀释 | 入口 `yO2`、`pO2` 和总反应物浓度下降 | 低负荷高电位限制、耐久保护 | 传质极化增加、功率下降、饥饿风险 | `yO2_in`、`pO2_in`、总/新鲜空气流量、I/V |
| 自增湿 | 回流带回水蒸气和部分液水 | 膜含水量提高、欧姆损失下降 | 过湿、液水积累、压力波动和淹没 | RH、气相水、液水/冷凝量、膜水代理量 |
| 排水与分布 | 回流改变阴极总流量、压力和通道流速 | 高负荷时改善水排出和电压均匀性 | 泵功耗、阀压降、局部流量不足 | `mdot_mix`、压差、背压、冷凝/分离、故障标志 |
| 动态库存 | 回流容腔和管路增加压力/组分状态 | 缓和供气波动、改善水状态建立 | 初态更难、响应滞后、DAE 更敏感 | 各 chamber `p/T/y_i`、设备动态、响应时间 |
| 电化学耦合 | O2 扩散、ORR、膜质子传导和欧姆阻抗变化 | 解释电压和耐久趋势 | 仅看外部流量无法解释失效 | 电压、O2 分压、RH、极化/阻抗代理 |
| 热/冷启动 | 回流减少新鲜空气与散热，保留水和热量 | 怠速降功耗、冷启动加快 | 液水冻结、局部缺氧、压力冲击 | 热状态、液水、泵/阀功率、冷启动阶段 KPI |

### 4.2 cEGR 影响项与气路控制分层

文献共同支持以下影响关系，但这些关系不能反过来改变 cEGR 的物理定义：

- 增大回流通常提高湿度，但同时稀释氧气；
- 低负荷适合研究电位/氧分压限制，高负荷则必须重新检查排水、压降和总流量；
- 回流泵速提高不等于系统性能提高，泵功耗和动态下冲必须计入；
- 被动压差回流和主动泵回流的物理因果不同，不能只用一个命令字段隐藏差异；
- 冷启动/怠速是独立场景，不能把普通稳态 cEGR sweep 的结论外推到冻结初态。

RouteA 中的控制链应保持为：

```text
阴极出口物理状态
    -> 分流/排气支路
    -> 阀开度、泵速或其他执行器命令
    -> cEGR 实际流量
    -> 入口混合气体状态
```

`cegr_ratio_cmd` 如果保留，只能是上层研究目标或控制器设定值，由控制器转换为阀开度、泵速或背压命令；它不能直接写入 `mdot_cegr`，更不能直接写入回流气体组分。实际回流量和组分必须由 Simscape 气路反馈产生。文献中的影响项用于选择控制目标和验证 KPI，不构成新增 cEGR 物理模块的理由。

## 5. 变量口径与 RouteA 接口约束

### 5.1 回流比必须保留原始流量

论文中的回流比至少有三种口径，不能直接混用：

```text
phi_recirc_to_fresh = mdot_cegr / mdot_fresh
XEGR_dry = mdot_cegr_dry / (mdot_cegr_dry + mdot_fresh_dry)
XEGR_wet = mdot_cegr_total / (mdot_cegr_total + mdot_fresh_total)
```

当前 RouteA 架构中的 `cegr_ratio_actual` 更接近总湿气体的回流/混合器入口口径：

```text
cegr_ratio_actual = abs(mdot_cegr) / max(abs(mdot_mix_in), epsilon)
```

RouteA_v2 必须同时发布：

| 字段 | 语义 |
|---|---|
| `mdot_fresh` | 新鲜空气总质量流量 |
| `mdot_cegr` | cEGR 支路实际质量流量，方向按接口约定记录 |
| `mdot_mix_in` | 混合器进入电堆/加湿器的总质量流量 |
| `mdot_cegr_dry` / `mdot_fresh_dry` | 干基流量，只有在水蒸气/液水分离口径明确时才开放 |
| `cegr_ratio_wet` | 湿基回流/混合流比 |
| `cegr_ratio_dry` | 干基回流/混合流比 |
| `cegr_to_fresh_ratio` | 回流/新鲜空气比 |

报告中不得只给一个无定义的“EGR ratio”。

### 5.2 新鲜空气过量系数、总过量系数和氧分压分开

至少区分：

- `lambda_fresh`：只根据新鲜空气供给定义的过量系数；
- `lambda_mix`：混合气总有效氧供给相对于电化学消耗的过量系数；
- `pO2_ca_in`：阴极入口氧分压，直接反映氧稀释和压力共同作用；
- `yO2_ca_in`：阴极入口氧摩尔分数；
- `RH_ca_in`：阴极入口实际湿度，而不是命令设定值。

任何脚本不得把“新鲜空气流量”直接命名为 cEGR 下的实际氧过量系数，也不得用命令值替代网络反馈值。

### 5.3 被动与主动回流是执行设备配置，不是两种 cEGR 物理定义

两种配置都遵循同一个基本气路：阴极出口气体经过分流后，经由实际的流量控制设备返回阴极入口。区别只在于流量由压差/阀阻力自然决定，还是由泵和其功率/性能边界参与决定。不能因为研究目标不同就复制 cEGR 气路或给回流气体另造独立组分源。

| 模式 | 流量决定因素 | 必要组件/状态 | 默认定位 |
|---|---|---|---|
| `PassiveValveEGR` | 尾气与入口之间的压差、阀开度、局部阻力 | 出口容腔、排气分流、阀、管路、混合点、压力状态 | RouteA_v2 首先闭合的物理模式 |
| `ActivePumpEGR` | 泵速/泵地图、阀、压差和泵动态 | 泵或等效设备、功率、入口/出口压力、旁路/保护 | 专项研究配置，不能伪装成被动回流 |

被动模式不得使用强制质量流源直接定义实际 cEGR；主动模式必须报告泵功率或明确其等效边界。水分离器、收集罐和排水口只有在对应液水状态存在时才允许进入默认拓扑。

## 6. 当前 RouteA 资产映射

### 6.1 保留资产

| 当前资产 | 保留原因 | RouteA_v2 处理 |
|---|---|---|
| 官方 Gas Mixture/FuelCell 四物种域和 MEA | 与文献的 O2/N2/H2O 混合、反应和水生成语义一致 | 继续作为物理主域和官方结构参照 |
| 当前电堆、热端、阴极/阳极气路和 BOP | 已完成大量结构搭建，直接丢弃会丢失接口和审计经验 | 先读回、分类和最小验证，再按边界收敛 |
| 当前 cEGR 支路、背压、加湿、水管理尝试 | 已经承载 RouteA 的核心气路和后续研究接口 | 默认保留为 RouteA_v2 的主气路；只对未闭合接口、设备边界和观测口做定点收敛，不整体推倒 |
| I/P/V 统一 runner 和 `I_cmd` 思路 | 文献工况需要负载扰动与同一 plant 比较 | 保留单一 plant 入口，清理重复装配语义 |
| 观测、气体闭合、水账本和历史结果 | 为文献 KPI 和失败分类提供基础 | 从物理拓扑中解耦为结果层插件，保留证据 |

### 6.2 必须重构的资产

| 当前问题 | 文献/物理原因 | 重构方向 |
|---|---|---|
| `Source_Conditioner` 两侧未连接端口 | 端口代表的物理边界、混合和初态没有唯一语义 | 先按端口实际用途归类，再决定保留为设备边界、适配器或停用；禁止用 Terminator 隐藏问题；不据此否定已经闭合的 cEGR 主气路 |
| 多功能入口调理与独立物种源叠加 | 文献要求混合气守恒和设备因果，多个强制源会破坏可解释性 | 将新鲜边界、cEGR 回流和混合点分成唯一物理路径 |
| 一个回流命令承载所有用途 | 低负荷、增湿、高负荷、冷启动目标冲突 | 改为 `mode` + 明确控制输入 + 原始反馈；不同模式共享 plant，不复制 `.slx` |
| cEGR 比、空气过量系数和 O2 分压混用 | 文献口径不同且物理含义不同 | 发布原始流量和多种派生指标，命名中包含基准 |
| `m_condensed=0` 或类似水接口占位 | 直接文献表明凝结、膜水和淹没是关键边界 | 只有在模型存在实际相变/分离状态后，才将液水 KPI 标记为已验证 |
| 观测字段与控制写入点重复 | 实际流量/压力不能由脚本伪造 | 物理输出为唯一真值，控制器仅写命令和限幅状态 |

### 6.3 暂缓资产

- 未有明确文献问题、设备边界和验证工况支持的额外 Source_Conditioner 端口；
- 产品级压缩机 map、泵 map、分离效率和腐蚀模型；
- 将单篇论文的 10 kW、30 kW、120 kW 或单电池参数直接写入 `platform_default`；
- 将概念冷启动结果直接写成当前 RouteA 的性能承诺；
- 为 Current、Power、Voltage 或不同 cEGR 用途复制物理 plant。

## 7. RouteA_v2 的文献准入阶段

### Phase 0.5：CEGR 证据链和现状映射

**输入：** 本文献矩阵、官方 Gas Mixture 案例、当前模型审计、既有 RouteA 实施记录和 v09/v10 结果边界。

**必须完成：**

1. 先固定 cEGR 的物理边界：阴极出口分流、阀/泵/阻力设备、入口混合和排气支路；文献影响项不作为另建气路的理由；
2. 每篇核心论文记录对象规模、变量定义、方程/实验范围、证据等级和不可迁移参数；
3. 将当前模型每个 CEGR/BOP/控制模块标记为 `PRESERVE`、`REFACTOR`、`DEFER` 或 `HISTORICAL`；
4. 建立“文献影响 - 模型变量 - 模块 - 验证工况”四列映射；
5. 选定 RouteA_v2 首个闭环验证用例。建议先选低负荷 O2 分压/湿度权衡，而不是同时开放冷启动、全液水和产品级泵图；
6. 明确被动和主动 cEGR 是否都进入 v2，若都进入，必须是同一 plant 的两个执行设备配置而非两套结构。

**出口条件：** 所有拟修改模块都有证据来源和验证目标；所有拟保留模块都有物理职责；所有暂缓能力都有明确原因；用户确认后才进入 `.slx` 结构修改。

### 后续阶段建议

| 阶段 | 目标 | 收口证据 |
|---|---|---|
| v2-L1 | 当前模型资产和官方结构的端口/状态/参数差异表 | read-back、warning ledger、模块分类表 |
| v2-L2 | 只闭合一个 cEGR 模式和一个最小用例 | `model_check`、冷态/热态短 smoke、质量/物种闭合 |
| v2-L3 | 低负荷电位/O2 分压与自增湿权衡 | O2、RH、压力、I/V、cEGR 原始流量和辅助功耗 |
| v2-L4 | 高负荷排水、动态饥饿和主动泵专项 | 液水/凝结状态、动态下冲、寄生功率、失败分类 |
| v2-L5 | 冷启动/怠速概念研究配置 | 热状态、液水、冻结假设、泵阀功耗和独立验证报告 |

每一阶段都必须有明确的“完成”和“暂停”条件。下一阶段不能用上一阶段的结构存在或脚本静态检查代替运行证据。

## 8. 文献驱动的最小验证矩阵

| 用例 | 首要控制量 | 必须观察 | 通过条件的性质 |
|---|---|---|---|
| 低负荷高电位限制 | 泵速/阀开度、`pO2` 或电压目标 | `pO2_in`、`yO2_in`、电压、RH、泵功耗 | 目标电位/氧分压可追踪，且没有未分类饥饿或压力冲击 |
| 自增湿 | 回流路径和湿度/旁路配置 | RH、气相水、膜水代理、HFR/欧姆代理、电压 | 湿度改善与氧稀释、电压变化的方向可解释 |
| 高负荷排水 | 新鲜空气/总流量、背压、回流量 | 总流量、压差、凝结/液水、O2、功率 | 不能只因 RH 提高就判定成功；必须同时审计排水和氧供给 |
| 动态反应物饥饿 | 回流动态、空气流量、阀/泵速 | 电压下冲、O2、压力、液水、限幅 | 失败分类能区分饥饿、淹没、供气不足和控制饱和 |
| 怠速/冷启动概念 | 回流模式、阀、泵、热边界 | 净功率、热状态、液水/冻结状态、压力 | 只在所有关键假设和水/热状态显式时报告概念结果 |

## 9. 参数来源与报告纪律

RouteA_v2 使用以下来源标签，不允许把文献值无标签写进默认初始化：

| 标签 | 含义 | 是否可直接进入默认平台 |
|---|---|---|
| `OFFICIAL` | MathWorks 官方示例、官方库或官方 solver 设置 | 可作为结构和基础参考，仍需做 RouteA 读回 |
| `LITERATURE` | 论文中的对象参数、实验点、拟合值或控制器结果 | 否；必须带论文、范围和适用对象 |
| `ENGINEERING_DEFAULT` | 有物理依据但未由本项目数据校核的工程假设 | 只能显式标记并进入待验证层 |
| `PLATFORM_DEFAULT` | 经过官方、文献和当前模型一致性审查的通用值 | 是，但必须有审计记录 |
| `EXTERNAL_CASE` | 10 kW 台架、DQ60、旧标定或历史数据 | 否；显式案例开关才加载 |
| `PLACEHOLDER` | 尚无证据的占位参数 | 不得作为已验证结果使用 |

文献中的控制器性能指标、单一泵速、容腔体积和额定功率均属于 `LITERATURE`，不得因为数值看起来合理就上升为 `PLATFORM_DEFAULT`。

## 10. 未决问题

以下问题必须在进入 RouteA_v2 结构修改前收口：

1. 当前 RouteA 首个正式目标是被动压差回流，还是包含真实主动泵？二者是否需要同一模型内的 mode 配置；
2. 当前模型的水管理目标是气相湿度等效、凝结等效，还是实际液水分离和收集；
3. 低负荷高电位、普通性能、动态抗饥饿和冷启动是否分别拥有独立 runner case，而不是共享一个未分层的 profile；
4. `platform_default` 的 stack 规模、面积、温度和压力如何由官方案例与文献量级共同确定，10 kW 台架如何保持 `external_case` 边界；
5. 当前 `Source_Conditioner` 的每个物理端口究竟对应气体边界、混合点、测量量还是历史遗留接口；
6. 哪些电化学机制可以由官方 MEA 直接支撑，哪些只能作为 O2/RH/温度的系统级代理，不能过度解读为耐久性预测。

## 11. 参考资料与本地证据

### 11.1 直接论文

- [Cheng et al. 2014, DOI 10.1109/ITEC-AP.2014.6941250](https://doi.org/10.1109/ITEC-AP.2014.6941250)
- [Jiang et al. 2017, DOI 10.1016/j.ijhydene.2017.04.183](https://doi.org/10.1016/j.ijhydene.2017.04.183)
- [Zhang et al. 2020, DOI 10.1016/j.jpowsour.2020.228388](https://doi.org/10.1016/j.jpowsour.2020.228388)
- [Zhang et al. 2021, DOI 10.1016/j.renene.2020.10.105](https://doi.org/10.1016/j.renene.2020.10.105)
- [Liu et al. 2024, Fuel, DOI 10.1016/j.fuel.2023.129886](https://doi.org/10.1016/j.fuel.2023.129886)
- [Aggarwal et al. 2024, DOI 10.1016/j.ijhydene.2024.11.287](https://doi.org/10.1016/j.ijhydene.2024.11.287)
- [Liu et al. 2024, Journal of Power Sources, DOI 10.1016/j.jpowsour.2024.234165](https://doi.org/10.1016/j.jpowsour.2024.234165)
- [Liu et al. 2024, International Journal of Hydrogen Energy, DOI 10.1016/j.ijhydene.2024.02.254](https://doi.org/10.1016/j.ijhydene.2024.02.254)

### 11.2 补充论文

- [Kim and Kim 2012, DOI 10.1016/j.ijhydene.2011.11.103](https://doi.org/10.1016/j.ijhydene.2011.11.103)
- [Zhao et al. 2018, DOI 10.1016/j.ijhydene.2018.06.172](https://doi.org/10.1016/j.ijhydene.2018.06.172)
- [Becker et al. 2018, DOI 10.1002/fuce.201700219](https://doi.org/10.1002/fuce.201700219)
- [Rodosik et al. 2019, DOI 10.1016/j.ijhydene.2018.11.139](https://doi.org/10.1016/j.ijhydene.2018.11.139)
- [Liu et al. 2022, DOI 10.1016/j.ijhydene.2022.07.142](https://doi.org/10.1016/j.ijhydene.2022.07.142)
- [Applied Energy 2025, DOI 10.1016/j.apenergy.2025.126647](https://doi.org/10.1016/j.apenergy.2025.126647)

### 11.3 本地论文目录

- `00_支撑材料/03_cEGR阴极循环技术研究/`
- `00_支撑材料/02_PEMFC系统级建模与仿真/`

官方案例和当前模型的映射依据：

- `00_支撑材料/RouteA_材料池与模型候选比较_v01.md`
- `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`
- `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/03_审计与研究/RouteA_cEGR_PEMFC_Platform_current-audit_20260724_v01.md`
