# Route A cEGR-PEMFC 模型裁决与资产处置

文件类型：模型裁决记录（当前决策真源）  
日期：2026-07-29（cold-start-only 决策后更新；2026-08-14 架构边界更新）
适用范围：当前工作树内的官方 Gas Mixture PEMFC 资产、三个 Route A 模型版本、活动脚本、初态包和 v09 结果。

## 1. 裁决摘要

本项目继续采用 Route A 官方 Gas Mixture PEMFC 派生平台，但只保留一个活动系统模型和一个活动运行入口。当前唯一主模型为：

`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`

官方 MathWorks Gas Mixture PEMFC 示例和 `FuelCell_lib` 组件作为不可变参考内核；cEGR、BOP 接口、观测和平台脚本在该主模型上收敛。`RouteA_v2` 不继续作为第二条主线，而是作为当前收敛工作的隔离验证副本，只有经过读回、结构检查和最小仿真验证的局部脚本改进才允许回迁。`RouteA_before`、旧 Route B、旧台架模型和历史 runner 全部降级为证据或外部案例，不进入默认 MATLAB path、默认参数链或默认验收标准。

当前不裁决”继续增加功能”，而裁决”先恢复可解释、可初始化、可验证的最小 plant”。在 cold Voltage 收敛边界未收口前，不扩大 cEGR 控制、液水、整车接口或完整正式矩阵；Hydrogen Source runtime warning 已由最小物理连线修复收口。

**更新（2026-07-29）：** Source_Conditioner 已删除（恢复官方供气路径），S2 冷态 smoke、S3 稳态验证和当前拓扑 metadata 读回均已完成。此前生成并提升的 Current/Power/Voltage v10 formal bundle 现在降级为历史审计/对比资产；活动 panel 和正式 runner 固定使用 `cold_start_only`，不加载 `ModelOperatingPoint`。

### 当前初始化裁决

1. 活动 Route A 只允许 `simCase.initialState.mode="cold"`。
2. 活动输入装配显式设置 `LoadInitialState="off"`，所有 case 从模型默认冷态在逻辑 `t=0` 开始。
3. v10 bundle、其 topology hash 和 metadata 仍可用于 provenance 读回，但不能作为活动运行前置或默认参数真源。
4. 热启动 attach/generate helper 和 bundle 已移入 `99_历史归档/2026-07-29_RouteA_hot_start_retired/`；活动 contract 只读其 provenance，不得由 panel/runner 调用或加载。

## 2. 资产证据与版本关系

| 资产 | 当前角色 | 处置 | 依据 |
|---|---|---|---|
| 官方 `PEMFuelCellSystemWithACustomLibrary.slx` | 官方结构和组件参考 | 保留、只读对照 | Gas Mixture PEMFC 官方案例 |
| 活动 `RouteA_v01.slx` | 唯一候选主模型 | 保留并收敛 | 当前活动目录、现有 v09 runner 和结果均围绕此命名 |
| `RouteA_v2_v01.slx` | 隔离验证副本 | 不升格为第二主线 | 已有冷态 helper 和 M/Phi 观测改进，但没有正式 v2 初态包和结果 |
| `RouteA_before/.../RouteA_v01.slx` | 修改前快照 | 只读历史 | 与 `_git_provenance_7f20c7a` 快照一致，保留回溯证据 |
| v09 Current/Power/Voltage MAT | 历史回归证据 | 冻结、不外推 | 三组 `passed=true`，但不覆盖 v10 Source_Conditioner 和 v10 初态 |
| v2 legacy initial-state MAT | 兼容性材料 | 只读输入，禁止冒充正式初态 | 元数据仍指向旧模型名和 v09 schema |
| `00_支撑材料` 官方示例与 CEGR 文献 | 来源池 | 保留为来源，不直接覆盖默认值 | 见文献映射文件和参数 source metadata |

当前模型 hash、MATLAB/SATK 读回和 warning 数量随每次实施记录更新；本文件不把一次读回结果永久化为“已验证”。

## 3. 三个模型版本的裁决

### 3.1 活动 Route A v01：主线

保留其官方派生的 Stack/MEA、官方 FuelCell 气体和热组件、已形成的 cEGR 主气路、BOP 分层和观测接口。下一步只做以下范围内的修改：

1. 保持已完成的 Source_Conditioner 删除和端口处置证据，不在活动模型重新引入竞争边界；
2. 保持已恢复的单一且可追溯的新鲜空气/氢气边界，避免官方路径与独立物种质量源并联；
3. 将 cEGR 的目标拓扑固定为“阴极出口分离后气相边界 -> 回流/排放分流 -> 压降/阀/管路 -> 入口混合”，被动零流量为默认；分离效率和液水库存仍不属于当前默认模型，实际模型连接必须通过读回确认；
4. 将 Current、Power、Voltage 统一映射到一个内部 `I_cmd`，不复制 plant 拓扑；
5. 将参数、命令、初态和结果审计分层。

### 3.2 Route A v2：已归档的验证副本

**更新（2026-07-27）：** 随 S2/S3 验证完成，RouteA_v2 验证副本连同 RouteA_before 快照一并归档至 `99_历史归档/2026-07-27_RouteA_before_and_v2_archived/`。v2 不再作为活动资产或并行验证平台。

v2 允许承载冷态模式选择、局部 M/Phi 观测闭合和脚本兼容性实验，但必须满足以下条件才可回迁：

- 变更在 v2 上有明确目标、模型 read-back、`model_check` 和最小仿真证据；
- 变更不新增未定义的全局命令字段、不引入 Terminator 伪闭合、不改变官方组件的物理语义；
- 变更回迁到主模型后重新生成正式 v10 初态并重新跑 Gate 2；
- v2 不产生独立的正式结果品牌、独立参数真源或独立 runner。

若 v2 与主模型发生结构分叉，保留差异说明后立即停止并重新裁决，不允许两套模型并行”各自修复”。

### 3.3 `RouteA_before` 和其他旧路线：历史/外部案例

这些资产用于回溯、旧结果复核和 `external_case` 适用性研究。它们不应被复制回活动目录，也不能作为 Route A `platform_default` 的参数真源。需要复现实验时，必须建立显式外部案例配置、记录源文件和适用范围，并使用同一个主模型。

## 4. 物理和接口裁决

### 4.1 新鲜气体边界

官方 Oxygen/Hydrogen supply、compressor/reservoir、gas mixture 和 stack 路径是默认边界。阴极和阳极 `Source_Conditioner` 已从活动模型删除；其历史端口处置记录保留在已封闭实施记录中，不得作为当前活动拓扑读回。

裁决顺序为：先恢复官方供气路径的最小闭环；只有当某个 Source_Conditioner 的独立功能、端口责任、物料输入和初态均有明确证据时，才允许在一个受控边界内重新引入。默认不保留“官方供气 + 独立物种质量源”两套竞争真源。

### 4.2 cEGR

默认采用被动 cEGR 目标物理路径，真实回流量应由出口分离后气相边界、回流/排放分流、阻力/阀、管路和入口混合共同决定。`cegr_ratio_cmd` 只能作为目标或研究命令；它不是实际质量流量，也不能绕过压力差、阻力和混合器。每个用例必须以分流点 `r_split=m_return/(m_return+m_exhaust)` 为主回流率，同时报告空压机入口混合比例、相应湿/干基口径、入口 O2 分压和 RH；若当前结构尚未达到目标分离后分流，必须标记为代理状态。

### 4.3 电气边界

plant 内只保留一个 `I_cmd`。用户侧 Current/Power/Voltage 仅是命令适配器，均需通过限幅、单位转换和 anti-windup 进入同一电负载边界；三种输入不改变气路、热路或电堆拓扑。

### 4.4 参数和结果

`platform_default`、`scaling_rule`、`external_case`、`study_command` 和 `result_audit` 分层。历史台架 CSV、DQ60 map、10 kW workbook 和临时 profile 不得自动进入默认链。v09 结果只用于回归对照，不能证明当前 v10 结构或新初态已经通过。

## 5. 继续工作和停止条件

允许继续的工作：只读审计、文献映射、参数来源清单、warning ledger、官方结构对照、最小端口修复设计和小规模验证。

**更新（2026-07-29）：** S2/S3 已完成，S4 cold-only 首轮回归和 S5 首轮验证已形成证据，当前允许继续以下工作：
- 进入 S5 分层验证、正式 runner 的长时间 I/P/V 研究和 warning ledger 收口；
- 将 22 列 profile 收缩为结构体 case 配置；
- 收缩脚本入口为统一 runner 链；
- 仅在 S5 门槛和接口证据稳定后，进入 S6 cEGR 研究扩展。

必须停止并重新裁决的情况：

1. 需要再复制一个 `.slx` 或 runner 才能表达新工况；
2. 需要增加全局 command 字段才能绕过未闭合的物理边界；
3. 需要用 Terminator、未解释连接器或放宽 solver 来掩盖 DAE 初态失败；
4. 结构 warning 增加但没有逐条归类和 owner；
5. 新参数没有单位、来源、适用范围或唯一写入点。

## 6. 关联文件

- [当前资产审计](../03_审计与研究/RouteA_cEGR_PEMFC_Platform_current-audit_20260724_v01.md)
- [平台系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)
- [平台架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)
- [收敛实施路线图](RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)
- [平台实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)
- [平台测试计划](RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)
- [CEGR 文献研究与模型映射](../03_审计与研究/RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)
