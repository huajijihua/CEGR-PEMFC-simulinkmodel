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
