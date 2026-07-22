# 04_Simulink物理网络模型当前工作树

状态更新：2026-07-22

本目录只保存 Route A 官方 Gas Mixture PEMFC 派生平台的活动资产。唯一当前模型为 `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；任何 I/P/V、电气边界或 cEGR 工况均在该模型内切换，不创建第二个系统模型。

| 目录 | 当前职责 |
|---|---|
| `01_模型/RouteA_GasMixture_Derived/` | 唯一 `.slx`、平台默认参数脚本和正式初态包。 |
| `03_脚本/RouteA_GasMixture_Derived/` | 通用 profile、输入装配、运行调度、KPI 审计、初态生成/提升和维护回归工具。 |
| `04_说明/RouteA_GasMixture_Derived/` | 当前规划设计和实施记录。 |
| `05_汇报/` | 用户明确指定时才保存紧凑结果或汇报材料；不作为模型或参数真源。 |

当前设计、控制权限、初态协议、求解器、稳态判据、离线计算和并行规则见 [工程化建模规格](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_工程化建模规格_v01.md)。变更证据和未完成事项见 [实施记录](04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_实施与验证路线_v01.md)。

当前初态门禁：模型在 2026-07-22 的参数化和持久观测配置改动后，旧 `v03` initial-state bundle 已失效并被脚本拒绝。新的 v09 Current、Power、Voltage 候选尚待用户在 MATLAB GUI 中完成多周期长计算并原子提升；在此之前不得启动正式 I/P/V 矩阵或复用旧结果作为当前模型证据。

`slprj/`、`.slxc` 和当前运行缓存默认保留、但不纳入 Git。历史模型、旧 runner、旧说明和阶段证据只位于项目根目录 `99_历史归档/`，不参与活动默认链。
