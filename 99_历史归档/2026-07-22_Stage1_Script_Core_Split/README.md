# Route A 脚本核心收口归档

归档日期：2026-07-22。

本目录保存本轮被统一核心链替代的活动脚本实现，仅用于历史追溯、差异核对和必要的回归定位。归档目录不加入默认 MATLAB path，不作为当前参数、模型、runner 或测试入口，也不得从归档实现派生新的工况专用脚本。

原活动路径：

04_Simulink物理网络模型/03_脚本/RouteA_GasMixture_Derived/

| 归档文件 | 当前替代入口 |
|---|---|
| 03_脚本/RouteA_GasMixture_Derived/run_routeA_platform_demo.m | 活动目录同名兼容薄 wrapper，内部调用 run_routeA_electrical_boundary_study.m。 |
| 03_脚本/RouteA_GasMixture_Derived/routeA_generate_platform_default_drive_cycle_initial_state.m | 活动 routeA_generate_platform_default_initial_state.m，用 loadInputType 统一分支。 |
| 03_脚本/RouteA_GasMixture_Derived/routeA_generate_platform_default_voltage_initial_state.m | 活动统一初态入口的 Voltage 分支。 |
| 03_脚本/RouteA_GasMixture_Derived/routeA_mark_observability_signals.m | 统一 runner 和通用结果审计链；不再由 demo 单独标记信号。 |
| 03_脚本/RouteA_GasMixture_Derived/run_routeA_cegr_valve_closed_open_unit_test.m | 活动 RouteACegrValveConstitutiveTest.m 的私有静态 fixture 方法。 |

已有的 99_历史归档/2026-07-22_Stage1_Script_Consolidation/ 保持独立，不与本轮归档混合。现有模型 .slx、platform_default 参数和正式结果文件均不属于本轮归档操作范围。
