# RouteA 面板全链路可信性审计实施记录

## 前置决策

依据 `PLAN (2).md` 的面板全链路可信性重建要求，继续使用唯一活动 Route A 模型和冷态正式 panel runner；在输入/输出行为审计完成前，不恢复工程解释或汇报使用。

## 已实施

- 在正式模型 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` 的 `Cathode_Exhaust_Backpressure_Water` 中增加 `OutletPressure_Pa_to_MPa` Gain，增益为 `1e-6`，将 `routeA_p_outlet` 的 Pa 信号转换后再送入 `SeparatorOrCondensation/p_MPa`。
- 将 `cathode.waterSeparationRate` 降级为 `not_validated`，并在结果对象和面板中明确标记为 L2 气相饱和过量估算，不再称为真实分离器流量。
- 结果对象增加 `resultProvenance` 和 `panelTrust`，记录来源信号、单位、采样位置、后处理公式、状态和证据范围。
- 面板 KPI 的水列改为 `not validated (L2 estimate)`；诊断表保留数值，但标注无液水库存/输运/排液闭合。
- 增加唯一正式审计 runner `run_routeA_panel_trust_audit.m`，执行冷态基线与单变量扰动，并分离 `not_run`、`executed`、`behavior_changed_pending_direction`、`no_observable_response` 和 `blocked` 状态。
- 观测能力矩阵将 `acceptanceAllowed` 保守置为 false；结构已连通不再等价于行为已验证。

## 实际验证证据

### 101 项审计 runner 实施与执行状态

- 将正式 runner 重建为单一 `run_routeA_panel_trust_audit.m`，不创建模型副本或并行 runner。支持 `scope=all_active`、`dryRun`、`maxCases`、`resume`、`caseFilter`、`domainFilter`、10 s/600 s 两级运行和失败后继续。
- 每个输入记录 UI 控件、`simCasePath`、写入路径、单位、基线/扰动值、消费者状态、关联观测、输出 delta、方向/单位状态和 fingerprint；每个 case 完成后更新 `trust_audit_state.mat`、`trust_audit_cases.csv`、`trust_audit_summary.md`。
- dry-run 已通过：`planned=101`，与当前 registry `active=101` 一致。证据根目录为 `04_Simulink物理网络模型/outputs/RouteA_Panel/trust_audit/`。
- 已完成的真实小批量：Current/Power/Voltage 各执行基线+扰动，短时四层门槛通过；`consumerState=write_target_library_boundary_verified`，模型输出发生变化，方向和结果单位契约通过。
- 全量 10 s 筛查已启动并按 case 持久化，但 MATLAB MCP 单次执行在 600 s 超时；某次全量尝试观察到 `no_observable_response` 和执行失败项，均作为失败分类处理。随后用同一 fingerprint 恢复并重建完整 101 项状态。Codex 专用 R2025b 会话已启动 2-worker `Processes` 池，runner 使用 `parfeval` 并发执行、主进程逐项写回证据；两个 4 项短时批次实测 286.6 s 和 291.2 s。已修复 runner 的报告返回契约、worker future 原始错误保留、非数值诊断观测保护，以及局部复查保留 101 项全矩阵的行为。`cathode.airControlMode` 复查证明仿真执行完成，但关联观测无量化变化，正确分类为 `no_observable_response` 而非执行失败。当前正式证据为 `partial`：4 项已完成、16 项已有失败/无响应裁决、81 项待运行。该超时或执行状态均不等于通过，也不允许恢复面板可信状态；后续必须使用相同模型、runner 和 fingerprint `resume=true` 续跑。

### 当前状态摘要

当前 CSV/MAT 是可复查的逐项状态真源，不能以静态注册表的“已连线”替代行为证据。已完成项、失败项、无响应项和未运行项均保留在同一矩阵中；分类扰动（电边界模式、solver、空气模式）采用显式合法替代值，数组保持形状，不再用无意义标量乘法伪造扰动。

- 正式 panel runner 短时冷态工况 `audit_unit_5s` 完成：`Tout=329.199309 K`、`Tstack=20.6372096 degC`、`RH in=0.104399402`、`RH out=0.649644369`、`Water sep=0 kg/s`。该工况 `gas_closure` 未通过，因此结果仅为诊断证据。
- `run_routeA_panel_trust_audit(struct('stopTime_s',2,'maxCases',1))` 成功执行基线和一项扰动；汇总为 `base=1, executed=1, behaviorChanged=1, noResponse=0`。编译期分类参数被明确记为 `not_run`，未被伪造为通过。
- 读回四个阴极出口 PS-Simulink Converter 的 `Unit` 均为 `inherit`；模型保存后 `Dirty=off`。
- `model_check` 已执行；保留原模型的 Simscape 未连接端口类 warning，共 77 个 warning，未发现由本次压力转换引入的新增 error。需后续逐项归类 warning 是否可接受。

## 未决风险

- 当前仍未完成全部可编辑输入的完整行为矩阵；`run_routeA_panel_trust_audit` 默认只适合分批执行，完整审计需将 `maxCases` 扩展至 `Inf` 并保存紧凑证据。
- 当前全量短时矩阵尚未完成，不能将 101 项中的未运行项视为通过；应按输出目录中的 state fingerprint 分批续跑，并在全部项有明确结论后再进入 600 s 长时复核。
- 出口温度和组分转换器仍为 `Unit=inherit`，需结合实际信号 `DataInfo.Units` 和行为扰动进一步确认 K、质量/摩尔分数契约。
- RH 结果已来自模型输出，但采样位置与温度定义仍需在代表性温度/RH/背压工况中闭合验证。
- Water sep 仍不是液水库存、排液量或分离效率，主 KPI 不得用于工程结论。

## 状态

`implemented_structurally_verified_executed_pending_behavior_audit`。面板可信状态保持暂停。

## 2026-08-13 审计器缺陷更正与停点

### 今日确认的问题

- 原审计 runner（`RouteA_Panel_TrustAudit_v02`）把参数注册表的关联观测泛化为“任一信号有变化即可”，没有把输入的物理含义、互斥控制模式和实际取样位置作为门槛。该方法不能证明面板输入真的控制了应有的模型量。
- `cathode.targetOer` 的观测链接错误地指向 `cathode.inletRelativeHumidity`。RH 是加湿后果，不是 OER 控制器的消费者证据；因此 v02 中 OER 的 `failed` / `no_observable_response` 不能解释为面板或模型链路失败。
- runner 从 `routeA_panel_extract_results` 读取尾窗统计结构时，只接受数值标量，未统一提取 `.mean`。这会遗漏已经由模型计算出的尾窗量，造成“无响应”的假阴性。
- v02 的 10% 扰动对带有明确上下界的控制量并不总是足以形成可辨识响应。已改为优先选取距离默认值最远的合法边界；OER 因此使用 `3 -> 5`，与面板人工对比的有效工况一致。
- 后台 MATLAB 仿真没有在面板窗口显示运行状态，容易造成“没有运行”的误解。后续每批运行前必须报告参数集合、模型时间、运行方式和预计墙钟时间；运行后报告真实已执行数与证据位置。

### 已完成的 v03 定向修复与证据

- `run_routeA_panel_trust_audit.m` 升级为 `RouteA_Panel_TrustAudit_v03`；旧 v02 fingerprint 不再复用。
- 新 runner 为每项保留 `validationContract`。契约至少包含：激活模式、实际模型观测、方向规则、单位契约和无法定义时的阻塞原因。未定义契约的项会得到 `blocked_validation_contract`，而不是伪造 `failed` 或 `passed`。
- 修正能力矩阵：`cathode.targetOer` 的观测为 `cathode.inletOxygenStoich` 和 `cathode.compressorInletMassFlow`；新增前者为基于 `routeA_mdot_species_ca_in_ts` 和电堆电流计算的模型派生观测，而非 UI 命令快照。
- 修正 runner 的尾窗统计量读取：对 `windowStats` 结构统一取 `.mean` 后再比较。
- OER 定向冷态短时对照已实际执行，使用正式 `simCase -> routeA_panel_build_simulation_input -> SimulationInput -> sim -> routeA_panel_extract_results` 链：目标 OER `3 -> 5`，并强制 `airControlMode=2`。结果为实际阴极入口氧过量系数 `3.85057 -> 6.48282`，压缩机入口质量流量 `0.0152902 -> 0.0257426 kg/s`；写入读回、消费者证据、响应、方向和单位声明均通过。此结论仅适用于该 OER case。
- 当前证据根目录 `outputs/RouteA_Panel/trust_audit/` 的 v03 状态为 `planned=101`、`completed=1`（仅 `cathode.targetOer`）、其余 100 项未运行。旧 v02 的 9 个 `failed`、24 个 `no_observable_response` 和并行 future 错误不再作为任何面板输入的行为结论，只保留为发现审计器设计缺陷的历史证据。

### 明日续作顺序

1. 建立并评审完整的 101 项输入级契约表。每项必须有 UI 控件、`simCase` 路径、`SimulationInput` 写入点、实际消费者、激活前置条件、主观测、单位、采样位置、扰动规则和通过判据。
2. 优先完成基础/高级面板的运行控制、阴极边界、温度/RH、组分、cEGR 和阳极控制契约；设备和 solver 参数按各自消费者分组，不用通用 KPI 代替。
3. 对每个契约实施一次定向基线/扰动。先短时验证写入、消费者、主观测和方向；只有短时通过的项才进入 600 s 尾窗复核。
4. 单独闭合 RH/温度/压力/组分：确认 `stackTemperatureSet_C`、实际堆温、加湿器温度、`routeA_T_outlet`、RH 计算温度和 `routeA_p_outlet` 的采样位置及单位。水分离继续仅作为 L2 诊断量。
5. 只有完整契约和短时矩阵建立后，才恢复并行分批运行；每批保持可见的开始/结束记录，不使用旧 v02 状态续跑。

## 2026-08-14 v10 契约闭合与阳极源边界观测修复

### 前置决策

- 沿用本记录的输入级验证要求：输入必须闭合 UI -> `simCase` -> `SimulationInput` -> 实际模型消费者 -> 同一物理位置的观测，再讨论物理响应。
- 本节不复用 v02-v08 的 `failed`、`no_observable_response` 或 `passed` 状态；它们只保留为审计器或观测位置问题的定位证据。

### 实际完成

- `run_routeA_panel_trust_audit.m` 更新至 `RouteA_Panel_TrustAudit_v10`。v10 静态契约为 101/101 完整项：96 项 `physical_response`，5 项 `numerical_integrity`，零项因“当前未观测”或“数值设置”被禁止进入验证。
- 对旧 20 个错误分类项完成原因区分：电气模式/Voltage PI 是审计矩阵遗漏观测映射；5 个 solver 项是 `SimulationInput.setModelParameter` 的数值一致性消费者；阳极 H2 已到 `tank_yH2`；阳极源 P/T 原先由脚本写到 `tank_p`/`tank_T`，但主观测错误地使用了减压阀出口。
- 在唯一正式模型 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` 的 `Anode_Hydrogen_BOP/Hydrogen Source` 中发布燃料罐气体出口 P/T 观测：`FuelTankPressureSensor_FC`、`FuelTankPressureSensor_AbsoluteReference_FC`、P/T PS-Simulink Converter 及两个 To Workspace 输出。输出为 `routeA_anode_source_pressure_ts`（MPa）和 `routeA_anode_source_temperature_ts`（degC），保存格式均为 `Structure With Time`。
- 同时保留此前发布的阳极入口压力/温度、入口组分/RH、出口组分和 purge state 输出。提取器和观测验证器改为将 `Structure With Time` 的尾置时间维（例如 `4x1xN`）规约为时间首维；RH 明确取湿度向量 `W(:,4)`，而不是将整条四分量向量误作标量。
- v10 将 `anode.sourcePressure_MPa_abs` 的主观测改为 `anode.sourcePressure`，将 `anode.sourceTemperature_C` 的主观测改为 `anode.sourceTemperature`；两者采样位置均为减压阀上游的燃料罐气体出口。减压阀出口压力仅属于 `anode.inletPressure_MPa_abs` 的主观测。
- 结果对象契约同步升为 `RouteA_Panel_Result_v03`，成功和失败结果使用同一版本标签。

### 实际验证证据

- 结构读回：源 P/T 传感器、组分参考块、两个 Converter 和两个 To Workspace 均存在；两个新输出均为 `Structure With Time`；正式模型读回 `Dirty=off`。模型更新执行 `SimulationCommand=update` 并成功保存。
- v10 dry-run 实际生成 CSV/MAT/Markdown：101 行、缺失契约 0、`physical_response=96`、`numerical_integrity=5`、`runnable=101`。证据根目录：`02_结果/RouteA_GasMixture_Derived/outputs/RouteA_Panel/trust_audit_v10_contract/dry_run/`。
- 仅作为问题定位而非行为结论，v08 对 `anode.sourcePressure_MPa_abs` 实际执行了基线和扰动各 10 s（2 次 `sim()`，模型时间共 20 s）。`tank_p` 为 `0.30 -> 0.50 MPa`；写入读回、消费者、单位和响应均通过，但减压阀出口尾窗压力为 `0.161298330 -> 0.161057258 MPa`，故旧的“源压升高必须使减压阀出口压力升高”方向判据失败。该现象与下游压力受减压阀控制一致，不能分类为源压面板或模型故障。

### 未决项与停点

- 未执行 v10 的任何短时或 600 s 仿真；燃料罐出口 P/T 新观测尚无 v10 行为通过结论。恢复时应先对 `anode.sourcePressure_MPa_abs` 和 `anode.sourceTemperature_C` 各执行基线/扰动短时切片，只有短时门通过才执行对应 600 s 复核。
- Rapid Accelerator 仍对既有阴极/系统 To Workspace `Timeseries` 输出告警；阳极新输出已经使用兼容格式。该全局观测格式整治尚未开始，不能将告警涉及的阴极、RH、组分或 Water sep 项当作已可信。
- 面板整体保持 `audit_pending`；Water sep 仍仅为 L2 气相饱和过量诊断，不能解释为液水分离量、排液量或效率。
