# 04_Simulink物理网络模型目录说明

状态更新：2026-07-15

本目录当前以 Route A 官方 Gas Mixture PEMFC 派生平台为唯一 Simulink 主线。唯一当前模型是 `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`，其根层 `cEGR_Mode_Selector` 在 update-diagram 时由 `routeA_cegr_enabled` 选择直接回流或官方 `Infinite Flow Resistance (FC)` 隔离。无 cEGR 不再维护独立模型，主排气结构保持不变。

| 目录 | 角色 | 说明 |
|---|---|---|
| `01_模型/RouteA_GasMixture_Derived/` | 当前主模型工作副本 | 只保留 `.slx`、模型工作区参数脚本和直接加载的 drive cycle `.mat` |
| `03_脚本/RouteA_GasMixture_Derived/` | 当前运行入口 | `run_routeA_fullcase_study.m` 是唯一全工况研究入口；`run_routeA_platform_demo.m` 是日常名义工况入口；路径和 Simscape 日志辅助函数与两者共同保留 |
| `04_说明/RouteA_GasMixture_Derived/` | 当前工程化规格 | `RouteA_cEGR_PEMFC_工程化建模规格_v01.md` 定义模型目标、边界与架构；`RouteA_cEGR_PEMFC_实施与验证路线_v01.md` 定义实施、验证和资料维护门禁 |
| `99_历史归档/2026-07-14_RouteB_Core_Physical/` | 路线 B 归档 | 原 `PEMFC_cEGR_Core_Physical_v01` 相关模型、参数、脚本和旧整改要求已移出当前建模目录 |
| `99_历史归档/2026-07-15_RouteA_TwoModel_Baseline/` | Route A 双模型历史基线 | 独立 no-cEGR 模型与双模型对比 runner；仅保留历史证据，不作为当前入口 |
| `99_历史归档/2026-07-15_RouteA_Stage_Evidence/` | Route A 阶段审计归档 | A6-A10 阶段脚本和说明；仅用于追溯，不作为后续建模规范或默认运行入口 |

`slprj/`、`.slxc` 和其他 Simulink 自动生成缓存不作为 Git 项目资产，也不作为版本事实；但在模型频繁迭代期间默认保留，以避免重复编译和初始化。仅在用户明确要求、缓存损坏或需要专项释放空间时清理。
