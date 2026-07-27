# RouteA cEGR-PEMFC 实施记录：内容要求 1-3 电边界、气路权限与初态/求解器核对

文件类型：实施记录（增量维护；当前分卷活动）  
记录日期：2026-07-22；增量更新：2026-07-24  
核对对象：Current、Power、Voltage 三种电边界、单 study 互斥门禁、气路控制权限及初态/求解器合同  
当前决策和路线入口：[模型裁决与资产处置](../../01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)、[收敛实施路线图](../../01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)

## 0. 用户要求归纳：Stage 1 长要求的短合同

本节把本轮建模要求固定为可复用的短合同，后续不再要求用户重复粘贴长段原文。若活动实现与本节冲突，应先按本节整改；若存在明确的技术限制，必须在实施记录中写出证据和未闭环项，不得用说明文字替代验证。

### 0.1 平台、脚本和说明文件边界

1. 当前 Route A 只有一个活动 `.slx`，且派生自官方 Gas Mixture PEMFC 案例；电堆、气路、热路、控制和 cEGR 集成在同一模型内。
2. MATLAB 脚本只做参数/工况装配、`SimulationInput` 配置、`sim`/`parsim` 调度、结果提取和审计；脚本可以调用模型求解，但不得在脚本中复制或替代电堆、气路、热路的物理计算。脚本按通用职责收口，不按策略、负载或工况复制；一次性研究脚本完成后归档。
3. 除 `AGENTS.md` 和 `README` 外，说明文件分为规划设计和实施记录两类：规划设计采用覆盖式更新，实施记录按日期/阶段增量更新；禁止在多个说明文件中无限重复同一要求和证据。

### 0.2 每次研究的三组计算前合同

每个 study 在进入 `sim`/`parsim` 前必须同时明确：

1. **初态**：气路和电堆气体状态来自统一的低负载物理热初态；参考点避开阳极周期吹扫抖动，用吹扫后的安静窗口和相邻周期变化小于 `0.5%` 的数据生成。初态只锁定拓扑、物种维度和关键组件兼容性，不锁定研究压力、温度、湿度、组成、流量、cEGR、回流/吹扫或 I/P/V 目标。
2. **控制要求**：每个 study 只允许一种 I/P/V 电边界，Current、Power、Voltage 分开调用；每个 case 由统一 runner 注入该边界和统一气路/热控 profile。逻辑 `t=0` 先保持初态基准，再按默认 `0.5 s` 保持 + `60 s` 斜坡进入目标。主动命令与物理网络随动响应必须分开记录。
3. **求解器**：稳态和瞬态分开声明；研究求解器 `StartTime` 始终为 `0 s`。稳态按尾窗平均和关键量相对变化 `<0.5%` 判定，瞬态保留物理量随时间的完整曲线。热启动 operating-point 的绝对快照时间若不能重基准为 `0 s`，必须明确标注为已知限制。

### 0.3 长任务和并行任务工作流

- MATLAB GUI 离线交接是例外，不是交互超时兜底。只有流程/输入输出契约固定、agent 已用同一模型和参数链亲自完成代表性 case 的端到端无报错运行、预计至少约 `30 min` 或数小时且通常涉及 `10` 个以上工况、命令和验收判据可直接粘贴这四项同时成立时，才交给用户执行。Code Analyzer、`model_check` 或装配无报错不能代替亲自运行证据。
- v10 低负载物理热初态生成、三分支候选和提升、兼容性审计及必要短 smoke 由 agent 自己完成，不得因预计耗时交接；未达到上述门槛的任务也由 agent 继续执行或拆分验证。
- 通过门禁的正式矩阵才由用户执行，完成后 agent 只读取约定的 KPI、失败栈和紧凑结果文件；不得缩短、降精度、轮询打断或重复正式任务。串行/并行由脚本字段控制，并行池默认 `2`、最大 `4`，同一初态依赖链保持串行。

### 0.4 当前合规状态（截至 2026-07-24）

| 要求 | 当前结论 | 证据和未闭环项 |
|---|---|---|
| 单一官方派生模型 | **已满足（结构层）** | 根级读回只有一个活动 `.slx`；当前文件 hash 为 `7916d490e076d165a564389af1f320e8b8d7a56ff6b2c98a315f249cb7c5f928`，`Dirty=off`，包含电堆、BOP、cEGR、控制和观测。 |
| 通用脚本、避免文件爆炸 | **已满足（职责层）** | 活动脚本按 runner、输入/KPI、初态链、审计和测试分工；不按工况复制；旧一次性脚本已归档。`sim`/`parsim` 仅是模型执行入口，不是脚本替代物理模型。 |
| 规划/记录纪律 | **本卷已补齐** | 本节固定短合同；规划规格覆盖更新，实施记录按阶段增量维护。 |
| 三组计算前合同 | **接口已实现，最终验收待完成** | runner 已有初态、统一 22 列命令 profile、稳态/瞬态求解器和 preflight；v10 Current/Power/Voltage MAT 尚未生成，因此正式 v10 study 当前应被门禁拒绝。 |
| 长任务/并行工作流 | **已实现（带交接门禁）** | 只有固定流程、agent 亲自无报错验证、预计至少约 `30 min`/数小时且通常 `10+` case 的正式大任务才交给 GUI；runner 默认 `parallelWorkers=2`，限制 `1..4`，并行只调度 `SimulationInput`。 |

当前模型因此可以宣称“满足单模型、统一脚本职责、计算前合同和工作流的结构要求”，但不能宣称 Stage 1 v10 全部验收完成；v10 三分支热初态生成、三例短 smoke 和 root 级 warning 的专项审计仍是关闭前置条件。

## 1. 模型结构读回

当前唯一模型中的 `Electrical Load` 是带掩码的三选一接口，掩码选项为 `Current | Power | Voltage`，变体激活时机为 `update diagram`。`Inputs` 下实际存在三个变体：

- `Current Demand`：`From Workspace` 电流 profile，经 Simulink-PS Converter 进入受控电流物理端口。
- `Power Demand`：`From Workspace` 功率 profile，经 `kW -> W`、`P/V` 换算和电流限幅后进入同一受控电流物理端口。
- `Voltage Demand`：电压参考、堆端电压测量、误差、PI、限流和电流动态，经 Simulink-PS Converter 进入同一受控电流物理端口。

三条变体的实际 `VariantControl` 分别为 `Current`、`Power`、`Voltage`；当前 MATLAB 会话读回 `input_type=Current`、`OverrideUsingVariant=Current`，模型 `Dirty=off`。

## 2. 单次计算任务互斥门禁

- `run_routeA_electrical_boundary_study.m` 收集全部 case 的 `boundary.type`，只接受 `Current`、`Power`、`Voltage`。
- 一个 study 中出现多种类型时，在任何模型仿真前抛出 `RouteA:ElectricalBoundaryMixedModes`，要求分开调用三个 study。
- 每个 case 通过独立 `SimulationInput` 设置 `Electrical Load/input_type`，并只写入对应的 `drive_cycle_current`、`drive_cycle_power` 或 `drive_cycle_voltage` profile。
- 本次无仿真负向测试使用 Current + Power 混合 case，实际收到 `RouteA:ElectricalBoundaryMixedModes`；因此没有把“互斥”只停留在说明文字层面。

## 3. 行为证据

- 三份既有 formal 结果只读回确认：Current `9/9`、Power `3/3`、Voltage `3/3`，均 `matrixComplete=1`、`failed=0`、`passed=1`。
- 脚本核心收口后的单例 600 s 回归中，Current、Power、Voltage 各 1 例均 `simCompleted=1`、`finiteTail=1`、`casePassed=1`、`studyPassed=1`，`StartTime=0`，且 `resultFile=""`。
- runner、输入装配和 profile 规范化的 Code Analyzer 均为 0 个问题；`FCU_BoP_Control` 定向 `model_check` 为 healthy。

## 4. 结论与边界

内容要求 1 已满足：平台具备三种可执行电边界；研究任务按工况选择一种边界；同一 study 不允许混合；Current、Power、Voltage 均通过模型结构读回、互斥负向测试和至少一个 600 s 单例回归。

这里的“切换”是不同研究任务通过 `SimulationInput` 在 `update diagram` 阶段选择变体，不是一次仿真运行中的在线无扰 I/P/V 模式切换。在线切换不属于当前合同，也没有被错误宣称为已实现。

## 5. 内容要求 2：气路控制权限核对

### 5.1 结构与入口证据

模型读回确认当前唯一 `.slx` 同时包含 `Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Anode_Hydrogen_BOP`、`FCU_BoP_Control` 和 `Thermal_Management_BOP`。其中：

- `Oxygen Source/Compressor Control` 有总入口质量流量目标、新鲜空气等效 OER、直接压缩机命令三种空气控制语义；模型同时记录实际压缩机入口流量、压力、温度、组分、命令和转速。
- 阴极加湿器由 RH 设定、比例控制和旁路增益驱动；阴极出口含压力释放阀、出口压力/温度/RH/组分和水分离观测。
- `FCU_BoP_Control` 以总压缩机入口流量为分母，对 cEGR 实际流量执行目标比值控制，输出阀面积命令、限幅命令、控制误差和实际比值。
- 阳极含氢源、减压阀、阳极加湿器、基于堆电流的回流前馈和 N2 Relay 吹扫链；实际阳极流量、回流量和吹扫流量由物理网络响应。

统一入口 `[routeA_prepare_electrical_boundary_input.m](../../../../03_脚本/RouteA_GasMixture_Derived/routeA_prepare_electrical_boundary_input.m)` 现将下列控制域装配为 22 列 `RouteA_Command_Profile_v10`；所有连续标量默认保持基准 `0.5 s` 后以 `60 s` 斜坡进入目标：

| 控制域 | 主动设置字段 | 随动响应或限制 |
|---|---|---|
| 阴极组分、压力、温度 | `cathode.sourcePressure_MPa_abs`、`sourceTemperature_C`、`freshAirO2MoleFraction`、`freshAirWaterMoleFraction` | 压缩机入口/入堆压力、温度、混合组分和库存；当前不是任意全组分输入。 |
| 阴极流量 | `air.modeId=1/2/3` 及对应总流量、等效 OER 或直接压缩机命令 | 实际流量、压缩机命令/rpm、入堆 O2 分数和 `lambda_ca_in`；mode 2 不是 cEGR 下实际 lambda。 |
| 阴极背压和湿度 | `cathode.outletPressure_MPa_abs`、`humidifierRelativeHumidity`、`humidifierEnabled` | 出口压力、RH、冷凝和水分离；背压当前是 Pressure Relief Valve 目标接口，不是产品 PI。 |
| cEGR | `cegr` 标量或 profile | 实际 cEGR 流量/比值、阀面积、压差、入口混合组分和氧计量比；runner 当前固定比值控制和开放阀变体。 |
| 阳极组分、源压力、源温度、入口压力 | `anode.hydrogenMoleFraction`、`tankPressure_MPa_abs`、`sourceTemperature_C`、`inletPressure_MPa_abs` | 减压后压力、实际进气流量、H2/N2/H2O 组分和库存；当前仅开放 H2 分数，实际进气流量不能直接指定。 |
| 阳极湿度 | `anode.humidifierRelativeHumidity` | 阳极 RH 和水状态；当前没有单独 enable/bypass 字段。 |
| 阳极回流 | `recirculationBaseCommand`、`recirculationCurrentGain_A_inv` | 实际回流质量流量、回流容腔压力/组分和入口状态；不是直接回流流量命令。 |
| 阳极吹扫 | `purgeEnabled`、`purgeOnN2MoleFraction`、`purgeOffN2MoleFraction` | v10 profile 驱动 Relay 记忆和门限，实际吹扫流量、N2 库存和电压扰动随动；没有独立周期/持续时间/流量 profile。 |
| 热管理温度接口 | `thermal.stackTemperatureSet_C` | 实际堆温和冷却侧热流响应；不等于产品级泵、散热器逐项控制。 |

### 5.2 不仿真装配门

使用同一 `caseCfg` 同时填写上述阴极、阳极、cEGR 和热控字段，实际输出为：

```text
R2_ASSEMBLY_OK=1
AIR_MODE_1_ASSEMBLY_OK=1
AIR_MODE_2_ASSEMBLY_OK=1
AIR_MODE_3_ASSEMBLY_OK=1
SOLVER_START=0
MODEL_DIRTY=off
```

这证明统一 runner 能够接受并映射当前开放的气路控制接口，但没有把装配成功误当作设备闭环性能验证。本次未启动仿真、未写正式结果文件，也未修改 `.slx`。

补充结构检查：对未改动的当前 `.slx` 做 root 级 `model_check(all)` 返回 `status=warnings`、`total_warnings=70`，输出为 Simscape/Variant 物理端口类 warning，未返回 error 级条目；对 `FCU_BoP_Control` 的定向检查仍为 `healthy`。这组 root warning 是当前模型检查的残余风险，不能用本次输入装配门抵消，也不能归因于本轮文档更新；后续若要宣称 root 级结构零警告，需要另立模型结构审计工作包。

### 5.3 结论与未开放边界

内容要求 2 的“明确控制能力并区分主动控制与随动响应”已满足。当前平台可以主动设定阴极组分/压力/温度/流量语义/RH/背压目标、cEGR 目标比、阳极 H2 源及压力/温度/RH、阳极回流前馈、阳极吹扫门限和堆温设定点；实际流量、压力、温度、湿度、混合组分、回流和吹扫过程均须按物理网络响应检查。

以下能力目前明确标记为未开放或部分开放：任意全组分气体 profile、阳极独立进气或回流质量流量、独立吹扫周期/持续时间/流量 profile、产品级背压 PI 和完整热管理执行器控制。它们不应从已有响应信号反推为主动控制能力；需要时作为新的独立控制接口工作包推进。

本卷继续开放。只要仍在同一轮“平台控制能力核对”连续工作包内，后续内容要求或新增证据直接按日期/进度追加；只有用户确认完成、工作包验收、文件明显过长或证据链独立时才封卷。

## 6. 内容要求 3：初态、控制要求与求解器核对

### 6.1 统一计算前合同

当前 runner 已把每个 case 的计算前信息固定为三组：

| 计算前信息 | 当前实现 | 证据/边界 |
|---|---|---|
| 气路和电堆气体状态初始值 | v10 `routeA_attach_platform_default_initial_state` 只接受拓扑/四物种维度/关键组件参数兼容的 Current/Power/Voltage `ModelOperatingPoint`；现有 v09 文件只读保留。 | v10 三分支 MAT 尚未生成；v09 快照与门值仅作历史证据，不作为当前 v10 runner 输入。 |
| 气路和电堆控制要求 | `routeA_prepare_electrical_boundary_input` 注入单一 I/P/V profile 和统一 22 列 `RouteA_Command_Profile_v10`；不同 case 彼此独立。 | 当前开放字段和主动/随动边界已在本卷第 5 节记录，运行命令不再作为热初态兼容锁。 |
| 计算求解器设置 | runner 注入 `StartTime=0`、`VariableStepAuto`、`Variable-step`、`RelTol=AbsTol=1e-3`、稳态 `MaxStep=5 s`；瞬态默认 `MaxStep=0.1 s`。 | 预检清单在执行前写入 base workspace 的 `routeA_electrical_boundary_preflight`，完成后保存为 `study.preflight`。 |

### 6.2 v09 低电流初态历史证据（只读）

MATLAB bundle 读回结果：

```text
CURRENT  type=Current  currentDensity=0.1  periodicPassed=1  purgeFree=1  maximumRelativeChange=0.1626%  limit=0.5%  quiet=60 s
POWER    type=Power    currentDensity=0.1  periodicPassed=1  purgeFree=1  maximumRelativeChange=0.1638%  limit=0.5%  quiet=60 s
VOLTAGE  type=Voltage  currentDensity=0.1  periodicPassed=1  purgeFree=1  maximumRelativeChange=0.1497%  limit=0.5%  quiet=60 s
```

初态生成器至少识别两个连续阳极吹扫周期，在吹扫后偏移 `100 s` 的 `60 s` 静默窗口中计算时间加权均值，并比较相同吹扫相位的相邻周期；静默窗口内出现吹扫或跨周期变化超过 `0.5%` 时拒绝候选。新增挂载门进一步拒绝缺少上述 metadata、非低电流或未通过静默窗的状态文件。

### 6.3 稳态与瞬态求解合同

- 稳态默认研究时长 `600 s`，逻辑尾窗 `[540,600] s`；`routeA_assess_electrical_boundary_outputs` 将最后 `60 s` 做时间加权平均，并把 `[540,570] s` 与 `[570,600] s` 半窗均值的最大相对变化与 `0.005` 比较，同时要求尾窗无阳极吹扫。
- 瞬态支持同一统一 runner，默认 `MaxStep=0.1 s`，并自动保留完整 `SimulationOutput` 时序；若 `retainSimulationOutputs=false`，runner 返回 `RouteA:TransientCurveRetention`，防止瞬态仅剩标量尾窗。
- 稳态判据当前覆盖统一日志中的关键电堆、压缩机、阴极 RH、氧计量比和 cEGR 量；压力、流量、组分、水分离和吹扫事件也进入尾窗审计。未暴露的内部状态不宣称已逐一执行 `0.5%` 判据。

### 6.4 MATLAB 核验结果与剩余风险

本轮非仿真合同核验输出：

```text
R3_STEADY_ASSEMBLY_OK=1 START=0 MAXSTEP=5 CALC=steady TAIL=[540 600] STEADY_WIN=60
R3_TRANSIENT_ASSEMBLY_OK=1 START=0 MAXSTEP=0.1 CALC=transient
R3_INITIAL_STATE_CURRENT_SNAPSHOT=9487.5
R3_TRANSIENT_DEFAULT_RETENTION=1 EXEC=not_started PREFLIGHT=0
R3_TRANSIENT_FALSE_GATE=RouteA:TransientCurveRetention
R3_MODEL_DIRTY=off
```

补充仿真 smoke（v09 历史证据，均使用既有 formal 结果中的真实 case 合同，不写结果文件）：Current steady、Power steady、Voltage steady 均返回有效 `SimulationOutput`；Current transient 也返回有效 `SimulationOutput`，`ErrorMessage` 为空、日志信号约 `23` 个、堆电压时序 `359` 个样本，`Dirty=off`。这些结果不作为 v10 初态或 v10 运行命令验证。

统一 runner 的 2 s transient contract smoke 进一步得到 `retainSimulationOutputs=1`、`preflightPassed=1`、`simCompleted=1`、`caseOutputs(1).out` 为 `Simulink.SimulationOutput` 且 `ErrorMessage` 为空；该短时 case 的 KPI `passed=0`（lambda/稳态研究量不适合 2 s）是预期，不把它当作曲线留存失败。

另做了一个 v09 主动覆盖全部气路字段的 mode-1 隔离 smoke。严格 checksum 门拒绝了不匹配 operating point；临时将 checksum 降为 warning 后只加载部分状态，并在阳极排气管路出现零分母/不可解状态，因此该 warning 方案未进入 runner。该结果只说明 v09 状态不应部分加载，不作为 v10 runner 行为证据。

已有三份正式 600 s 结果只读回仍为 `matrixComplete=1`、`failed=0`、首 case `passed=1`、`steadyPassed=1`、`tailPurgeFree=1`；本轮没有重跑、覆盖或迁移这些结果。由于它们生成于 preflight 字段加入之前，旧结果文件没有 `study.preflight`，不把旧文件伪装成新 schema。

`SimulationInput` 的求解器配置和逻辑研究起点均为 `0 s`；但 `ModelOperatingPoint.snapshotTime` 是只读属性，热启动后的 Simulink 绝对 `tout` 仍从各自快照时间继续。因此，内容要求 3 在“配置起点/逻辑研究时间”层已满足，在“热启动后的绝对模型时间也必须从 0 s”这一严格字面层仍是已知技术限制；需要绝对时间重基准时应另立全状态 rebase 或冷态状态注入验证工作包。

本节核对完成但本卷仍保持活动，后续若继续核对内容要求3的时间曲线、更多稳态观测量或绝对时间重基准，直接按日期/进度追加；不因本节完成自动封卷。

### 6.5 2026-07-22 热启动策略整改（v09 记录）

本次不新增文件，直接在统一 `routeA_prepare_electrical_boundary_input`、`routeA_attach_platform_default_initial_state` 和 `run_routeA_electrical_boundary_study` 中收口策略：

| 项目 | 整改后行为 | 核验结果 |
|---|---|---|
| 默认策略 | `hotStartPolicy="auto"`；正式 I/P/V、空气模式/OER/直接命令、cEGR profile 和 Voltage PI 作为研究命令，继续使用分支匹配热启动状态。 | Current、Power、Voltage 无仿真装配均为 `mode=hot`、`usedOperatingPoint=1`、`Start=0`。 |
| 初态字段变化 | v09 记录曾使用 `auto_cold_fallback` 语义。该语义已由 v10 删除：运行命令字段不再是兼容锁，物理结构不兼容时明确拒绝。 | v10 `hotStartPolicy="auto"` 不允许静默冷态回退；冷态必须显式选择 `cold`。 |
| checksum 处理 | 热态使用 `SimulationInput.InitialState` 单一声明；内容 checksum 显式为 `error`，不设置 warning 放行。 | 直接改变 `env_T` 的严格 hot smoke 被 `Simulink:op:OperatingPointContentsChecksumMismatch` 拒绝；没有部分加载。 |
| 正式 runner 回归 | 统一 runner 依然执行三种边界的独立短 transient case，preflight 记录初态模式，输出保留。 | 三个 case 均 `preflightPassed=1`、`simCompleted=1`、`executionMode=serial`、`Dirty=off`；短时 `passed=0` 仅因不满足 600 s 稳态/KPI 窗，不作为仿真失败。 |

本整改解决的是 v09 的热启动引用错误、重复声明和 checksum 部分加载风险；本段不覆盖 v10 物理初态状态。

### 7. 2026-07-24 v10 物理热初态与统一命令增量

本轮继续同一活动分卷，未新增模型、脚本或说明文件，未运行正式矩阵；模型与 Route A 活动实现已在 `d4bbf3c`（`feat(routea): implement v10 physical hot-start and command profiles`）提交并通过系统代理推送，正式结果目录 `05_汇报` 未纳入该提交：

1. 在 `Cathode_Air_cEGR_BOP/Oxygen Source` 和 `Anode_Hydrogen_BOP/Hydrogen Source` 中读回并保留官方 FuelCell `Reservoir (FC)`、`Mass Flow Rate Source (FC)`、`Constant Volume Chamber (FC)`、`Pressure Source (FC)` 与受控温度源；阴极物种为 N2/O2/H2O，阳极为 H2/N2。
2. 阳极调理器与既有 Fuel Tank/PRV 节点之间改用官方 `Local Restriction (FC)`。此前试验性的 0.05 m `Pipe (FC)` 产生独立热-流动状态并在冷初始化中不收敛，已移除；对应参数脚本中的短管长度变量已删除。调理器仍保持真实容积和物种库存，阳极入口没有新增独立质量流量执行器。
3. `Anode Exhaust` 的 Relay enable/on/off 已由统一 profile 通过记忆/乘积门控接收；没有把吹扫流量虚构成独立命令。
4. 模型结构读回确认 `Conditioned_Fuel -> Local Restriction -> Fuel Tank/PRV`、原 PRV 输出和原 H2 接口完整；显式 `save_system` 后模型编译通过，保存状态为 `Dirty=off`。`model_check` 对 Simscape 物理端口仍返回既有适配器误报 warning，不能替代编译证据。
5. 参数脚本、profile 装配/规范化、初态链和 runner 共 9 个 MATLAB 文件 Code Analyzer 全部为 0 个问题。22 列 profile 自检通过：字段数为 22、t=0 等于基准、默认 0.5 s 保持和 60 s 斜坡时间单调且有限。
6. v10 MAT 尚未生成。当前模型 `LoadInitialState=off`、`InitialState=xInitial`，模型工作区和 base workspace 均无 `xInitial`；0.2 s 冷启动 Current smoke 在湿气体网络初始条件求解阶段未收敛，首要诊断涉及既有 `EGRPipe`/阳极加湿管和 H2 Reservoir，不把该次运行记为通过，也不据此修改既有 EGR/加湿管。
7. v09 `RouteA_platform_default_initial_state.mat` 与 `RouteA_formal_v09_matrix_20260722` 三组正式结果保持原路径、原内容和原哈希，未重跑、未覆盖。下一步由 agent 自己串行执行 v10 Current/Power/Voltage 初态生成；完成后继续由 agent 审计 metadata、热初态兼容门和三例短 smoke，不把该必要阶段交给用户。

### 8. 2026-07-24 MATLAB GUI 离线交接门禁修订

用户补充并确认：GUI 离线执行只用于长时间、固定流程、已由 agent 亲自用同一模型/参数链/求解器和代表性 case 验证无报错、预计至少约 `30 min` 或数小时且通常涉及 `10` 个以上工况的正式扫描或敏感性任务。agent 必须先完成短 smoke 和运行链闭环，再提供可粘贴命令、I/O 契约、结果路径和验收判据；不满足任一项时不得以交互超时为理由交接。v10 初态生成/提升及其必要审计明确归 agent 自执行。上述规则已同步到项目 `AGENTS.md`、工程化规格和本卷；本次只更新说明文件，未修改 `.slx`、未触碰 v09 正式结果。
