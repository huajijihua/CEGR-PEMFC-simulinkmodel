# RouteA_v2 Execution Record

文件类型：RouteA_v2 阶段执行记录目录
建立日期：2026-07-24
职责：只记录已经发生的盘点、文档决策、模型/脚本修改、读回、验证、失败和阶段收口，不承担规划正文。

本目录是 [RouteA_v2 实施计划](../RouteA_v2_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md) 的事实证据入口。实施计划规定“要做什么”和“什么条件才可以继续”；本目录记录“实际做了什么、证据在哪里、现在是否收口”。

## 1. 目录边界

- 只记录 RouteA_v2 独立工作树的执行；
- 原 RouteA 只作为来源、对照和历史证据，不在此目录修改；
- 不在此目录复制正式结果、`.slx`、`slprj/`、`.slxc` 或完整 timeseries；结果摘要和失败栈放入 `../../05_结果/`，记录只引用路径；
- v09/v10 结果不能因为被引用而变成 v2 通过证据；
- 记录状态没有 `PASSED` 就不能把对应阶段描述为完成。

## 2. 阶段状态

| 阶段 | 责任 | 当前状态 | 当前记录 |
|---|---|---|---|
| Phase 0 | 资产、接口和现状基线冻结 | `IN_PROGRESS` | [R00 baseline](R00_baseline_and_interface_freeze_20260724_v01.md)、[R00 document review](R00_document_review_20260724_v01.md) |
| Phase 0.5 | CEGR 文献证据和模型映射 | `IN_PROGRESS` | [R00.5 literature mapping](R00_5_cegr_literature_mapping_20260724_v01.md) |
| Phase 1 | 物理拓扑和未闭合接口收敛 | `PENDING` | 尚未执行，按模板新建 `R01_*.md` |
| Phase 2 | 参数单一真源 | `PENDING` | 尚未执行，按模板新建 `R02_*.md` |
| Phase 3 | 控制和负载接口收缩 | `PENDING` | 尚未执行，按模板新建 `R03_*.md` |
| Phase 4 | runner、结果和失败分类 | `PENDING` | 尚未执行，按模板新建 `R04_*.md` |
| Phase 5 | 分层验证和推广 | `PENDING` | 尚未执行，按模板新建 `R05_*.md` |

## 3. 记录命名和状态

文件命名：

```text
R<phase>_<short-name>_<YYYYMMDD>_vNN.md
```

允许的状态：`PENDING`、`IN_PROGRESS`、`PASSED`、`PASSED_WITH_OPEN_RISKS`、`BLOCKED`、`DEFERRED`。

阶段记录必须从 [执行记录模板](TEMPLATE_phase-execution-record.md) 开始。一次实际执行可以产生同一阶段的多个版本，但不能覆盖历史记录；新版本必须说明相对上一版的新增证据、修正和状态变化。

## 4. 每份记录的最低证据

1. 目标模型/脚本路径、模型根名称和执行范围；
2. 输入版本、参数层、case、solver、初态和模型 hash/时间；
3. 允许修改和禁止修改的边界；
4. 实际执行步骤和关键命令；
5. read-back、`model_check`、update/compile、最小仿真和保存到磁盘的证据；
6. KPI、warning/error、失败栈、结果文件和证据路径；
7. 出口条件逐项判定；
8. 未决项、暂停/回滚决定和下一阶段准入条件。

静态检查、模型可编译或脚本运行无报错只能作为对应证据项，不能自动填充运行验证项。

## 5. 当前记录

- [R00 baseline and interface freeze](R00_baseline_and_interface_freeze_20260724_v01.md)：记录 v2 分离后的模型/脚本/文档基线、当前 23 个容器、77 个结构 warning、接口冻结草案和未决项；本记录不修改 `.slx`。
- [R00.5 CEGR literature mapping](R00_5_cegr_literature_mapping_20260724_v01.md)：记录第一轮 8 篇直接 CEGR 文献矩阵、物理口径修正、模型映射和 Phase 0.5 尚未收口的项目。
- [R00 core documentation review](R00_document_review_20260724_v01.md)：记录五份核心文档的职责审查、已落地修正、交叉核验结果和未验证边界。
