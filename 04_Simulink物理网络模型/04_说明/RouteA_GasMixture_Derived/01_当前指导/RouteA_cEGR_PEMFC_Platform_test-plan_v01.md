# RouteA cEGR-PEMFC Platform Test Plan v01

文件类型：平台验证计划  
日期：2026-07-24（初稿）；2026-07-27（更新：S2/S3 验证完成）  
前置文档：[模型裁决与资产处置](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)、[收敛实施路线图](RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)、[系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)、[架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)、[CEGR 文献研究与模型映射](../03_审计与研究/RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)

本文件定义验证门槛。**当前状态：Gate 0/1/2/3 已通过**（Source_Conditioner 已删除、冷态 smoke 四个 case 全部通过、恒电流/恒功率/恒电压 + cEGR 稳态验证全部完成）。Gate 4 动态验证和正式矩阵准入待推进。v09 结果只作为历史回归证据。

## 1. 验证原则

验证分为三层：子系统开环、整机开环、闭环策略。结构、数值求解、物理 KPI 和结果审计分别记录，不能用一类证据替代另一类证据。

每个测试记录：模型 hash、参数层、case 输入、solver、初态类型、MATLAB/Simulink 版本、结果文件、warning/error 分类和结论。

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
