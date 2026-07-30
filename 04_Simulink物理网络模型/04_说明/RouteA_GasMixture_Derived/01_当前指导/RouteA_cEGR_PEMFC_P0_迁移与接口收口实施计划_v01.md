# Route A cEGR-PEMFC P0 迁移与接口收口实施计划

文件类型：阶段实施计划（P0）<br>
日期：2026-07-28<br>
版本：v01<br>
状态：P0 代码实施和最小验证已完成；当前活动初始化策略为 cold-start-only，历史 v10 bundle 仅作审计资产；P1 面板基础版已获条件实施准入

## 1. 阶段目标

P0 将 Route A 从依赖开发机路径和分散脚本约定的研究入口，收口为可迁移的启动、依赖、参数、观测量和模型契约基础层。

本阶段不修改 `.slx` 物理拓扑，不新增物理块，不开放尚未完成验证的设备参数。

## 2. 实施范围

| 能力 | 实施结果 |
|---|---|
| 路径解析 | `routeA_project_paths` 根据自身文件位置解析工程、模型和脚本路径 |
| 启动入口 | `launch_routeA_panel` 支持从外部 MATLAB 当前目录启动 |
| 依赖检查 | 检查 MATLAB、Simulink、Simscape、FuelCell_lib、模型和核心脚本 |
| 参数注册 | 登记当前 active 输入，并盘点 `platform_default` 设备参数 |
| 观测量注册 | 登记 `logsout`、SimulationOutput 和待确认信号 |
| Model contract | 读回 block path、Model Workspace 变量和 22 列 profile schema |
| 输出契约 | 用真实仿真输出核对注册观测量，不把文档名称当作实际信号 |
| 初态边界 | v09/Source_Conditioner 初态契约明确拒止；活动 runner 固定 cold-start-only，v10 I/P/V bundle 仅作历史审计 |

## 3. 当前支持边界

支持入口为 `launch_routeA_panel`、程序化 `RouteA_Panel_v01` 和其 panel matrix helper。活动 electrical-boundary runner 已通过 cold-start-only 输入契约和代表性冷态运行；长时间研究矩阵仍需经过 S5 分层验证。

`platform_default` 是默认参数源。inventory 参数只记录现状，不等于已经可以在面板中修改。入口组分 `env_yH20` 保留为模型真实变量名，并在注册表中显式标记。

## 4. 出口标准

1. 外部 MATLAB 当前目录下可解析 Route A 路径并启动面板。
2. 依赖缺失时在进入仿真前明确拒止。
3. model contract 无 error 级读回问题。
4. 参数和观测量注册表均能回指当前模型或明确标记为 inventory/unresolved。
5. Current 10 s smoke、3 case matrix smoke 和 Current 100 A/600 s 回归通过。
6. `.slx` 保持未保存修改关闭状态，既有 77 条结构 warning 不因 P0 增加。

## 5. 后续入口

P0 之后进入：

- S4：当前拓扑的 cold-start-only 输入契约和 I/P/V cold 回归；历史 v10 初态包不进入活动运行链；
- S5：正式 runner 的分层验证和长时间 I/P/V 研究；
- [P1：完整燃料电池系统面板基础能力](RouteA_cEGR_PEMFC_P1_完整燃料电池系统面板基础版实施计划_v01.md)：P0 的准备能力在此转入面板-模型双向迭代主线；
- P3：cEGR 目标比例、阀面积诊断和研究仪表板；
- P5：按注册表逐项开放设备参数。

P0 不定义 P1 的核心功能完成度。P1 及后续阶段必须先在 `01_当前指导/` 建立具体实施计划，再进入对应的模型、脚本和面板实施。
