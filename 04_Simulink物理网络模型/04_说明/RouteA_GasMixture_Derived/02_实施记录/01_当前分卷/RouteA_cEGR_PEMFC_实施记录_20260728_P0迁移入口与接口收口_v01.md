# Route A cEGR-PEMFC P0 迁移入口与接口收口实施记录

文件类型：实施记录（P0 连续实施线）<br>
记录日期：2026-07-28<br>
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`<br>
对应计划：[P0 迁移与接口收口实施计划](../../01_当前指导/RouteA_cEGR_PEMFC_P0_迁移与接口收口实施计划_v01.md)

## 1. 实际完成工作

### 1.1 路径和启动入口

- 新增 `routeA_project_paths.m`，从自身文件位置解析项目根、Simulink 工作树、模型目录、脚本目录、模型文件和 Model Workspace 源文件。
- 新增 `launch_routeA_panel.m`，启动前执行依赖检查和 model contract 检查，再创建现有 `RouteA_Panel_v01`。
- 新增 `routeA_check_dependencies.m`，检查 MATLAB R2025b 基线、Simulink、Simscape、FuelCell_lib、模型文件和核心脚本。
- `FuelCell_lib` 通过 MATLAB 逻辑库名解析到当前安装位置，没有把 `D:\matlab2025b` 写入运行入口。
- `PEMFuelCellSystemWithACustomLibraryParameters.m` 的相邻 MAT 文件读取改为基于 `mfilename('fullpath')`，不再依赖当前工作目录。

### 1.2 参数、观测量和模型契约

- 新增 `routeA_parameter_registry.m`：
  - 总登记项：123；
  - 当前可运行 active 项：24；
  - platform_default inventory 项：99；
  - 未完成范围、模型映射或编译行为验证的 inventory 项不作为 UI 开放项。
- 新增 `routeA_observation_registry.m`：登记 `logsout`、SimulationOutput 和 unresolved 观测量。
- 新增 `routeA_validate_observation_output.m`：用真实 `SimulationOutput` 核对注册信号。
- 新增 `routeA_model_contract.m`：读回 block path、Model Workspace 变量、22 列 profile schema、输入分层和初态状态。
- 观测量首次实际读回发现：RH、物种流量、水分离和排气流量来自 SimulationOutput ToWorkspace；cEGR 质量流量的真实日志名为 `EGR_mdot_log`；压力实际以 Pa 记录，温度实际以 K 记录。注册表已按实际输出修正。

### 1.3 面板链路

- `RouteA_Panel_v01.m` 保存平台路径状态，并在单工况和矩阵运行前执行 model contract 检查。
- 面板单工况和矩阵运行在结果提取前执行观测量契约检查。
- `routeA_panel_build_simulation_input.m` 和 `routeA_panel_run_matrix.m` 改用统一路径解析，不再重复拼接模型目录。
- `.slx` 物理网络没有结构修改，面板仍为程序化 `.m` 主文件。

### 1.4 初态旧契约处置

- `routeA_attach_platform_default_initial_state.m` 不再把 Source Conditioner 物理参数作为当前模型的有效兼容条件。
- 旧 `sourceConditionerState` metadata 会明确报 `RouteA:InitialStateLegacySourceConditionerContract`。
- 缺少当前 Air Intake/Hydrogen Source metadata 的热初态会明确报 `RouteA:InitialStateCurrentTopologyMetadata`。
- 当前平台仍以 cold mode 为可运行基线；v10 当前拓扑热初态生成和热启动 smoke 进入 S4，不在本记录中宣称完成。

## 2. 实际验证证据

### 2.1 外部目录启动和预检

MATLAB 当前目录固定为：`C:\Users\ADMIN\AppData\Local\Temp\opencode`。

| 验证 | 实际结果 |
|---|---|
| 路径解析 | 解析到当前项目模型和脚本目录，未使用当前目录 |
| 依赖检查 strict=true | `passed=1`，errors=`0`，warnings=`0` |
| model contract | `passed=1`，errors=`0`，warnings=`1` |
| 唯一 warning | 当前初态文件仍需 S4 当前拓扑验证 |
| 一键面板入口 | `RouteA_Panel_v01` 创建成功，UI 可见 |

### 2.2 单工况和矩阵

| 工况 | 实际结果 |
|---|---|
| Current 100 A，10 s cold smoke | 无 `ErrorMessage`；面板运行完成，KPI 表写入 1 行 |
| Current 100 A，10 s 观测契约 | 26 个注册项，20 个 required，required 缺失 `0` |
| Current 100 A，cEGR `[0, 0.1, 0.3]`，10 s serial matrix | 3/3 PASS |
| Current 100 A，600 s | `V=409.976923 V`，`I=100.000000 A`，`P=40.997692 kW`，无 `ErrorMessage` |
| Current 100 A，600 s 观测契约 | `passed=1`，required 缺失 `0` |

10 s smoke 的尾窗 KPI 为 `V=453.442894 V`、`I=24.473689 A`、`P=10.102860 kW`；由于仿真时间短于默认 60 s 尾窗，该结果只作为启动/输出契约证据，不作为稳态性能基线。

### 2.3 静态和结构检查

- 本轮新增和修改的 MATLAB 文件 Code Analyzer 无 error/warning；面板既有无效隐藏消息已清理。
- `model_check`：`status=warnings`，`total_warnings=77`，无 error 级结果；warning 仍集中在现有 Simscape 物理端口、传感器和接口层。
- 仿真后模型 `Dirty=off`，未执行 `save_system`，未修改 `.slx`。

## 3. 未解决风险与下一步

1. `routeA_generate_platform_default_initial_state.m`、`routeA_promote_platform_default_initial_state_bundle.m` 和正式 runner 的 v10 metadata 生成/合并链仍引用旧 `sourceConditionerState`，需要在 S4 统一改为当前官方 Air Intake/Hydrogen Source 契约。
2. 99 个 inventory 参数尚未全部完成范围、block/workspace 映射、compile 行为和物理响应验证，不得直接开放到面板。
3. （本记录原始时点）现有 77 条结构 warning 尚未完成逐项 warning ledger 复核；P0 只确认本轮没有新增 error。当前状态见本记录第 5 节和 2026-07-29 warning ledger。
4. `.mlapp`、完整阳极/冷却观测面板、完整结果包和大规模矩阵不属于本阶段完成内容。

## 4. 保留产物

- 保留 Simulink 运行缓存 `slprj/`、`.slxc` 和当前 MATLAB 会话缓存，未纳入 Git。
- 未生成额外截图、CSV、模型副本或批量中间文件。

## 5. 2026-07-29 读回更正

本记录第 3 节反映的是 P0 初始收口时点。随后已完成当前 root scope 的 77 条 `unconnected_ports` 逐条 ledger，见 [warning ledger](../../03_审计与研究/RouteA_cEGR_PEMFC_model_check_warning_ledger_20260729_v01.md)。当前活动初始化链也已固定为 cold-start-only，热启动 helper/bundle 已移入 `99_历史归档/2026-07-29_RouteA_hot_start_retired/`；因此第 3 节中关于 v10 metadata 生成链和 warning ledger “尚未完成”的内容不代表当前状态。
