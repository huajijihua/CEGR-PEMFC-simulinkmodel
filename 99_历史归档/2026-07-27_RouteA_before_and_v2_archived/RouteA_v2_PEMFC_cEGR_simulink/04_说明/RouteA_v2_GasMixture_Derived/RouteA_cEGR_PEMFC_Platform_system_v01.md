# RouteA cEGR-PEMFC Platform System Specification v01

文件类型：RouteA_v2 平台系统规格
日期：2026-07-24
状态：RouteA_v2 独立副本的目标与边界；当前 `.slx` 仍处于复制基线，未因本规格自动视为已验证。
副本范围：RouteA_v2 独立模型树；原 RouteA 只作为来源、对照和历史证据。
配套文档：[架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)、[实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)、[测试计划](RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)、[CEGR 文献研究与模型映射](RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)、[阶段执行记录](../RouteA_v2_Execution_Record/README.md)

本规格定义 RouteA_v2 要解决的问题、系统边界、接口、保真度和平台级验收目标。它不替代实施计划中的具体操作顺序，也不把文献中的研究结果直接写成平台默认参数或模型控制结构。

## 1. 平台目标

RouteA_v2 是一个面向系统尺度的阴极尾气循环 PEMFC 仿真平台，服务于：

1. 阴极尾气循环的流量、压力、组分、湿度、温度和水管理研究；
2. PEMFC 系统性能分析，包括电堆电压/功率、氧供给、气路压降、cEGR 比和热状态；
3. 新鲜空气供给、背压、加湿、cEGR、阳极回流/吹扫和热管理策略研究；
4. 后续参数扫描、控制器比较、局部高保真模型结果回灌和外部案例复现。

平台的首要目标不是承载尽可能多的命令字段，而是保持一个物理闭合、参数可追溯、运行入口稳定的 plant。新增设备或控制能力必须能说明：它解决哪个研究问题、对应哪个物理状态、来自哪类证据、如何被验证以及失败时如何退出。

## 2. 三方依据和不可替代关系

| 依据 | 在 RouteA_v2 中负责什么 | 不能替代什么 |
|---|---|---|
| MathWorks 官方 Gas Mixture/FuelCell 案例和库 | 气体域、MEA、物理组件语义、求解器和初始化参考 | 不直接定义 cEGR 研究问题和项目专用验收 |
| CEGR 文献 | 气路影响机制、控制目标、变量口径、研究工况、风险和 KPI | 不直接决定当前 RouteA 的块连接，也不把单篇论文参数变成默认值 |
| 当前 RouteA 现状 | 已完成的官方派生、cEGR 主气路、BOP、控制、runner、观测资产和失败证据 | 不因历史投入而豁免接口、初态和运行验证 |

RouteA_v2 采用证据保留式重构，不回退到官方案例从零重建，也不把当前 RouteA 整体推翻。具体保留/重构/暂缓决定写入实施记录。

## 3. cEGR 的物理定义和研究影响分层

cEGR 在模型中的物理本体是一个气路系统：

```text
阴极出口气体
    -> 分流
    -> 阀/泵/局部阻力等实际流量控制设备
    -> 管路/容腔
    -> 阴极入口混合
```

回流气体的物种组成、温度、压力和湿度必须由阴极出口物理网络产生。控制器可以接收上层 `cegr_ratio_cmd`、氧分压目标或电压目标，但只能把它们转换为阀开度、泵速、背压、旁路或其他真实执行器命令；不能直接写入 `mdot_cegr`，更不能直接写入回流组分。

氧稀释、自增湿、排水、低负荷高电位限制、动态饥饿、寄生功耗和冷启动是 cEGR 对系统的影响项、研究问题或验证 KPI。它们不自动构成新的 cEGR 物理控制模块；是否开放某个影响项取决于模型状态、设备边界和可验证证据。

## 4. 范围与非目标

### 4.1 当前范围

- 电堆/MEA、阳极气体域、阴极气体域和热端；
- 新鲜空气供给、阴极排气、阴极尾气到阴极入口的 cEGR 支路；
- 阳极氢源、减压、阳极回流和吹扫；
- 加湿、背压和基础热管理接口；
- 电堆端电流、电压和功率测量；
- 稳态、瞬态和策略研究所需的统一输入与观测接口；
- 结构、参数、初态、结果和失败分类的阶段性审计。

### 4.2 不在当前默认保真度内

- 产品级压缩机/泵地图、效率、轴功率、喘振和机械惯量；
- DCDC、母线、电池和整车能量管理；
- 未经可验证证据支持的全液水库存、液水输运、分离效率和冻结机理；
- 把 10 kW 台架、DQ60 map、旧 CSV、历史 workbook 或旧标定直接升格为默认参数；
- 为每种工况、负载或策略复制 `.slx` 和 runner；
- 将系统级 O2/RH/电压代理直接解读为耐久性或产品安全结论。

上述内容可以作为后续扩展或显式 `external_case`/专项配置，但不改变当前平台默认边界。

## 5. 预期使用场景

| 场景 | 主要输入 | 主要输出 | 目的 | 首次开放阶段 |
|---|---|---|---|---|
| Nominal steady | 电堆电流、空气供给、背压、基础湿度 | I/V/P、压力、组分、RH、温度 | 建立系统性能基线 | Phase 5 基础门 |
| cEGR zero/small | cEGR 拓扑保持，目标比为 0 或小幅命令 | 实际回流、O2、RH、压力和 I/V | 先验证物理方向和零循环语义 | Phase 1/5 |
| Low-load tradeoff | 阀/泵执行器或 O2/电压目标、低负荷 | `pO2`、RH、电压、实际回流、功耗 | 研究高电位限制与自增湿权衡 | Phase 5 首个策略用例 |
| Load transient | `I_cmd` 或用户侧 P/V 命令 | 电压、流量、压力、限幅、控制误差 | 研究动态响应和约束 | Phase 3/5 |
| High-load drainage | 空气/总流量、背压、回流配置 | 总流量、压差、液水/凝结、O2、功率 | 研究排水与氧供给冲突 | 后续专项 |
| Active cEGR | 泵速、阀、泵功耗和压差边界 | 实际回流、功耗、动态下冲 | 研究主动设备配置 | 后续专项 |
| Cold start/idling | 热边界、回流模式、水/冻结假设 | 热状态、液水、压力、净功率 | 概念性冷启动/怠速研究 | 后续专项 |
| External case replay | 显式案例包 | 可比 KPI 和边界审计 | 复现历史/台架数据 | 不进入默认链 |

## 6. 系统边界与接口

模型采用电堆为中心的 plant 边界。Simscape 物理网络负责气体、热和电堆动态；控制器通过明确的信号接口作用于 plant；脚本只负责参数装配、工况配置、仿真调度和结果审计。

### 6.1 `u`：主动控制输入

`u` 只包含模型可以主动施加的命令，不包含由物理网络响应得到的实际流量、压力或组分。

| 域 | 输入 | 单位 | 约束 |
|---|---|---:|---|
| Electrical | `I_cmd` | A | plant 的唯一内部负载接口 |
| User boundary | Current/Power/Voltage | A/W/V | 先经适配器转换为 `I_cmd` |
| Cathode supply | `air_flow_cmd` 或 `air_oer_cmd` | kg/s 或 - | 同一 study 只选择一种空气供给语义 |
| Cathode pressure | `p_ca_out_cmd` | MPa abs | 背压设定点，不宣称为独立出口压力 |
| Cathode humidity | `RH_ca_cmd` | 0..1 | 加湿器设定或旁路命令，不能替代实际 RH |
| cEGR | `cegr_ratio_cmd` 或 `cegr_valve_cmd` | - 或设备单位 | 同一配置明确 setpoint/actuator 语义 |
| Active cEGR | `cegr_pump_cmd` | pump-specific | 仅在主动泵配置开放 |
| Anode | `p_h2_cmd`、`T_h2_cmd`、`y_h2_cmd` | MPa abs、degC、- | 氢源或减压器边界 |
| Anode operation | `recirc_cmd`、`purge_cmd` | - | 回流和吹扫命令 |
| Thermal | `T_stack_cmd` 或冷却侧命令 | degC 或模型单位 | 只有热网络存在实际响应时开放 |

用户侧可以提供 Current、Power 或 Voltage 研究命令，但模型内部只保留一个 `I_cmd`。Power 使用 `P_ref / max(V_stack,V_floor)`；Voltage 使用明确的电压控制器；三者不构成三套 plant。

### 6.2 `w`：外部扰动和边界条件

`w` 包括环境压力/温度、入口组成、冷却环境、外部背压、初始负载扰动和未由控制器闭环的边界条件。`w` 不应以 `cmd` 命名，也不能在结果中被误认为主动执行器反馈。

### 6.3 `y`：控制器可见的测量量

`y` 只发布模型中实际存在传感器和转换器的量：电堆 I/V/P、温度、阴极/阳极入口和出口压力/温度/总质量流量/组分/RH、cEGR 实际流量和比例、阀/泵命令与限幅状态、吹扫状态及实际可观测的水分离输出。

### 6.4 `z`：真值和审计量

`z` 用于结果审计，不作为默认控制反馈，包括各物种质量流、库存变化、混合点前后组分、阀压差、热流、反应量、守恒残差和内部状态。没有对应日志或传感器的量不能写入 `y` 或报告为已验证 KPI。

### 6.5 cEGR 原始量和派生量

RouteA_v2 必须保留原始流量，不能只发布一个无定义的 EGR ratio：

```text
cegr_ratio_wet = abs(mdot_cegr) / max(abs(mdot_mix_in), epsilon)
cegr_to_fresh_ratio = abs(mdot_cegr) / max(abs(mdot_fresh), epsilon)
```

湿/干基口径必须注明水蒸气和液水是否纳入分母。至少记录 `mdot_fresh`、`mdot_cegr`、`mdot_mix_in`、`lambda_fresh`、`lambda_mix`、`pO2_ca_in`、`yO2_ca_in` 和 `RH_ca_in`。

## 7. 保真度等级

| 等级 | 用途 | 必须具备 | 当前定位 |
|---|---|---|---|
| L1 | 拓扑和接口 smoke | 官方块、端口闭合、最小求解 | 重置后的第一道门 |
| L2 | 系统尺度研究 | 四物种气体域、MEA、BOP 动态、cEGR 气路、热端和观测 | RouteA_v2 默认目标 |
| L3 | 局部机理/产品校核 | 可验证设备地图、液水/冻结状态、局部空间分布或实验标定 | 后续扩展，不阻塞 L2 |

RouteA_v2 不因未来需要 L3 就在当前 L2 中提前加入无法验证的设备细节。每个 BOP 模块必须标记为官方复用、L2 等效、待标定、专项配置或未开放。

## 8. 初始化、时间和结论边界

1. 冷态 nominal 是第一等价验证路径；热启动只是加速工具，不是冷态失败的替代证明；
2. 初态描述 plant 的结构兼容性和已声明的基准工作点，不锁定后续研究的 I/P/V、cEGR、空气、压力、湿度或热命令；
3. `StartTime`、solver、容差、`MaxStep`、初态类型、快照绝对时间和逻辑研究时间必须写入 case metadata；
4. 当前 v2 的 77 个 `model_check` warning 和旧 RouteA 的 `NE_DAE_IC_Failure` 只属于已知基线/失败证据，不能写成平台通过；
5. v09 formal 结果只能证明旧结构的历史 case，不能证明 v2 结构、v10 初态或新参数链。

## 9. 平台级验收目标

RouteA_v2 只有在以下条件全部满足后，才可称为可用的通用系统模型：

1. 只有一个当前系统 `.slx`，其自然容器与电堆、阴极、阳极、热、电负载、控制和观测职责一致；
2. 活动物理端口闭合，update/compile 通过，剩余 warning 已分类并有责任边界；
3. `platform_default` 可独立初始化，冷态 nominal smoke 通过；
4. I/P/V 不改变物理拓扑，只改变负载命令或控制器行为；
5. cEGR 的目标值、实际值、分母、方向和零循环语义明确，物种和质量流可审计；
6. 稳态、瞬态、失败分类和结果保存遵循同一个 runner 契约；
7. 至少完成低负荷、额定附近和高负荷代表性 case 的 agent 端到端验证后，才允许交接大规模矩阵；
8. 每个阶段的真实执行证据都已写入 [RouteA_v2_Execution_Record](../RouteA_v2_Execution_Record/README.md)。

## 10. 文档责任边界

- [架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)：定义自然边界、目标容器、气路和端口语义；
- [实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)：定义阶段顺序、执行步骤、准入/出口/暂停条件；
- [测试计划](RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)：定义 Gate、case、KPI、数值门和失败分类；
- [CEGR 文献研究与模型映射](RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)：定义证据、机制、变量口径和可迁移边界；
- [阶段执行记录](../RouteA_v2_Execution_Record/README.md)：只记录已发生的盘点、修改、验证、结果和未决项。
