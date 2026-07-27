# Route A 活动脚本入口

本目录保持平铺，避免破坏既有 scriptDir/../.. 相对路径。当前活动链收口为一个正式研究 runner、通用辅助脚本和一个 MATLAB unittest 入口；不按 Current/Power/Voltage、负载或研究工况复制脚本。

平台重置规格审阅期间，本目录中的脚本只作为现状证据和兼容入口维护，不新增按边界、负载、策略或 Source_Conditioner 复制的脚本。新的活动 API 目标见 `04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md`；当前 v10 初态链和 22 列 profile 尚未通过重置后的冷态/结构门禁。

## 正式核心

| 分类 | 活动入口 | 职责 |
|---|---|---|
| 输入装配 | routeA_build_electrical_boundary_cases.m、routeA_normalize_electrical_profile.m、routeA_prepare_electrical_boundary_input.m | 组装单一电边界、气路、cEGR、热和控制输入；不运行模型计算。 |
| 仿真调度 | run_routeA_electrical_boundary_study.m | 唯一正式研究 runner；支持 Current、Power、Voltage 分开执行，以及 serial/parsim 调度；仿真前生成初态/控制/求解器 preflight。 |
| 结果审计 | routeA_assess_electrical_boundary_outputs.m、routeA_stage1_cathode_gas_closure_from_outputs.m、routeA_stage1_water_ledger_from_outputs.m | 提取电边界、气相闭合、cEGR、设备控制和水账本 KPI。 |
| 初态维护 | routeA_generate_platform_default_initial_state.m、routeA_prepare_parameter_consistent_initial_state.m、routeA_attach_platform_default_initial_state.m、routeA_promote_platform_default_initial_state_bundle.m | 生成、校验、挂载和提升统一的 Current/Power/Voltage 初态资产。 |
| 共享读回 | routeA_block_paths.m、routeA_simscape_log_mea.m、routeA_stack_electrical_power_timeseries.m、routeA_restore_model_and_folder.m | 提供模型路径、Simscape log、功率时序和环境恢复辅助。 |

routeA_generate_platform_default_initial_state 无参数时继续生成 Current 候选；通过 userCfg.loadInputType = "Current"|"Power"|"Voltage" 选择其他分支。Power/Voltage 仍要求通过 v09 Current 源初态校验，并保留既有候选 MAT 文件名和 metadata 语义。

每个 case 进入 `sim`/`parsim` 前必须完成 `routeA_electrical_boundary_preflight`：初态、气路/电堆控制、计算类型、求解器、逻辑起点和统计窗均被记录；稳态默认使用最后 60 s 的时间加权平均并以 0.5% 半窗变化门验收。瞬态默认保留完整 `SimulationOutput` 时序，显式关闭时 runner 拒绝执行。`StartTime` 配置和逻辑研究时间为 0 s，但热启动 operating point 的绝对模型时间仍从快照时间开始。

热启动不复制脚本，也不把 checksum warning 当作兼容：`hotStartPolicy="auto"` 默认复用低电流物理 operating point；I/P/V、空气模式/OER/直接命令、cEGR profile 和 Voltage PI 是研究命令。若 case 明确改变气源、湿度/旁路或堆温基准，auto 不挂载 operating point 并记录 `auto_cold_fallback`；`hot` 则在仿真前拒绝，`cold` 始终关闭 `LoadInitialState`。所有正式 runner 输入都显式保持 `OperatingPointContentsChecksumMismatchMsg="error"`，不允许部分状态加载。

## 验证与兼容

RouteACegrValveConstitutiveTest.m 是唯一正式 cEGR 阀构成测试入口，使用 MATLAB runtests。run_routeA_platform_demo.m 只是兼容薄 wrapper：复用统一 runner 装配 10 s nominal demo，并保留 routeA_platform_demo_summary base 输出；它不得用于正式矩阵、敏感性分析或参数标定。

### S3 验证新增脚本

| 脚本 | 用途 |
|---|---|
| `run_routeA_power_cegr_matrix.m` | 恒功率模式 cEGR 验证运行器（6 工况：40kW/120kW × cEGR=0/0.1/0.3），直接构建 SimulationInput |
| `run_routeA_voltage_cegr_matrix.m` | 恒电压模式 cEGR 验证运行器（6 工况：410V/375V × cEGR=0/0.1/0.3），直接构建 SimulationInput，含 PI 控制器参数 |
| `routeA_set_entry_composition.m` | 阴极入口气体组分控制辅助函数，设置 env_yO2/env_yH20 变量 |

这些脚本为 S3 验证产物，通过直接 SimulationInput 方式绕过 v10 初态 schema 检查。后续正式研究应使用统一 runner 链。

归档目录为 99_历史归档/2026-07-22_Stage1_Script_Core_Split/，不加入默认 MATLAB path。归档脚本只用于追溯和差异核对，不得从中派生新的工况脚本；新研究统一通过 run_routeA_electrical_boundary_study 的 case/profile 配置完成。
