# 04_Simulink物理网络模型当前工作树

状态更新：2026-07-22

本目录只保存 Route A 官方 Gas Mixture PEMFC 派生平台的活动资产。唯一当前模型为 `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；任何 I/P/V、电气边界或 cEGR 工况均在该模型内切换，不创建第二个系统模型。

2026-07-24 起增加一套平台重置规格草案，用于重新收敛系统边界、参数层、`u/w/y/z` 接口、单一内部 `I_cmd` 和分层验证顺序。在该规格包完成审阅前，不继续扩大当前 `.slx` 的结构。2026-07-25 起，模型版本选择以[模型裁决与资产处置](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)为准，实施顺序以[收敛实施路线图](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)为准：

- [模型裁决与资产处置](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)
- [收敛实施路线图](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)
- [平台系统规格](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_system_v01.md)
- [平台架构规格](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_architecture_v01.md)
- [平台实施计划](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)
- [平台测试计划](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)
- [当前资产审计](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_current-audit_20260724_v01.md)

| 目录 | 当前职责 |
|---|---|
| `01_模型/RouteA_GasMixture_Derived/` | 唯一 `.slx`、平台默认参数脚本和正式初态包。 |
| `03_脚本/RouteA_GasMixture_Derived/` | 一个正式 electrical-boundary runner、通用 profile/输入/KPI/气体/水账本辅助、统一 Current/Power/Voltage 初态链和唯一 MATLAB unittest 入口；不按工况或策略复制 runner。 |
| `04_说明/RouteA_GasMixture_Derived/` | 当前规划设计和实施记录。 |
| `05_汇报/` | 用户明确指定时才保存紧凑结果或汇报材料；不作为模型或参数真源。 |

当前设计、控制权限、初态协议、求解器、稳态判据、离线计算和并行规则见 [工程化建模规格](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_工程化建模规格_v01.md)。变更证据和未完成事项按日期、进度或连续需求核对线增量记录，必要时再按独立工作包分卷：

- [2026-07-16 至 2026-07-18：Stage 1 基线与气路审计](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_实施记录_20260716_20260718_Stage1基线与气路审计_v01.md)
- [2026-07-19 至 2026-07-21：I/P/V 迁移与矩阵验证](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_实施记录_20260719_20260721_IPV迁移与矩阵验证_v01.md)
- [2026-07-22：平台脚本收口与回归验证](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_实施记录_20260722_平台脚本收口与回归验证_v01.md)
- [2026-07-22：内容要求 1-3 电边界、气路权限与初态/求解器核对（当前分卷持续增量）](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_实施记录_20260722_内容要求1_三电边界核对_v01.md)

当前初态门禁：模型在 2026-07-22 的参数化和持久观测配置改动后，旧 `v03` initial-state bundle 已失效并被脚本拒绝。新的 v09 Current、Power、Voltage formal bundle 已完成多周期条件化、原子提升、2 s 热启动 smoke，以及统一 runner 的正式 `9 Current + 3 Power + 3 Voltage`、600 s 尾窗和气相 WM-L1+ 审计；三组均通过且结果仍属于可覆盖的迭代审计产物，不是冻结结果。

活动脚本的分类、统一初态 API、demo/test 入口和本轮归档替代关系见 `03_脚本/RouteA_GasMixture_Derived/README.md`。`slprj/`、`.slxc` 和当前运行缓存默认保留、但不纳入 Git。历史模型、旧 runner、旧说明和阶段证据只位于项目根目录 `99_历史归档/`，不参与活动默认链；本轮脚本收口归档位于 `99_历史归档/2026-07-22_Stage1_Script_Core_Split/`，既有 `Stage1_Script_Consolidation` 保持不动。
