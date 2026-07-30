# Route A cEGR-PEMFC 实施记录：P1 面板单工况与结果契约

日期：2026-07-29
对应计划：[P1 完整燃料电池系统面板基础版实施计划](../../01_当前指导/RouteA_cEGR_PEMFC_P1_完整燃料电池系统面板基础版实施计划_v01.md)
状态：本次连续实施线已完成当前验证项，P1 整体仍在实施中

## 1. 实际完成的工作

1. 在 `RouteA_Panel_v01.m` 中修复 KPI 表写入问题：将 `results.caseId` 从 scalar `string` 转换为 `char`，避免 `uitable.Data` 类型错误。
2. 扩展 `routeA_panel_extract_results.m` 的面板结果契约，加入 `RouteA_Panel_Result_v01`、`compact_panel` 以及 stack/cathode/cegr/thermal/water 分域结果。
3. 扩展面板精简 KPI 表，显示 cEGR 目标/实际比例、回流量、阴极入口流量、阴极出口压力、入口/出口 RH 和分离水流量。
4. 在面板运行日志中加入 cEGR 目标/实际比例、回流量和阀压差摘要。
5. 新增 `run_routeA_p1_panel_single_case.m`，一次只运行一个 Current、Power 或 Voltage 工况；结果显式标记 `panelValidation.matrixExecuted=false`。
6. 在 `routeA_project_paths.m` 登记新增 P1 单工况入口。
7. P1 面板隐藏矩阵按钮；矩阵 helper 保留给后续研究阶段。

本次没有修改正式 `.slx` 模型结构，也没有把研究矩阵接入 P1 验证链。

## 2. 验证证据

### 2.1 MATLAB Code Analyzer

以下文件均返回 `code_issues=[]`：

- `RouteA_Panel_v01.m`
- `run_routeA_p1_panel_single_case.m`
- `routeA_panel_extract_results.m`

### 2.2 独立单工况入口

以下结果来自 MATLAB workspace 中的实际 `SimulationOutput` 结果。四个 case 均为 `passed_with_warnings`，`gasClosurePassed=1`，且 `matrixExecuted=0`。

| Case | 电边界命令 | 尾窗 V | 尾窗 I | 尾窗 P | cEGR 目标 | cEGR 实际 |
|---|---:|---:|---:|---:|---:|---:|
| `p1Current` | Current 100 A | 409.982 V | 100.000 A | 40.998 kW | 0 | 0 |
| `p1Power` | Power 40 kW | 410.391 V | 97.468 A | 40.000 kW | 0 | 0 |
| `p1Voltage` | Voltage 410 V | 409.857 V | 100.360 A | 41.133 kW | 0 | 0 |
| `p1Cegr` | Current 100 A | 409.073 V | 100.000 A | 40.907 kW | 0.1000 | 0.1000 |

`p1Cegr` 的实际回流量为 `0.004252 kg/s`，阀压差为 `0.060775 MPa`。

### 2.3 真实面板回调

- `P1_ui_result_contract`：Current 100 A，状态 `passed_with_warnings`，矩阵按钮 `off`，KPI 表 11 列、1 行。
- `P1_ui_cegr_100A`：Current 100 A、cEGR 目标比例 0.10，状态 `passed_with_warnings`，矩阵按钮 `off`，KPI 表 13 列、1 行。

### 2.4 工程契约检查

- `routeA_check_dependencies(pathsP1, false)`：通过，0 errors，0 warnings。
- `routeA_model_contract(pathsP1, ...)`：通过，0 errors，0 warnings。

## 3. 警告和边界

1. Rapid Accelerator 仍不记录 Simscape 数据。
2. 若干 To Workspace 块使用 `Timeseries`，在 rapid accelerator 下不记录；该警告发生在拓扑 checksum 读取链中。
3. 观测注册表仍无法提供部分单位元数据，出现 A、kW、kg/s 单位警告。
4. 当前结果契约明确标记 L2 液水库存、液水输运、排水、分离效率和完整水闭合未建立；不得把分离水信号解释为完整液水衡算。

## 4. 未决项

- P1 其他系统域控件和参数白名单尚未全部完成。
- 当前只完成代表性独立工况，不开展研究矩阵；最终 P1 状态需用户联合评审确认。
- 本次没有发现需要修改 `.slx` 的模型级阻塞；后续若出现面板接口无法覆盖的真实模型缺口，需另立最小模型变更记录并做 read-back。

## 5. 本次 P1 面板壳升级（2026-07-29）

本次连续实施线把面板推进到“按系统域查看结果”的新阶段，未重复运行上一轮工况，也未将研究矩阵接回 P1：

1. `RouteA_Panel_v01.m` 增加固定页眉、系统域导航、可滚动配置画布和基础/高级模式边界；基础输入首屏包含电边界、阴极进气、cEGR、求解器、温度、Case ID 和单工况运行按钮，后续系统域保留在滚动区。
2. 结果区改为六个页签：总览、阴极、cEGR、热/水、时序、追溯/诊断；结果表按结果契约分域显示，水管理继续显示 `L2_not_closed` 和能力范围，不扩大为完整液水闭合声明。
3. 结果级别默认 `compact_panel`；只有显式切换到 `full_export` 后才允许导出完整结果。新增清空结果按钮，清空操作不修改当前输入或模型。
4. `routeA_parameter_registry.m` 新增堆温设定的 active 注册项，并为参数项写入 `panelExposure`、`applyAction`、`validationGate` 和 `unsupportedReason` 元数据；`routeA_observation_registry.m` 同步写入结果/状态-only 面板元数据。
5. `routeA_project_paths.m` 增加 `outputs/RouteA_Panel` 作为显式结果导出根目录。

### 5.1 实际读回证据

- MATLAB Code Analyzer：`RouteA_Panel_v01.m`、`routeA_parameter_registry.m`、`routeA_observation_registry.m`、`routeA_panel_extract_results.m`、`routeA_project_paths.m` 均返回 `code_issues=[]`。
- 非仿真面板启动：实际读回六个结果页签、配置画布尺寸 `555 x 1160`、结果页签组位置和九行系统域状态表，MATLAB UI 对象创建成功。
- 输入契约读回：`case1 / Current / stop=600.0 s / ramp=60.0 s`，`routeA_validate_case` 通过。
- 注册表读回：参数 `total=124, active=25, basic=13, advanced=12`；观测 `total=26, result=22, status_only=4`。
- 视觉检查图：`04_Simulink物理网络模型/outputs/RouteA_Panel/RouteA_P1_panel_layout.png`。该文件仅用于本次布局检查。

本次没有写入正式 `.slx`；工作树中已有的模型修改保持原样。完整结果导出和新工况行为验证留待面板进入下一阶段后统一执行。

## 6. 面板布局修复与三工况回归（2026-07-29）

### 6.1 问题定位与修复

用户通过面板运行恒电流 100 A 后，仿真和结果提取均完成，但状态栏显示“无法从 struct 转换为 char”。现场日志确认失败发生在 `RouteA_Panel_v01.addResultToTable` 的结果视图回写阶段；`routeA_panel_extract_results.m` 中 `results.modelVersion` 按设计保留为包含 `fileName`、`bytes` 和 `modified` 的追溯结构体，诊断表此前直接调用 `char(results.modelVersion)`。

本次将模型版本改为面板只读追溯文本格式，不破坏结果 contract 中的结构化 provenance；同时关闭导航、配置画布、左/右结果容器的自动子控件缩放，并在最大化后强制执行一次统一布局。高级参数、Case ID 和运行按钮不再互相覆盖。

### 6.2 三个独立单工况实际结果

以下均使用 `run_routeA_p1_panel_single_case.m` 的单工况入口；恒电流额外通过真实面板回调 `p1Current_ui_fixed` 重跑，以验证 UI 回写修复。

| Case | 入口 | 结果状态 | 尾窗 V | 尾窗 I | 尾窗 P | 气体闭合 | 矩阵执行 |
|---|---|---|---:|---:|---:|---:|---:|
| `p1Current_ui_fixed` | 面板回调，Current 100 A | `passed_with_warnings` | 409.980 | 100.000 | 41.000 | 1 | 0 |
| `p1Power_fixed` | 单工况入口，Power 40 kW | `passed_with_warnings` | 410.391 | 97.468 | 40.000 | 1 | 0 |
| `p1Voltage_fixed` | 单工况入口，Voltage 410 V | `passed_with_warnings` | 409.857 | 100.360 | 41.133 | 1 | 0 |

MATLAB 读回的面板状态为 `passed_with_warnings`，诊断表模型版本已正常显示，日志中无 `✗ 失败` 标记。保留的 warnings 仍包括 rapid accelerator 下 Timeseries 不记录、单位元数据不完整和 L2 液水闭合未建立；这些不构成当前三工况的求解失败，但仍限制水管理结论范围。

## 7. 面板参数扩展与统一输入链读回（2026-07-30）

本轮按“面板能带动当前模型并回传结果”为主线推进内容扩展，不重复运行历史工况，也未修改正式 `.slx`：

1. `RouteA_Panel_v01.m` 在高级区增加 10 个阳极输入：源压力、源温度、H2 分数、入口压力、阳极 RH、回流基础命令、回流电流增益、吹扫启用、吹扫开启 N2 阈值和吹扫关闭 N2 阈值。阳极输入统一收集到 `simCase.controls.anode`，不由 callback 直接写模型。
2. 参数目录接入 `routeA_parameter_registry`：实际读回 `registry.count=139`、`activeCount=40`、`inventoryCount=99`。active 项显示真实应用动作，inventory 项只读展示，不创建无效输入框。设备与控制器导航已改为直接定位参数目录；阳极输入导航定位高级区。
3. `routeA_prepare_electrical_boundary_input` 为面板输入增加 `tank_yH2` 的 `SimulationInput.setVariable` 写入；阳极其他控制量由统一 `routeA_command_profile` 传递。当前 profile 实际读回为 `23` 列，即时间列加 22 个控制字段。
4. 非仿真面板读回使用一组合法阳极值：源压力 `0.35 MPa`、源温度 `30 C`、H2 `0.995`、入口压力 `0.18 MPa`、RH `0.65`、回流基础 `0.25`、回流增益 `0.003`、吹扫 `1`、阈值 `0.55/0.12`；`routeA_validate_case` 和 profile 装配通过。
5. 非法输入读回：源压力 `0.16 MPa`、入口压力 `0.18 MPa` 被仿真前校验阻止，返回 `RouteA:ValidateRange`。此前发现的逻辑型吹扫开关传入 profile 的类型问题已修复为数值模型字段。
6. `RunButtonPushed` 和矩阵入口现在在运行期间锁定输入、导航、模式切换和结果级别选择，结束后恢复当前模式的互斥/灰显规则；导出按钮按是否存在可导出结果恢复状态。
7. `routeA_panel_build_simulation_input` 非仿真装配读回通过，`SimulationInput` 中确认存在 `tank_yH2`、`routeA_command_profile` 和 `env_yH20` 等变量；该检查触发的已知 Timeseries/Rapid Accelerator 警告与现有模型记录一致。

本轮没有执行 `sim()`，因此新增阳极输入对模型输出的物理响应和阳极结果观测仍未宣称已验证；阳极结果继续按 status-only/待确认显示。最新面板窗口已保持打开，供后续继续扩展窗口内容和由用户进行联合操作检查。

## 8. 系统模型参数第三层（2026-07-30）

本轮按用户确认把现有系统参数目录正式放入配置区第三层“系统模型参数”，不重复运行历史工况，也没有修改正式 `.slx`：

1. `RouteA_Panel_v01.m` 增加“基础 / 高级 / 系统模型参数”三态互斥页签；系统模型参数页与基础、高级输入页分离，导航项改为“系统模型参数 / 设备目录”。从高级页切入目录页时先同步当前输入，避免回到面板运行时丢失高级设置。
2. 参数目录保留实际 registry 的 `139` 行（`active=40`、`inventory=99`），设备性能类参数优先显示，覆盖电堆/MEA、空压机、中冷器、加湿器、阀/管路、分离器、腔体和热管理等平台参数；控制默认值、数值设置和环境参数仍保留在完整目录的后段。
3. 目录表扩展为 `8` 列：`canonicalName`、中文参数含义、设备/域、单位、默认值、开放状态、应用方式和模型映射。139 项均有中文含义；数组型默认值以实际数值摘要显示，不再只显示 MATLAB 类型名。
4. `active` 项显示基础页/高级页可编辑及其运行前应用方式；`inventory` 项显示“目录只读 / 待模型接口接入”，不生成无效编辑框。第三层当前是完整设备参数目录和后续开放入口，不把尚未闭合的模型写入点伪装成已生效控件。

### 8.1 实际读回证据

- MATLAB Code Analyzer：本轮仅保留参数目录 mapping 动态增长的 info 级性能提示，无 error/warning 级问题；`git diff --check` 通过。
- 面板实际创建成功，默认状态为基础页；第三层切换读回为 `FutureDomainsPanel.Visible=on`、基础/高级页隐藏，返回高级和基础均恢复互斥显示。
- 参数表实际读回 `139 x 8`；首行设备参数为 `platform.stack.num_cells`，中文含义为“电堆单体数量”，设备域为“电堆 / MEA”。所有行的中文含义非空。
- 当前最新 `routeA_latest_app` 窗口保持打开；本轮没有执行 `sim()`，也没有宣称设备参数已经对模型产生物理响应。后续逐项开放设备参数时仍需补齐真实写入点、范围和模型反馈。
