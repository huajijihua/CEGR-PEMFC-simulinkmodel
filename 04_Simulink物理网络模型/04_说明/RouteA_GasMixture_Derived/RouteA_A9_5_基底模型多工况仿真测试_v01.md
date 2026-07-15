# RouteA A9.5 基底模型多工况仿真测试 v01

执行日期：2026-07-10

## 1. 目标与边界

A9.5 用 A9 已收口的 50 kW `platform_default` 参数基线做基底模型功能性多工况仿真测试。该测试只验证当前模型在 no-EGR、low-EGR、mid-EGR 与低/中/高负载组合下能稳定计算，关键 KPI 有限，EGR 方向性和负载趋势合理。

本轮不做台架拟合、不读取旧 10 kW/DQ60/公司资料、不新增阴阳极计量比或真实入口温压控制接口、不保存 `.slx`、不导出全量 timeseries。

## 2. 工况矩阵

负载档位沿用 A9 公式包络，当前模型仍以功率命令为主要运行入口，因此脚本用电流密度定义工况，再换算目标功率驱动模型。

| 负载档 | 电流密度 | 电堆电流 | 参考单电池电压 | 目标功率 |
|---|---:|---:|---:|---:|
| low | `0.2 A/cm^2` | `56 A` | `0.78 V` | `17.47 kW` |
| nominal | `0.7 A/cm^2` | `196 A` | `0.65 V` | `50.96 kW` |
| high | `1.2 A/cm^2` | `336 A` | `0.58 V` | `77.95 kW` |

| EGR 档 | 阀面积表达式 | 面积比例 |
|---|---|---:|
| no-EGR | `cegr_valve_area_closed` | `1e-6` |
| low-EGR | `cegr_valve_area_low` | `5e-4` |
| mid-EGR | `2e-3*cegr_pipe_area` | `2e-3` |

## 3. 验收门槛

- 9/9 工况仿真完成。
- 每个工况先跑 `30 s`；若末段稳态未通过则自动重跑 `60 s`。
- 末段稳态判据：actual power 后 5 s 与前 5 s 漂移不超过目标功率 `2%`，`egr_ratio_comp_in` 绝对漂移不超过 `0.005`。
- no-EGR 的 `egr_ratio_comp_in < 1e-3`。
- 同一负载下 `mid-EGR > low-EGR > no-EGR`。
- 同一 EGR 档下 actual power 随负载单调上升。
- 压力链、KPI 有限性和非负性通过。

## 4. 结果摘要

`run_routeA_a9_5_multicase_functional_test.m` 已通过 `checkcode`、单点 smoke 和 9 点全矩阵仿真。9 个工况均在 `30 s` 达到稳态，无工况触发 `60 s` 重跑。

| case | stop | actual power | `egr_ratio_comp_in` | `egr_split_ratio_out` | steady | passed |
|---|---:|---:|---:|---:|---:|---:|
| `no_egr_low_load` | `30 s` | `17.47 kW` | `3.086e-05` | `2.927e-05` | 1 | 1 |
| `no_egr_nominal_load` | `30 s` | `50.96 kW` | `1.019e-05` | `9.514e-06` | 1 | 1 |
| `no_egr_high_load` | `30 s` | `77.95 kW` | `6.535e-06` | `6.020e-06` | 1 | 1 |
| `low_egr_low_load` | `30 s` | `17.47 kW` | `0.01526` | `0.01446` | 1 | 1 |
| `low_egr_nominal_load` | `30 s` | `50.96 kW` | `0.005044` | `0.004709` | 1 | 1 |
| `low_egr_high_load` | `30 s` | `77.95 kW` | `0.003237` | `0.002981` | 1 | 1 |
| `mid_egr_low_load` | `30 s` | `17.47 kW` | `0.06075` | `0.05745` | 1 | 1 |
| `mid_egr_nominal_load` | `30 s` | `50.96 kW` | `0.02015` | `0.01880` | 1 | 1 |
| `mid_egr_high_load` | `30 s` | `77.95 kW` | `0.01294` | `0.01191` | 1 | 1 |

总体验收：

| 项目 | 结果 |
|---|---:|
| cases passed | `9/9` |
| trend passed | `1` |
| no-EGR close | `1` |
| EGR 档位单调性 | `1` |
| 功率负载单调性 | `1` |

## 5. 回归确认

A9.5 全矩阵通过后，已重跑 `run_routeA_a9_parameter_governance_audit.m`。A9 回归结果：`passed=1`，A8 回归、参数隔离、公式包络、`nominal_50kW_steady`、`max_cegr_area_sanity` 和第二轮硬门槛均通过。

## 6. 后续接口缺口

当前模型可直接覆盖的 A9.5 运行入口为 `drive_cycle_power`、`drive_cycle_time`、`EGRValveRestriction.restriction_area` 和 `routeA_cathode_humidifier_gain`。阴阳极计量比、真实入口温压和冷却运行控制尚未暴露为独立控制接口；本轮只把这些量作为结果审计方向和后续 A10/A11 接口设计输入，不在 A9.5 中强行新增结构。
