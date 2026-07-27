# RouteA cEGR-PEMFC 工程化建模规格 v01

文件类型：规划设计（覆盖式维护）
当前版本：2026-07-24
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`

## 1. 平台定位

Route A 是基于 MathWorks 官方 Gas Mixture PEMFC 案例派生的系统级 PEMFC-cEGR 通用仿真平台。它用于系统结构集成、BOP 控制接口、参数匹配和工况研究；不宣称已完成产品数字孪生、真实压缩机轴功率/效率/喘振、DCDC/母线、液水库存/排液或整车能量管理。

`platform_default` 是唯一默认参数语义。历史 10 kW 台架、DQ60、旧 CSV 和外部标定只能作为显式 `external_case`，不得进入默认模型、默认初态或默认研究入口。

官方示例 `.slx`、`.m` 和 `.mat` 保留在 `00_支撑材料/` 作为派生依据，不属于 Route A 当前系统结构或当前 runner。`99_历史归档/` 中的旧模型、旧 runner、旧说明和阶段证据只用于追溯。

## 2. 资产边界

| 类别 | 当前唯一事实源 | 规则 |
|---|---|---|
| 系统结构 | `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` | 每种系统结构只保留一个当前 `.slx`；I/P/V 与 cEGR 通过同一模型的受控分支和参数切换，不派生第二个模型。 |
| 默认参数 | `PEMFuelCellSystemWithACustomLibraryParameters.m` | 只保存 `platform_default`、单位和参数语义；不承担案例脚本或临时计算。 |
| 正式初态 | `RouteA_platform_default_initial_state.mat` | 当前 v09 文件只读保留；v10 生成/提升前必须先归档 v09，并保存 Current、Power、Voltage 三个匹配的 `ModelOperatingPoint` 与完整 metadata。v10 bundle 未生成前统一 runner 必须拒绝运行。 |
| 通用研究入口 | `run_routeA_electrical_boundary_study.m` | 单一案例合同、串行/并行调度、统一 KPI 和可选紧凑结果文件。 |
| 历史证据 | `99_历史归档/` | 不参与当前默认初始化、参数真源或验收。 |

## 3. 结构与电边界

模型保留官方 MEA、四物种气体域、阳极回流、阴极供气/排气、冷却和受控负载结构；cEGR 为从阴极出口返回压缩机入口混合器的同域物理支路。`routeA_cegr_valve_mode_id=0` 是严格物理隔离拓扑回归，`=1` 是正常 cEGR 研究拓扑。正常性能研究使用 `mode=1`，目标为零时仅表示近似零循环比。

Electrical Load 的三个模式互斥。一次 `SimulationInput` 只设置一个 mask，其他两个控制器不参与该次计算。

| 模式 | 主动命令 | 受控量 | 当前边界 |
|---|---|---|---|
| `Current` | `drive_cycle_current`，单位 A | 堆电流 | 受控电流源；不等同于 DCDC 或母线控制。 |
| `Power` | `drive_cycle_power`，单位 kW | 堆端功率请求 | 先在 Simulink 域显式换算为 W，再由 `P/V` 生成 A 电流命令，受 `0..392 A` 限幅约束。 |
| `Voltage` | `drive_cycle_voltage`，单位 V | 堆端电压 | 现有连续 PI、anti-windup 和电流限幅；Voltage Measurement 同时发布全局 `v_stack` 观测；只代表堆端恒压曲线控制。 |

## 4. 气路与热管理控制权限（对应内容要求 2）

下表明确区分三种状态：`主动` 表示统一 runner 能通过 `SimulationInput` 注入；`响应` 表示由物理网络、执行器动态或闭环计算产生；`部分` 表示只有部分变量或设定点开放。研究报告不得把响应量误写成独立执行器能力。

| 域 | 当前可主动设置的输入 | 模型执行机制 | 主要响应量与当前边界 |
|---|---|---|---|
| 阴极进气组分 | `cathode.freshAirO2MoleFraction`、`cathode.freshAirWaterMoleFraction`，映射到 `env_yO2`、`env_yH20` | 新鲜空气源与压缩机入口混合器 | 实际混合组分、入堆 O2/H2O 分数和气体库存；当前只开放 O2、H2O 两个组分输入，剩余组分按模型气体域处理，不是任意全组分 profile。 |
| 阴极进气压力/温度 | `cathode.sourcePressure_MPa_abs`、`cathode.sourceTemperature_C`，映射到 `env_p`、`env_T` | 环境边界、压缩机、容腔和管路动态 | 压缩机入口、预加湿器和入堆压力/温度；实际值随压缩机、cEGR 和阻力响应。 |
| 阴极进气流量 | `air.modeId=1` 总入口质量流量目标；`=2` 新鲜空气等效 OER；`=3` 直接压缩机命令 | 模式 1/2 通过现有空气控制 PI，模式 3 为开环命令，均经过官方压缩机 map | 实际总入口流量、压缩机命令/rpm、入堆组分和 `lambda_ca_in`；mode 2 的 OER 是新鲜空气等效输入，不是 cEGR 下的实际氧计量比。 |
| 阴极出口压力 | `cathode.outletPressure_MPa_abs`，映射到 `routeA_target_p_ca_out_MPa` | 现有 Pressure Relief Valve 目标接口 | 阴极出口及入堆压力、阀开度和流量响应；当前不是产品背压阀 PI，也不是独立的压缩机出口压力闭环。 |
| 阴极湿度 | `cathode.humidifierRelativeHumidity`、`cathode.humidifierEnabled` | 阴极加湿器比例控制和旁路增益 | `RH_ca_in/out`、水蒸气组分、冷凝和水分离响应；不是直接指定出口 RH 的理想源。 |
| cEGR 循环比 | `cegr` 标量或 profile，定义为 `abs(mdot_egr)/max(abs(mdot_comp_inlet),eps)` | cEGR 比值 PI、阀面积动态、开放阀变体和 cEGR 管路 | 实际循环流量、实际比值、阀面积、阀压差、入口混合组分和实际氧计量比；当前 runner 固定使用比值控制和开放 cEGR 研究拓扑，直接面积控制不是 case-level 默认接口。 |
| 阳极进气组分 | `anode.hydrogenMoleFraction`，映射到 `tank_yH2` | 氢源、阳极气体域和回流混合 | 减压后 H2/N2/H2O 组分、膜传质和阳极库存；当前只开放 H2 分数，不支持任意阳极全组分独立 profile。 |
| 阳极源压力/温度 | `anode.tankPressure_MPa_abs`、`anode.sourceTemperature_C`，映射到 `tank_p`、`tank_T` | 氢罐、减压阀和阳极管路 | 减压后压力、进堆流量、温度和库存响应。 |
| 阳极入口压力 | `anode.inletPressure_MPa_abs`，映射到 `routeA_anode_inlet_pressure_MPa_abs` | 阳极 Pressure-Reducing Valve 目标接口 | 阳极入口压力和实际进气流量；实际流量不是独立设定量。 |
| 阳极湿度 | `anode.humidifierRelativeHumidity`，映射到 `routeA_anode_rh_setpoint` | 阳极加湿器比例控制 | 阳极 RH、水蒸气组分和水状态；当前没有单独的阳极加湿器 enable/bypass case 字段。 |
| 阳极回流 | `anode.recirculationBaseCommand`、`anode.recirculationCurrentGain_A_inv` | 基于堆电流的前馈回流命令、限幅、传递函数和回流容腔 | 实际回流质量流量、回流容腔压力/组分和阳极入口状态；不能直接指定实际回流质量流量。 |
| 阳极吹扫 | `anode.purgeEnabled`、`anode.purgeOnN2MoleFraction`、`anode.purgeOffN2MoleFraction` | v10 统一命令 profile、N2 组分选择、Relay 记忆和吹扫阀 | 实际吹扫时刻、吹扫流量、N2 库存和周期性电压扰动；当前仍没有独立的吹扫周期、持续时间或流量 profile。 |
| 热管理相关温度 | `thermal.stackTemperatureSet_C`，映射到 `routeA_stack_temperature_set_C` | 现有冷却控制接口和热网络 | 实际堆温、冷却侧状态和热流响应；当前不等于已具备产品级泵、散热器或热管理执行器逐项控制。 |

当前 runner 将阴极源、空气、阴极出口/湿度、cEGR、阳极源/湿度/回流/吹扫和堆温统一装配为 22 列 `RouteA_Command_Profile_v10`；连续标量默认在逻辑 `t=0` 保持基准 `0.5 s`，再用 `60 s` 斜坡进入目标。尚未开放的直接控制包括任意全组分气体输入、阳极独立进气/回流质量流量、独立吹扫周期/持续时间/流量、产品级背压 PI 和完整热管理执行器控制。这些是明确的能力边界，不应被正式结果中的响应信号替代或反向宣称为主动控制。

## 5. 初态与时间基准（对应内容要求 3）

每个正式研究从同一个低电流正常运行条件的分支匹配初态启动，而不从上一例结束状态串联。Current、Power、Voltage 必须各自拥有与 Electrical Load 分支匹配的完整 `ModelOperatingPoint`。

三个分支初态来自同一 `platform_default` 低负载、零 cEGR、正常吹扫协议，但保留为三个 branch-compatible operating points；这是因为 `ModelOperatingPoint` 同时携带 Electrical Load 分支和 Voltage PI 状态的 checksum，不能把 Current 快照直接冒充 Power 或 Voltage 初态。

v10 物理热初态生成协议：

1. 从冷态模型时间 `0 s` 开始，使用约 `28 A` 低负载、`mode=1`、零 cEGR 目标和正常阳极吹扫；研究目标不写入热初态。
2. 使用默认平台气源、压力、湿度、热管理和阳极回流设置；每一项都写入 `metadata.initializationCondition`，不再把旧候选的 `60 degC / 120 kPa / 130 kPa` 作为当前事实。
3. 至少识别两个连续吹扫周期。每个周期在吹扫后 `100 s` 起计算 `60 s` 安静窗口，窗口内不得有吹扫；`0.5%` 硬门施加于相邻周期同相位时间加权窗口均值的相对差。阳极 N2 在两个吹扫之间的窗口内缓慢累积是稳定极限环的诊断量，记录为 `maximumWithinWindowRelativeChange`，不被误判为非稳态。
4. 保存最后一个合格安静窗口末端的完整状态，并记录快照时间、吹扫周期、跨周期门值 `maximumRelativeChange`、窗内诊断量、参数面积和求解器设置。
5. 只有三个 v10 候选均通过后，`routeA_promote_platform_default_initial_state_bundle` 才能在保留 v09 归档的前提下原子提升正式初态包。

每个 case 在进入 `sim` 或 `parsim` 前，统一 runner 生成 `routeA_electrical_boundary_preflight`。该预检清单逐 case 固化初态文件及 metadata、低电流参考和吹扫静默核验、I/P/V 与 cEGR profile、阴阳极/热控制要求、求解器设置、逻辑时间起点、ModelOperatingPoint 快照时间和稳态统计窗；仿真完成后同一清单保存在 `study.preflight`。预检失败时不进入仿真。

热启动选择收口为一个不增加脚本的通用策略 `hotStartPolicy="auto"|"hot"|"cold"`：

| 策略 | 选择条件 | SimulationInput 行为 |
|---|---|---|
| `auto`（默认） | 22 列运行命令 profile、I/P/V 边界、空气模式/OER/直接命令、cEGR、回流/吹扫和热设定均由 runner 在逻辑 `t=0` 后接管；不作为热初态兼容锁。 | 使用对应分支的 v10 `ModelOperatingPoint`；仅检查拓扑、四物种维度和关键组件参数兼容，研究逻辑起点为 `0 s`；物理不兼容时明确拒绝，不静默冷态回退。 |
| `hot` | 研究者要求强制热启动。 | 只要存在上述初态字段差异，仿真前以 `RouteA:HotStartIncompatibleCase` 拒绝，不降级为 checksum warning。 |
| `cold` | 研究者明确要求冷态。 | 仅显式选择时不挂载 operating point，设置 `LoadInitialState="off"`；内容 checksum 保持 `error`，禁止部分加载。 |

空气模式、压力、温度、湿度、组成、cEGR、回流、吹扫和热设定都属于运行期命令，不再作为热初态兼容锁；只有拓扑、物种维度和关键组件参数不兼容时才拒绝。`hotStartPolicy="auto"` 不得静默回退冷态；若需要冷态，必须显式使用 `cold`，且 solver 失败不能被伪装成通过。

已知技术约束：`ModelOperatingPoint` 保存了非零快照时间；Simulink 不允许将该完整热启动状态以绝对仿真时间 `0 s` 直接加载。当前模型配置的 `StartTime` 仍为 `0 s`，但热启动仿真的 `tout` 会从 operating-point 快照时间开始；运行合同将用户研究时间定义为 `t_study=t_model-snapshotTimeS`，因此逻辑起点仍为 `0 s`。冷态初态生成的求解器起始时间也是 `0 s`。若必须令热启动后的 Simulink 绝对时间也为 `0 s`，需要单独开发并验证全状态 rebase/Dataset 路线，当前不得伪称已实现。

## 6. 求解与结果合同（对应内容要求 3）

| 计算类型 | 默认设置 | 输出与通过条件 |
|---|---|---|
| `steady` | `VariableStepAuto`，`RelTol=AbsTol=1e-3`，`MaxStep=5 s`，默认研究 `600 s`，尾窗 `[540,600] s` | 尾窗采用时间加权均值；关键 I/V/P、流量、压力、温度、RH、氧计量比和 cEGR 分成两个 30 s 半窗，变化不超过 `0.5%`，且窗口内无阳极吹扫。 |
| `transient` | 同一变量步长求解器与容差；未显式指定时 `MaxStep=0.1 s`；默认强制保留 `SimulationOutput` | 保留完整物理量变化曲线；不强制稳态门，但必须记录命令、限幅、有限值、气体闭合和故障分类。显式关闭时 runner 拒绝启动。 |

每个 `studyCfg` 必须明确：初态文件、I/P/V 单一边界 profile、阴阳极/热控制命令、cEGR、计算类型、求解器设置（包括 `StartTime=0 s`）、统计窗和验收门。profile 可为常值标量、数值 `N×2` 的 `[time_s,value]`、`time_s/value` 向量结构体或 `timeseries`；结构体若声明 `unit`，必须严格为 Current=A、Power=kW、Voltage=V、cEGR=ratio，错误单位被拒绝且不做隐式换算。

当前稳态门施加于统一观测链中的关键电堆、压缩机、阴极湿度、氧计量比和 cEGR 物理量；尾窗同时记录压力、流量、组分、水分离和吹扫事件。未被模型日志暴露的内部状态不能被报告为已逐一执行 `0.5%` 判据，必要时需先建立独立观测审计工作包。

当前实现的 `StartTime=0 s` 是所有 `SimulationInput` 的求解器配置值和逻辑研究时间起点。由于 `ModelOperatingPoint.snapshotTime` 为只读属性，热启动后的 Simulink 绝对时间仍从快照时间继续；这不是“绝对 `tout` 从 0 s 开始”，不得在报告中混写。若后续要求绝对时间重基准，需另立并验证全状态 rebase 或冷态状态注入方案。

当瞬态 `MaxStep` 与初态生成时的求解器历史不一致时，Simulink 可能丢弃 solver history 后恢复 operating-point 物理状态；该预期 warning 必须保留在结果审计中，不得当作模型拓扑通过或失败的替代证据。

低电流初态是热启动参考，不是任意模型 workspace 气热边界的无条件兼容状态。当前策略把可安全复用的研究命令与初态字段分开：前者继续热启动，后者在物理不兼容时明确拒绝，只有研究者显式选择 `cold` 才冷态运行。任何 checksum warning 后的“部分加载”都不属于可接受结果。

## 7. 脚本职责与运行工作流

核心脚本只承担工况装配、仿真调度、KPI 提取、结果持久化和审计，不复制电堆、气路、热路或控制器物理计算：

| 脚本 | 唯一职责 |
|---|---|
| `routeA_build_electrical_boundary_cases.m` | 将用户提供的通用 case 规格整理为单一电边界的 `cases`，不运行仿真、不修改模型。 |
| `routeA_normalize_electrical_profile.m` | 校验和规范化 I/P/V/cEGR 及 22 列运行命令 profile。 |
| `routeA_prepare_electrical_boundary_input.m` | 构造不修改主模型的 `SimulationInput`，注入边界、初态和求解器。 |
| `run_routeA_electrical_boundary_study.m` | 串行或 `parsim` 调度，收集统一结果并可保存紧凑 `.mat`。 |
| `routeA_assess_electrical_boundary_outputs.m` | 提取 KPI、模式跟踪、稳态门、吹扫、气体闭合和水账本入口。 |
| `routeA_generate_platform_default_initial_state.m` | 统一 Current/Power/Voltage v10 物理热初态生成入口；不按研究工况复制初态。 |
| `routeA_prepare_parameter_consistent_initial_state.m` | 底层参数一致性条件化和低电流稳态初态计算引擎。 |
| `routeA_attach_platform_default_initial_state.m`、`routeA_promote_platform_default_initial_state_bundle.m` | 分支初态挂载、校验和正式 bundle 原子提升。 |
| `RouteACegrValveConstitutiveTest.m` | 唯一正式 cEGR 阀构成 unittest 入口。 |

历史 matrix runner 仅可作为薄兼容 wrapper 或追溯证据；大规模旧研究脚本只保留为历史证据或专项回归，不能再派生新的工况专用脚本。临时研究脚本完成后进入 `99_历史归档/`，不作为活动入口。

2026-07-22 脚本核心收口后，活动目录保留统一 runner、通用输入/KPI/账本辅助、统一初态生成/挂载/提升链、模型读回辅助和唯一 cEGR unittest。旧 demo 完整实现、重复初态 wrapper、独立观测标记脚本和独立 cEGR 测试实现移至 `99_历史归档/2026-07-22_Stage1_Script_Core_Split/`；活动目录只保留同名 demo 兼容薄 wrapper。不得再新建按负载、策略或电边界复制的 runner。

MATLAB GUI 离线交接是例外，不是交互超时兜底。只有同时满足以下准入条件才交给用户执行：流程和输入输出契约固定；agent 已使用同一模型、参数链、求解器设置和同一入口亲自完成代表性 case 的端到端运行并确认无报错；预计运行至少约 `30 min` 或数小时，且通常包含 `10` 个以上工况或等量级正式矩阵/敏感性扫描；命令、结果路径和验收判据可以直接粘贴执行。仅有 Code Analyzer、`model_check` 或装配无报错不能替代亲自运行证据。未达到门槛时，agent 必须继续执行或拆分验证。

v10 低负载物理热初态的生成、Current/Power/Voltage 三分支候选、原子提升、兼容性审计和必要短 smoke 是当前实施任务，由 agent 自己串行完成，不得交给用户；三分支依赖同一模型、Simscape 缓存和前一分支候选，不得并行化。通过门禁的正式大规模 study 才采用固定交接顺序：agent 先生成单一 `boundaryType` 的 `studyCfg` 和 `resultFile`，用户在 MATLAB 中执行 `run_routeA_electrical_boundary_study(studyCfg)`，完成后 agent 只读 `study.execution`、`study.summaryTable`、失败栈和紧凑结果文件。agent 不在交互超时后轮询、打断、缩短或重复发起正式计算。

当案例数大且已通过单例 smoke 时，可选择 `executionMode="parallel"`。该模式使用 `parsim`，默认申请 2 个 worker、上限 4 个；所有案例先在客户端构造独立 `SimulationInput`，worker 不修改 `.slx`。并行不是正式矩阵的前置条件；若已有并行池不足所需数量或超过 4，脚本停止并要求用户显式调整，不擅自关闭或重建用户的池。

统一 runner 现在强制一个 study 内所有 case 使用同一个 `Current`、`Power` 或 `Voltage` 类型；三种电边界必须分三次 study 调用。并行只改变调度方式，不改变模型、case 合同或电边界选择。

## 8. 文件维护

除 `AGENTS.md` 和 `README.md` 外，当前说明文件只分为两类：

1. 规划设计：本文件和材料池，覆盖式更新，只保留当前决策、接口和未闭合项。
2. 实施记录：`04_说明/RouteA_GasMixture_Derived/RouteA_cEGR_PEMFC_实施记录_*.md`，按日期、进度、连续需求核对线或阶段工作包增量记录动作、证据、结果和阻塞项。

实施记录分卷规则采用“连续核对线优先、长度和边界控制”：同一项连续需求核对、同一研究问题或同一整改工作包，只要当前分卷仍处于活动状态，就可以在原文件中按日期、进度或子要求追加小节，不因阶段标签变化自动封卷。只有在用户确认本卷完成/冻结、工作包已经验收、文件明显过长，或主题已经变成独立证据链时才封卷；封卷后不再追加。封卷后确需继续时才建立新分卷，新分卷只引用前卷和新增证据，不复制全文。原始长记录保存在 `99_历史归档/2026-07-22_Stage1_Implementation_Record_Split/`，只用于追溯。

已合并的 `04_说明/PLAN/Route A IPV 通用 Profile 接口与 Runner 迁移.md` 已移至 `99_历史归档/2026-07-22_Stage1_Script_Consolidation/04_说明/PLAN/`，不再作为活动说明入口。当前规划只保留本规格和材料池，当前执行保留按日期、进度或连续需求核对线维护的实施记录；空的活动 `04_说明/PLAN/` 不承载说明文件。

## 9. 当前门禁

模型已具备 I/P/V 三分支、cEGR 物理支路、Source_Conditioner、动态吹扫接收端、22 列运行命令 profile 和持久观测信号。2026-07-24 的结构读回确认阴极 N2/O2/H2O、阳极 H2/N2 的官方 Reservoir/Mass Flow Rate Source/Constant Volume Chamber/Pressure Source 物理调理链；阳极调理器通过官方 `Local Restriction (FC)` 接回原 Fuel Tank/PRV 共用节点，避免新增短管热容。模型已显式 `save_system` 并编译通过，保存状态 `Dirty=off`；相关 MATLAB 脚本 Code Analyzer 均为 0 个问题，22 列 profile 自检通过。v10 初态 MAT 尚未生成，当前 `RouteA_platform_default_initial_state.mat` 和 v09 正式 600 s 结果均未覆盖、未重跑；没有 v10 MOP 前的直接冷态 smoke 在湿气体网络初始化阶段未收敛，不作为通过证据。v09 矩阵仍只作冻结审计证据，v10 初态生成应由 agent 继续串行执行并审计；只有通过离线长任务门禁的正式大规模研究才交给用户 GUI 执行。当前仍须单独推进显式液水库存、液水输运/排液和分离效率能力，不能把气相 WM-L1+ 通过外推为完整液水设备能力。
