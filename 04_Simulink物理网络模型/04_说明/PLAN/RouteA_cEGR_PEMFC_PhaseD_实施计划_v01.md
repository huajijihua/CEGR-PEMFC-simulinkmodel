# Route A cEGR-PEMFC Phase D 实施计划：面板与单工况闭环

文件类型：规划设计文件（Phase D 实施计划，覆盖式更新）  
日期：2026-07-28  
版本：v02  
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`

前置：

- [平台能力建设需求](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)
- [控制接口汇总表](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_控制接口汇总表_v01.md)
- [CR3 三要素 schema](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_CR3三要素schema_v01.md)
- [Phase D 前审计修复记录](../RouteA_GasMixture_Derived/02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260728_PhaseD前审计修复_v01.md)

## 1. 当前真实状态

本计划以当前模型和脚本实际内容为准，不沿用上一版“D3 仿真已触发”的未闭环表述。

### 1.1 活动资产

| 类型 | 当前资产 | 实际状态 |
|---|---|---|
| 唯一模型 | `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` | 活动模型，唯一 Route A `.slx` |
| 面板主文件 | `03_脚本/RouteA_GasMixture_Derived/RouteA_Panel_v01.m` | 可实例化的程序化 AppBase 类 |
| `.mlapp` | 计划中的 `RouteA_Panel_v01.mlapp` | 当前不存在；不作为 D3 接口修复的前置门槛 |
| 输入装配 | `routeA_panel_build_simulation_input.m` | D3-A 已修复并通过三模式装配及实际 `sim()` |
| 结果提取 | `routeA_panel_extract_results.m` | D3 已通过 KPI、时序和缺失信号拒止验证 |
| 模板与校验 | `routeA_simCase_template.m`、`routeA_validate_case.m` | Voltage 默认 PI 已由平台参数派生；显式不完整 PI 会拒止 |
| profile 装配 | `routeA_assemble_command_profile.m` | 22 列 profile 结构体 + `workspaceValue` 兼容矩阵已存在 |
| 矩阵 runner | `routeA_panel_run_matrix.m` | D4 首个 Power × cEGR 正式矩阵已通过 |

### 1.2 已完成与未完成边界

| 阶段 | 实际判定 | 依据 |
|---|---|---|
| D0 现状审计 | 已完成 | 已核对唯一模型、真实块路径、工作区变量、面板和 helper |
| D1 UI 原型 | 部分完成 | `.m` 面板有基础/高级布局和回调；`.mlapp` 尚未生成 |
| D2 参数绑定与校验 | 已完成（核心范围） | 基础/高级核心字段、Voltage PI、O2/H2O 和 T6-T8 已验证 |
| D3 单工况仿真 | 已闭环 | Current/Power/Voltage 600 s case、cEGR、O2 和面板 10 s smoke 均有证据 |
| D4 批量矩阵 | 首个矩阵已闭环 | Power 40 kW × cEGR `[0,0.1,0.3]`，600 s serial，3/3 PASS |
| D5 测试与收尾 | 进行中 | 当前实施记录已追加；完整测试矩阵、`.mlapp` 和最终收尾未完成 |

### 1.2.1 Phase D 之后的规划入口

用户已确认 Phase D 面板不是最终工具形态。D5 收尾后，后续工作转入“完整燃料电池系统面板 -> cEGR 研究扩展 -> 参数和观测量全面开放 -> 迁移交付”的连续平台建设主线。详细目标、部署边界、参数开放门槛、cEGR 目标比例/阀面积控制语义、精简/完整结果分级和 P0-P5 路线见：

- [面板-模型双向迭代规划](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_面板-模型双向迭代规划_v01.md)

该规划是后续目标，不改变 D3/D4 已完成事实，也不把尚未实现的功能写成 Phase D 证据。

### 1.3 当前确认的 D3 阻断项

1. Current 路径真实输入是 `FromWorkspace` 的 `[drive_cycle_time, drive_cycle_current]`，helper 不能设置不存在的 `Value` 参数。
2. Power 路径真实输入是 `FromWorkspace` 的 `[drive_cycle_time, drive_cycle_power]`，不能把 `PS-Simulink Converter1` 子系统当作带 `K` 参数的 Gain。
3. Voltage 路径真实输入是 `FromWorkspace` 的 `[drive_cycle_time, drive_cycle_voltage]`，PI 参数通过模型工作区变量传入；当前 `voltageController=[]` 会在校验阶段拒绝 Voltage case。
4. `Cathode_Air_cEGR_BOP/cEGRControl_ModeSwitch` 在当前模型中不存在；cEGR 控制应使用实际的 `routeA_*` 模型工作区变量和 `FCU_BoP_Control/EGR Area Mode Switch` 逻辑。
5. 气路模式开关的真实 Threshold 是 `0.5`，控制量是 `routeA_air_control_mode_id` 派生的布尔信号，不应把模式编号直接写入 Threshold。
6. 面板的 cEGR 复选框、阀模式、控制模式和目标输入模式尚未全部写入 `SimulationInput`。
7. 面板基础/高级按钮当前没有切换回调；高级参数区也尚未实现。
8. 面板运行前没有确保模型已加载，`save_system(model)` 依赖外部 MATLAB 状态。

## 2. 目标与范围

### 2.1 Phase D 目标

将 Route A 从脚本调用入口推进到可操作的 MATLAB 面板，先完成可靠的单工况闭环，再扩展批量矩阵：

- 面板设置 Current、Power、Voltage 三种电边界。
- 面板设置 OER、背压、阴极加湿 RH、cEGR 启用和目标比例。
- 面板调用统一 `simCase -> validate -> profile -> SimulationInput -> sim` 链路。
- 单工况结果自动提取尾窗 KPI 和时序曲线。
- 保留 caseId、参数快照、运行状态和错误信息，保证结果可追溯。
- D3 完成后再实现 D4 的矩阵对话框和 `parsim`。

Phase D 只负责建立可运行面板和最小仿真闭环，不承担完整系统参数实验台、完整气路观测面板和迁移交付的全部目标。

### 2.2 范围约束

**包含：**

- 面板程序化 `.m` 主文件的功能修复；后续视需要转存 `.mlapp`。
- `simCase`、SimulationInput、模型工作区变量和 logsout 之间的接口修复。
- Current/Power/Voltage 单工况最小 smoke 和代表性回归。
- 基础模式的可用性、模式切换状态和结果展示。
- D4 所需的矩阵输入契约和结果汇总设计。

**不包含：**

- 不修改 `.slx` 的物理网络拓扑、块连接或控制算法。
- 不生成或迁移 v10 初态包；Phase D 继续走冷态直接计算路径。
- 不接入 v09 初态链 `routeA_prepare_electrical_boundary_input`。
- 不做实时仿真、硬件在环或多模型切换。
- 不把旧台架、DQ60、10 kW workbook 或历史标定数据提升为默认参数。

## 3. 固定接口契约

### 3.1 装配链路

```text
routeA_simCase_template
    -> 面板字段覆盖
    -> routeA_validate_case
    -> routeA_assemble_command_profile
    -> routeA_panel_build_simulation_input
    -> sim / parsim
    -> routeA_panel_extract_results
```

`routeA_prepare_electrical_boundary_input` 继续保留为 legacy，不进入 Phase D 新代码。

### 3.2 Electrical Load 真实接口

| 模式 | 模型块 | SimulationInput 变量 | 数据形式 |
|---|---|---|---|
| Current | `Inputs/Current Demand/Current Demand` | `drive_cycle_time`、`drive_cycle_current` | 两个列向量 |
| Power | `Inputs/Power Demand/From Workspace` | `drive_cycle_time`、`drive_cycle_power` | 两个列向量，单位 kW |
| Voltage | `Inputs/Voltage Demand/Voltage Reference` | `drive_cycle_time`、`drive_cycle_voltage` | 两个列向量，单位 V |

三种模式均只通过 Electrical Load mask 的 `input_type` 选择活动分支。不得对非真实参数写入 `Value` 或 `K`。

### 3.3 气路与 cEGR 变量接口

SimulationInput 必须显式设置以下模型工作区变量，不能依赖当前模型工作区残留值：

```text
routeA_air_control_mode_id
routeA_cegr_enabled
routeA_cegr_valve_mode_id
routeA_egr_control_mode_id
routeA_egr_target_input_mode_id
routeA_command_profile
```

`A98_CompressorCmd_ModeSwitch` 和 `A98_MdotSet_ModeSwitch` 的 Threshold 保持模型值 `0.5`。气路控制模式由 `routeA_air_control_mode_id` 驱动。

### 3.4 Voltage PI 接口

Voltage case 必须拥有完整结构：

```matlab
simCase.controls.electrical.voltageController = struct( ...
    'Kp_A_V', ..., ...
    'Ki_A_V_s', ..., ...
    'currentMin_A', ..., ...
    'currentMax_A', ...);
```

PI 和限幅变量通过模型工作区覆盖：

```text
routeA_voltage_pi_Kp
routeA_voltage_pi_Ki
routeA_voltage_current_min_A
routeA_voltage_current_max_A
```

Voltage 初始参考值必须来自参数入口或明确的 Route A 平台默认值，不能在面板回调中散落硬编码。

## 4. 执行计划

### D0：现状校正与接口冻结（已完成）

**工作：**

- 盘点唯一 `.slx`、面板 `.m`、helper、模板、校验和 profile 脚本。
- 读取模型根层、`Electrical Load`、`FCU_BoP_Control`、气路和日志链路。
- 记录真实 `FromWorkspace` 变量名和 cEGR/气路控制变量。
- 明确当前不具备 D3 端到端结果证据。

**证据：**

- 模型当前 `SimulationStatus=stopped`。
- Current/Power helper 仅能构造对象，不能替代 `sim()` 通过。
- Voltage case 在 `routeA_validate_case` 阶段因 PI 结构为空而失败。
- `model_check` 为 warning-only，但存在大量物理候选/非活动 Variant 端口 warning，不能写成 clean pass。

### D3-A：修复单工况装配链路（已完成）

**目标：** 三种模式都能从同一个 `simCase` 构造出参数一致、路径真实的 `SimulationInput`。

**实施项：**

1. 在 `routeA_simCase_template` 中把 Voltage PI 默认结构从 `[]` 改为参数文件派生值。
2. 在 `routeA_panel_build_simulation_input` 中使用 `routeA_normalize_electrical_profile` 生成电边界时序。
3. 按模式设置 `drive_cycle_time` 和对应的 `drive_cycle_*` 列向量。
4. 保留 `routeA_command_profile` 的 `[time, 22 fields]` 格式，并确保其时间范围等于面板 StopTime。
5. 显式设置气路、cEGR、PI 和 solver 模型工作区变量。
6. 删除不存在的 `cEGRControl_ModeSwitch` 路径写入。
7. 增加模型自动加载和关键路径存在性检查。
8. 对 stopTime 小于 startup ramp 的输入提前报错，避免 profile 装配阶段产生难以定位的错误。
9. 对 `SimulationOutput.ErrorMessage`、缺失 logsout 信号和空尾窗增加明确错误。

**验收：**

- Current/Power/Voltage 三种 case 均能完成 helper 装配。
- `SimulationInput.BlockParameters` 只包含真实存在的块和参数。
- `SimulationInput.Variables` 包含电边界、profile、气路和 cEGR 所需变量。
- 不触碰 `.slx` 结构。

**实际证据：** Current/Power/Voltage 三种 `SimulationInput` 均通过回读；Current 10 s smoke 无 `ErrorMessage`，关键 logsout 有限且非空。

### D3-B：Current 单工况基线闭环

**顺序：**

1. 10 s Current smoke：100 A 目标，cEGR=0，确认无装配/编译/DAE 报错。
2. 600 s Current 回归：100 A，cEGR=0，启动斜坡 60 s。
3. 提取尾窗 540-600 s 的电压、电流、功率和时序。
4. 对照 Phase C 基线 409.2011 V，并记录与 S3 基线 408.89 V 的偏差。

**验收判据：**

| 指标 | 判据 |
|---|---|
| 仿真状态 | 无 `ErrorMessage`、无 DAE IC Failure |
| 尾窗电压 | 相对 409.2011 V 偏差不超过 0.1% |
| 尾窗稳定性 | 电压跨度/均值不超过 0.5% |
| 尾窗电流 | 与 100 A 命令一致，按回归脚本判据检查 |
| 结果提取 | KPI 和三条时序均非空且有限 |

**实际证据：** 平台默认 case 尾窗 `V=409.976977 V`、`I=100 A`、span=`0.06109%`；Phase C 兼容参数 case（anode RH=0.5、入口压力 0.15 MPa）尾窗 `V=409.200935 V`、`I=100 A`、span=`0.06938%`，与 Phase C `409.2011 V` 相差约 `0.00004%`。因此 D3-B 已闭环；两套参数集保持分开记录。

### D3-C：Power 与 Voltage 单工况闭环

**Power：**

- 先做 10 s 40 kW smoke。
- 再做 600 s 40 kW、cEGR=0 回归。
- 尾窗功率相对目标误差不超过 0.5%。

**Voltage：**

- 先做 10 s 410 V smoke。
- 再做 600 s 410 V、cEGR=0 回归。
- 尾窗电压误差不超过 0.5%，电压跨度不超过目标的 0.5%。
- PI 参数和电流限幅必须来自 `simCase`，不能依赖模型当前工作区残留。

**cEGR 与入口组分补充检查：**

- 至少完成一个 `cEGR enabled=true, targetRatio=0.3` 的 Current 或 Power case。
- 至少完成一个 `cathode.o2MoleFraction=0.18` 的 Current case。当前模型的
  `Oxygen Source/Air Intake` Reservoir 使用 `env_yO2/env_yH20` 的 compile-time
  组成表达式，不能把 profile 中已连接到 Terminator 的诊断信号误认为入口驱动；
  helper 必须显式覆盖这两个模型工作区变量。
- 验证结果中记录实际 cEGR 比或氧稀释后的电压变化，不把“输入已写入”当作物理验证。

**实际证据：** cEGR 0.3 case actual ratio=`0.300001`、尾窗电压=`406.580678 V`；O2=0.18 case 尾窗电压=`409.063774 V`，相对 O2=0.21 有响应。

### D3-D：面板行为与结果展示（核心范围已完成）

**实施项：**

1. 面板构造时从 `routeA_simCase_template` 填充默认值，不重复维护参数常量。
2. 根据电边界模式更新命令单位和默认命令值。
3. 实现基础/高级模式切换；未实现的高级字段不得显示为已可用。
4. Voltage 模式显示并启用 PI 参数字段，Current/Power 模式禁用这些字段。
5. Run 前禁用重复点击，Run 后恢复按钮状态。
6. 状态栏区分“就绪、校验失败、仿真中、完成、失败”。
7. 日志保留 caseId、模型名、参数层、仿真时长、关键 KPI 和错误标识。
8. 结果表采用数值列或明确格式化列，保存当前 `simCase` 快照和结果摘要。
9. 电压、电流、功率曲线使用真实时间轴；功率优先使用模型日志信号，缺失时才由 V×I 派生并标注来源。

**实际证据：** 基础/高级回调、Voltage 单位切换、面板 Current 10 s Run、KPI 表写入和运行按钮互斥均已通过；完整 CR2 高级字段和后台异步仍未完成。

### D4：批量矩阵（首个矩阵已完成，扩展矩阵未完成）

**范围：**

- 矩阵输入对话框支持电边界命令、cEGR 比、OER、入口 O2 四个扫描轴。
- 采用笛卡尔积生成 case 列表，caseId 自动唯一化。
- 每个 case 独立生成 `SimulationInput`，不共享可变工作区状态。
- `<=6` 个 case 先以 serial smoke 验证，再切换 `parsim` 2 workers。
- 结果表汇总每个 case 的目标值、尾窗 KPI、误差和 PASS/FAIL。
- 多工况曲线叠加必须保留 caseId 和单位。

**首个矩阵验收：**

- Power 40 kW × cEGR `[0, 0.1, 0.3]`，3 cases。
- 结果与现有 Power cEGR 回归脚本的目标和误差判据一致。
- 首次矩阵闭环前不扩展到 OER/O2 四轴组合。

**实际证据：** 3×10 s Power/cEGR serial smoke 为 3/3 finite KPI；3×600 s Power 40 kW × cEGR `[0,0.1,0.3]` serial 为 3/3 formal PASS。功率均为 `40.000000 kW`，actual cEGR 为 `0`、`0.099996`、`0.299989`，尾窗稳定性均小于 `0.05%`。矩阵按钮已接入 runner、输入对话框、KPI 回填和电压曲线叠加。

### D5：测试、记录与交付

**测试集合：**

| 编号 | 测试 |
|---|---|
| T1 | Current 100 A，cEGR=0，600 s |
| T2 | Power 40 kW，cEGR=0，600 s |
| T3 | Voltage 410 V，cEGR=0，600 s |
| T4 | Power 40 kW × cEGR `[0, 0.1, 0.3]` |
| T5 | Current 100 A，入口 O2=0.18 |
| T6 | OER=10，必须在仿真前拦截 |
| T7 | Voltage PI 缺字段，必须在仿真前拦截 |
| T8 | stopTime 小于 ramp，必须在 profile 装配前拦截 |

**当前执行结果：** T1/T2/T3/T4/T5/T6/T7/T8 均已有实际证据；T1 的平台默认参数与 Phase C 兼容参数分开记录，T4 已完成 3×600 s serial formal 矩阵。

**收尾产物：**

- Phase D 实施记录追加实际运行证据、KPI、失败栈和未决风险。
- 计划文件覆盖式更新为最终阶段状态。
- 只保留必要的结果摘要和测试产物；Simulink 缓存不纳入 Git。
- 提交前检查 `git status`、`git diff` 和最近提交记录，只纳入本阶段意图文件。

**当前状态：** 实施记录已追加为 [Phase D D3 闭环与 D4 首个矩阵记录](../RouteA_GasMixture_Derived/02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260728_PhaseD_D3闭环与D4首个矩阵_v01.md)。`.mlapp` 转存、完整 CR2 高级字段、后台异步和最终提交审查仍待完成。Phase D 之后的用户确认目标已记录在 [面板-模型双向迭代规划](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_面板-模型双向迭代规划_v01.md)，不作为本轮已完成证据。

## 5. 验证门槛与停止条件

### 5.1 通过门槛

必须同时满足以下条件，才能推进下一阶段：

1. D3-A 三模式装配通过。
2. D3-B Current 100 A 600 s 端到端通过。
3. D3-C Power 和 Voltage 代表性 case 端到端通过。
4. 结果提取对缺失信号和失败仿真有明确拒止，不静默生成 NaN KPI。
5. 面板输入与 `simCase`、SimulationInput 的字段映射可回读。

### 5.2 停止条件

出现以下任一情况时，停止扩展到 D4，先修复当前层：

- 任一模式仍依赖错误的块参数名或不存在的块路径。
- `sim()` 报 DAE IC Failure、变量未定义、FromWorkspace 维度错误或模型编译错误。
- Current 基线偏离对应参数集的基线且未完成根因分析。平台默认 anode RH=1.0 与 Phase C 兼容 anode RH=0.5 必须分开比较。
- cEGR/O2 输入已写入但没有对应的实际 logsout 或物理响应证据。
- 面板运行回调异常后按钮仍处于禁用或“仿真中”状态。

## 6. 风险与处理策略

| 风险 | 影响 | 处理 |
|---|---|---|
| 单工况冷态仿真耗时较长 | D3 反馈慢 | 先 10 s smoke，再运行 600 s 正式 case；不以缩短正式 case 代替验收 |
| Voltage PI 初态和目标参考不匹配 | 仿真饱和或推进很慢 | 使用参数入口的初始参考值和显式 PI 参数；先做 10 s smoke |
| Variant/物理端口 warning 较多 | 结构检查噪声 | 区分非活动 Variant warning 与运行 error；不在本阶段扩大模型结构整改 |
| `.mlapp` 尚不存在 | App Designer 交付形式滞后 | 先以可审计 `.m` 主文件完成 D3；功能闭环后再转换/保存 `.mlapp` |
| 面板同步调用 `sim()` 阻塞 | UI 无响应 | D3 先完成正确性；D3-D 再引入 `uiprogressdlg`、后台任务或受控异步调度 |
| 参数文件与模型工作区漂移 | 结果不可追溯 | 所有可改参数从 `routeA_platform_default_parameters` 或 `simCase` 显式覆盖，并在结果中记录快照 |

## 7. 当前执行顺序

```text
1. 覆盖本计划文件并冻结接口契约
2. 修复 routeA_simCase_template 的 Voltage PI 默认结构
3. 修复 routeA_panel_build_simulation_input 的三模式变量装配
4. 运行无仿真装配 smoke 和 SimulationInput 回读
5. 运行 Current 10 s smoke
6. 运行 Current 100 A / 600 s 基线
7. 运行 Power 40 kW 和 Voltage 410 V 代表性 case
8. 修正面板模式切换、按钮状态和结果快照
9. 更新实施记录
10. D4 首个 Power × cEGR 矩阵已完成；下一步补 OER/O2 扩展矩阵和 D5 收尾
```

## 8. 关联文件

- [平台能力建设需求](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_平台能力建设需求_v01.md)
- [控制接口汇总表](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_控制接口汇总表_v01.md)
- [CR3 三要素 schema](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_CR3三要素schema_v01.md)
- [模型裁决与资产处置](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)
- [Phase D 前审计修复记录](../RouteA_GasMixture_Derived/02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260728_PhaseD前审计修复_v01.md)
- [面板-模型双向迭代规划](../RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_面板-模型双向迭代规划_v01.md)
- `../../03_脚本/RouteA_GasMixture_Derived/routeA_simCase_template.m`
- `../../03_脚本/RouteA_GasMixture_Derived/routeA_validate_case.m`
- `../../03_脚本/RouteA_GasMixture_Derived/routeA_assemble_command_profile.m`
- `../../03_脚本/RouteA_GasMixture_Derived/routeA_panel_build_simulation_input.m`
- `../../03_脚本/RouteA_GasMixture_Derived/routeA_panel_extract_results.m`
- `../../03_脚本/RouteA_GasMixture_Derived/routeA_panel_run_matrix.m`
- `../../03_脚本/RouteA_GasMixture_Derived/RouteA_Panel_v01.m`
