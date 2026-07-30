# Route A cEGR-PEMFC P3 阳极与系统性能参数开放实施计划 v01

**日期**：2026-07-30
**状态**：首轮实施中
**范围**：单一正式 Route A `.slx`、`platform_default` 参数链、现有面板 runner；不重复 P1/P2 历史验收矩阵。

## 1. 目标与边界

P3 首轮目标是把当前面板从“阳极输入已显示”推进到“阳极输入有完整语义和范围约束”，并开放一小组已经存在于正式模型工作区、能够通过 `SimulationInput` 写入的系统性能参数。每个开放输入必须经过：

`UI -> simCase -> routeA_validate_case -> routeA_panel_build_simulation_input -> SimulationInput -> 当前模型`

本轮不把尚未完成观测闭环的阳极输出伪装成结果，不把设备参数目录中的只读 inventory 变成可编辑控件，也不为了 P3 重跑 P1/P2 已完成的历史工况。

## 2. 首轮工作包

| 工作包 | 内容 | 交付判据 |
|---|---|---|
| P3-W0 | 固定本计划、更新当前指导入口和实施记录边界 | 计划文件进入 `01_当前指导`，README 可追溯 |
| P3-W1 | 强化阳极 10 项输入的中文含义、单位、合法范围和吹扫互斥状态 | 每项有 UI 限制；阳极仍写入统一 command profile，H2 仍写入 `tank_yH2` |
| P3-W2 | 开放 cEGR PI `Kp/Ki`、阀执行器时间常数，以及电堆 `numCells/area/iL/io` | 均有 `platform_default` 默认值、验证范围和明确模型工作区变量 |
| P3-W3 | 完成静态检查、`simCase` 校验、`SimulationInput` 写入读回和新面板 UI 读回 | 不运行旧等价工况；未通过项明确标记 |
| P3-W4 | 记录实际改动、证据和未闭合风险 | 当前分卷追加 P3 实施记录 |

## 3. 首轮开放参数契约

| 域 | canonical 参数 | 单位/范围 | 写入或反馈路径 | 本轮状态 |
|---|---|---|---|---|
| 阳极 | `anode.sourcePressure_MPa_abs` | MPa(abs), 0.2-0.5 | command profile | active input |
| 阳极 | `anode.sourceTemperature_C` | degC, 10-60 | command profile | active input |
| 阳极 | `anode.h2MoleFraction` | -, 0.9-1.0 | command profile + `tank_yH2` | active input |
| 阳极 | `anode.inletPressure_MPa_abs` | MPa(abs), 0.1-0.3 | command profile | active input |
| 阳极 | `anode.humidifierRH` | -, 0-1 | command profile | active input |
| 阳极 | `anode.recirculationBaseCommand` | -, 0-1 | command profile | active input |
| 阳极 | `anode.recirculationCurrentGain_A_inv` | 1/A, 0-1 | command profile | active input |
| 阳极 | `anode.purgeEnabled` | -, 0/1 | command profile | active input |
| 阳极 | `anode.purgeOnN2MoleFraction` / `purgeOff...` | -, 0-1；开阈值大于关阈值 | command profile | active input |
| cEGR | `cegr.controller.Kp_area` / `Ki_area` | m^2；m^2/s，正值 | `routeA_egr_control_Kp_area` / `routeA_egr_control_Ki_area` | active compile-time input |
| cEGR | `cegr.actuatorTau_s` | s，正值 | `routeA_egr_valve_actuator_tau` | active compile-time input |
| 电堆 | `stack.numCells` | -, 1-1000 整数 | `stack_num_cells` | active compile-time input |
| 电堆 | `stack.area_cm2` | cm^2, 1-1000 | `stack_area` | active compile-time input |
| 电堆 | `stack.iL_A_cm2` / `stack.io_A_cm2` | A/cm^2；0.001-5、1e-8-0.1 | `stack_iL` / `stack_io` | active compile-time input |

## 4. 明确不在首轮开放的内容

- cEGR 直通阀控制模式：当前验证器和结果评估仍固定目标比例模式，待单独补齐控制模式验证后再开放。
- 压缩机 map、互冷器、阴极/阳极分离器、散热器和冷却回路几何：当前仍是完整参数目录中的 inventory，只读。
- 阳极压力、回流、吹扫等观测结果：当前模型结果信号尚未完成读回证据，本轮只显示输入接入和 status-only 状态。
- 水管理、设备性能矩阵和大规模参数扫描：不作为本轮面板运行前置条件。

## 5. 出口门

1. 变更文件通过 MATLAB Code Analyzer / 语法检查。
2. 默认 `simCase` 经 `routeA_validate_case` 通过；边界值和非法值能在入口被拒绝。
3. `SimulationInput` 读回包含本轮新增的 cEGR 和电堆工作区变量，且 context 使用被覆盖的单体数等值。
4. 新面板窗口能读回字段、范围、中文标签、只读目录状态和 P3 状态提示；不关闭最新版窗口。
5. 记录中只写入实际检查得到的事实；本轮没有仿真 KPI 时明确写未运行。
