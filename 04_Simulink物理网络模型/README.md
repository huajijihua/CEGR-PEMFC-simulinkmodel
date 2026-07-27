# 04_Simulink物理网络模型当前工作树

状态更新：2026-07-27（S2/S3 稳态验证完成）

本目录只保存 Route A 官方 Gas Mixture PEMFC 派生平台的活动资产。唯一当前模型为 `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；任何 I/P/V、电气边界或 cEGR 工况均在该模型内切换，不创建第二个系统模型。

**当前阶段完成情况：**
- S0 决策冻结 ✅ — 模型裁决、资产处置已确认
- S1 物理边界收敛 ✅ — Source_Conditioner 删除，恢复官方供气路径
- S2 最小 plant ✅ — 冷态 smoke 4 case 全部通过
- S3 参数与控制收敛 ✅ — 恒电流/恒功率/恒电压 + cEGR 矩阵 + 入口组分控制全部完成
- S4 初态和数值收敛 ⏳ — 待生成 v10 初态包
- S5 分层验证 ⏳ — 待动态验证
- S6 CEGR 研究 ⏳ — 待推进

模型版本选择以[模型裁决与资产处置](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)为准，实施顺序以[收敛实施路线图](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)为准：

- [模型裁决与资产处置](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)
- [收敛实施路线图](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)
- [说明目录索引](04_说明/RouteA_GasMixture_Derived/README.md)
- [平台系统规格](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_system_v01.md)
- [平台架构规格](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_architecture_v01.md)
- [平台实施计划](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)
- [平台测试计划](04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)
- [当前资产审计](04_说明/RouteA_GasMixture_Derived/03_审计与研究/RouteA_cEGR_PEMFC_Platform_current-audit_20260724_v01.md)

| 目录 | 当前职责 |
|---|---|
| `01_模型/RouteA_GasMixture_Derived/` | 唯一 `.slx`、平台默认参数脚本和正式初态包。 |
| `03_脚本/RouteA_GasMixture_Derived/` | 一个正式 electrical-boundary runner、通用 profile/输入/KPI/气体/水账本辅助、统一 Current/Power/Voltage 初态链和唯一 MATLAB unittest 入口；不按工况或策略复制 runner。 |
| `04_说明/RouteA_GasMixture_Derived/` | 说明索引；下分当前指导、实施记录、审计研究和交接材料。 |
| `05_汇报/` | 用户明确指定时才保存紧凑结果或汇报材料；不作为模型或参数真源。 |

当前模型设计、控制权限、初态协议、求解器、稳态判据、离线计算和并行规则以[说明目录索引](04_说明/RouteA_GasMixture_Derived/README.md)及其 `01_当前指导/` 为准。工程化建模规格 v01 已移入 `99_历史归档/2026-07-25_RouteA_说明整理/`，不再作为当前规划真源。变更证据和未完成事项按 `02_实施记录/` 的当前分卷维护：

- [2026-07-16 至 2026-07-18：Stage 1 基线与气路审计](04_说明/RouteA_GasMixture_Derived/02_实施记录/02_已封闭/RouteA_cEGR_PEMFC_实施记录_20260716_20260718_Stage1基线与气路审计_v01.md)
- [2026-07-19 至 2026-07-21：I/P/V 迁移与矩阵验证](04_说明/RouteA_GasMixture_Derived/02_实施记录/02_已封闭/RouteA_cEGR_PEMFC_实施记录_20260719_20260721_IPV迁移与矩阵验证_v01.md)
- [2026-07-22：平台脚本收口与回归验证](04_说明/RouteA_GasMixture_Derived/02_实施记录/02_已封闭/RouteA_cEGR_PEMFC_实施记录_20260722_平台脚本收口与回归验证_v01.md)
- [2026-07-27：S2 冷态 smoke、Source_Conditioner 处置与 S3 稳态验证（当前分卷）](04_说明/RouteA_GasMixture_Derived/02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260727_S2冷态smoke与Source_Conditioner处置_v01.md)

当前初态门禁：`RouteA_platform_default_initial_state.mat` 的 metadata 仍为 v09 schema，正式 runner 链无法使用。当前 S3 验证均通过直接 SimulationInput 绕过。v10 初态包需要在当前模型、当前参数链和当前拓扑 hash 下重新生成。

活动脚本的分类、统一初态 API、demo/test 入口和本轮归档替代关系见 `03_脚本/RouteA_GasMixture_Derived/README.md`。`slprj/`、`.slxc` 和当前运行缓存默认保留、但不纳入 Git。历史模型、旧 runner、旧说明和阶段证据只位于项目根目录 `99_历史归档/`，不参与活动默认链；本轮脚本收口归档位于 `99_历史归档/2026-07-22_Stage1_Script_Core_Split/`，既有 `Stage1_Script_Consolidation` 保持不动。
