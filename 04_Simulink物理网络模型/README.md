# 04_Simulink物理网络模型目录说明

状态更新：2026-07-15

本目录当前以 Route A 官方 Gas Mixture PEMFC 派生平台为唯一 Simulink 主线。`01_模型/RouteA_GasMixture_Derived/` 保留共享参数和设备封装的两份规范基础模型：有 cEGR 的 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` 与无 cEGR 的 `PEMFuelCellSystem_GasMixture_noCEGR_RouteA_v01.slx`。无 cEGR 模型以官方无限流阻隔离整条回流支路，主排气结构不变。

| 目录 | 角色 | 说明 |
|---|---|---|
| `01_模型/RouteA_GasMixture_Derived/` | 当前主模型工作副本 | 只保留 `.slx`、模型工作区参数脚本和直接加载的 drive cycle `.mat` |
| `03_脚本/RouteA_GasMixture_Derived/` | Route A 运行与审计入口 | `run_routeA_platform_demo.m` 是日常入口；`run_routeA_steady_state_cegr_comparison.m` 是无/有 cEGR 双基础模型稳态入口；A6-A10 脚本是阶段回归和排障入口 |
| `04_说明/RouteA_GasMixture_Derived/` | Route A 阶段说明和审计记录 | 保存 A8-A10 参数、控制、边界和验收说明 |
| `99_历史归档/2026-07-14_RouteB_Core_Physical/` | 路线 B 归档 | 原 `PEMFC_cEGR_Core_Physical_v01` 相关模型、参数、脚本和旧整改要求已移出当前建模目录 |

`slprj/`、`.slxc` 和其他 Simulink 自动生成缓存不作为项目资产；若在顶层或模型目录重新出现，应按缓存清理，不纳入说明文件或版本事实。
