# Route A cEGR-PEMFC S4 当前拓扑 v10 初态与热启动实施记录

文件类型：实施记录（S4 当前拓扑初态连续实施线）<br>
记录日期：2026-07-28<br>
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`<br>
对应路线：[Route A cEGR-PEMFC 收敛实施路线图](../../01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)

## 1. 实际完成工作

### 1.1 当前供气边界和 v10 metadata

- 初态 metadata 从退役 `sourceConditionerState` 迁移为当前官方供气边界契约：`Air Intake` 与 `Hydrogen Source`。
- 新增并实际写入 `supplyBoundaryState`、`topologyHash`、`parameterLayer`、`externalCaseEnabled`、`studyCommandBinding` 和 `modelVersion`。
- `topologyHash` 在从磁盘重载模型、尚未写入 Current/Power/Voltage 分支运行时命令时采集，避免把分支命令差异误判为拓扑差异。
- cEGR 质量流量统一使用真实日志名 `EGR_mdot_log`；不再查找退役的 `routeA_egr_mdot`。
- 阴极出口压力初始化条件改为读取当前 22 列 v10 command profile baseline 的第 8 列，不再读取不存在的 `routeA_target_p_ca_out_MPa`。

### 1.2 I/P/V 初态候选和原子提升

- 生成 Current、Power、Voltage 三个 mode-1 zero-cEGR platform-default 候选。
- 三个候选共同 topology hash：`2D8AE250-895A2A82-1980FB9C-C8E0A06A`。
- 三个候选均使用 `RouteA_Supply_Boundary_v01`、`platform_default`、`externalCaseEnabled=false`，并通过 post-purge quiet-window 门禁。
- 通过 `routeA_promote_platform_default_initial_state_bundle.m` 原子提升至：
  `RouteA_platform_default_initial_state.mat`。
- 旧 formal v09 文件已自动移入：
  `99_历史归档/2026-07-22_Stage1_InitialState_Superseded/`。

### 1.3 热启动 runner 和冷启动审计修复

- runner 设置 `OperatingPointInterfaceChecksumMismatchMsg=error`，禁止静默丢弃 operating-point solver state。
- hot Current/Power/Voltage 保持各自 MOP baseline 命令。
- cold Current/Power 从零电负载开始，允许供气建立后通过显式 profile ramp 到目标；Voltage 保持原 baseline 启动语义。
- `inletSpeciesMetrics` 允许冷启动 ramp 前的零阴极入口流量，并将有限性和尾窗供气建立交给后续 KPI 审计。
- 更新 boundary input 的历史 v09 注释，明确当前 runner 已使用 v10 bundle。
- `routeA_model_contract` 已将 formal hot-start 状态从 `blocked_until_S4_current_topology_metadata` 更新为 `available_v10_current_topology_bundle`，并实际读回三分支 metadata、共同 hash 和当前供气边界。

## 2. 实际验证证据

### 2.1 候选初态

| 分支 | snapshotTimeS | I [A] | V [V] | P [kW] | 最大周期相对变化 | quietWindowPurgeFree |
|---|---:|---:|---:|---:|---:|---:|
| Current | 9484.140458 | 28.000000 | 427.648894 | 11.974169 | 0.0016820066 | 1 |
| Power | 9492.157732 | 28.000016 | 427.648656 | 11.974169 | 0.0016496532 | 1 |
| Voltage | 9990.473040 | 28.250932 | 427.539472 | 12.078389 | 0.0015041702 | 1 |

三者最大周期相对变化均小于 `0.005`。

### 2.2 依赖、contract 和挂载

| 验证 | 实际结果 |
|---|---|
| `routeA_check_dependencies(..., true)` | `passed=1`，errors=`0`，warnings=`0` |
| `routeA_model_contract` | `passed=1`，errors=`0`，warnings=`0` |
| Current/Power/Voltage attach | 三者均 `mode=hot`，`useOperatingPoint=1`，共同 hash 与 formal bundle 一致 |
| Code Analyzer | 本轮新增和修改 MATLAB 文件均无 code issues |

### 2.3 短时 I/P/V hot-start smoke

三类测试均使用正式 bundle、`hotStartPolicy=hot`、`researchDuration=2 s`、`MaxStep=5 s`、严格 operating-point interface checksum 门禁：

| 分支 | simCompleted | study.passed | 结果 |
|---|---:|---:|---|
| Current | 1 | 1 | PASS，尾部 `I=28 A`，`lambda=4.1975` |
| Power | 1 | 1 | PASS，boundary error `2.4033e-14 kW`，`lambda=4.1974` |
| Voltage | 1 | 1 | PASS，boundary error `0.0002638 V`，`lambda=4.1602` |

严格 interface checksum 门禁下未再出现 solver state 被丢弃的 warning。

### 2.4 cold-start direction smoke

- 工况：Current，显式 profile `[0,0; 60,28; 65,28]`，`hotStartPolicy=cold`，总时长 `65 s`，尾窗 `[60,65]`。
- 实际结果：`simCompleted=1`、`study.passed=1`、`matrixComplete=1`。
- 尾窗 KPI：`I=27.999 A`、`P=11.905 kW`、`V=425.18 V`、`lambda=4.1975`、实际 cEGR ratio `1.5466e-6`。
- 初次 2 s cold 对照曾在 `Mdot Denominator Guard` 触发连续过零；根因是 cold policy 错误沿用热初态 baseline 电命令，并非正式 cold ramp 的供气建立失败。修正启动命令和零流量审计后，65 s cold ramp 通过。

### 2.5 结构状态

- `model_check`：`status=warnings`，`total_warnings=77`，无 error 级结果。
- warning 仍集中在已有 Simscape 物理端口、传感器和接口层；本轮未修改 `.slx` 物理网络。
- 仿真后模型保持 `Dirty=off`，未执行 `save_system`。

## 3. 未解决风险与下一步

1. （本记录原始时点）现有 77 条结构 warning 尚未完成逐项 warning ledger 复核；当前只确认无 error 且不阻断 I/P/V/cold smoke。当前状态见本记录第 5 节和 2026-07-29 warning ledger。
2. 当前已验证的是初态生成、挂载和短时启动闭环；Power/Voltage 正式 600 s 稳态矩阵和更长时间边界研究仍待后续研究任务验证。
3. `routeA_topologyHash` 当前基于磁盘重载模型 fingerprint；若以后修改 `.slx` 或 Model Workspace source，必须重新生成并原子提升全部 I/P/V 初态。
4. 99 个 inventory 参数仍不应直接开放到面板，除非完成范围、block/workspace 映射、compile 行为和物理响应验证。

## 4. 保留产物

- 保留正式 v10 I/P/V bundle：`RouteA_platform_default_initial_state.mat`。
- 保留被替换的旧 formal 初态归档文件，用于恢复和审计。
- 候选 `.mat` 已在原子提升后清理，没有保留重复候选副本。

## 5. 2026-07-29 资产处置更正

本分卷前述 hot-start 生成、挂载和 2 s smoke 是已发生的历史验证事实，不回写删除。根据后续 cold-start-only 裁决，正式活动链不再使用这些资产；helper 与 bundle 已移入 `99_历史归档/2026-07-29_RouteA_hot_start_retired/`，当前只保留历史审计和 provenance 对照用途。当前 cold 回归证据以 [S5 当前分卷](RouteA_cEGR_PEMFC_实施记录_20260728_S5分层验证与正式矩阵首轮_v01.md)第 6 节为准。
- 保留 Simulink 运行缓存 `slprj/`、`.slxc` 和当前 MATLAB 会话缓存；未生成额外截图、CSV、报告或模型副本。
