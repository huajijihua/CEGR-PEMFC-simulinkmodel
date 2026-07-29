# Route A cEGR-PEMFC S5 分层验证与正式矩阵首轮实施记录

文件类型：实施记录（S5 连续实施线）<br>
记录日期：2026-07-28<br>
当前模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`<br>
前置决策：[模型裁决与资产处置](../../01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)<br>
当前路线：[收敛实施路线图](../../01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)<br>

## 1. 本轮范围和固定输入

- 只使用当前 Route A 主模型、`platform_default` 参数层和 v10 Current/Power/Voltage 初态 bundle。
- 模型拓扑 hash：`2D8AE250-895A2A82-1980FB9C-C8E0A06A`。
- `externalCaseEnabled=false`；未读取历史台架 CSV、DQ60 map 或 workbook。
- 统一 runner：`run_routeA_electrical_boundary_study.m`；每个 case 独立生成 `SimulationInput`，不复制 `.slx`。
- 长时 solver：`VariableStepAuto`、`RelTol=1e-3`、`AbsTol=1e-3`、`MaxStep=5 s`。
- 稳态尾窗：逻辑时间 `[540,600) s`，稳态半窗门 `0.5%`；动态 case 保留完整时序。
- 正式 water ledger 使用 `runWaterLedger=true` 的 Power `cEGR=0/0.3` 两点，仍仅对当前可观测的气相和相变通量做审计。

## 2. 实际完成工作

### 2.1 动态 cEGR profile 输入修复

修改文件：

- `03_脚本/RouteA_GasMixture_Derived/routeA_prepare_electrical_boundary_input.m`
- `03_脚本/RouteA_GasMixture_Derived/routeA_assemble_command_profile.m`

实际修复：

- `getCegrProfile` 支持标准 `time_s/value` profile struct。
- 统一 22 字段 command profile 对动态 profile 提取标量首值作为 `initialValue`，同时保留原始时间变化，不再把 struct 直接传给 `validateattributes`。
- 支持嵌套 `profile`、`constant`、`step` 和 `ramp` 规格的初值提取。

验证证据：

- 两个修改文件的 MATLAB Code Analyzer 均返回 `code_issues=[]`。
- 独立 command profile 装配通过：7 个时间节点，cEGR 首值 `0`、尾值 `0.3`、最大值 `0.3`。
- 真实 `SimulationInput` 装配通过：v10 初态挂载、Power 初始基线一致性、动态 cEGR profile 和模型停止时间均通过。

### 2.2 Gate 4 代表性动态 case

| Case | 结果 | 实际证据 |
|---|---|---|
| `S5_gate4_power_ramp_600s_no_purge` | PASS | Power ramp；`P=11.974169 kW`，`I=28.214454 A`，`V=424.398407 V`，saturation/gas closure/finite tail 均通过 |
| `S5_gate4_voltage_ramp_600s_no_purge` | PASS | Voltage ramp；`V=427.412848 V`，`I=21.353501 A`，`P=9.126759 kW`，saturation/gas closure/finite tail 均通过 |
| `S5_gate4_power_cegr_step_600s_no_purge` | PASS | cEGR `0 -> 0.1 -> 0.3`；尾窗实际 `0.299999994`，target error `-6.20e-9`，`P=11.974169 kW`，无 purge，气相闭合通过 |

以上三个 case 均 `simCompleted=1`、`matrixComplete=1`、`study.passed=1`。运行时仍出现 Hydrogen Source dangling-line warning，详见第 5 节。

### 2.3 Power 基础矩阵

文件：`outputs/RouteA_S5_20260728/S5_power_base_matrix_600s_no_purge.mat`

| Case | 尾窗 P [kW] | 尾窗 I [A] | 尾窗 V [V] | 结果 |
|---|---:|---:|---:|---|
| `0.75P0` | `8.98062678` | `21.0030255` | `427.587310` | PASS |
| `P0` | `11.9741690` | `28.2143540` | `424.399915` | PASS |
| `1.25P0` | `14.9677113` | `35.4974366` | `421.656131` | PASS |

三点均通过电边界、稳态、气相闭合、有限尾窗、无 purge、氧供给和 cEGR 零目标门。

### 2.4 Voltage 基础矩阵

文件：`outputs/RouteA_S5_20260728/S5_voltage_base_matrix_600s_no_purge.mat`。当前 Voltage 初态基线 `V0=427.648894 V`。

| Case | 尾窗 P [kW] | 尾窗 I [A] | 尾窗 V [V] | 600 s 严格结果 |
|---|---:|---:|---:|---|
| `V0-20` | `45.0249049` | `110.484506` | `407.522297` | PASS |
| `V0` | `9.12185612` | `21.340906` | `427.435306` | NOT STEADY |
| `V0+20` | `1.15057604` | `2.57050502` | `447.607009` | NOT STEADY |

三点仿真均完成，电边界、饱和、气相闭合和无 purge 均通过；`V0` 的尾窗最大相对变化为 `0.0146526454`，因此不能按 `0.5%` 稳态门标记通过。延长验证见第 2.5 节。

### 2.5 长时 persistence 验证

| Case | 结果 | 尾窗证据 |
|---|---|---|
| `S5_power_persistence_3600s_no_purge` | PASS | `P=11.974169 kW`，`I=28.4694545 A`，`V=420.597066 V`，steady change `4.44e-6`，boundary relative error `6.01e-13`，purge count `0` |
| `S5_voltage_persistence_3600s_no_purge` | PASS | `V=427.643050 V`，`I=11.0420375 A`，`P=4.72205062 kW`，steady change `7.71e-4`，boundary relative error `1.36e-5`，purge count `0` |

因此，Voltage 600 s canonical case 的结论是“未通过严格稳态门”，不是仿真失败；同一 v10 链在 3600 s no-purge persistence case 通过。

### 2.6 cEGR 与 water ledger 矩阵

文件：`outputs/RouteA_S5_20260728/S5_power_cegr_water_matrix_600s_no_purge.mat`

| Case | 尾窗 cEGR | 尾窗 P [kW] | 尾窗 V [V] | case | water ledger |
|---|---:|---:|---:|---|---|
| `cEGR=0` | `1.49908488e-6` | `11.974169` | `424.399915` | PASS | PASS |
| `cEGR=0.3` | `0.299999995` | `11.974169` | `420.944580` | PASS | PASS |

共享 water ledger 的 `auditPassed=1`，气相/相变通量证据通过。液水库存、液水输运、排液和分离效率四项为 `closed=0`，表示当前平台尚未闭合这些液水能力，不能将本结果解释为全液水模型验证。

### 2.7 Gate 4 控制专项

文件：`outputs/RouteA_S5_20260728/S5_gate4_control_specials_600s.mat`。

五个 case 均使用 Power `P0`、cEGR=0、600 s transient、完整时序保留和统一 runner。每个 case 的命令在逻辑时间 `120-300 s` 后发生 step，尾窗为 `[540,600) s`。

| Case | 尾窗 I [A] | 尾窗 V [V] | lambda 最小值 | 事件/结果 |
|---|---:|---:|---:|---|
| `air_oer_step` | `28.1837991` | `424.860021` | `4.8636` | OER `2.5 -> 3.5`，PASS |
| `backpressure_step` | `28.3397075` | `422.522694` | `3.4547` | 阴极出口压力 `0.161325 -> 0.175 MPa`，PASS |
| `humidity_step` | `28.2117736` | `424.438736` | `3.4705` | 阴极 RH `1.0 -> 0.8`，PASS |
| `temperature_step` | `28.2616409` | `423.689817` | `3.4644` | 堆温 `80 -> 82 degC`，PASS |
| `purge_event` | `27.9353562` | `428.638835` | `3.5015` | 检测到 3 个 purge 事件，尾窗事件数 `0`，PASS |

五个 case 均 `simCompleted=1`、气相闭合通过、有限尾窗通过、Power 边界通过。purge case 的检测事件模型时间约为 `[9653.71246, 9830.28788, 10011.1224] s`，均早于逻辑尾窗；运行时 Hydrogen Source dangling-line warning 仍重复出现。

## 3. 结构和 warning ledger

### 3.1 当前读回证据

| 检查 | 实际结果 |
|---|---|
| `model_check(all)` | `status=warnings`，`total_warnings=77`，无 error |
| `model_check(unconnected_lines)` | `status=healthy` |
| Gate 4/矩阵 SimulationOutput | 所有已报告 case `simCompleted=1`，无阻断性 `ErrorMessage` |
| Code Analyzer | 本轮修改的两个 MATLAB 文件无 code issues |

### 3.2 warning ledger 分组

| 分组 | 代表路径/对象 | 物理责任与处置 | 当前结论 |
|---|---|---|---|
| 合法或可选 Simscape conserving port | `Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Stack_Core`、`EGRPipe` 等的 `LConn/RConn` | 属于封装层或可选物理接口；不使用 Terminator 伪闭合，不删除 solver 配置；通过 update/compile、短时和长时仿真验证 | 非本轮阻断项，但仍保留逐项 owner 复核任务 |
| 可选传感器/未使用物理输出 | `CathodeInletMassFlowSensor_FC`、阴极/阳极 Composition and Humidity Sensor 等 | 当前 runner 使用已注册的可观测量，未使用端口不宣称已观测；不为清零 warning 强行增加无意义连接 | 非本轮阻断项，能力标记为未使用或未观测 |
| cEGR/排气支路可选接口 | `Cathode_Exhaust_Backpressure_Water`、`EGRPipe`、`Pipe (N Gas)1` 相关端口 | 保持真实 cEGR 气路和 solver 物理语义；通过 cEGR=0/0.3、动态 step 和 gas closure 证据 | 气相闭合已验证，液水闭合仍 deferred |
| Hydrogen Source runtime dangling-line warning | `Anode_Hydrogen_BOP/Hydrogen Source` | 修复前 `model_check(unconnected_lines)` 为 healthy，但 `sim()` 重复报告该运行时 warning；当时曾验证删除残留线会使 Hydrogen Source 失去 Solver Configuration | 修复前未完全关闭；后续修复和回归见第 6.9 节 |

本轮不以 warning 数量归零作为目标，也未通过放宽 solver、删除 solver configuration、增加人工质量源或新增模型副本来规避 warning。

### 3.3 最终平台契约读回

- `routeA_model_contract`: `passed=1`，`errors=0`，`warnings=0`；active initialization status 为 `cold_start_only`，历史 hot-start bundle 不在活动 contract 输入链。
- `routeA_check_dependencies(paths,true)`: `passed=1`，`errors=0`，`warnings=0`。
- 两个本轮修改 MATLAB 文件的 Code Analyzer：`code_issues=[]`。
- 本轮在 Hydrogen Source 保存了最小拓扑修复；保留已有 `.slx` provenance 差异和 Simulink 运行缓存。

## 4. 当前结论

- S5 已完成第一轮分层验证、Gate 4 代表性 Power/Voltage ramp 和 cEGR step、Power 基础矩阵以及 Power cEGR water-ledger 矩阵。
- Power `0.75P0/P0/1.25P0` 全部通过；Voltage 三点均仿真完成，但 600 s 严格稳态门只有 `V0-20` 通过，`V0` 和 `V0+20` 标记为 `not_steady`。
- Voltage 3600 s no-purge persistence 已通过（此前 hot-start 历史证据），说明该历史运行链未出现输入装配或模型运行失败；当前 cold-start-only Voltage 3600 s 结论以第 6 节为准，仍为 `not_steady`。
- Gate 4 代表性空气/OER、背压、湿度、温度和 purge 专项均已通过；这只是单变量代表性覆盖，不等同于完整产品级控制矩阵。S5 仍不宣称整体收口，S6 研究扩展不开放。
- 当前 `.slx` 为 MATLAB 官方 API 重写后的 `250556 bytes` 文件；当前文件 blob hash 与 Git `HEAD` blob 不同。后续必须在实施记录和提交前保留该 provenance 差异，不能直接按字节一致处理。

## 5. 保留产物和修复前未决项

已保留：

- `outputs/RouteA_S5_20260728/S5_power_base_matrix_600s_no_purge.mat`
- `outputs/RouteA_S5_20260728/S5_voltage_base_matrix_600s_no_purge.mat`
- `outputs/RouteA_S5_20260728/S5_power_cegr_water_matrix_600s_no_purge.mat`
- `outputs/RouteA_S5_20260728/S5_gate4_power_cegr_step_600s_no_purge.mat`
- `outputs/RouteA_S5_20260728/S5_gate4_control_specials_600s.mat`
- 已有 Power/Voltage canonical、3600 s persistence 和 Gate 4 ramp compact 结果

未决项：

1. Hydrogen Source runtime dangling-line warning 的正式 owner、精确线段和不改变 solver 语义的处置方案（修复前记录，已由第 6.9 节关闭）。
2. Voltage `V0`/`V0+20` 的稳态时间或控制策略收敛边界；不得仅放宽 `0.5%` 门。
3. Gate 4 的空气供给、背压、湿度、温度和 purge 专项。
4. 物理液水库存/输运/排液/分离效率闭合，以及对应 water-ledger 适用范围。
5. 完成 S5 后的正式提交前模型 provenance 审计和当前分卷增量记录。

## 6. 2026-07-29 cold-start-only 收敛改造与回归

### 6.1 决策和实现

本轮根据当前路线裁决，撤销活动 runner/panel 对热启动 `ModelOperatingPoint` 的依赖。v10 Current/Power/Voltage bundle 已移入 `99_历史归档/2026-07-29_RouteA_hot_start_retired/`，只作为历史审计/对比资产；活动 contract 不把它们作为运行前置。

实际修改：

- `routeA_prepare_electrical_boundary_input.m` 从模型工作区读取 22 字段 command baseline，生成 `RouteA_cold_start_metadata_v01`，固定 `initializationPolicy="cold_start_only"`、`operatingPointLoaded=false`、`researchStart=0`，并显式设置 `LoadInitialState="off"`。
- `routeA_panel_build_simulation_input.m`、`routeA_panel_extract_results.m` 和 `routeA_panel_run_matrix.m` 移除活动热启动选择/回退字段，统一输出 cold initialization provenance。
- `run_routeA_electrical_boundary_study.m` 移除 `hotStartPolicy` 和活动 `initialStateFile` 配置；preflight 使用 `operatingPointLoaded=false`。
- `routeA_simCase_template.m`/`routeA_validate_case.m` 将活动 `initialState.mode` 收紧为 `cold`；显式 `hot` 探针返回 `RouteA:ValidateInitialStateMode`。
- 当前指导、控制接口、测试计划和平台 README 已同步为 cold-start-only；旧 hot 记录不回写。

### 6.2 读回和静态验证

| 检查 | 实际结果 |
|---|---|
| `routeA_model_contract` | `passed=1`，`errors=0`；model workspace、block path、22 字段 profile、历史 bundle provenance 读回通过 |
| `routeA_check_dependencies(paths,true)` | `passed=1`，`errors=0`，`warnings=0` |
| cold 输入探针 | `policy=cold_start_only`、`mode=cold`、`LoadInitialState=off`、22 fields/baseline、topology hash 读回通过 |
| MATLAB Code Analyzer | 本轮活动输入装配、panel build/extract、统一 runner、model contract、simCase template/validator 均为 `code_issues=[]` |
| `model_check(root)` | `77` 条既有 warning、无 error；`unconnected_lines` 既有专项结论仍为 healthy。warning 未因本轮输入链改造新增为阻断项 |

### 6.3 Cold runner 结果

本轮均使用 `platform_default`、`externalCaseEnabled=false`、拓扑 hash `2D8AE250-895A2A82-1980FB9C-C8E0A06A`、`VariableStepAuto`、`RelTol=1e-3`、`AbsTol=1e-3`、`MaxStep=5 s`。

| Case | study.passed | 实际 KPI | 结论 |
|---|---:|---|---|
| Current 28 A, 600 s | 0 | `I=28 A`、`V=424.917593 V`、`P=11.8976926 kW`、gas closure=1、purge=1 | 完成但 `not_steady` |
| Power 11.974169 kW, 600 s | 0 | `I=28.1855047 A`、`V=424.834311 V`、`P=11.974169 kW`、gas closure=1、purge=1 | 完成但 `not_steady`；功率边界误差 `1.05e-11 kW` |
| Voltage 427.648894 V, 600 s | 0 | `I=22.2373524 A`、`V=427.574962 V`、`P=9.50813563 kW`、gas closure=1、purge=1 | 完成但 `not_steady` |
| Current 28 A, 3600 s | 1 | `I=28 A`、`V=425.441491 V`、`P=11.9123618 kW`、steady=1、gas closure=1、purge=1 | `PASS` |
| Power 11.974169 kW, 3600 s | 1 | `I=28.1478294 A`、`V=425.402950 V`、`P=11.974169 kW`、steady=1、gas closure=1、purge=1 | `PASS` |
| Voltage 427.648894 V, 3600 s | 0 | `I=22.5435675 A`、`V=427.413249 V`、`P=9.63541888 kW`、gas closure=1、purge=1 | 完成但 `not_steady` |

### 6.4 Cold panel matrix

Current `cEGR=0/0.3`、600 s serial panel matrix 两例均完成，无仿真错误：

- `cEGR=0`：`I=28 A`、`V=425.195887 V`、`P=11.9054848 kW`、actual cEGR `1.84146506e-6`，`gasClosure=1`，但 `not_steady`。
- `cEGR=0.3`：`I=28 A`、`V=421.979674 V`、`P=11.8154309 kW`、actual cEGR `0.299979826`，`gasClosure=1`，但 `not_steady`。

### 6.5 结论和未决风险

1. cold-start-only 输入链、Current/Power/Voltage 装配、观测契约、气相闭合和 purge 审计均已闭环；原 hot-start checksum/interface 风险不再进入活动运行链。
2. 600 s 不是当前 cold-start-only I/P/V 的统一稳态验收时长；Current/Power 在 3600 s 通过，Voltage 在 3600 s 仍未通过 `0.5%` 稳态门。
3. 不得把 600 s 或 3600 s Voltage 的 `not_steady` 写成模型运行失败，也不得放宽稳态门替代收敛研究。
4. 修复前 Hydrogen Source runtime warning 已明确单独 owner 和处置边界；既有 77 条结构 warning 已逐条形成 ledger，但不以数量归零作为目标；L2 液水库存/输运/排液/分离效率仍未闭合。

保留结果文件：

- `outputs/RouteA_S5_20260728/S5_cold_current_28A_600s_20260729.mat`
- `outputs/RouteA_S5_20260728/S5_cold_power_P0_600s_20260729.mat`
- `outputs/RouteA_S5_20260728/S5_cold_voltage_V0_600s_20260729.mat`
- `outputs/RouteA_S5_20260728/S5_cold_current_28A_3600s_20260729.mat`
- `outputs/RouteA_S5_20260728/S5_cold_power_P0_3600s_20260729.mat`
- `outputs/RouteA_S5_20260728/S5_cold_voltage_V0_3600s_20260729.mat`
- `outputs/RouteA_S5_20260728/S5_cold_panel_current_cegr_0_030_600s_20260729.mat`

### 6.6 Warning ledger and current disposition update

2026-07-29 已完成当前 root scope `unconnected_ports` warning 的逐条审计，详见 [RouteA model_check warning ledger](../../03_审计与研究/RouteA_cEGR_PEMFC_model_check_warning_ledger_20260729_v01.md)。当前读回将 77 条分为：

- `R1 readback-confirmed`：22 条，当前 `model_read` 可确认连接；
- `R2 optional-wrapper-interface`：36 条，封装层或可选 Connection Port；
- `R3 unused-observation`：11 条，传感器输出未进入当前 observation registry；
- `R4 unused-physical-input`：8 条，Pipe/Chamber 的可选 MIn/TIn 未启用。

`model_check(unconnected_lines)` 读回为 healthy。修复前 Hydrogen Source runtime dangling-line warning 作为独立 `RT-H2-20260729` 未决项保留，禁止用删除 Solver Configuration、人工质量源或 Terminator 伪清零。本节记录的是周期门实施前的首轮结果；修复后结论见第 6.9 节。

### 6.7 Cold Voltage 未收敛边界的结果审计

未重复运行 3600 s case，直接读取 `outputs/RouteA_S5_20260728/S5_cold_voltage_V0_3600s_20260729.mat` 的 compact `case` 结果。尾窗为模型时间 `[3540,3600] s`，实际读回如下：

| 量 | 第一半窗均值 | 第二半窗均值 | 相对变化 | 判定 |
|---|---:|---:|---:|---|
| stack voltage | `427.4109 V` | `427.4156 V` | `1.0798e-5` (`0.00108%`) | 稳定 |
| stack current | `22.7180 A` | `22.3691 A` | `0.0154` (`1.535%`) | 未通过 `0.5%` 和 `1%` |
| stack power | `9.7099 kW` | `9.5609 kW` | `0.0153` (`1.53%`) | 未通过 `0.5%` 和 `1%` |
| cathode O2 stoich | `4.3113` | `4.3785` | `0.0154` (`1.535%`) | 随电流变化 |
| stack temperature | `79.9984 degC` | `79.9983 degC` | `1.5923e-7` | 稳定 |
| compressor mass flow | `0.0139 kg/s` | `0.0139 kg/s` | `1.8417e-9` | 稳定 |
| cathode inlet RH | `0.9884` | `0.9884` | `2.2222e-8` | 稳定 |
| cEGR ratio | `1.8050e-6` | `1.8050e-6` | `8.8089e-7` | 稳定 |

电边界自身跟踪通过：tail mean voltage `427.413246 V`，目标 `427.648894 V`，tail relative error `5.5103e-4` (`0.0551%`)，tail span `0.008445 V`；gas closure=1，tail purge event count=0。由此当前证据支持以下判断：cold Voltage case 的稳态门由电流/功率及其派生的氧计量比慢变化触发，电压跟踪、温度、压缩机和气相闭合不是当前失败主因。下一步应做恒电压电流/PI 动态的时长或控制边界研究，并同时检查电气状态/电流命令的慢变量；不得仅放宽稳态阈值，也不应把本结果记为 solver failure。

新增周期审计产物：`outputs/RouteA_S5_20260728/S5_cold_voltage_periodic_anode_audit_20260729.mat`。该产物直接从已保留的 3600 s `SimulationOutput` 生成，未重复仿真：检测到 4 个 purge event、3 个完整周期，周期均值 `767.016546 s`、标准差 `2.096902 s`；3 个完整周期的 stack current span 为 `7.324812/7.179144/7.178176 A`，Voltage span 为 `2.894047/3.471504/3.461470 V`，tail event count=0。`routeA_assess_electrical_boundary_outputs` 现将同一结果写入 `result.periodicAnode`；最终周期响应门见第 6.8 节。

### 6.8 恒电压控制链、空气 OER 耦合与 purge 对照（2026-07-29）

本轮针对 cold Voltage 3600 s 未通过原始稳态门的问题，读回 Voltage 变体和 Oxygen Source/Compressor Control 的实际连接。控制链为：

```text
V_stack -> Voltage Error(+)
V_ref   -> Voltage Error(-)
Voltage Error = V_stack - V_ref
          -> PI(Kp=1, Ki=0.05, clamp 0..392 A, clamping anti-windup)
          -> Current Command Dynamics(tau=0.1 s)
          -> single I_cmd -> Electrical Load -> Stack
```

因此当堆电压高于设定值时，误差为正，PI 增大电流；燃料电池负载电流增大使堆电压下降，反馈方向为负反馈。短时日志验证 `routeA_voltage_control_error_V` 与 `V_stack - V_ref` 残差为 0，实际 `routeA_voltage_current_cmd_A` 与堆电流残差为 0。

阴极空气控制实际为 `routeA_air_control_mode_id=2` 的 `target OER` 模式。Compressor Control 先用 `OER * max(I_stack, 0.1*stack_iL*stack_area)` 计算目标空气质量流量，再由空气 PID 跟踪实测压缩机流量。当前参数 `stack_iL=1.4 A/cm^2`、`stack_area=280 cm^2`，最小电流折算值为 `39.2 A`。最终 OER 基线已将模型 workspace 的 `routeA_command_profile_baseline[6]` 从 `2.5` 对齐到 `3.0`，阴极背压基线从 `0.161325` 对齐到 `0.1613 MPa`；`routeA_model_contract` 新增两项 platform-default baseline 检查。

最终同条件 cold V0 对照结果：

| Case | 3600 s 结果 | 关键证据 |
|---|---|---|
| purge-enabled | 原始 steady `not_steady`；新门 `periodic_response_voltage_tracked` | 4 个 purge event、3 个完整周期；周期均值 `759.972257 s`、标准差 `1.557600 s`；Current/Power/derived O2 stoich 最大变化 `1.554%`，Voltage tail 相对误差 `0.0577%`、span `0.011457 V` |
| purge-disabled | strict `PASS` | 最大稳态变化 `0.0874%`；Voltage tail 相对误差 `0.00153%`；无 purge event |

两组 case 的电流均小于 `39.2 A`，`air_mdot_set=0.016667929 kg/s` 全程 span 为 0；实际压缩机流量仅在设定值附近跟踪。因此本次电流波动不是阴极空气设定流量被错误带动，而是阳极 purge 引起阳极库存/堆电压变化后，恒电压 PI 正常调节 `I_cmd` 的结果。`cathodeOxygenStoich` 的变化主要是电流派生量，不应单独作为恒电压失败证据。

P0 验收现已增加周期响应门：Voltage 跟踪、限幅、气相闭合、`lambda>1`、温度/压缩机/压力/RH 等非周期信号仍为强制条件；在至少 2 个完整周期且周期标准差/均值不超过 `1%` 时，Current、Power 和 derived O2 stoich 转为周期诊断项。正式 P0 回归读回：preflight=1、longCases=1、overall=1；Current/Power 为 strict pass，Voltage 为 `periodic_response_voltage_tracked`。

紧凑诊断证据：`outputs/RouteA_S5_20260728/S5_voltage_control_coupling_diagnostic_20260729.mat`。正式 P0 报告：`04_Simulink物理网络模型/outputs/RouteA_P0_acceptance/RouteA_P0_acceptance_latest.mat`。

### 6.9 Hydrogen Source dangling-line 修复与回归（2026-07-29）

本节记录第 6.6 节未决 runtime warning 的实际处置，不回写修复前的历史结果。

#### 根因定位

- `model_read(scope=blk_893, depth=1)` 和 MATLAB `Line` API 读回显示，修复前 `Hydrogen Source` 内有 14 条内部线；其中存在 `SrcBlockHandle=-1`、`DstBlockHandle=-1` 且 `Connected=off` 的孤立 line object。
- 该孤立对象位于 `Pressure-Reducing Valve/LConn1` 的残留分支。官方 Gas Mixture PEMFC 母版对应拓扑为 `Fuel Tank/A <-> Pressure-Reducing Valve/LConn1` 的唯一直接连接；当前模型此前保留了额外残留线段。
- `model_check(scope=blk_893, checks=["all"])` 的 15 条 warning 主要是 Fuel Tank/Pipe 的可选端口提示，不能识别上述 runtime dangling line；root `unconnected_lines` 仍为 healthy。

#### 最小修复

通过 `model_edit(scope=blk_893)` 执行以下操作：

1. 断开 `blk_921.LConn1` 的全部旧物理分支；
2. 断开 `blk_918.A` 的全部旧物理分支；
3. 重建唯一连接 `blk_918.A <-> blk_921.LConn1`。

未删除 Solver Configuration，未增加人工质量源、温度源或 Terminator，未修改 Fuel Tank、Pipe、PRV 参数和活动 cold-start 输入链。

#### 修复后读回

| 检查 | 实际结果 |
|---|---|
| Hydrogen Source MATLAB line readback | 12 条内部线，12/12 `Connected=on`，`orphan_or_unresolved=0` |
| Hydrogen Source model readback | `blk_918.A <-> blk_921.r1`；`blk_921.y1 <-> blk_935.A`；`blk_935.B <-> blk_917.port`；热绝缘连接保持；Solver Configuration 未删除 |
| `model_check(scope=blk_893, all)` | 12 条可选 Fuel Tank/Pipe 端口 warning，无 dangling line error |
| `model_check(root, unconnected_lines)` | `healthy` |
| MATLAB model update | `lastwarn` 为空 |
| `routeA_model_contract` | `passed=1`，`errors=0`，`warnings=0` |
| 修复后正式 P0 provenance | `generatedAt=2026-07-29 13:11:31`；topology hash `CA518FBC-E65AB763-5FEDF9CA-0FAF6D89`；`preflight=1`、`longCases=1`、`overall=1` |

#### 修复后行为回归

- P0 10 s smoke：2/2 case 完成，P0 smoke section `passed=1`，`SimulationOutput.ErrorMessage` 为空；命令窗口未再出现 Hydrogen Source dangling-line warning。
- 正式 P0 3600 s：`preflight=1`、`longCases=1`、`overall=1`；Current `strict_pass_0p5_percent`，最大变化 `0.000388383280105`；Power `strict_pass_0p5_percent`，最大变化 `0.000400096869657`；Voltage `periodic_response_voltage_tracked`，最大变化 `0.0155424152471`。
- 修复后仍出现的 `ToWorkspace/Timeseries` 与 Simscape logging 提示属于既有 checksum/toolchain hygiene，不再归属于 `RT-H2-20260729`，也未产生 `SimulationOutput.ErrorMessage`。

结论：`RT-H2-20260729` 已关闭。S5 的剩余工作是 600 s/面板/完整 cold 矩阵、Voltage 收敛边界研究、液水闭合和模型 provenance 收口。

### 6.10 P1 面板基础版实施准入（2026-07-29）

本节记录 P0/S5 当前证据对 P1 的阶段裁决。该裁决只允许启动 P1 实施，不把 P1 目标写成已交付结果。

#### 准入依据

- `routeA_check_dependencies(paths,true)` 和 `routeA_model_contract` 均通过，错误数和 contract warning 数为 0；
- 活动 runner 固定 `cold_start_only`，显式 `LoadInitialState="off"`；
- P0 10 s smoke 2/2 case 完成；正式 P0 3600 s `preflight=1`、`longCases=1`、`overall=1`；
- Current/Power 为 `strict_pass_0p5_percent`，Voltage 为 `periodic_response_voltage_tracked`；
- Hydrogen Source runtime warning 已关闭，修复后 12/12 条内部线已连接，Solver Configuration 保持；
- 现有 `RouteA_Panel_v01`、`routeA_panel_build_simulation_input`、`routeA_panel_extract_results` 和 `routeA_panel_run_matrix` 已形成可复用的 P1 基础。

#### P1 实施边界

P1 只扩展现有面板和已注册接口，优先覆盖电边界、阴极进气、温度控制、气相结果和当前 L2 水管理状态。P1 不新增未经批准的物理块，不直接开放 `inventory`/`unresolved` 参数，不复制 plant 或 runner，也不通过 UI 控件掩盖模型缺口。

#### 保留的 P1 验收约束

- cold 600 s I/P/V 与面板 `cEGR=0/0.3` 矩阵仍需按稳态/周期口径完成判定；
- 完整 cold 矩阵仍未收口；
- 阳极压力、阳极 purge 状态和冷却侧响应仍有 unresolved 观测项；
- L2 液水库存、输运、排液和分离效率尚未闭合，不能宣称全液水平衡；
- 每个 P1 功能必须完成单工况 smoke、基线回归、最小矩阵、结果读回和实施记录后才能标记完成。

阶段结论：**允许进入 P1 面板基础版实施；不宣称 P1 完成，也不开放 P2 cEGR 研究仪表板或全设备参数实验台。**
