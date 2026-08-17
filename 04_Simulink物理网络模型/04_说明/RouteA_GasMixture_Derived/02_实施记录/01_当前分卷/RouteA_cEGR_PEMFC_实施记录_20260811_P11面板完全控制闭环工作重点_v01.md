# Route A cEGR-PEMFC P11 面板完全控制闭环工作重点

## 范围

本记录固化后续面板-模型双向迭代的工作重点：面板不是参数目录的展示层，而是仿真人员输入基础工况、高级工况和设备参数、运行统一模型并读取结果的完整操作入口。

## 本次确认的处置原则

1. **设备目录非编辑项分层处置**（本轮前为 67 项；B1 后当前为 `74` 个 `platform_default` 源目录项 + `1` 个未接入审查项）：
   - 模型已引用、尚未开放：进入优先开放审查，完成来源、单位、范围、校验器、写入路径、编译要求和代表性响应证据后加入面板；本轮 B1 已完成其中 10 项；
   - 当前活动模型未引用：核对面板计算链用途；无用途的历史遗留项移除或归档，有用途的先补齐模型接入；
   - 派生量、结构量和编辑器组成员：保留参数含义和映射说明，不提供独立数值框，由规范输入或成组编辑器完成推导和原子提交；
   - 内部建模或初始化量：保留在“系统模型参数”只读页，不伪装成仿真人员输入。
2. **52 个未引用/辅助工作区变量**：逐项确认其是否参与当前模型或面板计算链。物性表、查表数据和必要配置元数据保留为内部只读；无用途的历史别名、profile shadow 和未接入变量移除或归档；确有研究用途的变量补齐模型接线后重新审计。
3. **21 个模型已引用但待开放变量**：作为当前模型功能缺口清单，按研究价值和开放风险排序推进；不是所有变量都必须变成输入框，内部建模/初始化变量继续只读。原 24 项候选中的 `drive_cycle_time`、`tank_yH2` 和 `radiator_tube_Leq` 已确认由现有 profile/设备几何派生链覆盖。
4. **操作闭环**：

   `基础页/高级页/系统设备参数设置 -> draftSimCase -> routeA_validate_case -> SimulationInput -> PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01 -> SimulationOutput -> 面板结果`

   “系统模型参数”页只读展示完整模型参数、物理含义、所属子系统、引用状态和面板承接状态。

## 本次实际更新

- 更新 `RouteA_cEGR_PEMFC_P5_仿真平台前端输入能力_v01.md`，固化 B1-B3 后的设备目录、21 项处置和 52 项辅助变量规则。
- 更新 `RouteA_cEGR_PEMFC_模型-面板参数汇总表_v01.md` 的维护规则，明确模型引用但未开放参数应进入开放审查，`workspace_only` 参数必须先确认用途。
- 修正 `RouteA_Panel_v01.m` 模型页顶部残留旧计数文案，改为关系性说明并由动态审计状态显示数量。

## 当前证据

- 参数审计当前读回：工作区变量 `138`，实际引用 `86`，其中面板已承接 `81`、只读内部/结构变量 `5`，未引用/辅助 `52`，异常映射 `0`。
- 设备目录当前读回：`129` 行，其中可编辑 `54`、`platform_default` 源目录 `74`、未接入审查 `1`。目录高于原计划 `121` 的原因是新增默认参数叶项按源目录规则自动展开，不是活动输入超额。
- 面板契约回归：`passed=1`，`advancedMappingPassed=1`、`devicePageMappingPassed=1`、`modelPanelAuditPassed=1`，未启动仿真，正式模型 `Dirty=off`；保留既有 `To Workspace/Timeseries` checksum 警告。
- 代表性 cold-start smoke：B1 设备扰动工况 `B1_SMOKE_OK`；B2 环境/PID/直接 cEGR 工况以及环境/PID、目标比例 cEGR 对照均在 Solver Configuration 初始条件阶段报 `physmod:simscape:engine:core:dae_errors:NE_DAE_IC_Failure`。因此 B2 的 SimulationInput 写入链已读回，但组合工况的物理响应尚未通过。

### B2 初始化失败诊断

在 Codex MCP MATLAB 桌面会话中对同一正式模型执行了变量隔离：

| 对照工况 | 结果 | 结论 |
|---|---|---|
| 只改 `routeA_air_pid_Kp/Ki`，环境默认、cEGR 关闭 | `PID_ONLY_OK` | 空气 PID 写入和该数值组合不是根因 |
| 只改 `routeA_egr_valve_area_direct`、`routeA_target_egr_ratio_comp_in`，环境默认 | `DIRECT_ONLY_OK` | 直接 cEGR 参数写入和默认环境下可完成初始化 |
| 只改 `env_T=32 degC`，cEGR 关闭 | `NE_DAE_IC_Failure` | `env_T` 单独即可触发初始化失败 |
| 只改 `env_p=0.095 MPa(abs)`，cEGR 关闭 | `NE_DAE_IC_Failure` | `env_p` 单独即可触发初始化失败 |

补充对照：将 `env_T=20 degC`、`env_p=0.101325 MPa(abs)` 显式恢复为 `platform_default`，保留 B2 的 `Kp=6`、`Ki=0.6` 和直接 cEGR 面积/目标比例，5 s cold-start smoke 返回 `ENV_DEFAULT_SMOKE_OK`。默认环境下可以正常初始化和运行，进一步确认环境边界改动是当前失败触发条件。

两个环境变量均在 `SimulationInput` 中被正确读回，且数值处于面板声明范围；32 degC 和 0.095 MPa(abs) 也是物理上合理的环境边界。因此首个真实问题不是输入值越界，也不是 `SimulationInput.setVariable` 失效，而是模型环境边界的初始化一致性缺口：

- `env_T/env_p` 被同时用于阳极、阴极、堆芯和热管理多个块的 `T0/p0` 或环境温度；
- `Oxygen Source/Air Intake` 仍固定为 `T0=293.15 K`、`p0=101325 Pa`，没有跟随 `env_T/env_p`；
- 冷却液罐 `Coolant Volume` 的 `environment_pressure` 仍固定为 `0.101325 MPa`，只把 `p0` 绑定到 `env_p`；
- 因此改变环境变量会把同一 cold-start 网络中的边界初值拆成不一致的温度/压力集合，Simscape 在 `Solver Configuration` 的 DAE 初始条件求解阶段无法找到一致初态。

这属于模型边界/初始化接口设计问题，不能通过放宽面板范围解决。后续应先统一空气入口、冷却液罐和所有 cold-start 初值的环境来源，再恢复 `env_T/env_p` 的物理响应验证；在此之前它们虽已完成面板写入接入，但不应被宣称为已完成行为验证。

## 今日小结与明日任务

### 今日小结

今天的工作重点是完善面板用户输入能力：把 21 个模型已引用但待开放变量按 B1-B3 分流，完成 10 项 BOP 标量设备参数和 6 项环境/控制参数的注册、默认值、范围校验、面板控件、草稿同步和 `SimulationInput` 写入适配；同时将 5 项内部/结构/数值保护变量留在模型参数页只读追溯。当前审计口径为 `138 = 81 面板承接 + 5 只读 + 52 未引用/辅助`，活动契约 102，设备目录 `129 = 54 可编辑 + 74 源目录 + 1 未接入审查`。面板契约、UI 读回、B1 smoke 和默认环境下 B2 对照均通过。

### 明日任务

1. 修复 `env_T/env_p` 与空气入口、冷却液罐及 cold-start 初始条件之间的统一边界来源，先通过默认环境和扰动环境的初始化对照。
2. 在环境边界修复后，重新验证 B2 的环境/PID/直接 cEGR 参数，并回归 Current/Power/Voltage 结果契约。
3. 对设备目录的 74 个 `platform_default` 源目录项和 1 个未接入审查项继续做逐项用途分类，明确保留只读、补接入或归档。
4. 审计 52 个未引用/辅助工作区变量，区分物性/配置支撑与历史遗留产物，形成可执行的归档清单。
5. 最后再做一次模型-面板数量关系、默认值恢复、非法值拦截和正式模型 `Dirty=off` 的出口回归。

以上是 B1-B3 实施前的基线证据；当前收口后的计数和处置见上方“当前证据”和“本轮 B1-B3 实施结果”。

## 本轮 B1-B3 实施结果

### B1 BOP 标量

10 项参数已完成 registry、默认值、设备页控件、草稿同步、恢复默认、联合范围校验和 `SimulationInput` 写入适配。设备页的目录状态与 54 个可编辑契约一致。

### B2 研究工况与控制

6 项参数已进入高级页。`env_T/env_p` 使用独立环境边界入口；空气 PID Kp/Ki 仅在空气控制器有效路径参与写入；直接 cEGR 面积和目标比例仅在控制模式 2 启用，模式 1 仍使用现有目标比例闭环入口。

### B3 只读内部/结构变量

以下 5 项不增加输入框：`anode_tube_D`、`cathode_tube_D`、`cegr_comp_map_t_denom_epsilon`、`stack_num_channels`、`stack_w_channels`。模型参数只读页显示物理含义、引用块、默认值、只读原因和后续开放条件。

## 下一步未决工作

1. 对当前 `74` 个 platform_default 源目录项和 `1` 个未接入审查项继续增加逐项处置分类和 owner；
2. 对 52 个未引用/辅助变量执行模型引用、面板计算链和历史来源检查；
3. 先处理 B2 组合工况的初始条件收敛问题，再补充环境/PID/直接 cEGR 的 cold-start smoke 和 Current/Power/Voltage 结果回归；
4. 用至少一个基础工况、一个高级工况和一个设备参数变更工况验证“输入-运行-结果”完整闭环。

## 状态

当前状态：**B1-B3 接口实现和契约审计已完成；代表性物理仿真 smoke 与 52 项辅助变量清理仍未完成。**

## 本轮首个逻辑切片：设备目录非编辑项语义收口

### 实际读回

- `67` 个设备目录非编辑项被拆解为 `66` 个 `platform.*` / `platform_default` 源目录叶项，以及 `1` 个 `device.cathode.intercoolerCondTau_s` 未接入审查项。
- 66 个源目录叶项来自 `routeA_platform_default_parameters` 的自动展开，不是 66 个额外的活动模型输入；设备页改为显示“platform_default 源目录 / 不单独编辑”，并在映射列显示实际来源路径。
- 未接入项改为显示“未接入审查 / 暂不编辑”，映射列显示其工作区变量 `intercooler_cond_tau`。

### 实际修改

- `RouteA_Panel_v01.m`：基线阶段设备状态栏为 `111 = 44 可编辑 + 66 platform_default 源目录 + 1 未接入审查`；B1 后动态状态栏读回当前 `129 = 54 + 74 + 1`。
- `routeA_audit_parameter_inventory.m`：审计报告增加 `deviceInventoryEntryCount` 与 `deviceUnresolvedEntryCount`，并将维护规则写入生成器，防止报告重生成时回退到旧口径。
- 重新生成模型-面板参数汇总表，正式模型读回 `Dirty=off`。

### 验证

- MATLAB 面板读回（基线）：设备目录 `111` 行；状态栏显示 `可编辑 44 + platform_default 源目录 66 + 未接入审查 1`。B1 后的最新读回见当前证据。
- 面板契约回归：`passed=1`、`simulationStarted=0`；现有 `To Workspace / Timeseries` checksum 提示仍为既有警告。
- MATLAB Code Analyzer：本轮仅有既有 `info` 级预分配提示，无新增 error/warning。

## 审计派生写入修正

继续核对待开放变量时发现，原 24 项中有 3 项已经由现有输入链覆盖，但此前未登记为派生写入目标：

| 模型变量 | 实际来源 | 处置 |
|---|---|---|
| `drive_cycle_time` | 电边界 current/power/voltage profile 的统一时间轴 | 不单独编辑 |
| `tank_yH2` | 阳极 H2 摩尔分数输入的编译期同步写入 | 不单独编辑 |
| `radiator_tube_Leq` | 散热器几何成组输入的等效长度推导 | 不单独编辑 |

审计脚本已登记这三类派生写入目标。当前真实数量更新为：`138 = 86 实际引用 = 65 面板已承接 + 21 待开放`，`52` 个未引用/辅助变量保持不变，异常映射为 `0`。

## 2026-08-12：环境压力固定化

### 前置决策

按 `RouteA_cEGR_PEMFC_P5_仿真平台前端输入能力_v01.md` 收敛环境边界：保留环境温度为用户输入，环境绝对压力回归平台标准大气压 `0.101325 MPa(abs)`，不再向用户暴露压力调节。

### 实际修改

- `RouteA_Panel_v01.m`：删除高级页 `AdvancedAmbientPressureEditField`；收集高级页草稿时把 `controls.environment.ambientPressure_MPa_abs` 固定为 `platform_default`。
- `routeA_validate_case.m`：非 `0.101325 MPa(abs)` 的压力工况返回 `RouteA:FixedAmbientPressure`。
- `routeA_prepare_electrical_boundary_input.m`：无条件向 `SimulationInput` 写入平台默认 `env_p`，不采用外部工况中的压力值。
- `routeA_parameter_registry.m`、`routeA_p1_panel_capability_matrix.m` 和参数审计：将 `env_p` 标为“固定平台边界 / 只读”，并重新生成模型-面板参数汇总表。
- `run_routeA_p1_panel_contract_tests.m`：增加“高级页不存在环境压力编辑控件”的回归断言。

### 验证

- `run_routeA_p1_panel_contract_tests`：`passed=1`、`simulationStarted=0`；高级页温度设为 `32 degC` 时，`SimulationInput.env_T=32`，`SimulationInput.env_p=0.101325 MPa(abs)`；手工写入 `0.095 MPa(abs)` 被校验器拒绝。
- 参数审计：工作区变量 `138`，活动输入契约 `102`，`panelWriteTargetMismatchCount=0`。
- MATLAB Code Analyzer：本轮修改文件无新增 error/warning；面板文件仅保留既有预分配 info。

### 未决项

本次只完成输入语义和写入链验证，没有启动物理仿真。此前已复现的 `env_T=32 degC` cold-start `NE_DAE_IC_Failure` 仍是独立的模型初始化问题；环境温度虽继续允许输入，但尚未完成物理响应验证。

## 2026-08-12：真实面板端到端单工况验证

### 验证目标与实际操作

- 目标：以正式面板验证 `打开面板 -> 检查/更改设备参数 -> 输入研究工况 -> 点击运行 -> Simulink 计算 -> 面板展示结果` 的完整操作链，而非通过独立 runner 代替面板调用。
- 正式模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；正式面板：`RouteA_Panel_v01`。
- 在可见面板中先切换至“设备参数”页，将中冷器面积由默认值改为 `0.0020 m^2`；再切换至“基础工况”页，输入 `caseId=UI_E2E_DEVICE_5A_5S`、恒电流 `5 A`、仿真时长 `5 s`、爬升时间 `0.5 s`、cEGR 关闭。环境温度保持 `20 degC`，环境压力固定为平台默认 `0.101325 MPa(abs)`。
- 通过面板实际 `RunButtonPushed` 回调执行；回调依次完成 UI 收集、工况校验、`SimulationInput` 构建、`sim`、观测契约校验、结果提取和结果视图刷新。

### 输入链读回与执行结果

- 面板收集后的 `simCase` 与构建后的 `SimulationInput` 读回一致：`device.intercoolerArea=0.0020 m^2`、`intercooler_area=0.0020 m^2`、`env_T=20 degC`、`env_p=0.101325 MPa(abs)`、电流剖面末值 `5 A`、爬升时间 `0.5 s`。该证据确认设备参数和工况参数均已写入正式仿真输入链；不据此宣称该设备参数的物理敏感性已经校核。
- 仿真正常完成并返回面板，尾窗为 `2.5--5.0 s`。面板显示：`V=446.18 V`、`I=5.00 A`、`P=2.23 kW`、`OER=3.00`、阴极出口压力 `0.16049 MPa(abs)`、入口/出口相对湿度 `0.893/0.382`、分水量 `0.00044 kg/s`。
- 结果页已新增 1 条 KPI 行、结果图像区已绘制 1 条曲线、导出按钮可用；界面状态为 `completed_gas_closure_failed`，并显示 `observations=verified`、`gasClosure=not_verified`、`waterCapability=L2_not_closed`、`cEGRAbility=disabled_or_zero_target`。

### 结论与未决项

- 对上述 5 A、5 s、常温、cEGR 关闭工况，面板到 Simulink 再到结果展示的操作闭环已实际执行并完成，结论级别为“行为已验证”。
- 本次不构成气体守恒、水能力或工程适用范围的物理验证：结果分类仍为 `gas_closure`，须沿模型闭合诊断主线处理。此前已发现的环境温度升至 `32 degC` 时的 Simscape DAE 初始条件失败也仍是独立未决项。

## 2026-08-12：P12 长时程真实工况与面板功能收口

### 前置决策

- 当前真源：`RouteA_cEGR_PEMFC_P5_仿真平台前端输入能力_v01.md` 与 `RouteA_cEGR_PEMFC_S6_被动cEGR研究规格与预检计划_v01.md`。
- 本切片不以 GUI 鼠标操作作为“真实”证据；用正式面板同一链路 `routeA_validate_case -> routeA_panel_build_simulation_input -> sim -> routeA_panel_extract_results`，以物理上有研究意义的 600 s、1800 s、3600 s 工况验证输入、计算和结果输出。
- 每例由完整 `routeA_simCase_template` 装配全部 101 项活动输入。电边界、空气模式和 cEGR 控制模式互斥，故以互补工况覆盖其有效路径；平台设备、阳极控制、热边界、源条件与求解器参数每例均显式装配，不把“未选中的互斥控制源”冒充已发生的物理作用。

### 实际修复

1. **无效 cEGR 阀型输入**：模型变体只有关闭（0）和开度限制（1），原面板曾允许阀型 2，导致 `VariantNoVariants`。现将 `cegr.valveMode` 固定为 1、面板只读展示；`routeA_validate_case` 与构建器对其他值返回 `RouteA:CegRValveMode`。
2. **直接空气冷启动**：直接空压机命令原在冷启动初值后阶跃，导致 EGR/空气路径 DAE 或分母保护零交叉。`routeA_assemble_command_profile` 将 `air_direct_command` 从 0 平滑爬升到用户值；`routeA_panel_build_simulation_input` 在调用方未给爬升时长时采用 `min(platform_default.startupRampDuration_s, 0.1*stopTime_s)`。
3. **控制模式验收**：直接空气和直接阀面积是低层开环命令，不能以 OER/质量流量或 cEGR 闭环比例跟踪门判失败。`routeA_assess_electrical_boundary_outputs` 现只对闭环 cEGR 严格跟踪；直接开度检查实际比可观测、有限且处于物理范围，并保留目标参考和实际响应供结果页显示。
4. **阳极吹扫实际读取**：结果提取改从 `simlog` 中 Anode BOP 的 `Purge_Valve.AR` 实际阀面积识别事件，而不再由阳极组分斜率臆测。面板诊断增加“阳极吹扫观测、全程事件数、尾窗事件数、尾窗 purge-free”。这只是实际阀动作诊断，阳极氮积累与完整阳极组成尚未纳入正式 KPI。

### 真实工况执行与读回

| 工况 | 主要研究设置 | 时长 | 实际读回 | 结果 |
|---|---|---:|---|---|
| `P12_PWR40K_OER30_CEGR030_600S` | Power 40 kW，OER 3.0，闭环 cEGR 0.30 | 600 s | 406.862 V，98.313 A，40.000 kW，实际 cEGR 0.299989，气体闭合/工程稳态通过 | `passed_with_warnings`；L2 水管理未闭合 |
| `P12_CUR100A_MDOT045_CEGR010_1800S` | Current 100 A，空气质量流量 0.045 kg/s，闭环 cEGR 0.10 | 1800 s | 408.329 V，100.000 A，40.833 kW，实际 cEGR 0.100000；首次实际吹扫 955.889 s，持续 8.226 s，尾窗事件 0 | `passed_with_warnings`；气体闭合/工程稳态通过 |
| `P12_V427648_BASELINE_CEGR0_3600S` | Voltage 427.648894 V，OER 3.0，cEGR 关闭 | 3600 s | 427.408 V，23.122 A，9.883 kW；实际吹扫 4 次，首次 724.529 s，尾窗事件 0；最大相对变化 0.015267 | `completed_not_steady`；物理计算到结束但未过 0.01 工程稳态门 |
| `P12_V410_DIRECTAIR_RAMPED_CEGR0_600S` | Voltage 410 V，直接空气命令 0.45，cEGR 关闭 | 600 s | 409.806 V，109.617 A，44.922 kW；气体闭合、工程稳态、尾窗吹扫判据通过 | `passed_with_warnings` |
| `P12_V410_DIRECTAIR_DIRECTCEGR020_600S` | Voltage 410 V，直接空气命令 0.45，直接阀面积 `3.927e-6 m^2`，参考 cEGR 0.02 | 600 s | 409.807 V，109.074 A，44.699 kW，实际 cEGR 0.013575；气体闭合、工程稳态通过 | `passed_with_warnings`；直接开度为物理响应，不宣称闭环 0.02 跟踪 |

所有运行环境为 `env_T=20 degC` 与固定平台大气压 `env_p=0.101325 MPa(abs)`。环境温度 32 degC 的初始条件 DAE 失败仍未解决，未把它改写为面板映射失败。

### 回归与当前出口

- `run_routeA_p1_panel_contract_tests`：`passed=1`，覆盖三种电边界、三种空气控制模式、设备写入、固定环境压力、无效阀型拒绝、默认爬升时长和直接空气冷启动斜坡；未启动测试仿真。
- `routeA_audit_parameter_inventory(false)`：工作区 138、模型引用 86、活动面板契约 101、模型映射 80、内部/固定 6、`panelWriteTargetMismatchCount=0`。设备目录为 129 行（54 可编辑、75 只读目录）。
- MATLAB Code Analyzer：`routeA_panel_build_simulation_input.m`、`routeA_assess_electrical_boundary_outputs.m`、`routeA_panel_extract_results.m`、`run_routeA_p1_panel_contract_tests.m` 无问题；`RouteA_Panel_v01.m` 仅保留 5 条既有 info 级预分配提示。

### 未决项

1. 3600 s 基线的尾窗最大相对变化仍为 0.015267；应基于实际阳极吹扫周期、氮积累和阴极/热状态建立周期稳态判据，不能用“严格不动”替代。
2. 阳极吹扫阀动作已可见，但阳极氮分数、积氮速率及完整组分尚未进入 22 项注册结果观测；不能据现有事件数报告阳极氮积累定量结论。
3. `env_T=32 degC` 冷启动的 `NE_DAE_IC_Failure` 仍需统一空气入口、冷却液罐和 cold-start 初值后处理。
4. 本轮优先完成了功能与物理执行验证；面板布局、排版和可视化优化留待后续独立切片。

## 2026-08-12：P12 左侧配置页布局与分组修复

### 修复范围

- 面板源文件：`03_脚本/RouteA_GasMixture_Derived/RouteA_Panel_v01.m`。
- 工况值、参数默认值、模型文件和参数写入链均未修改；本切片只处理左侧配置页的布局、滚动边界和分类标题。
- Case ID 与“运行单工况”从配置滚动容器提升到左侧固定底栏；长页面滚动不会遮挡运行入口。
- 基础页压缩并重排电边界、阴极进气/湿度、cEGR、求解器和温度边界区块。
- 高级页重新拉开电边界、阴极进气/组分/湿度、cEGR、热边界/求解器和阳极系统的段间距，修复 cEGR 控件与热/求解器标题及输入行的重叠。
- 系统设备参数页按电堆与 MEA、cEGR 回流支路、阴极 BOP、阳极 BOP、热管理分组，并为补充标量增加明确的子系统标题。
- 系统模型参数页将说明、当前草稿、最近运行快照和全量模型目录分离，避免顶部说明文字与表格相互覆盖。

### 实际验证

- MATLAB 中关闭旧面板并从当前源文件重载成功；读回 `UIFigure.Visible=on`，左侧栏与配置滚动区均为有效句柄。
- 分别显示基础、高级、设备、系统模型参数页并导出临时 QA 截图；四页均可见固定底栏，长页面内容位于底栏之上滚动。
- 对四页及基础子区块的所有可见直接子控件按 `Position` 做矩形相交检查，读回 `P12_OVERLAP_TOTAL=0`。
- `check_matlab_code(RouteA_Panel_v01.m)` 无 error/warning，仅保留既有 5 条 info 级预分配提示；`git diff --check` 通过。

### 结论与剩余风险

- 左侧配置 UI 的空白过大、长页面遮挡运行栏、系统设备参数分类不清和高级页控件重叠问题已完成代码级修复并通过当前面板实例的行为/几何验收。
- 本切片没有启动新的 Simulink 仿真；此前已完成的 600 s、1800 s、3600 s 物理运行证据仍有效。后续可在用户自行设置研究工况后继续做功能演示和结果展示优化。

## 2026-08-12：P13 输入控件悬停说明

### 实际修改

- 在 `RouteA_Panel_v01.m` 中增加统一 `applyInputTooltips` 配置，在面板创建完成后为基础、高级、设备参数、阳极输入和结果级别控件设置简短 Tooltip。
- Tooltip 只表达参数用途、单位或生效条件，不在页面增加常驻说明块；加湿器和 cEGR 的动态回调继续根据启用状态替换提示文字。
- 设备数值框由统一设备字段构造器提供默认设备输入提示，已存在的更具体提示保持不被覆盖。

### 实际验证

- 从当前源文件关闭旧窗口并重载面板成功；MATLAB 读回全部 `120/120` 个输入类控件（EditField、DropDown、CheckBox）均有非空 Tooltip。
- 关键控件读回示例：OER 提示说明仅 OER 模式生效；环境温度提示说明环境压力固定为平台标准值；设备参数提示说明会随本页设备参数写入本次仿真。
- MATLAB Code Analyzer 无 error/warning，仅保留既有 5 条 info 级预分配提示；`git diff --check` 通过；正式模型 `Dirty=off`。

### 结论

- 面板已具备“鼠标悬停查看简短注释”的统一交互能力，画面保持紧凑，操作人员无需额外打开帮助页即可理解输入项的基本用途和生效范围。
- 本切片未启动新的 Simulink 仿真，也未修改任何研究工况或模型参数写入逻辑。

## 2026-08-12：P14 仿真时长输入语义修正

- 用户指出长时程研究不应被提示文字限制为固定时长。检查确认基础页和高级页时长框实际运行校验接受任意正值，先前限制性来自 Tooltip 文案而非模型能力。
- 将基础/高级时长框 Tooltip 改为“任意正值均可，按研究目的设置，单位 s”，并把两个输入框的 UI `Limits` 明确设为 `[eps Inf]`，让负数在输入阶段即被拦截。
- MATLAB 重载读回：基础/高级 `Limits=[eps Inf]`，两处 Tooltip 均为任意正值语义；代码分析无 error/warning，仅保留既有 info 提示；`git diff --check` 通过。
- 未启动新的 Simulink 仿真，未修改模型和当前工况；600/1800/3600 s 仍只是此前已执行的代表性研究案例，不是面板限制。

## 2026-08-12：P15 Tooltip 物理含义全量重写

### 问题与修改

- P13 的设备页 Tooltip 使用了“设备参数：字段名；修改后写入本次仿真”这一模板，只重复标签，没有帮助操作者理解参数代表的部件、过程或影响路径，按反馈整体作废重写。
- 设备页逐项改为物理解释：例如 GDL 厚度说明气体扩散与液水迁移阻力，膜厚度说明质子传导与膜内水传输，中冷器面积说明空气/冷却侧换热能力，散热器翅片间距说明空气侧流阻与有效换热面积。
- 基础/高级页补充边界、控制、求解器与 cEGR 的作用机理；阳极页补充供氢、回流与氮积累触发吹扫的含义。动态 cEGR、加湿器回调也同步替换为物理状态说明。
- 删除面向操作者无用的内部变量名、单纯合法范围和“写入本次仿真”模板文字。

### 实际验证

- 当前源文件重载面板成功。遍历全部输入类控件读回：`120/120` 均有非空 Tooltip；扫描旧模板“设备参数：”和“修改后随设备输入写入”残留计数为 `0`。
- 抽查读回：GDL 为“影响反应气体扩散路径及液水迁移阻力”；cEGR PI Kp 为“比例偏差的即时阀面积修正强度”；阳极吹扫开启阈值为“氮气达到该比例时开始吹扫，阈值越低吹扫越早”。
- MATLAB Code Analyzer 无 error/warning，仅保留既有 info 级预分配提示；`git diff --check` 通过。本切片未运行新的 Simulink 仿真，也未修改模型或研究工况。
