# Route A Stage 1 脚本与说明收口归档

归档日期：2026-07-22

本目录保存已被当前统一 Route A 入口替代的专题脚本，以及已经合并到当前工程化规格的 I/P/V 规划草案。文件没有删除，后续只用于历史结果追溯或显式回放；新研究不得从本目录复制出新的工况专用 runner。

活动入口是：

- `04_Simulink物理网络模型/03_脚本/RouteA_GasMixture_Derived/run_routeA_electrical_boundary_study.m`
- 同目录下的 profile、输入装配、KPI/气体闭合/水账本、初态生成和初态提升辅助
- 当前指导目录：`04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/`
- 当前实施记录目录：`04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/02_实施记录/`

归档脚本不参与默认参数、默认初态、当前模型或当前验收。当前 formal I/P/V 长矩阵必须使用活动统一 runner，并且一次 study 只允许一种电边界。
