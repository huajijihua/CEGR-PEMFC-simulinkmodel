# RouteA_v2 PEMFC-cEGR Simulink

文件类型：RouteA_v2 独立模型与脚本工作树
建立日期：2026-07-24
状态：已从当前 RouteA 复制建立基线；尚未进行 v2 结构修改、compile 或 smoke test。

## 1. 工作边界

本目录是 RouteA_v2 的独立工作树。原 RouteA 仍位于：

`04_Simulink物理网络模型/`

RouteA 与 RouteA_v2 不共享活动模型文件、脚本目录或运行缓存。RouteA_v2 的模型和脚本需要复用时，在本目录内复制、修改和验证；不得直接在 RouteA 原目录继续叠加 v2 结构。

RouteA_v2 不是从官方案例重新起步，而是当前 RouteA 的独立副本。官方 Gas Mixture/FuelCell 资产、CEGR 文献和当前 RouteA 现状共同作为后续收敛依据。

## 2. 目录

| 目录 | 职责 |
|---|---|
| `01_模型/RouteA_v2_GasMixture_Derived/` | v2 `.slx`、参数脚本、drive-cycle 和兼容初态资产 |
| `03_脚本/RouteA_v2_GasMixture_Derived/` | v2 活动 MATLAB 脚本副本；脚本仍保留 `routeA_` API 前缀以减少无必要的函数级改名 |
| `04_说明/RouteA_v2_GasMixture_Derived/` | v2 平台规格、架构、实施、测试和 CEGR 文献映射 |
| `04_说明/RouteA_v2_Execution_Record/` | Phase 0、Phase 0.5 及后续各阶段的实际执行记录、证据、失败和收口状态 |
| `05_结果/` | v2 后续结果摘要、失败栈和 KPI；当前为空 |

## 3. 复制基线

| v2 资产 | 来源 | 当前语义 |
|---|---|---|
| `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx` | 当前 RouteA `.slx` | 已通过 MATLAB `model_overview` 读回；结构仍是复制基线，不代表 v2 已验证 |
| `PEMFuelCellSystemWithACustomLibraryParameters.m` | 当前 RouteA 参数脚本 | 兼容副本；后续只在 v2 目录内修改 |
| `PEMFuelCellSystemWithACustomLibraryDriveCycle.mat` | 当前 RouteA drive-cycle | 兼容副本 |
| `RouteA_v2_legacy_source_initial_state_from_RouteA_v01.mat` | 当前 RouteA 初态资产的只读来源副本 | 仅用于来源对照；v2 脚本不会自动加载，不得作为 v2 formal 结果证据 |

未复制 `slprj/`、`.slxc`、正式结果和历史归档。v2 的缓存只在 v2 目录或 MATLAB 默认运行位置生成，并不作为版本化模型资产。

## 4. 当前验证边界

- 已完成：目标目录建立、模型/脚本/文档复制、v2 模型文件名和脚本相对路径读回；
- 已完成：v2 模型根名称读回为 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01`；
- 已完成：v2 `model_check(all)` 读回，结果为 77 个 warning；该数量与当前 RouteA 已知基线一致，不代表通过；
- 未完成：v2 update/compile、冷态初始条件和行为 smoke；
- 未完成：任何 RouteA 旧 warning、`NE_DAE_IC_Failure` 或 v09 结果向 v2 的迁移证明。

后续 v2 修改必须遵循：定位 -> 小步修改 -> read-back -> `model_check` -> 最小仿真 -> 记录。阶段顺序、出口条件和暂停条件以 `04_说明/RouteA_v2_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md` 为准；实际证据以 `04_说明/RouteA_v2_Execution_Record/` 为准。RouteA 原目录保持只读参考和历史证据边界。
