# RouteA cEGR-PEMFC 工程化建模规格 v01

文件类型：规划设计（覆盖式维护）
当前版本：2026-07-22
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`

## 1. 平台定位

Route A 是基于 MathWorks 官方 Gas Mixture PEMFC 案例派生的系统级 PEMFC-cEGR 通用仿真平台。它用于系统结构集成、BOP 控制接口、参数匹配和工况研究；不宣称已完成产品数字孪生、真实压缩机轴功率/效率/喘振、DCDC/母线、液水库存/排液或整车能量管理。

`platform_default` 是唯一默认参数语义。历史 10 kW 台架、DQ60、旧 CSV 和外部标定只能作为显式 `external_case`，不得进入默认模型、默认初态或默认研究入口。

## 2. 资产边界

| 类别 | 当前唯一事实源 | 规则 |
|---|---|---|
| 系统结构 | `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` | 每种系统结构只保留一个当前 `.slx`；I/P/V 与 cEGR 通过同一模型的受控分支和参数切换，不派生第二个模型。 |
| 默认参数 | `PEMFuelCellSystemWithACustomLibraryParameters.m` | 只保存 `platform_default`、单位和参数语义；不承担案例脚本或临时计算。 |
| 正式初态 | `RouteA_platform_default_initial_state.mat` | 必须同时保存 Current、Power、Voltage 三个匹配的 `ModelOperatingPoint` 与 metadata。 |
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

## 4. 气路与热管理控制权限

下表区分可主动设置的边界/执行器命令与模型响应。研究报告不得把响应量误写成独立执行器能力。

| 域 | 可主动设置 | 主要响应量/边界 |
|---|---|---|
| 阴极新鲜气源 | `env_p`、`env_T`、`env_yO2`、`env_yH20` | 压缩机入口/入堆压力、温度、组分和库存。 |
| 阴极流量 | `air.modeId=1` 总入口质量流量、`=2` 新鲜空气等效 OER、`=3` 直接压缩机命令 | 实际总流量、新鲜空气近似流量、入堆 O2 分数和 `lambda_ca_in`。mode 2 的 OER 不是实际氧计量比。 |
| 阴极背压 | `routeA_target_p_ca_out_MPa` | 阴极出口及入堆压力响应；当前是压力释放阀目标接口，不是产品背压阀 PI。 |
| 阴极湿度 | 阴极加湿器 RH 设定与旁路使能 | 入/出口 RH、冷凝和水蒸气组分。 |
| cEGR | 目标比 `abs(mdot_egr)/max(abs(mdot_comp_inlet),eps)`，其中分母为总压缩机入口质量流量 | 实际循环流量、阀面积、阀压差、入口混合组分和实际氧计量比。 |
| 阳极源 | `tank_p`、`tank_T`、`tank_yH2` | 减压后进堆流量、组分、压力和库存；实际进气流量不是独立设定量。 |
| 阳极入口压力 | `routeA_anode_inlet_pressure_MPa_abs` | 减压阀后压力与进堆流量。 |
| 阳极加湿 | 阳极 RH 设定 | 阳极气体湿度和水状态。 |
| 阳极回流 | 回流前馈基值与电流增益 | 实际回流质量流量、回流容腔状态和组分。 |
| 阳极吹扫 | 使能、N2 打开/关闭阈值 | 吹扫时刻、N2 库存和周期性电压扰动。 |
| 热管理 | `routeA_stack_temperature_set_C` | 实际堆温与热液网络响应；当前是现有温控接口，不代表泵/散热器能力已匹配。 |

## 5. 初态与时间基准

每个正式研究从同一个低电流正常运行条件的分支匹配初态启动，而不从上一例结束状态串联。Current、Power、Voltage 必须各自拥有与 Electrical Load 分支匹配的完整 `ModelOperatingPoint`。

初态生成协议：

1. 从冷态模型时间 `0 s` 开始，使用 `0.1 A/cm^2` 低电流、`mode=1`、零 cEGR 目标和正常阳极吹扫。
2. 使用默认平台气源、压力、湿度、热管理和阳极回流设置；每一项都写入 `metadata.initializationCondition`，不再把旧候选的 `60 degC / 120 kPa / 130 kPa` 作为当前事实。
3. 至少识别两个连续吹扫周期。每个周期在吹扫后 `100 s` 起计算 `60 s` 安静窗口，窗口内不得有吹扫；`0.5%` 硬门施加于相邻周期同相位时间加权窗口均值的相对差。阳极 N2 在两个吹扫之间的窗口内缓慢累积是稳定极限环的诊断量，记录为 `maximumWithinWindowRelativeChange`，不被误判为非稳态。
4. 保存最后一个合格安静窗口末端的完整状态，并记录快照时间、吹扫周期、跨周期门值 `maximumRelativeChange`、窗内诊断量、参数面积和求解器设置。
5. 只有三个 v09 候选均通过后，`routeA_promote_platform_default_initial_state_bundle` 才能原子替换正式初态包。

已知技术约束：`ModelOperatingPoint` 保存了非零快照时间；Simulink 不允许将该完整热启动状态以绝对仿真时间 `0 s` 直接加载。当前运行合同将用户研究时间定义为 `t_study=0`，并保留 metadata 中的模型快照时间用于可追溯性。冷态初态生成的求解器起始时间仍为 `0 s`。若必须令热启动后的 Simulink 绝对时间也为 `0 s`，需要单独开发并验证全状态 rebase/Dataset 路线，当前不得伪称已实现。

## 6. 求解与结果合同

| 计算类型 | 默认设置 | 输出与通过条件 |
|---|---|---|
| `steady` | `VariableStepAuto`，`RelTol=AbsTol=1e-3`，`MaxStep=5 s`，默认研究 `600 s`，尾窗 `[540,600] s` | 尾窗采用时间加权均值；关键 I/V/P、流量、压力、温度、RH、氧计量比和 cEGR 分成两个 30 s 半窗，变化不超过 `0.5%`，且窗口内无阳极吹扫。 |
| `transient` | 同一变量步长求解器与容差；未显式指定时 `MaxStep=0.1 s` | 保留完整变化曲线；不强制稳态门，但必须记录命令、限幅、有限值、气体闭合和故障分类。 |

每个 `studyCfg` 必须明确：初态文件、I/P/V 单一边界 profile、阴阳极/热控制命令、cEGR、计算类型、求解器设置、统计窗和验收门。profile 可为常值标量、数值 `N×2` 的 `[time_s,value]`、`time_s/value` 向量结构体或 `timeseries`；结构体若声明 `unit`，必须严格为 Current=A、Power=kW、Voltage=V、cEGR=ratio，错误单位被拒绝且不做隐式换算。

## 7. 脚本职责与运行工作流

核心脚本只承担工况装配、仿真调度、KPI 提取、结果持久化和审计，不复制电堆、气路、热路或控制器物理计算：

| 脚本 | 唯一职责 |
|---|---|
| `routeA_normalize_electrical_profile.m` | 校验和规范化 I/P/V/cEGR profile。 |
| `routeA_prepare_electrical_boundary_input.m` | 构造不修改主模型的 `SimulationInput`，注入边界、初态和求解器。 |
| `run_routeA_electrical_boundary_study.m` | 串行或 `parsim` 调度，收集统一结果并可保存紧凑 `.mat`。 |
| `routeA_assess_electrical_boundary_outputs.m` | 提取 KPI、模式跟踪、稳态门、吹扫、气体闭合和水账本入口。 |
| 初态生成/提升工具 | 只生成、校验和原子提升初态，不承担研究矩阵。 |

旧 matrix runner 仅可作为薄兼容 wrapper；大规模旧研究脚本只保留为历史证据或专项回归，不能再派生新的工况专用脚本。临时研究脚本完成后进入 `99_历史归档/`，不作为活动入口。

离线长任务由用户在 MATLAB GUI 执行。调用者可显式设置 `resultFile`，runner 只保存不含原始 `SimulationOutput` 的紧凑结果；用户确认完成后再由 agent 读取 KPI、失败栈或结果文件审计。不得因交互超时缩短正式矩阵、降低精度或重复发起同一长任务。三分支初态生成始终串行，因为它们依赖同一模型、同一 Simscape 缓存和前一分支候选；不得对它们并行化。

当案例数大且已通过单例 smoke 时，可选择 `executionMode="parallel"`。该模式使用 `parsim`，默认申请 2 个 worker、上限 4 个；所有案例先在客户端构造独立 `SimulationInput`，worker 不修改 `.slx`。并行不是正式矩阵的前置条件；若已有并行池不足所需数量或超过 4，脚本停止并要求用户显式调整，不擅自关闭或重建用户的池。

## 8. 文件维护

除 `AGENTS.md` 和 `README.md` 外，当前说明文件只分为两类：

1. 规划设计：本文件和材料池，覆盖式更新，只保留当前决策、接口和未闭合项。
2. 实施记录：`RouteA_cEGR_PEMFC_实施与验证路线_v01.md`，增量追加时间、动作、证据、结果和阻塞项。

`04_说明/PLAN/` 下的旧迁移草案已并入本规格，不是当前设计真源。历史说明只在 `99_历史归档/` 追溯，不参与默认决策。

## 9. 当前门禁

模型已具备 I/P/V 三分支、cEGR 物理支路、上述控制参数化和持久观测信号。最终模型结构冻结后，`RouteA_platform_default_initial_state.mat` 已原子提升为 v09 Current/Power/Voltage 三分支初态包：快照分别为 `9487.499491 s`、`9495.447219 s`、`9994.787357 s`，跨周期门值分别为 `0.1626%`、`0.1638%`、`0.1497%`，三条 2 s 热启动 smoke 均无 warning 且 I/V/P 有限。旧 v03 与中间 v09 bundle 均已移至项目根 `99_历史归档/`。初态门禁已打开；新的正式 I/P/V 矩阵仍须通过统一 runner 的案例 parity、尾窗、气体闭合和 `WM-L1+` 审计，不能用初态 smoke 替代矩阵证据。
