# Route A hot-start assets retired

归档日期：2026-07-29

本目录保存 Route A 先前生成的 v10 `ModelOperatingPoint`/热启动相关脚本和 bundle。它们只用于历史审计、provenance 对照和兼容性追溯，不属于活动 MATLAB path、默认参数链或 runner 输入。

当前活动初始化策略为 `cold_start_only`：统一 runner/panel 由模型默认状态启动，并显式设置 `LoadInitialState="off"`。不要从本目录恢复热启动来替代 cold 收敛验证；如需研究热启动行为，必须另立经过裁决的历史复现任务。

归档内容：

- `routeA_attach_platform_default_initial_state.m`
- `routeA_generate_platform_default_initial_state.m`
- `routeA_prepare_parameter_consistent_initial_state.m`
- `routeA_promote_platform_default_initial_state_bundle.m`
- `RouteA_platform_default_initial_state.mat`
