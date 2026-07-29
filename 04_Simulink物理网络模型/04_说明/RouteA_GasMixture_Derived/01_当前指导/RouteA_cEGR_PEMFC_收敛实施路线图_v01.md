# Route A cEGR-PEMFC 收敛实施路线图

文件类型：后续实施、模型收敛和验证路线图  
日期：2026-07-29（cold-start-only 决策后更新）
决策前置：[模型裁决与资产处置](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)

## 1. 总目标

在不重建官方案例、不复制第三套模型、不把 v09 结果冒充 v10 证明的前提下，把当前 Route A 收敛为一个可初始化、可解释、可审计的 L2 PEMFC-cEGR 系统平台。研究目标按"先物理闭合，再参数/控制，再性能矩阵，再机理扩展"推进。

本路线的活动主线只有：

- 一个主模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；
- 一个正式运行入口：统一 `SimulationInput`/`sim` 调度器；
- 一个主平台默认参数层：`platform_default`；
- 一个明确隔离的外部案例层：`external_case`；
- 一套分层验证证据：结构、初始化、短仿真、KPI、守恒和回归。

## 2. 阶段总表

| 阶段 | 核心任务 | 状态 | 必须产物 | 出口门 |
|---|---|---|---|---|
| S0 决策冻结 | 固定模型、接口和资产处置 | ✅ 已完成 | 裁决记录、参数清单、warning ledger | 用户确认本路线；不再新增模型副本 |
| S1 物理边界收敛 | 关闭真实未连接端口，恢复单一供气边界 | ✅ 已完成 | 端口处置表、模型 read-back、结构检查记录 | Source_Conditioner 不再有未解释真实端口；结构 warning 可分类 |
| S2 最小 plant | 保留官方 stack/BOP，缩小 cEGR 到最小可验证路径 | ✅ 已完成 | 最小闭环模型记录、hash、compile/update 证据 | 无 DAE 初态失败的短 smoke |
| S3 参数和控制收敛 | 参数分层、单一 I_cmd、统一 case 装配 | ✅ 已完成 | 参数 API、case schema、兼容适配器 | Current/Power/Voltage 同一拓扑可装配 |
| S4 初态和数值收敛 | 冷态基线、求解器和边界敏感性 | ✅ 完成，Current/Power 严格通过，Voltage purge 周期响应已分类 | cold-start-only 合同、I/P/V 3600 s 结果、控制耦合诊断 | 电压跟踪、供气安全和周期响应门明确 |
| S5 分层验证 | 子系统、整机、策略和回归 | 部分完成，P0 I/P/V 3600 s 已通过，Hydrogen runtime warning 已关闭，77 条 warning ledger 已形成 | 紧凑 KPI、失败栈、warning ledger、首轮矩阵记录 | 600 s/面板/完整矩阵收口后再开放研究扩展 |
| S6 CEGR 研究扩展 | 扫描回流比、背压、湿度、负载和控制策略 | ⏳ 待推进 | 文献映射结果、敏感性/策略报告 | 每项扩展不改变平台边界和证据链 |

## 3. S0：决策冻结 — 已完成

### 工作内容

1. 以[模型裁决记录](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)为唯一模型版本决定；
2. 冻结 `u/w/y/z`、单位、符号、采样和单一 `I_cmd` 接口；
3. 为每个当前 block、脚本、MAT 和说明标记 `PRESERVE`、`REFACTOR`、`DEFER` 或 `HISTORICAL`；
4. 建立 warning ledger，至少包含路径、端口/警告、物理责任、处置方式、验证证据和 owner；
5. 建立参数表，记录名称、单位、来源、适用范围、写入点和默认/外部案例属性。

### 禁止事项

不改 `.slx` 结构、不生成正式矩阵、不迁移 v09 结果、不把 v2 hash 或旧初态名称写成当前事实。

### 出口条件

主模型、官方参考、v2 副本和历史资产的职责没有歧义；任何新结构请求都能判断为主线、实验或归档。

## 4. S1：物理边界收敛 — 已完成

### 4.1 阴极供气

已删除 `Cathode_Source_Conditioner`，恢复官方 Air Intake (Reservoir FC) → CompressorInletMixer 的单一气体边界。22 列 profile 的组分相关 Goto 信号链保留，From 块被 Terminator 吸收。

### 4.2 阳极供气与排气

保留官方 Hydrogen/Fuel Tank/PRV/Anode Exhaust 语义。`Anode_Source_Conditioner` 已删除，恢复 v09/官方示例的简单架构。

### 4.3 cEGR 主路径

保留一条出口分流到入口混合的 cEGR 路径：出口 chamber → 分流 → 阻力/阀 → EGR pipe → cathode mixer。默认阀关闭或零目标时实际回流量接近零；小目标 case 已通过验证产生有方向、可解释的压力和组分变化。

### S1 出口

- `model_read` 能读回每个保留端口和连接；
- `model_check` warning 已分类，不再把真实未连接端口藏在 wrapper 中；
- update/compile 通过；
- 未引入 Terminator（仅信号链 From 块被吸收，非物理端口）、人工质量源或 solver 放宽；
- 记录修改前后模型 hash 和差异说明。

## 5. S2：最小 plant 与冷态可解性 — 已完成

此阶段只保留官方 stack/MEA、官方气路、最小 cEGR 支路、热边界和一个电负载边界。

### 最小 smoke 结果

| Case | 时长 | 设定 | 结果 |
|---|---|---|---|
| cold_idle | 1s | 5A, cEGR=0 | ✅ PASSED |
| cold_nominal_current | 10s | 100A, cEGR=0 | ✅ PASSED |
| cold_cegr_zero | 10s | 100A, cEGR=0 | ✅ PASSED |
| cold_cegr_small | 10s | 100A, cEGR=0.1 | ✅ PASSED |

全部通过，无 DAE IC Failure。详情见[实施记录](../02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260727_S2冷态smoke与Source_Conditioner处置_v01.md)。

## 6. S3：参数与控制收敛 — 已完成

### 完成内容

1. **恒电流 + cEGR 稳态验证**：6 个工况（5A~392A × cEGR=0），全部通过，电压偏差 < 0.05%
2. **恒电流 + cEGR 回流比验证**：4 个工况（100A/336A × cEGR=0.1/0.3），全部通过
3. **恒功率模式验证**：6 个工况（40kW/120kW × cEGR=0/0.1/0.3），全部通过，功率误差 0.00%
4. **恒电压模式验证**：6 个工况（410V/375V × cEGR=0/0.1/0.3），全部通过，电压误差 < 0.11%
5. **入口组分控制**：6 个组分工况（O2=15-21%, H2O=0.5-3.0%），全部通过

### 验证证据

所有验证使用 60s 斜坡、600s 总仿真、540-600s 尾窗统计。Current/Power/Voltage 三种模式在同一个 `.slx` 拓扑内切换，不复制模型。

### 已知限制

- v09 初始状态和 v10 I/P/V bundle 均冻结为历史审计/回归材料；当前活动 runner 不加载 operating point
- 22 列 profile 的 O2/H2O 字段被 Terminator 吸收，不参与 Air Intake 控制
- H2O > 0.04 可能触发 DAE IC Failure

## 7. S4：初态与数值收敛 — cold-only 回归完成，Voltage purge 周期响应已分类

冷态模式现在是活动 Route A 的唯一初始化路径。此前生成并提升的 v10 Current/Power/Voltage bundle 仅保留为历史审计/对比资产，不拥有活动场景命令，也不再作为 runner 前置。

实际出口证据：

- 模型名和拓扑 hash 与当前主模型一致；
- `platform_default`/`external_case` 标识正确；
- 初态不携带场景命令、cEGR 目标或功率/电压控制语义；
- 活动 runner 固定 `initializationPolicy="cold_start_only"`，并显式设置 `LoadInitialState="off"`；
- v10 bundle 仍可被 contract 读回用于 provenance 审计，但不会被活动 panel/runner 加载；
- cold Current 10 s smoke 已通过，600 s Current/Power/Voltage cold 回归作为本轮出口证据。

S4 的 cold-only 回归已在同一输入契约下完成：Current/Power 3600 s 通过；purge-disabled Voltage 严格通过；purge-enabled Voltage 的电压跟踪、气相、温度和空气侧非周期信号通过，Current/Power/derived O2 stoich 被识别为阳极 purge 周期响应，并按专门门接受。当前 `model_check(all)` 仍为 `77` 条 warning、无 error；`unconnected_lines` 专项检查 healthy，77 条结构 warning 已逐条形成 [warning ledger](../03_审计与研究/RouteA_cEGR_PEMFC_model_check_warning_ledger_20260729_v01.md)，Hydrogen Source 运行时 dangling-line warning 已通过最小物理连线修复关闭。Power/Voltage 历史 hot 结果只作对比，不替代 cold 结果。

## 8. S5：验证和正式矩阵准入 — P0 3600 s 收口，P1 条件准入，矩阵专项待收口

验证继续按"结构 -> 子系统开环 -> 整机开环 -> 闭环策略 -> 回归矩阵"顺序。既有 Gate 4 和 hot-start 矩阵只作为历史证据；当前活动验收改以 cold-start-only 的 I/P/V 600/3600 s case、面板矩阵和 warning ledger 为准。Voltage 的 purge 周期响应门已落地并在正式 P0 回归中通过；Hydrogen Source runtime warning 已关闭，600 s/面板/完整 cold 矩阵仍待处理，因此 S5 尚未整体标记完成。

正式矩阵的每个结果必须包含紧凑摘要、模型 hash、参数层、case schema、solver、cold 初始化策略、KPI、warning/error 分类和失败栈路径。当前历史结果见[ S5 实施记录 ](../02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260728_S5分层验证与正式矩阵首轮_v01.md)；v09/v10 hot 结果只做历史回归对照，不与 cold 结果混写。

### 8.1 P1 实施准入结论（2026-07-29）

当前允许进入 P1，但结论是“P1 面板基础版实施准入”，不是“P1 已完成”或“S5 全部收口”。准入依据如下：

- P0 依赖检查、model contract、cold-start-only 输入契约和观测注册链通过；
- 10 s smoke 通过，正式 Current/Power/Voltage 3600 s P0 回归 `overall=1`；
- Hydrogen Source dangling-line runtime warning 已关闭，修复后 Hydrogen Source 12/12 条内部线均已连接；
- 现有 `RouteA_Panel_v01`、panel SimulationInput 装配、结果提取和 panel matrix helper 已可作为 P1 基础。

P1 的实施边界固定为：完善现有面板的电边界、阴极进气、温度和气相/水管理结果闭环，复用统一 runner、参数注册表、观测注册表和结果契约；不新增未经批准的物理块，不把 inventory/unresolved 参数直接开放为 UI 控件，不以 UI 控件掩盖模型或观测缺口。

P1 的验收前置仍保留以下未决项：cold 600 s I/P/V 和面板 `cEGR=0/0.3` 矩阵的稳态判定、完整 cold 矩阵、阳极/冷却未解析观测量，以及 L2 液水库存/输运/排液/分离效率闭合。每个 P1 功能必须经过单工况 smoke、基线回归、最小矩阵和实施记录后才能标记完成。

## 9. S6：CEGR 研究扩展顺序 — 待推进

研究扩展按以下最小风险顺序推进：

1. cEGR=0 与小回流：确认方向、物种和水分变化；
2. 低负载稳态：研究自湿化、氧稀释和排水风险；
3. 额定附近稳态：研究高流量、背压和辅机功耗；
4. 负载 step/ramp：研究控制跟踪和瞬态氧贫化；
5. purge、湿度、温度和背压扰动；
6. 仅在前述证据稳定后，增加策略比较或局部 COMSOL/AMESim 校核。

每个扩展都必须回到同一个 `u/w/y/z` 接口和同一 plant；文献中的影响机制是 KPI/假设来源，不自动转化为新的物理模块。

## 10. 交付物与记录规则

每阶段至少保留：变更说明、模型 hash、read-back 摘要、`model_check` 分类、最小运行结果、未解决风险和下一阶段准入结论。保留 `slprj/`、`.slxc` 和运行缓存，不把缓存清理作为验证动作；无确切用途的临时截图、CSV 或模型副本不新增。

本路线的低层细节见[平台实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)，测试场景和门槛见[平台测试计划](RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)。
