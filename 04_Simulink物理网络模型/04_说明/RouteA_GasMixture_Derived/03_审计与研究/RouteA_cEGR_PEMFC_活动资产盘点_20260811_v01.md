# Route A cEGR-PEMFC 活动资产盘点

文件类型：当前资产审计（只读证据）
日期：2026-08-11
审计对象：活动 Route A `.slx`、面板、输入装配、验证、正式 runner 与测试代码。
审计目的：先判定平台是否可操作、可验证，再决定何时进入 cEGR 研究矩阵；不以计划文件替代模型和代码证据。

更新：同日完成 P3-M1 能力矩阵收口；本文件保留发现过程，并以第 4 节记录修复后的当前状态。

## 1. 本次结论

平台已经不是“仅有设计文本”的状态：被动 cEGR 物理支路、单工况面板、统一 `SimulationInput` 装配、结果抽取、单/矩阵 runner 和局部物理单元测试均真实存在。

平台已具备进入 cEGR 研究**规格化和小样本预检**的最小证据：此前发现的面板能力矩阵失配已在同日修复并通过无仿真契约回归；两组 20 s 面板参数 smoke 已证明参数能影响模型输出；Power 40 kW 下的 cEGR step、负载 ramp 与 OER step 均通过。正式多因素研究矩阵仍须先冻结变量、范围、KPI 和排除规则。

本次判定：**平台准入达到“研究规格化和小样本预检”，尚未达到“直接批量扫描”。** 20 s 端到端 smoke 与三类 600 s 动态覆盖均已完成；下一步是将研究矩阵及其 KPI/排除规则固化为单一正式 runner 配置。

## 2. 审计边界和证据方式

| 范围 | 实际读取/执行方式 | 结论边界 |
|---|---|---|
| 模型结构与参数 | MATLAB MCP `model_overview`、`model_read`、`model_query_params`、`model_check` | 证明拓扑和当前配置，不替代全工况动态验证 |
| 面板与脚本 | 直接读取活动 `.m` 文件；MATLAB Code Analyzer | 证明控制路径和静态质量，不证明物理效果 |
| 契约与依赖 | 执行 `routeA_check_dependencies`、`routeA_model_contract`、`run_routeA_p1_panel_contract_tests` | 证明程序集一致性；失败项应阻断用户接口验收 |
| 阀门机理 | 执行 `RouteACegrValveConstitutiveTest` | 仅覆盖关闭/开启局部构成，不覆盖整机 cEGR 控制性能 |

## 3. 活动资产清单

### 3.1 物理模型和控制拓扑

| 资产 | 唯一职责 | 实际读回 | 状态 |
|---|---|---|---|
| `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` | 活动系统级物理网络 | 根级包含阳极 BOP、阴极空气/cEGR BOP、阴极排气/背压/水、Stack、控制观测、热管理和 cEGR mode selector | 活动主模型 |
| `Cathode_Air_cEGR_BOP/EGRValveRestriction` | 被动回流阀 | Variant 子系统当前为 `Open`，内部是官方 `FuelCell_lib/elements/Local Restriction (FC)`；EGR pipe、压力/温度传感器和回流入口混合器均存在 | 已核查物理结构 |
| `System_Control_Observability/FCU_BoP_Control` | cEGR 比例控制 | 由 `abs(egr_mdot)/max(abs(mdot_comp_inlet),1e-6)` 形成实际比值；目标比值、误差、PID、执行器、一阶饱和限幅连接至阀面积命令 | 已核查控制结构 |
| `Cathode_Exhaust_Backpressure_Water/SeparatorOrCondensation` | 排气水量估计 | MATLAB Function 以饱和过量水蒸气计算 `m_water_sep` | L2 代理量；不是液水分离器/库存闭环 |

当前模型配置读回：`VariableStepAuto`、`StopTime=100 s`、`RelTol=AbsTol=1e-3`、`MaxStep=0.1 s`、`SimulationMode=normal`、`SimscapeLogType=all`。研究 runner 可按工况重设这些研究控制量。

`model_check` 返回 77 条 `unconnected_ports` warning、无悬空线错误。已有 warning ledger 将其分为 Simscape/Variant 读回限制、容器端口、未注册观测和未用物理输入；因此它们不是已忽略的零风险项，后续新增端口或观测时仍须按 ledger 复核。

### 3.1 2026-08-14 后续裁决

`Cathode_Exhaust_Backpressure_Water/SeparatorOrCondensation` 中的 MATLAB Function 仍是历史 L2 饱和过量水蒸气代理；它可以作为当前行为证据的已知边界，但不再作为新架构的正式物理模块模板。后续应优先使用官方 Simscape/Simulink 气体、湿度和相态模块；在完成替换或删除前，任何结果必须继续标注为气相 L2 代理，不得表述为液水分离器、液水库存或排液模型。

### 3.2 面板、参数与输入装配

| 资产 | 唯一职责 | 实际证据 | 状态 |
|---|---|---|---|
| `03_脚本/RouteA_GasMixture_Derived/launch_routeA_panel.m` | 用户入口 | 启动前严格执行依赖检查和模型契约检查，然后创建 `RouteA_Panel_v01` | 可操作入口 |
| `RouteA_Panel_v01.m` | 单工况/矩阵 UI | `RunButtonPushed` 依次调用校验、输入装配、`sim(simIn)`、结果抽取；提供矩阵、历史和导出动作 | 真实 UI，不是占位面板 |
| `routeA_simCase_template.m` + `routeA_validate_case.m` | 默认工况和边界校验 | 包含 cEGR PID/执行器和电堆 4 参数；校验其正值、整数或上下界 | 已接入 |
| `routeA_panel_build_simulation_input.m` + `routeA_prepare_electrical_boundary_input.m` | 单一装配链 | 写入求解器、cEGR 模式/目标/PID、执行器、电堆单体数/面积/`iL`/`io`、三类电边界、温度和命令 profile | 已接入；物理效应仍须运行读回 |
| `routeA_parameter_registry.m` | 参数真源 | 总 146；活动 47、库存 99；无 unresolved active parameter | 参数分层完整 |
| `routeA_observation_registry.m` | 观测真源 | 总 26；结果 22、status-only 4；已验证 18、可选 4、unresolved 4 | 阳极/冷却扩展项未闭环，不得作为验收 KPI |

`routeA_check_dependencies(paths,true)` 和 `routeA_model_contract(paths, strict=true)` 均通过（errors=0，warnings=0）。

### 3.3 正式运行和结果表达

| 资产 | 唯一职责 | 当前能力/边界 |
|---|---|---|
| `run_routeA_p1_panel_single_case.m` | 面板等价单工况 runner | 统一输入装配后 `sim`；默认 600 s；可选择导出结果 |
| `routeA_panel_run_matrix.m` | 面板矩阵 runner | 复用同一 builder 和 extractor；笛卡尔矩阵限制 24 例；支持串行/两 worker `parsim` |
| `run_routeA_electrical_boundary_study.m` | 正式三电边界研究入口 | 串行/并行统一管线；稳态默认 600 s、尾段 540--600 s；默认不保留大型 `SimulationOutput` |
| `routeA_panel_extract_results.m` | 面板结果契约 | 从结构化观测注册表提取 22 个结果项；4 个未闭环观测保持 status-only |
| `routeA_stage1_water_ledger_from_outputs.m` | 水账本后处理 | 可选后处理；不应被表述为闭合液水物理模型 |

静态 Code Analyzer：上述关键 `.m` 文件无 warning/error；`RouteA_Panel_v01.m` 仅有 4 条动态数组增长的 info 级建议，不影响功能判定。

### 3.4 已执行验证

| 项目 | 实际结果 | 可以说明什么 | 不能说明什么 |
|---|---|---|---|
| `RouteACegrValveConstitutiveTest` | 1 passed / 0 failed，11.63 s | 官方无限阻力关闭态阻断正反向质量/能量/组分流；官方局部阻力开启态存在正向流 | 不证明系统比例可达、控制稳定或研究结论 |
| 依赖检查 | pass，0 errors，0 warnings | 面板启动前的外部路径/资产可解析 | 不证明仿真物理正确 |
| 严格模型契约 | pass，0 errors，0 warnings | 模型、注册表、输入接口和冷态入口契约一致 | 不覆盖每个 UI 参数的能力矩阵注册 |
| P1 面板契约测试（修复前） | **fail** | 发现用户能力声明与代码映射不一致 | 该结果是修复触发证据，不代表当前状态 |
| P1 面板契约测试（修复后） | pass；`simulationStarted=0`；21 个非法输入拒绝；3 类电边界、3 种空气模式和高级映射均构建 | 面板到 `SimulationInput` 的无仿真契约闭环 | 不证明运行时动态效果 |

## 4. 已解决的契约阻断项

`run_routeA_p1_panel_contract_tests` 在以下断言失败：

```matlab
assert(all(arrayfun(@(entry) strlength(entry.uiProperty) > 0, ...
    matrix.parameters)), 'An active parameter has no UI mapping.');
```

诊断结果为 47 个 active parameter 中有 7 个在能力矩阵无 `uiProperty`：

| canonical name | 实际 UI 控件 | 实际 simCase 字段 | 实际写入变量 |
|---|---|---|---|
| `cegr.controller.Kp_area` | `AdvancedCegrKpEditField` | `controls.cegr.controller.Kp_area` | `routeA_egr_control_Kp_area` |
| `cegr.controller.Ki_area` | `AdvancedCegrKiEditField` | `controls.cegr.controller.Ki_area` | `routeA_egr_control_Ki_area` |
| `cegr.actuatorTau_s` | `AdvancedCegrActuatorTauEditField` | `controls.cegr.controller.actuatorTau_s` | cEGR 执行器时间常数写入 |
| `stack.numCells` | `AdvancedStackNumCellsEditField` | `controls.stack.numCells` | `stack_num_cells` |
| `stack.area_cm2` | `AdvancedStackAreaEditField` | `controls.stack.area_cm2` | `stack_area` |
| `stack.iL_A_cm2` | `AdvancedStackIEditField` | `controls.stack.iL_A_cm2` | `stack_iL` |
| `stack.io_A_cm2` | `AdvancedStackIoEditField` | `controls.stack.io_A_cm2` | `stack_io` |

问题位于 `routeA_p1_panel_capability_matrix.m` 的 `parameterContract` 漏项，而非 UI、模板、校验器或输入装配不存在。已补齐这 7 个 `case` 的 `uiProperty`、`simCasePath`、`writePath`、运行时属性和观测关联，并重跑同一契约测试通过。

同一面板 builder 对一组非默认输入的读回也已通过：`Kp_area=2.3562e-4`、`Ki_area=4.7124e-5`、`actuatorTau_s=0.75 s`、`numCells=401`、`area=266 cm^2`、`iL=1.47 A/cm^2`、`io=1.1e-4 A/cm^2` 在 `SimulationInput` 与 context 中一致。此证据只说明参数装配生效；不等价于仿真响应已验证。

随后两例由可见面板发起的 20 s 冷态仿真均完成、22 个 registered signals 通过观测契约：cEGR 控制参数工况为 `404.23 V / 40.42 kW / 实际 cEGR=0.089`，电堆参数工况为 `404.96 V / 40.50 kW / 实际 cEGR=0.086`。二者均因目标 cEGR=0.100 未在短窗口达到而标记 `completed_acceptance_failed / cegr_tracking`。这证明参数对求解输出可见，但不构成控制性能通过。

动态 profile 输入曾因 numeric `N-by-2` 初值提取错误而在输入装配阶段停止；修复后，正式 600 s Power 40 kW 工况的 cEGR `0 -> 0.1 -> 0.3` profile 通过：0.1 平台实际比 `0.09997139`，0.3 尾窗实际比 `0.299989675`，尾窗功率 `40.000 kW`、电压 `406.269 V`。22 个 registered signals 的观测契约通过；仅 Stack power 与 cEGR mass flow 保留上游 `logsout` 单位元数据缺失 warning。

同一动态链的最小扰动覆盖也通过：Power `20 -> 40 kW` ramp case 的尾窗为 `40.000 kW / 408.978 V / cEGR=0.099995739`；OER `2.5 -> 3.5` step case 的尾窗为 `40.000 kW / 409.724 V / cEGR=0.099994864`，压缩机入口质量流量由 `0.034551668` 增至 `0.048428306 kg/s`。两例均有 22 个 registered signals 和 0 observation errors。

## 5. 研究准入门槛与建议顺序

1. **S6-W0：研究规格化。** 固定控制变量、范围、基线、KPI、排除/失败规则、单位和研究 runner 配置；先小样本预检，后正式多因素扫描。
2. **P3-M3 限制保留。** 22 个 result 信号均有注册表单位、时间窗和缺失状态；Stack power 与 cEGR mass flow 的上游单位元数据 warning 留待模型信号元数据专项处理，阳极/冷却 4 项继续保持 status-only。
3. **S6 cEGR 研究：最后进入。** 研究矩阵应只调用通过上述门槛的 runner；液水结果仅按 L2 饱和过量估计解释，不能宣称真实分离效率或液水库存响应。

## 6. 文件使用规则

- 本文件只记录 2026-08-11 的实际读取和运行证据，不覆盖 `01_当前指导/` 的路线裁决。
- 修复 P3-M1 后，更新对应当前指导和实施记录；本审计保留为历史快照，并在必要时新增日期版本。
- `00_支撑材料/` 的文献、官方示例和外部案例是来源/校核资产，不能成为 Route A 默认参数或当前验收证据。
