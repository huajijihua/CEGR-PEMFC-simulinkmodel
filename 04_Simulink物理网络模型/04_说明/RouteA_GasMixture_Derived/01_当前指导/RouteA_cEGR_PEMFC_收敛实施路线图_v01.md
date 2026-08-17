# Route A cEGR-PEMFC 收敛实施路线图

文件类型：后续实施、模型收敛和验证路线图  
日期：2026-07-29（cold-start-only 决策后更新；2026-08-14 架构总规划更新）
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
| S5 分层验证 | 子系统、整机、策略和回归 | 部分完成，P0 I/P/V 3600 s 已通过，Hydrogen runtime warning 已关闭，77 条 warning ledger 已形成；P1 面板独立单工况闭环实施中 | 紧凑 KPI、失败栈、warning ledger、P1 独立工况记录 | P1 600 s/面板独立代表性工况收口后，由联合评审决定是否开放研究扩展 |
| S6 CEGR 研究扩展 | 先冻结工程化架构决策轴，再按单一决策轴建立聚焦配置和场景矩阵 | ⏳ 架构总规划已建立，基线收敛待执行 | 架构配置登记、官方组件审计、统一 KPI、对照配置和风险报告 | 每项扩展不改变平台边界、官方模块原则和证据链 |

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

验证继续按"结构 -> 子系统开环 -> 整机开环 -> 闭环策略 -> 独立代表性工况"顺序。既有 Gate 4 和 hot-start 矩阵只作为历史证据；P1 面板验证不以工况矩阵为前置，先对每个面板功能运行一个独立代表性 case。Voltage 的 purge 周期响应门已落地并在正式 P0 回归中通过；Hydrogen Source runtime warning 已关闭，完整研究矩阵留到模型和面板完成后的研究阶段。

正式矩阵的每个结果必须包含紧凑摘要、模型 hash、参数层、case schema、solver、cold 初始化策略、KPI、warning/error 分类和失败栈路径。当前历史结果见[ S5 实施记录 ](../02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260728_S5分层验证与正式矩阵首轮_v01.md)；v09/v10 hot 结果只做历史回归对照，不与 cold 结果混写。

### 8.1 P1 实施准入结论（2026-07-29）

当前允许进入 P1，但结论是“P1 面板基础版实施准入”，不是“P1 已完成”或“S5 全部收口”。准入依据如下：

- P0 依赖检查、model contract、cold-start-only 输入契约和观测注册链通过；
- 10 s smoke 通过，正式 Current/Power/Voltage 3600 s P0 回归 `overall=1`；
- Hydrogen Source dangling-line runtime warning 已关闭，修复后 Hydrogen Source 12/12 条内部线均已连接；
- 现有 `RouteA_Panel_v01`、panel SimulationInput 装配、结果提取和 panel matrix helper 已可作为 P1 基础。

P1 的实施边界固定为：完善现有面板的电边界、阴极进气、温度和气相/水管理结果闭环，复用统一 runner、参数注册表、观测注册表和结果契约；不新增未经批准的物理块，不把 inventory/unresolved 参数直接开放为 UI 控件，不以 UI 控件掩盖模型或观测缺口。

P1 的验收前置仍保留以下未决项：cold 600 s I/P/V 的稳态判定、阳极/冷却未解析观测量，以及 L2 液水库存/输运/排液/分离效率闭合。每个 P1 功能只需先完成一个独立代表性单工况 smoke、必要的基线回归和实施记录；工况矩阵、策略扫描和参数研究不属于 P1。

### 8.2 P1 具体实施计划（2026-07-29）

P0 只完成迁移、接口、注册表和运行契约准备；从 P1 开始进入面板-模型双向迭代主线。P1 的具体执行、范围裁决和出口门统一以 [P1 完整燃料电池系统面板基础版实施计划](RouteA_cEGR_PEMFC_P1_完整燃料电池系统面板基础版实施计划_v01.md) 为准，不再用本路线图中的概述条目替代阶段实施计划。

P1 工作包顺序固定为：

1. `P1-W0`：冻结面板能力矩阵、参数暴露级别、观测量和结果 contract；
2. `P1-W1`：建立按系统域组织的单一 `.m` 面板壳，基础/高级只作为局部显隐；
3. `P1-W2`：完成电边界、电堆和阴极空气控制闭环；
4. `P1-W3`：完成温度控制、加湿/RH 和当前可观测水状态闭环，保留液水 L2 缺口；
5. `P1-W4`：以目标比例闭环作为 cEGR 唯一主输入，补齐实际比例、阀和能力诊断；
6. `P1-W5`：建立精简/完整版结果分级和各功能独立单工况验证入口；
7. `P1-W6`：完成独立单工况 smoke、基线回归、结果审计、实施记录和联合评审。

P1 的基础系统优先级高于 cEGR 研究扩展；P1 不提前开放直接阀面积主控、全设备参数、阳极/冷却完整结果或最终迁移输出包。遇到阻塞时先检查面板 `.m`、统一 runner、参数/观测注册和输入契约，再判断是否为模型 bug；确需模型修复时只做最小修改，并完成 read-back、结构检查和独立单工况验证。未通过参数、观测和结果门的 UI 需求不得用新增控件掩盖缺口。

## 9. S6：CEGR 研究扩展顺序 — 受架构总规划约束

在工程化架构总规划的 Gate 0--Gate 3 通过前，不新增主动泵、自增湿或真实液水设备模型。基线和对照研究按以下最小风险顺序推进：

1. cEGR=0 与小回流：确认方向、物种和水分变化；
2. 低负载稳态：研究自湿化、氧稀释和排水风险；
3. 额定附近稳态：研究高流量、背压和辅机功耗；
4. 负载 step/ramp：研究控制跟踪和瞬态氧贫化；
5. purge、湿度、温度和背压扰动；
6. 仅在前述证据稳定后，增加策略比较或局部 COMSOL/AMESim 校核。

每个扩展都必须回到同一个 `u/w/y/z` 接口和同一聚焦平台；文献中的影响机制是 KPI/假设来源，不自动转化为新的物理模块。架构决策轴、当前基线、官方模块优先原则和 P0--P8 出口门见[工程化架构决策与聚焦模型总体规划](RouteA_cEGR_PEMFC_工程化架构决策与聚焦模型总体规划_v01.md)。

### 9.1 P1 之后的阶段计划门禁与顺延

P2、P3、P4、P5、P6 进入实施前，必须在 `01_当前指导/` 新增对应的具体实施计划文件。当前 P2 已切换为面板修复和操作性提升；原 cEGR 研究、阳极/冷却、全设备参数和迁移交付工作整体顺延为 P3-P6。计划至少要写清楚面板系统域、参数/观测/模型接口、结果输出、工作包、验证证据、出口门、未解析能力和与[面板-模型双向迭代规划](RouteA_cEGR_PEMFC_面板-模型双向迭代规划_v01.md)第 5 至第 10 节的逐项映射。没有阶段计划时，不得直接开展该阶段的结构或面板功能实施。

### 9.2 P2 当前实施入口

P2 当前实施计划为 [RouteA_cEGR_PEMFC_P2_面板修复和操作性提升实施计划](RouteA_cEGR_PEMFC_P2_面板修复和操作性提升实施计划_v01.md)。P2 不重复历史仿真，不修改正式 `.slx`，优先处理两栏布局、基础/高级/系统模型参数/帮助四层、单位和 RH 温度语义、高级参数分组、结果图像历史和操作反馈。P2 的开发期证据以 UI read-back 和代码检查为主，模型运行由用户保持打开的最新面板直接触发。

## 10. 交付物与记录规则

每阶段至少保留：变更说明、模型 hash、read-back 摘要、`model_check` 分类、最小运行结果、未解决风险和下一阶段准入结论。保留 `slprj/`、`.slxc` 和运行缓存，不把缓存清理作为验证动作；无确切用途的临时截图、CSV 或模型副本不新增。

本路线的低层细节见[平台实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)，测试场景和门槛见[平台测试计划](RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)。
