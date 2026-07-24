# RouteA cEGR-PEMFC Platform Test Plan v01

文件类型：RouteA_v2 平台验证计划
日期：2026-07-24
副本范围：RouteA_v2 独立模型树；结果、失败栈和执行记录写入 v2，不回写 RouteA。
前置文档：[系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)、[架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)、[实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)、[CEGR 文献研究与模型映射](RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)
记录入口：[RouteA_v2_Execution_Record](../RouteA_v2_Execution_Record/README.md)；结果入口：`../../05_结果/`

本计划定义测试对象、分层顺序、case、KPI、数值门和失败分类。它不把测试计划写成执行结果；每次真实执行必须在阶段记录中写明模型版本、参数、输入、solver、输出和证据路径。

## 1. 验证原则

验证分为三层：

1. **子系统开环**：验证供气、背压、cEGR 分流/混合、阳极回流/吹扫、热端和电负载边界；
2. **整机开环**：验证冷态、稳态、零/小幅 cEGR、额定和高负载代表性 case；
3. **闭环策略**：验证低负荷高电位/O2 分压、自增湿、高负荷排水、动态饥饿、主动泵功耗和冷启动等明确场景。

结构、数值求解、物理 KPI、控制性能和结果审计是不同证据类型，不能相互替代。`model_check`、Code Analyzer、update/compile 和脚本装配无报错，都不能单独证明仿真通过。

每个测试至少记录：模型 hash、模型根名称、脚本版本、参数层、case 输入、单位、solver/容差/MaxStep、初态类型、MATLAB/Simulink 版本、输出文件、运行时间、warning/error 分类、KPI 和结论。

## 2. Gate 0：来源、资产和工作树

| 检查 | 通过条件 | 证据 |
|---|---|---|
| 官方母版 | 当前 v2 模型可追溯到 Gas Mixture PEMFC 官方资产 | 来源映射和模型 read-back |
| 库复用 | 适用组件优先来自 `FuelCell_lib`，自定义块有理由和来源 | 架构/Phase 0 记录 |
| 参数层 | 默认链不读取旧台架 CSV、DQ60 map 或历史 workbook | 参数扫描和入口审计 |
| 工作树 | v2 有唯一活动 `.slx`；RouteA 原目录不作为 v2 写入目标 | 路径清单和 hash |
| 单位 | 物理参数、控制输入和输出 KPI 有单位、范围和 source metadata | 参数表 |
| 历史证据 | v09/v10 结果明确标记为历史或失败证据 | 记录 metadata |

Gate 0 未通过时，只允许资产盘点、路径核对、文档和记录维护，不允许结构扩展。

## 3. Gate 0.5：CEGR 文献证据和研究口径

在任何 RouteA_v2 结构修改或正式矩阵前，必须完成：

- 8 篇本地直接 CEGR 文献有逐篇证据状态、对象范围、变量定义、执行器、机制、限制和不可迁移参数；
- 官方案例、文献和当前 RouteA 的责任边界没有互相替代；
- 当前 CEGR/BOP/控制模块均有 `PRESERVE`、`REFACTOR`、`DEFER` 或 `HISTORICAL` 处置标签；
- cEGR 物理链固定为阴极出口分流 -> 实际阀/泵/阻力设备 -> 入口混合；回流组分来自出口网络；
- 首个研究用例、执行器配置和主动/被动模式已经固定；
- `mdot_fresh`、`mdot_cegr`、`mdot_mix_in`、湿/干基回流比、`lambda_fresh`、`lambda_mix`、`pO2_ca_in` 和 `RH_ca_in` 的定义已固定；
- 每个首个用例 KPI 都能追溯到论文机制、官方组件或当前模型证据；
- 文献参数没有适用范围时，不得进入 `platform_default`。

Gate 0.5 未通过时，只允许文献精读、接口表、模块分类和失败证据整理，不允许以增加块、端口或 command 字段推进模型。

## 4. Gate 1：结构和接口闭合

### 4.1 子系统检查

对 `Stack_Core`、`Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Anode_Hydrogen_BOP`、`Thermal_Management_BOP`、`System_Control_Observability`、`cEGR_Mode_Selector` 及 Phase 0 记录标出的 Source_Conditioner 分别执行：

- `model_read` 读回接口、连接、源块、汇块和关键 mask 参数；
- `model_check` 的 `unconnected_ports`、`unconnected_lines` 和 Stateflow lint；
- MATLAB/Simulink update/compile；
- 关键 block 参数的单位、数值、来源和写入点 read-back；
- 与该子系统职责对应的最小开环 smoke。

活动物理端口不能靠 Terminator、无语义连接器或脚本占位掩盖。合法边界端口必须在架构和 warning ledger 中列出；实际缺失连接属于阻断项。

### 4.2 cEGR 物理闭合检查

必须检查：

- 阴极出口确实存在分流、排气和回流两条因果支路；
- `mdot_cegr`、回流组分、温度和压力来自出口物理网络；
- 阀/泵/阻力设备是实际流量控制对象；
- 入口混合点的总流量和物种闭合可读回；
- `cegr_ratio=0` 是保留 cEGR 拓扑的零循环对照，而不是复制一个无 cEGR plant；
- 被动与主动配置不在同一 case 中混用，也不借同一个命令字段隐藏泵功耗或压力边界。

### 4.3 负载接口检查

Current、Power、Voltage 三种用户侧输入必须映射到同一内部 `I_cmd`，且不改变气路/热路/电堆物理拓扑。检查：

- 输入单位和非法值拒绝；
- `V_floor`、电流限幅和 anti-windup；
- P/V 命令变化时的 `I_cmd`、实际 I/V/P 和功率误差；
- 一个 study 不混合三种用户侧边界类型；
- 三种输入的模型结构摘要或 checksum 相同。

## 5. Gate 2：冷态、初态和数值稳定性

当前 v2 复制基线已知有 `model_check` warning 和未完成的冷态验证；本表是待执行判据，不是当前通过声明。

| Case | 设定 | 最小通过条件 |
|---|---|---|
| `cold_idle` | 默认气源、最小非零负载、cEGR=0 | 初始条件求解成功，1 s 仿真无 DAE failure |
| `cold_nominal_current` | 默认平台负载、官方气路 | 10 s 仿真完成，I/V/P、压力、温度和组分有限 |
| `cold_cegr_zero` | cEGR 拓扑启用、目标比为 0 | 实际比接近零，物理路径闭合，无未分类 warning |
| `cold_cegr_small` | 小幅 cEGR 目标 | 阀压差、回流量、混合组分和控制误差有物理响应 |
| `hot_start_reference` | canonical hot-start operating point | 仅作为加速对照，不能替代 cold case |

通过 Gate 2 前，不允许交接长时间矩阵。编译通过、静态检查通过、profile 装配通过或读取旧 hot-start MAT，都不算冷态验证。

## 6. Gate 3：系统性能和守恒

稳态默认使用明确的尾窗统计；尾窗必须位于无吹扫或已说明吹扫相位的区间。至少报告平均值、跨度和标准差，不能只报告最后一个采样点。

### 6.1 必须观察的 KPI

- 电堆 I、V、P、温度和电流密度；
- 阴极/阳极入口和出口压力、温度、总流量和组分；
- `lambda_fresh`、`lambda_mix`、`pO2_ca_in`、湿/干基 `cegr_ratio`、阀/泵命令和压差；
- 阴极/阳极 RH、气相水和实际可观测的冷凝/分离输出；
- 控制跟踪误差、限幅比例、吹扫事件和 solver warning；
- 可观测质量、物种和能量残差；
- 主动泵配置下的寄生功耗和净功率影响。

### 6.2 初始数值门

1. 所有被报告 KPI 必须有限、单位正确、采样和后处理方式明确；
2. 可观测关键量在稳态尾窗的两个半窗相对变化默认不超过 `0.5%`；不能观测的内部状态不得套用该门；
3. cEGR 实际比误差采用 `max(1e-4, 0.01*max(target,1e-3))` 作为初始工程门，最终值须由代表性 case 和控制器带宽复核；
4. 质量/物种/能量闭合按可观测边界定义，初始目标为 `1%` 以内；缺少必要观测时标记为 `not observable`，不得伪造通过；
5. 趋势方向必须与所引用文献的适用范围一致，但趋势一致不能替代量化验证。

## 7. Gate 4：动态和策略

至少覆盖：

- 低到额定负载 step/ramp；
- cEGR 0 -> small -> nominal 的变化；
- 空气供给和背压扰动；
- 湿度和温度设定变化；
- 阳极 purge 事件及其对电压/库存的影响；
- Current、Power、Voltage 用户侧边界的一致 plant 响应；
- 首个低负荷 O2 分压/湿度权衡用例。

动态测试不强制稳态尾窗门，但必须保留完整时序并检查命令、响应、限幅、NaN/Inf、守恒、压力冲击和失败分类。高负荷排水、动态饥饿、主动泵功耗和冷启动只有在对应水/热/设备状态显式存在时才能报告为结果，否则标为未开放或概念假设。

## 8. 回归、矩阵和结果交接门

建议建立以下 `model_test`/MATLAB 测试场景：

| 场景名 | 目的 | 最低前置 |
|---|---|---|
| `PlatformStructure` | 结构、官方块、端口和模型设置 | Gate 1 |
| `ColdStartNominal` | 冷态初始条件和短仿真 | Gate 1 |
| `ElectricalLoadCanonicalization` | I/P/V 到 `I_cmd` 的一致性 | Gate 1 |
| `CegrMassSpeciesClosure` | cEGR 方向、比例和物种守恒 | Gate 1/3 |
| `CathodeBackpressureResponse` | 背压设定和压力链响应 | Gate 2 |
| `AnodePurgeResponse` | N2 库存、吹扫和电压扰动 | Gate 2 |
| `ThermalResponse` | 温度控制和热流响应 | Gate 2/3 |
| `NumericalRobustness` | solver、MaxStep 和初态敏感性 | Gate 2 |
| `CegrLowLoadTradeoff` | 低负荷 O2/RH/电位权衡 | Gate 3/4 |

正式矩阵只能在至少一个低负荷、一个额定附近和一个高负荷代表性 case 由 agent 用同一模型、参数链和 solver 完成端到端验证后执行。矩阵结果必须保存紧凑摘要、失败栈、模型 hash、参数来源和运行 metadata；不能以清理 `slprj/`、`.slxc` 或运行缓存作为验证前置条件。

## 9. 失败分类和拒止规则

每个失败至少归入以下一类，并保留最小复现输入：

| 类别 | 例子 | 处置 |
|---|---|---|
| `STRUCTURE` | 未连接物理端口、非法连接、缺少设备边界 | 阻断结构阶段 |
| `INITIALIZATION` | `NE_DAE_IC_Failure`、不可满足初态 | 阻断 Gate 2，先修初态/边界 |
| `NUMERICAL` | solver divergence、步长问题、NaN/Inf | 记录 solver 和状态，不能静默放宽 |
| `PHYSICAL` | 物种/质量/能量不闭合、方向错误 | 阻断性能结论 |
| `CONTROL` | 饱和、跟踪失败、错误反馈或目标口径混用 | 只能作为策略失败，不能写成 plant 通过 |
| `OBSERVABILITY` | 需要的量未测量或未记录 | 标记 `not observable` |
| `CONFIGURATION` | 参数层、路径、case 或版本错误 | 重装配后重跑最小 case |

不能把失败 case 从矩阵中静默删除，也不能用旧版本结果替代当前 v2 失败证据。

## 10. 执行记录要求

每个 Gate 的实际执行都必须在 [RouteA_v2_Execution_Record](../RouteA_v2_Execution_Record/README.md) 更新对应阶段记录。记录中必须逐项回答：测试对象是什么、输入和参数是什么、实际运行了吗、读回证据在哪里、通过/失败/未观测的判定是什么、下一步是否被阻断。
