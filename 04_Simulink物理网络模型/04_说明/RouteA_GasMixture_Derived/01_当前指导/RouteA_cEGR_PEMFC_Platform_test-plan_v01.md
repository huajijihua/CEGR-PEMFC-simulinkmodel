# RouteA cEGR-PEMFC Platform Test Plan v01

文件类型：平台验证计划  
日期：2026-07-24（初稿）；2026-07-29（更新：cold-start-only 回归）
前置文档：[模型裁决与资产处置](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)、[收敛实施路线图](RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)、[系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)、[架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)、[CEGR 文献研究与模型映射](../03_审计与研究/RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)

本文件定义平台级验证门槛。**当前状态：Gate 0/1/2/3 和历史专项保留为平台背景；P1/P2 当前不以重复这些历史工况为前置条件。** 活动运行链已切换为 cold-start-only，P1/P2 主线是面板输入能否经统一接口驱动当前模型并把实际结果反馈到窗口；P2 先处理面板布局、输入语义、帮助和结果图像历史，研究矩阵后置。

## 1. 验证原则

验证分为三层：子系统开环、整机开环、闭环策略。结构、数值求解、物理 KPI 和结果审计分别记录，不能用一类证据替代另一类证据。

每个测试记录：模型 hash、参数层、case 输入、solver、初态类型、MATLAB/Simulink 版本、结果文件、warning/error 分类和结论。

### 1.1 P1/P2 使用口径

平台测试计划中的历史 Gate、长时基线和研究矩阵用于平台审计，不是 P1/P2 面板用户的操作步骤。P1/P2 只在需要定位控件映射、非法输入或结果回写问题时调用最小开发期 smoke；不因未重复历史 case 而阻塞窗口迭代。面板运行失败时，优先修正实际错误栈和 UI 反馈，再决定是否补充脚本。

## 2. Gate 0：来源和资产

| 检查 | 通过条件 |
|---|---|
| 官方母版 | 当前模型可追溯到归档的 Gas Mixture PEMFC 示例 |
| 库复用 | 适用组件优先来自 `FuelCell_lib`，自定义块有理由和来源 |
| 参数层 | 默认链不读取旧台架 CSV、DQ60 map 或历史 workbook |
| 工作树 | 只有一个当前 `.slx`，历史模型/脚本不在活动 MATLAB path |
| 单位 | 物理参数和控制输入均有单位、范围和 source metadata |

## 2.1 Gate 0.5：文献证据和研究口径

在任何 RouteA_v2 结构修改或正式矩阵前，必须完成：

- 当前 CEGR/BOP/控制模块均有 `PRESERVE`、`REFACTOR`、`DEFER` 或 `HISTORICAL` 处置标签；
- 首个研究用例、实际流量执行器和主动/被动设备配置已经固定；
- `mdot_fresh`、`mdot_cegr`、`mdot_mix_in`、湿/干基回流比、`lambda_fresh`、`lambda_mix`、`pO2_in` 和 `RH_in` 的定义已固定；
- 每个首个用例 KPI 都能追溯到对应论文机制、官方组件或当前模型实测证据；
- 文献参数不带适用范围时，不得直接写入 `platform_default`。

Gate 0.5 未通过时，只允许做只读盘点、文献精读、接口表和失败证据整理，不允许以增加块、端口或命令字段推进模型。

## 3. Gate 1：结构闭合

### 3.1 子系统检查

对 `Stack_Core`、`Cathode_Supply`、`Cathode_Exhaust_cEGR`、`Anode_Supply_Recirculation`、`Thermal_Management` 和 `Electrical_Load_Interface` 分别执行：

- `model_read` 读回接口和连接；
- `model_check` 的 `unconnected_ports`、`unconnected_lines` 和 Stateflow lint；
- MATLAB/Simulink update/compile；
- 关键 block mask 参数的单位和数值 read-back。

活动物理端口不能靠 Terminator 或未解释的连接器掩盖。合法的边界端口必须在架构规格中列出，实际缺失连接属于阻断项。

### 3.2 负载接口检查

验证 Current、Power、Voltage 三种用户侧输入均映射到同一内部 `I_cmd` 端口，且不改变气路/热路/电堆物理拓扑。检查内容包括：

- 输入单位拒绝和显式换算；
- `V_floor`、电流限幅和 anti-windup；
- P/V 命令变化时 `I_cmd`、实际 I/V/P 和功率误差；
- 不允许一个 study 混合三种用户侧边界类型。

## 4. Gate 2：冷态和数值稳定性 — ✅ 已完成

| Case | 设定 | 通过条件 | 结果 |
|---|---|---|---|
| `cold_idle` | 默认气源、最小非零负载、cEGR=0 | 初始条件求解和 1 s 仿真无 DAE failure | ✅ PASSED |
| `cold_nominal_current` | 默认平台负载、官方气路 | 10 s 仿真完成，I/V/P、压力、温度和组分有限 | ✅ PASSED |
| `cold_cegr_zero` | cEGR 拓扑启用、目标比为 0 | 物理路径闭合，实际比接近零且无未分类 warning | ✅ PASSED |
| `cold_cegr_small` | 小幅 cEGR 目标 | 阀压差、回流量、混合组分和控制误差有物理响应 | ✅ PASSED |

这些 case 已由 agent 在当前模型和正式参数链上亲自完成，验证记录见[当前实施分卷](../02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260727_S2冷态smoke与Source_Conditioner处置_v01.md)。

## 5. Gate 3：系统性能 — ✅ 已完成

稳态默认使用明确的尾窗统计，但尾窗必须位于无吹扫或已说明吹扫相位的区间。至少报告平均值、跨度和标准差；不能只报告最后一个采样点。

关键 KPI：

- 电堆 I、V、P、温度和电流密度；
- 阴极/阳极入口和出口压力、温度、总流量和组分；
- `lambda_fresh`、`lambda_mix`、`pO2_ca_in`、湿/干基 `cegr_ratio`、阀开度和压差；
- 阴极/阳极 RH、气相水和冷凝/分离输出；
- 控制跟踪误差、限幅比例、吹扫事件和 solver warning；
- 可观测质量、物种和能量残差。

暂定数值门：

1. 所有被报告的 KPI 必须有限且单位正确；
2. 可观测关键量在稳态尾窗的两个半窗相对变化默认不超过 `0.5%`；不能观测的内部状态不得套用该门；
3. cEGR 实际比误差采用 `max(1e-4, 0.01*max(target,1e-3))` 的初始工程门，最终值必须由代表性 case 和控制器带宽复核；
4. 质量/物种/能量闭合门按可观测边界定义，默认目标为 `1%` 以内；若缺少必要观测，测试标记为 `not observable`，不得伪造通过。

**Gate 3 完成状态：** 恒电流 6 工况（5A~392A）、恒功率 6 工况（40kW/120kW × cEGR=0/0.1/0.3）、恒电压 6 工况（410V/375V × cEGR=0/0.1/0.3）和入口组分控制 6 工况（O2=15-21%, H2O=0.5-3.0%）全部通过，尾窗偏差均 < 0.5%。详情见[当前实施分卷](../02_实施记录/01_当前分卷/RouteA_cEGR_PEMFC_实施记录_20260727_S2冷态smoke与Source_Conditioner处置_v01.md)第 4-8 节。

## 6. Gate 4：动态与策略

至少覆盖：

- 低到额定负载 step/ramp；
- cEGR 0 -> small -> nominal 的变化；
- 空气供给和背压扰动；
- 湿度和温度设定变化；
- 阳极 purge 事件及其对电压/库存的影响；
- Current、Power、Voltage 用户侧边界的一致 plant 响应。

动态测试不强制稳态门，但必须保留完整时序并检查命令、响应、限幅、NaN/Inf、守恒和失败分类。

### 6.1 已完成代表性证据

| Case | 结果 |
|---|---|
| Power ramp | PASS；`P=11.974169 kW`，气相闭合、限幅和有限尾窗通过 |
| Voltage ramp | PASS；`V=427.412848 V`，气相闭合、限幅和有限尾窗通过 |
| Power cEGR `0 -> 0.1 -> 0.3` | PASS；尾窗 actual `0.299999994`，tracking error 约 `-6.2e-9`，无 purge |

### 6.2 已完成控制专项

| 专项 | Case | 实际结果 |
|---|---|---|
| 空气供给/OER | `S5_gate4_air_oer_step_600s` | OER `2.5 -> 3.5`，Power、lambda、气相闭合和有限尾窗通过 |
| 阴极背压 | `S5_gate4_backpressure_step_600s` | `0.161325 -> 0.175 MPa`，Power、lambda、气相闭合和有限尾窗通过 |
| 阴极湿度 | `S5_gate4_humidity_step_600s` | RH `1.0 -> 0.8`，Power、lambda、气相闭合和有限尾窗通过 |
| 堆温 | `S5_gate4_temperature_step_600s` | `80 -> 82 degC`，Power、lambda、气相闭合和有限尾窗通过 |
| 阳极 purge | `S5_gate4_purge_event_600s` | 检测到 3 个事件，尾窗无 purge，Power、气相闭合和有限尾窗通过 |

以上 case 的紧凑结果保存在 `outputs/RouteA_S5_20260728/S5_gate4_control_specials_600s.mat`。

### 6.3 S5 尚未完成的收口项

Hydrogen Source runtime dangling-line warning 已关闭；cold 600 s I/P/V 和面板 `cEGR=0/0.3` 历史样本均已留下审计结果，但当前 P1 收口采用独立单工况链路，不把它们作为研究矩阵验收。P1 本轮只用 `cEGR=0` 与 `cEGR=0.3` 做简单带通验证，重点检查面板设定是否进入统一 `SimulationInput` 并驱动当前模型。Gate 4 历史代表性专项通过，不等于当前 cold-only S5 整体完成。77 条结构 warning 已形成逐条 ledger，见 [warning ledger](../03_审计与研究/RouteA_cEGR_PEMFC_model_check_warning_ledger_20260729_v01.md)；Voltage 控制链和 purge 周期诊断见 `outputs/RouteA_S5_20260728/S5_voltage_control_coupling_diagnostic_20260729.mat`。

### 6.4 Cold-start-only 回归证据（2026-07-29）

以下结果均使用当前 Route A 主模型、`platform_default`、拓扑 hash `2D8AE250-895A2A82-1980FB9C-C8E0A06A`、`VariableStepAuto`、`RelTol=1e-3`、`AbsTol=1e-3`、`MaxStep=5 s`，并由统一 runner 设置 `LoadInitialState="off"`。

注：下表的首轮 cold compact 结果形成于 2026-07-29 OER 基线对齐之前，保留作历史审计；最终 `platform_default` 对齐后的 3600 s 验收以 `outputs/RouteA_P0_acceptance/RouteA_P0_acceptance_latest.mat` 和第 6.5 节诊断为准。

| Case | 结果 | 尾窗 KPI 和判据 |
|---|---|---|
| cold Current 28 A, 600 s | 完成但 `not_steady` | `I=28 A`、`V=424.917593 V`、`P=11.8976926 kW`、gas closure=1、tail purge=1 |
| cold Power 11.974169 kW, 600 s | 完成但 `not_steady` | `I=28.1855047 A`、`V=424.834311 V`、`P=11.974169 kW`、gas closure=1、tail purge=1 |
| cold Voltage 427.648894 V, 600 s | 完成但 `not_steady` | `I=22.2373524 A`、`V=427.574962 V`、`P=9.50813563 kW`、gas closure=1、tail purge=1 |
| cold Current 28 A, 3600 s | `PASS` | `I=28 A`、`V=425.441491 V`、`P=11.9123618 kW`、steady=1、gas closure=1、tail purge=1 |
| cold Power 11.974169 kW, 3600 s | `PASS` | `I=28.1478294 A`、`V=425.402950 V`、`P=11.974169 kW`、steady=1、gas closure=1、tail purge=1 |
| cold Voltage 427.648894 V, 3600 s | `periodic_response_voltage_tracked` | purge-enabled；Voltage tracking/gas closure/nonperiodic signals pass；4 events、3 complete cycles；Current/Power/derived O2 stoich classified as periodic response |

面板 Current `cEGR=0/0.3` 的 600 s 矩阵两例均完成，分别得到 `V=425.195887/421.979674 V`、`P=11.9054848/11.8154309 kW`，实际 cEGR 为 `1.84146506e-6/0.299979826`；两例均因 `not_steady` 未通过，未出现仿真错误。

结果文件：`outputs/RouteA_S5_20260728/S5_cold_current_28A_600s_20260729.mat`、`S5_cold_power_P0_600s_20260729.mat`、`S5_cold_voltage_V0_600s_20260729.mat`、`S5_cold_current_28A_3600s_20260729.mat`、`S5_cold_power_P0_3600s_20260729.mat`、`S5_cold_voltage_V0_3600s_20260729.mat` 和 `S5_cold_panel_current_cegr_0_030_600s_20260729.mat`。

### 6.5 Voltage 控制链与 purge 周期响应（2026-07-29）

同一 cold V0 工况分别运行 purge-enabled 和 purge-disabled 3600 s 对照，空气基线已按 `platform_default` 对齐为 `air_target_oer=3.0`、阴极背压 `0.1613 MPa`。控制链读回为：`Voltage Error = V_stack - V_ref`，Voltage PI `Kp=1 A/V`、`Ki=0.05 A/(V*s)`、电流限幅 `[0,392] A`、anti-windup=`clamping`，PI 输出经 `0.1 s` 电流命令动态后进入唯一 `I_cmd`。

空气控制为 mode 2 `target OER`。其设定流量由 `OER * max(abs(I_stack), 0.1*stack_iL*stack_area)` 换算，当前最小电流折算值为 `39.2 A`。两个 V0 case 的电流均低于该值，因此 `air_mdot_set=0.016667929 kg/s` 全程不随电流波动；实际压缩机流量只在该设定附近跟踪，电流并未直接驱动阴极设定流量。

| Case | 结果 | 关键读回 |
|---|---|---|
| purge-enabled | `periodic_response_voltage_tracked` | 4 个 purge event、3 个完整周期，周期均值 `759.972257 s`、标准差 `1.557600 s`；Voltage tail 相对误差 `0.0577%`，tail span `0.011457 V`；只有 Current/Power/derived O2 stoich 超过原始 `1%` 稳态门，最大变化 `1.554%` |
| purge-disabled | `strict PASS` | 最大稳态变化 `0.0874%`，Voltage tail 相对误差 `0.00153%`，无 purge event |

结论：PI 符号和反馈方向正确；阳极 purge 改变阳极库存和堆电压，Voltage PI 随后调节 `I_cmd`，电流变化再影响由电流派生的氧计量比。当前结果是物理周期响应，不是恒电压控制符号错误。P0 验收已增加周期响应门：Voltage 跟踪、限幅、气相闭合、`lambda>1` 以及温度/压缩机/压力/RH 等非周期信号仍为强制门；Current、Power 和派生氧计量比仅在已识别且周期稳定的 purge case 中转为周期诊断项。

证据文件：`outputs/RouteA_S5_20260728/S5_voltage_control_coupling_diagnostic_20260729.mat`、`outputs/RouteA_P0_acceptance/RouteA_P0_acceptance_latest.mat`。

## 7. 回归和长期门禁

建议后续建立以下 `model_test`/MATLAB 测试场景：

| 场景名 | 目的 |
|---|---|
| `PlatformStructure` | 结构、官方块、端口和模型设置 |
| `ColdStartNominal` | 冷态初始条件与短仿真 |
| `ElectricalLoadCanonicalization` | I/P/V 到 `I_cmd` 的一致性 |
| `CegrMassSpeciesClosure` | cEGR 方向、比例和物种守恒 |
| `CathodeBackpressureResponse` | 背压设定与压力链响应 |
| `AnodePurgeResponse` | N2 库存、吹扫和电压扰动 |
| `ThermalResponse` | 温度控制和热流响应 |
| `NumericalRobustness` | solver、MaxStep 和初始化敏感性 |

正式矩阵只能在上述代表性 case 通过后执行。矩阵结果必须保存紧凑摘要和失败栈；不能以清理 `slprj/`、`.slxc` 或运行缓存作为验证前置条件。
