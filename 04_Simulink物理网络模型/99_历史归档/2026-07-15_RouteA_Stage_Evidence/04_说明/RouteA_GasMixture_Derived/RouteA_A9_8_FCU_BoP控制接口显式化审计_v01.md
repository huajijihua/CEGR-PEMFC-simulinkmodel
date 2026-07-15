# RouteA A9.8 FCU/BoP 控制接口显式化审计 v01

## 1. 目标

A9.8 将 Route A 从“脚本扰动 setpoint/参数”推进到“模型内有明确 FCU/BoP 控制接口”。本轮重点为空气供给和阴极 cEGR；氢气和冷却只保留现有结构与最小 setpoint 接口，不展开完整阳极 purge、氢过量系数或热管理标定。

## 2. 模型结构变更

| 子系统 | A9.8 变更 | 当前状态 |
|---|---|---|
| `Oxygen Source/Compressor Control` | 增加 `target_mdot`、`target_oer`、`direct_cmd` 三种空气控制模式；输出 `routeA_compressor_cmd`、`routeA_compressor_rpm_cmd`、`routeA_air_control_error`、`routeA_air_mdot_set` | 已接入现有 compressor command -> max rpm -> compressor map/质量流量源链路 |
| 顶层 `FCU_BoP_Control` | 新增 cEGR ratio 控制层：`abs(egr_mdot)/abs(mdot_comp_inlet)` -> ratio error -> PI -> valve area command | 已接入 `EGRValveRestriction.AR` 受控面积端口 |
| `EGRValveRestriction` | `const_area=false`，固定 `restriction_area` 不再作为默认控制入口 | direct_area 模式改用 `routeA_egr_valve_area_direct` |
| cEGR 阀执行器 | 新增 `EGR Area Actuator` 一阶环节，`routeA_egr_valve_actuator_tau=0.5 s`；执行器后再做最终面积限幅 | 用于打断测量-阀面积-物理网络直接代数环 |
| 加湿器 | 保留 `routeA_cathode_humidifier_gain` | 仍作为统一 setpoint 表的一员，不展开液态水控制 |
| 冷却 | 新增/保留 `routeA_stack_temperature_set_C` 语义 | 当前仍通过既有 `Cooling System/Stack Temperature` 常量接口使用 |

## 3. 控制变量

| 变量 | 模式/含义 |
|---|---|
| `routeA_control_mode_air` / `routeA_air_control_mode_id` | 1=`target_mdot`，2=`target_oer`，3=`direct_cmd` |
| `routeA_target_mdot_comp_inlet` | 压缩机入口总质量流量目标，A9.8 第一版口径 |
| `routeA_target_oer` | 目标 OER；`target_oer` 模式下沿用官方 OER->所需空气质量流量逻辑 |
| `routeA_compressor_cmd_direct` | 直接压缩机命令，用于开环诊断 |
| `routeA_control_mode_egr` / `routeA_egr_control_mode_id` | 1=`target_ratio`，2=`direct_area` |
| `routeA_target_egr_ratio_comp_in` | 目标压缩机入口 EGR ratio |
| `routeA_egr_valve_area_direct` | direct_area 开环阀面积 |
| `routeA_egr_control_Kp_area` / `routeA_egr_control_Ki_area` | 第一版 EGR ratio -> valve area PI 增益 |

## 4. 验证状态

已完成：

- `checkcode run_routeA_a9_8_fcu_bop_control_audit.m`：无 Code Analyzer issue。
- `model_read` 读回：空气控制模式选择块、`FCU_BoP_Control`、`EGRValveRestriction.AR` 接线存在。
- `model_check` on `FCU_BoP_Control`：healthy。
- A9.8 审计矩阵已按 `routeA_a9_8_case_filter` 拆批完成 15/15，聚合结果 `generated=1`、`passed=1`。
- 三档 `target_mdot`、三档 `target_oer`、三档 `target_egr_ratio`、五档 `direct_area` 和 nominal 组合工况均完成且 KPI finite。
- 原失败的 `direct_area_0.002` 在阀执行器重排后完成 10 s 拆批复跑。

未声明为完成：

- 当前 PI 增益只用于接口显式化和方向性验证，不是动态性能标定。
- A9.8 本身未整理背压接口；A9.9 已将现有 pressure relief/backpressure regulator 规整为 `routeA_target_p_ca_out_MPa` 目标压力接口，并完成三点短工况审计。

执行说明：`run_routeA_a9_8_fcu_bop_control_audit.m` 默认支持全矩阵；在 MCP 300 s 单次调用限制下，可在 base workspace 设置 `routeA_a9_8_case_filter` 为 caseId 或 group 数组，并分批运行，最后聚合 `routeA_a9_8_split_results`。

## 5. 继承给 A10/A11 的边界

A10/A11 可以继承本轮接口，把台架/车载配置的空气控制需求写成目标质量流量、OER 或直接命令，把 cEGR 控制需求写成目标 EGR ratio 或 direct_area。后续不应再把脚本直接改 `EGRValveRestriction.restriction_area` 当成默认控制手段；该参数只保留为库块历史字段。
