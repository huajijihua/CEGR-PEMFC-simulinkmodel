# R00 Core Documentation Review

记录编号：`R00_document_review_20260724_v01`
阶段：Phase 0
状态：`PASSED_WITH_OPEN_RISKS`
日期：2026-07-24
目标：对 RouteA_v2 五份核心 Markdown 文件进行职责、交叉约束、阶段执行和收口审查，并把审查结论落盘。
审查对象：系统规格、架构规格、实施计划、测试计划、CEGR 文献研究与模型映射。
模型边界：本次只审查文档和记录，不修改 `.slx`、MATLAB 脚本或原 RouteA。

## 1. 审查对象盘点

| 文件 | 应承担的责任 | 审查后状态 |
|---|---|---|
| `RouteA_cEGR_PEMFC_Platform_system_v01.md` | 定义研究目标、系统边界、接口、保真度和平台验收 | 已补齐三方依据、cEGR 物理定义、u/w/y/z、初始化和结论边界 |
| `RouteA_cEGR_PEMFC_Platform_architecture_v01.md` | 定义自然物理边界、逻辑容器、气路、控制、参数、状态和审计层 | 已补齐目标逻辑容器与当前 23 容器的映射原则、cEGR 端口契约和结构修改准则 |
| `RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md` | 作为后续建模、参数、控制、runner 和验证的阶段主计划 | 已重构为 Phase 0 -> 0.5 -> 1 -> 2 -> 3 -> 4 -> 5 的执行主计划 |
| `RouteA_cEGR_PEMFC_Platform_test-plan_v01.md` | 定义 Gate、case、KPI、数值门、失败分类和结果交接 | 已与实施阶段绑定，补齐初态、物理闭合、cEGR 和结果记录要求 |
| `RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md` | 定义 CEGR 文献证据、变量口径、模型映射、研究问题和可迁移边界 | 已把“第一轮矩阵完成”与“Phase 0.5 收口”分开，补齐逐篇精读字段和研究问题树 |

## 2. 审查前的主要缺口

1. 实施计划有重复阶段编号，Phase 5 只有原则性描述，缺少每阶段的准入、执行、出口、暂停和记录契约；
2. 架构规格的 8 个目标逻辑容器与当前读回的 23 个容器之间没有明确关系，容易被误解为必须一次性重排模型；
3. 系统规格虽有接口表，但没有把 cEGR 物理链、实际流量/组分来源和研究影响项的边界作为统一硬约束；
4. 测试计划已有 Gate 和 case，但没有明确“静态检查/编译/冷态仿真/结果审计”不可互相替代，也没有绑定阶段记录目录；
5. 文献文档的第一轮矩阵容易被读成全文精读和准入门已经完成，缺少逐篇证据字段、研究问题树和阶段收口状态；
6. 五份文档没有统一说明后续真实执行的记录位置、文件命名和失败后的继续/暂停规则。

## 3. 已落地的修正

### 3.1 物理口径

- cEGR 明确为阴极出口气体分流 -> 阀/泵/局部阻力 -> 管路/容腔 -> 阴极入口混合；
- 回流组分、压力、温度和湿度必须来自阴极出口物理网络；
- `cegr_ratio_cmd` 只能是上层设定值，不能直接写入实际 `mdot_cegr` 或气体组分；
- 氧稀释、自增湿、排水、低负荷高电位、动态饥饿、寄生功耗和冷启动被定义为影响项、研究问题或 KPI，不是自动新增的 cEGR 效果模块；
- 当前 RouteA 的官方物理域、MEA、cEGR 主气路和已完成 BOP 优先保留，Source_Conditioner 等未闭合接口定点审查。

### 3.2 阶段执行

- 实施计划现在是后续 RouteA_v2 建模仿真的阶段主计划；
- Phase 0/0.5 负责冻结来源、接口、文献证据和首个用例，未通过前不做大规模 `.slx` 修改；
- Phase 1-4 分别负责物理拓扑、参数真源、控制接口、runner/结果层；
- Phase 5 才负责分层运行、回归和矩阵推广；
- 每阶段统一执行闭环为：准入核对 -> 目标定位 -> 小步执行 -> read-back -> `model_check` -> 最小仿真 -> 保存核对 -> 记录和收口。

### 3.3 文献证据

- 第一轮 8 篇本地直接 CEGR 文献和补充文献矩阵保留；
- 新增逐篇精读最低字段：对象、气路、执行器、状态、口径、证据、适用范围、可迁移性和 RouteA 绑定；
- 新增 `EVIDENCE`、`INTERFACE`、`SCENARIO`、`PARAMETER_CANDIDATE` 使用级别，禁止未经审计把论文数值写入 `platform_default`；
- 新增从 cEGR 气路闭合到低负荷、高负荷、动态和冷启动专项的研究问题树；
- 明确 Phase 0.5 第一轮矩阵完成不等于文献准入门通过。

## 4. 当前阶段判定

| 项目 | 判定 | 说明 |
|---|---|---|
| 五份文档职责边界 | `PASS` | 系统、架构、实施、测试和文献映射已分工 |
| 实施计划可作为后续主计划 | `PASS_WITH_OPEN_RISKS` | 阶段契约已建立，但尚未执行 Phase 0/0.5 的未决项 |
| 执行记录机制 | `PASS` | 索引、模板、R00 基线、R00.5 文献和本审查记录已建立 |
| Phase 0 | `OPEN` | 23 容器完整映射和 warning ledger 尚未收口 |
| Phase 0.5 | `OPEN` | 逐篇精读字段、首个闭环用例和 Source_Conditioner 映射尚未收口 |
| RouteA_v2 模型运行 | `NOT_VERIFIED` | 当前 77 个 warning、冷态 smoke 和 `NE_DAE_IC_Failure` 不在本次文档审查中修复 |

## 5. 核验记录

本轮对 v2 工作树进行只读核验：

- 五份核心文档均存在，并已读回；
- `04_说明/RouteA_v2_Execution_Record/` 存在，包含索引、模板、Phase 0 基线、Phase 0.5 文献记录和本审查记录；
- 五份文档均包含执行记录入口；
- v2 模型文件存在，当前模型未因本轮文档审查修改；
- 本地 Markdown 链接检查：`broken_local_links=0`；
- `git diff --check`：退出码 `0`；
- 目录中的未跟踪 v2 模型/脚本/文档属于前序 v2 分离工作和本轮新增记录，未对原 RouteA 做回写。

## 6. 未验证和下一步

本记录不证明以下项目：

- v2 update/compile 成功；
- v2 冷态初始条件可收敛；
- `NE_DAE_IC_Failure` 已修复；
- 77 个 warning 已分类或已消除；
- 文献中的趋势已经在当前 v2 模型中复现；
- v09 formal 结果可以迁移到 v2。

下一步必须先按 [R00 baseline](R00_baseline_and_interface_freeze_20260724_v01.md) 和 [R00.5 literature mapping](R00_5_cegr_literature_mapping_20260724_v01.md) 收口 Phase 0/0.5，再按实施计划进入 Phase 1。未经阶段出口条件和用户确认，不进行大规模结构改动。
