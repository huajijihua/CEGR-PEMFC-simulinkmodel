# Route A cEGR-PEMFC 实施记录：P3 参数契约收口

日期：2026-08-11
触发：阻塞性问题解决（P3 已开放参数未登记至面板能力矩阵）。
范围：面板能力契约；不修改 `.slx`、默认参数、UI 布局或研究 runner。

## 实际改动

在 `03_脚本/RouteA_GasMixture_Derived/routeA_p1_panel_capability_matrix.m` 的 `parameterContract` 中补齐 7 个已 active 参数的契约：

| canonical 参数 | UI 控件 | SimulationInput 变量 |
|---|---|---|
| `cegr.controller.Kp_area` | `AdvancedCegrKpEditField` | `routeA_egr_control_Kp_area` |
| `cegr.controller.Ki_area` | `AdvancedCegrKiEditField` | `routeA_egr_control_Ki_area` |
| `cegr.actuatorTau_s` | `AdvancedCegrActuatorTauEditField` | `routeA_egr_valve_actuator_tau` |
| `stack.numCells` | `AdvancedStackNumCellsEditField` | `stack_num_cells` |
| `stack.area_cm2` | `AdvancedStackAreaEditField` | `stack_area` |
| `stack.iL_A_cm2` | `AdvancedStackIEditField` | `stack_iL` |
| `stack.io_A_cm2` | `AdvancedStackIoEditField` | `stack_io` |

每项同时登记 `simCasePath`、编译期属性及对应结果观测关联。

## 读回与验证

1. `launch_routeA_panel()` 成功构造 `RouteA_Panel_v01`，可见窗口标题为 `Route A cEGR-PEMFC 仿真平台`。
2. MATLAB Code Analyzer 对修改文件返回 0 issues。
3. `run_routeA_p1_panel_contract_tests()` 通过：`passed=1`、`simulationStarted=0`、21 个非法输入均被拒绝；cEGR 禁用目标归零、ramp 拒绝、三类电边界、三种空气模式和高级映射均通过。
4. 使用面板 builder 进行非默认参数读回，7 个 `SimulationInput` 变量均与经 `routeA_validate_case` 校验的 `simCase` 一致；context 同时读回电堆和 cEGR 控制值。

## P3-M2 短时参数实效 smoke

均由可见 `RouteA_Panel_v01` 的 `RunButtonPushed` 路径执行：`UI -> simCase -> validate -> SimulationInput -> sim -> panel result`。无结果文件导出。

| 工况 | 主要扰动 | 20 s 尾窗结果 | 运行/观测状态 |
|---|---|---|---|
| `P3_UI_cegr_smoke` | `Kp=2.3562e-4`、`Ki=4.7124e-5`、`tau=0.75 s`；100 A；目标 cEGR=0.100 | `V=404.23 V`、`P=40.42 kW`、实际 cEGR=0.089、回流量=0.00374 kg/s | 仿真完成；22 个观测信号 verified；正式结果为 `completed_acceptance_failed / cegr_tracking` |
| `P3_UI_stack_smoke` | cEGR 控制恢复默认；`401 cells`、`266 cm^2`、`iL=1.47 A/cm^2`、`io=1.1e-4 A/cm^2`；100 A；目标 cEGR=0.100 | `V=404.96 V`、`P=40.50 kW`、实际 cEGR=0.086、回流量=0.00364 kg/s | 仿真完成；22 个观测信号 verified；正式结果为 `completed_acceptance_failed / cegr_tracking` |

电堆参数扰动使尾窗电压增加 `0.73 V`、功率增加 `0.08 kW`。这证明该组参数已穿透面板和模型并影响可观测输出；两例均不满足 20 s 冷态窗口的 cEGR 跟踪验收，不能以此形成稳态性能或控制优劣结论。

## 未闭合风险和下一步

- P3-M2 已证明参数扰动可到达物理模型并改变可观测 KPI；但只运行 20 s 冷态窗口，未替代稳态或动态控制验收。
- `routeA_simCase_template` 的电边界 profile 默认留空，直接调用 builder 的脚本必须显式设置有效电流、功率或电压命令；面板和既有契约测试均会设置该必需输入。
- 当前结果面板已读回 22 个 registered signals，但仍有单位元数据缺失警告和 4 个 status-only 观测。下一逻辑切片是结果表达收口和 cEGR 跟踪动态验证，不进入研究矩阵。
