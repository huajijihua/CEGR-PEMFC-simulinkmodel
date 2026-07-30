# 04_Simulink物理网络模型当前工作树

状态更新：2026-07-29（cold-start-only P0/S4/S5 Voltage 控制链、purge 周期门与 Hydrogen Source runtime warning 收口）

本目录只保存 Route A 官方 Gas Mixture PEMFC 派生平台的活动资产。唯一当前模型为 `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；任何 I/P/V、电气边界或 cEGR 工况均在该模型内切换，不创建第二个系统模型。

**当前阶段完成情况：**
- S0 决策冻结 ✅ — 模型裁决、资产处置已确认
- S1 物理边界收敛 ✅ — Source_Conditioner 删除，恢复官方供气路径
- S2 最小 plant ✅ — 冷态 smoke 4 case 全部通过
- S3 参数与控制收敛 ✅ — 恒电流/恒功率/恒电压 + cEGR 矩阵 + 入口组分控制全部完成
- S4 初态与数值收敛 ✅ — 活动链固定 cold-start-only；Current/Power 严格通过，Voltage purge 周期响应已分类并通过专门门
- S5 分层验证 ◐ — Gate 4 和 P0 I/P/V 3600 s 回归通过；Hydrogen Source runtime warning 已关闭，P1 600 s/面板独立代表性工况仍未收口
- P1 面板基础版 ◐ — 已进入实施；单工况入口、结果契约和面板基础 smoke 已建立，研究矩阵后置
- Phase A 设计基础 ✅ — 控制接口汇总表 + CR3 三要素 schema + simCase 模板
- Phase B 模型优化 ✅ — 22 列 profile 结构体 + schema 单一真源 + 参数单入口
- Phase C 脚本清理 ⏳ — 待推进

模型版本选择以[模型裁决与资产处置](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)为准，实施顺序以[收敛实施路线图](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)为准：

- [模型裁决与资产处置](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)
- [收敛实施路线图](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)
- [说明目录索引](04_说明/RouteA_GasMixture_Derived/README.md)
- [平台系统规格](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_system_v01.md)
- [平台架构规格](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_architecture_v01.md)
- [平台实施计划](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)
- [平台测试计划](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)
- [当前资产审计](04_说明/RouteA_GasMixture_Derived/03_审计与研究/RouteA_cEGR_PEMFC_Platform_current-audit_20260724_v01.md)
- [77 条结构 warning ledger](04_说明/RouteA_GasMixture_Derived/03_审计与研究/RouteA_cEGR_PEMFC_model_check_warning_ledger_20260729_v01.md)

| 目录 | 当前职责 |
|---|---|
| `01_模型/RouteA_GasMixture_Derived/` | 唯一 `.slx` 和平台默认参数脚本；热启动 bundle 已移入历史归档。 |
| `03_脚本/RouteA_GasMixture_Derived/` | 一个正式 electrical-boundary runner、通用 profile/输入/KPI/气体/水账本辅助、cold-start-only 输入链和唯一 MATLAB unittest 入口；不按工况或策略复制 runner。 |
| `04_说明/RouteA_GasMixture_Derived/` | 说明索引；下分当前指导、实施记录、审计研究和交接材料。 |
| `05_汇报/` | 用户明确指定时才保存紧凑结果或汇报材料；不作为模型或参数真源。 |

当前模型设计、控制权限、初态协议、求解器、稳态判据、离线计算和并行规则以[说明目录索引](04_说明/RouteA_GasMixture_Derived/README.md)及其 `01_当前指导/` 为准。工程化建模规格 v01 已移入 `99_历史归档/2026-07-25_RouteA_说明整理/`，不再作为当前规划真源。变更证据和未完成事项按 `02_实施记录/` 的当前分卷维护（规则见该目录 `README.md`及 AGENTS.md"说明文件纪律"节）：

- [2026-07-27：S2 冷态 smoke、Source_Conditioner 处置与 S3 稳态验证（当前分卷）](04_说明/RouteA_GasMixture_Derived/02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260727_S2冷态smoke与Source_Conditioner处置_v01.md)
- [2026-07-27：Phase A — 设计基础（控制接口 + CR3 schema）（当前分卷）](04_说明/RouteA_GasMixture_Derived/02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260727_PhaseA设计基础_v01.md)
- [2026-07-27：Phase B — 模型优化（profile struct + 参数入口）（当前分卷）](04_说明/RouteA_GasMixture_Derived/02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260727_PhaseB平台能力升级_v01.md)

当前初态门禁：活动 runner 固定 `cold_start_only`，显式设置 `LoadInitialState="off"`，不读取热启动 bundle。旧 v10 bundle 和 helper 已移入 `99_历史归档/2026-07-29_RouteA_hot_start_retired/`，仅供 contract provenance 读回和历史审计；不得写成活动 runner 前置。

活动脚本的分类、统一初态 API、demo/test 入口和本轮归档替代关系见 `03_脚本/RouteA_GasMixture_Derived/README.md`。`slprj/`、`.slxc` 和当前运行缓存默认保留、但不纳入 Git。历史模型、旧 runner、旧说明和阶段证据只位于项目根目录 `99_历史归档/`，不参与活动默认链；本轮脚本收口归档位于 `99_历史归档/2026-07-22_Stage1_Script_Core_Split/`，既有 `Stage1_Script_Consolidation` 保持不动。
