# Route A cEGR-PEMFC 实施记录：P4 动态 cEGR Profile 与跟踪验证

日期：2026-08-11
触发：阻塞性问题解决与动态能力首次交付。
范围：统一电边界 runner 的显式 cEGR 时序输入；不修改 `.slx`、默认参数、面板布局或研究矩阵。

## 根因与实际改动

首次 P4 预检没有进入仿真。`routeA_prepare_electrical_boundary_input` 已正确接收显式 `N-by-2 [time_s,value]` cEGR profile，但 `routeA_assemble_command_profile` 的 `initialProfileValue` 将整个 numeric matrix 作为初始值传给 profile 归一化器，触发 `MATLAB:expectedScalar`。

在 `03_脚本/RouteA_GasMixture_Derived/routeA_assemble_command_profile.m` 中增加 numeric `N-by-2` profile 分支，返回首行的命令值作为 scalar initial value。标量、`timeseries` 和结构化 profile 的既有路径未改变。

## 预检与运行证据

1. MATLAB Code Analyzer 对修改文件返回 0 issues。
2. 无仿真装配读回通过：统一 `routeA_command_profile` 有 8 个时间行，cEGR 指令依次为 `0 -> 0.1 -> 0.3`。
3. 正式 runner `run_routeA_electrical_boundary_study` 运行一个 transient case：

| 项目 | 配置/结果 |
|---|---|
| caseId | `P4_power40kW_cegr_step_010_030_600s` |
| 电边界 | Power = 40 kW |
| cEGR profile | 0--60.5 s 为 0；60.5--180 s 为 0.1；180.1--600 s 为 0.3 |
| 求解 | 600 s，`VariableStepAuto`，`RelTol=AbsTol=1e-3`，`MaxStep=0.1 s` |
| 0.1 平台（120--170 s） | 实际比 `0.09997139`，误差 `-2.8610e-5` |
| 0.3 尾窗（540--600 s） | 实际比 `0.299989675`，误差 `-1.0325e-5` |
| 电边界尾窗 | Power = `40.000 kW`，Voltage = `406.269 V`，boundary error = 0 |
| 正式判定 | `passed=1`，failure category 为空 |

4. 动态 `SimulationOutput` 的观测契约通过：22 个 registered signals present，0 errors。上游 `logsout` 仍缺少 Stack power (`kW`) 与 cEGR mass flow (`kg/s`) 的嵌入式单位元数据；注册表单位和面板显示单位保留，但该限制不应被叙述为模型内测量元数据已完备。

## P4 最小负载与空气扰动覆盖

使用相同的 600 s transient 配置、Power 边界和 cEGR=0.1，新增两个独立 case：

| caseId | 扰动 | 尾窗结果 | 正式判定 |
|---|---|---|---|
| `P4_power_ramp20_40kW_cegr010_600s` | Power `20 -> 40 kW`，60.5 s 后 20 kW，180.1 s 后 40 kW | `P=40.000 kW`、`V=408.978 V`、actual cEGR=`0.099995739`、lambda=`2.86835` | `passed=1`，failure category 为空 |
| `P4_air_oer_step250_350_cegr010_600s` | OER `2.5 -> 3.5`，180.1 s step | `P=40.000 kW`、`V=409.724 V`、actual cEGR=`0.099994864`、尾窗 lambda=`3.36331` | `passed=1`，failure category 为空 |

OER 工况的已注册压缩机入口质量流量在 step 前 120--170 s 为 `0.034551668 kg/s`，在 step 后尾窗为 `0.048428306 kg/s`，增量 `0.013876638 kg/s`。两个 case 的观测契约均为 22 个 signal present、0 errors。

## 结论与剩余范围

- 20 s 面板 smoke 的 cEGR 未跟踪并非控制器或气路的直接失败证据；在完整动态时程中，0.1 和 0.3 平台均通过跟踪验收。
- Power 40 kW 下的 cEGR step、Power ramp 和空气 OER step 均已完成最小动态覆盖。S6 研究矩阵可以进入规格化和小样本预检，但尚未批准直接进行多因素正式扫描。
- 无结果文件导出；本次动态输出仅保留在 MATLAB base workspace 的 `routeA_p4_cegr_step_study`，用于当前会话审计。
