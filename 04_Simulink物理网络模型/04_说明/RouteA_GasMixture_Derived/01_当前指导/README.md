# 当前指导文件

本目录是 Route A 当前的设计、裁决、实施和验证指导层。文件是规划性真源，不等同于已通过的仿真结果。

阅读顺序：模型裁决与资产处置 -> 收敛实施路线图 -> 平台能力建设需求 -> 面板-模型双向迭代规划 -> P0 迁移与接口收口实施计划 -> 控制接口汇总表 -> CR3 三要素 schema -> 系统规格 -> 架构规格 -> 实施计划 -> 测试计划。

| 文件 | 状态 | 用途 |
|---|---|---|
| RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md | 当前决策真源 | 唯一主模型、v2 归档和历史资产处置 |
| RouteA_cEGR_PEMFC_收敛实施路线图_v01.md | 当前路线真源 | S0-S3 已完成，S4 cold-only 与 Voltage purge 周期门已收口，S5 P0 3600 s 已通过，S6 待推进 |
| RouteA_cEGR_PEMFC_平台能力建设需求_v01.md | **新阶段起点** | 平台能力升级需求定义、原则、执行路线图 |
| RouteA_cEGR_PEMFC_面板-模型双向迭代规划_v01.md | **用户确认目标** | 迁移边界、系统优先级、参数开放、cEGR 控制语义、结果分级和后续阶段 |
| RouteA_cEGR_PEMFC_P0_迁移与接口收口实施计划_v01.md | **P0 当前实施计划** | 路径入口、依赖检查、参数/观测量注册、model contract 和 P0 出口门 |
| RouteA_cEGR_PEMFC_控制接口汇总表_v01.md | **Phase A 产出** | 平台能力清单，所有可控制量/可观测量定义 |
| RouteA_cEGR_PEMFC_CR3三要素schema_v01.md | **Phase A 产出** | 标准化 simCase 输入格式定义 |
| RouteA_cEGR_PEMFC_Platform_system_v01.md | 当前规格 | 平台目标、u/w/y/z 和适用范围 |
| RouteA_cEGR_PEMFC_Platform_architecture_v01.md | 当前规格 | 官方组件、cEGR 和参数/状态架构 |
| RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md | 当前低层计划 | 规格冻结后的实现拆解 |
| RouteA_cEGR_PEMFC_Platform_test-plan_v01.md | 当前验证计划 | Gate 0-3、Gate 4 和 P0 I/P/V 3600 s 已有证据，Hydrogen warning 已关闭，600 s/面板矩阵和 S5 收口待推进 |

在当前模型通过 Gate 4 扩展动态验证和正式矩阵准入前，不把这些文件中的目标描述写成已验证事实。
