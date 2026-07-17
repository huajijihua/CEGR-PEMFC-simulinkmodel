# 04_Simulink物理网络模型当前工作树

状态更新：2026-07-17

本目录只存放 Route A 官方 Gas Mixture PEMFC 派生平台的当前 Simulink 资产。唯一当前模型是 `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`。正常研究工况由 `EGRValveRestriction` 的编译期 `routeA_cegr_valve_mode_id` 选择官方无限流阻断路（0）或官方局部限制连通（1）。`mode=1` 是 cEGR 性能研究的标准入口，可在同一仿真内用目标循环比实现零目标到正循环比再回零；零目标只表示近似零 cEGR。唯一正式 `RouteA_platform_default_initial_state.mat` 已刷新为 `v03/mode=1`；它是同一 mode=1 拓扑下可跨研究工况复用的正常运行 warm start，生成时的 `28 A/OER=3` 仅为来源 metadata，不限制后续 runner 的场景命令。`mode=0` 是独立编译的严格无 cEGR 验证，不加载该性能初值。根层 `cEGR_Mode_Selector` 仅保留作拓扑回归，不作为正常工况开关。

| 目录 | 角色 | 说明 |
|---|---|---|
| `01_模型/RouteA_GasMixture_Derived/` | 当前主模型工作副本 | 只保留 `.slx`、模型工作区参数脚本和直接加载的 drive cycle `.mat` |
| `03_脚本/RouteA_GasMixture_Derived/` | 当前运行入口 | `run_routeA_fullcase_study.m` 是全工况研究入口；`run_routeA_platform_demo.m` 是日常名义工况入口；`run_routeA_stage1_cegr_ratio_matrix.m` 是 mode=1 的 600 s 性能矩阵入口，并将同一三次 `SimulationOutput` 交给 `routeA_stage1_water_ledger_from_outputs.m` 生成 `WM-L1+` 水账本，不重复仿真；`run_routeA_phase1_matching_audit.m` 只输出既有基线的账本和缺口证据，不定义新的建模阶段；路径和 Simscape 日志辅助函数与这些入口共同保留 |
| `04_说明/RouteA_GasMixture_Derived/` | 当前工程化规格 | `RouteA_cEGR_PEMFC_工程化建模规格_v01.md` 定义模型目标、边界与架构；`RouteA_cEGR_PEMFC_实施与验证路线_v01.md` 定义实施、验证和资料维护门禁 |

所有历史资产统一位于项目根目录 `../99_历史归档/`，不在本工作树内复制或嵌套归档。`slprj/`、`.slxc` 和其他 Simulink 自动生成缓存不作为 Git 项目资产，也不作为版本事实；但在模型频繁迭代期间默认保留，以避免重复编译和初始化。仅在用户明确要求、缓存损坏或需要专项释放空间时清理。

当前处于工程化建模前的分析、整理、规划与归档阶段。新的 `.slx`、参数、控制或 runner 改动必须等待工程化规格和实施路线中的 Phase 4 顶层规划经用户单独确认。
