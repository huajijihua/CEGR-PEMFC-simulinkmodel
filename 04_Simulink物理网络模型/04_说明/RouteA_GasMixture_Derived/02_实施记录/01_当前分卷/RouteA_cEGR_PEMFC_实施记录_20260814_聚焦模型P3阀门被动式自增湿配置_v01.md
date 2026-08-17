# Route A cEGR-PEMFC 聚焦模型 P3 阀门被动式自增湿配置

日期：2026-08-14
状态：配置 A 已实现、输入链读回并完成零/小回流配置验证；仅验证 L2 气相水蒸气链，不代表低负荷工程性能或真实液水管理。

## 前置决策

- [两种阀门被动架构聚焦模型改造实施方案](../../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md) 的 P0.5、P1 和 P2 已完成。
- 外部 `MIn` 水质量注入必须关闭；环境新鲜空气中的水蒸气、MEA 反应产水、气相库存和回流支路保持为模型已有物理。
- 真实分离、液水库存/输运/排液和压缩机湿气耐受仍不在模型范围内。

## 实际完成的工作

涉及正式文件：

- `04_Simulink物理网络模型/03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_parameter_defaults.m`
- `04_Simulink物理网络模型/03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_case_template.m`
- `04_Simulink物理网络模型/03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_assess_outputs.m`

配置 A 的架构身份设为 `Passive_SelfHumidifying_PostSeparatorGas_CompressorInlet`，共同拓扑仍为“公共背压 -> L2 气相边界 -> 回流/排放分流 -> 空压机入口回流”。case 模板新增明确的架构字段，并把 `caseCfg.cathode.humidifierEnabled` 默认设为 `0`。

模型读回的现有写入链为：

```text
routeA_command_profile.cathode_humidifier_gain
 -> CathodeHumidifierGainCommand
 -> ProportionalControl.Mw * gain
 -> Simulink-PS -> Pipe (FC).MIn
```

因此 `humidifierEnabled=0` 使外部水质量注入命令为零，不创建第二条气路或新的自增湿器块。`Pipe (FC)` 本身仍保留为气相管路库存和压损，不将其误称为已实现的膜加湿器。

正式结果增加 `waterBalance`：

- `externalWaterInjectionEnableCommand`：正式 case 输入中的外部注水使能命令；
- `meaWaterGenerationFaraday_kg_s`：由结果的 O2 Faraday 消耗按阴极反应化学计量推导，不是新传感器；
- `recycleWaterVaporMdot_kg_s`：分流后回流支路四物种流量中的水蒸气分量；
- `outletWaterVaporMdot_kg_s` 和 `mixWaterResidual_kg_s`：气相水蒸气路径的审计量；
- 液水状态固定为 `not_implemented_L2_gas_phase_only`。

三个修改脚本均通过 MATLAB Code Analyzer，未报告问题。

## 验证证据

正式 runner `run_routeA_focused_study` 使用 `SimulationInput -> sim`、冷态初始化、5 A 电流边界和 `0.1613 MPa(abs)` 阴极出口压力命令运行以下 case：

| case | 模型时间 | CEGR 目标 | MIn 使能命令 | 当前结果 |
|---|---:|---:|---:|---|
| `p3_self_humidifying_zero_cegr_60s` | 60 s，尾窗 40--60 s | 0 | 0 | `passed=1`，稳态通过 |
| `p3_self_humidifying_small_cegr_60s` | 60 s，尾窗 40--60 s | 0.05 | 0 | 数值完成，只有 CEGR 比仍变化而未稳态 |
| `p3_self_humidifying_small_cegr_180s` | 180 s，尾窗 150--180 s | 0.05 | 0 | `passed=1`，稳态通过 |

最终小回流 case 的实际证据：

- 实际 CEGR 比 `0.0499984`，总质量基 `r_split=0.0504487`，目标误差 `-1.3975e-06`；
- 尾窗最大相对变化 `2.8116e-05`；
- `gasClosure.passed=1`，水蒸气混合残差 `-3.78284e-10 kg/s`；
- Faraday 派生 MEA 产水 `1.86550e-04 kg/s`，回流水蒸气 `1.24026e-05 kg/s`，出口水蒸气 `2.45846e-04 kg/s`；
- 阴极出口压力 `0.154522 MPa(abs)`，出口到压缩机入口压力裕度 `0.053197 MPa`；
- 七个 L2 气相湿度节点的饱和度均低于 1，最大值 `0.4653`。

正式结果文件：

- `04_Simulink物理网络模型/02_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_P3_self_humidifying_60s_validation_20260814.mat`
- `04_Simulink物理网络模型/02_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_P3_self_humidifying_small_cegr_180s_validation_20260814.mat`

快速加速模式仍提示 To Workspace timeseries 与 Simscape logging 不记录。本记录只使用正式 runner 的结果字段，不将未记录的工作区信号或 Simscape log 当作证据。

## 完成状态和未决项

- `implemented`：配置 A 架构身份、外部 `MIn` 关闭的正式 case 默认值和可审计水账本字段。
- `structurally_verified`：模型既有 `MIn` 写入链与 case 输入的零使能命令已读回。
- `executed`：零回流和 5% 小回流配置 A case 已完成；小回流 180 s case 达到当前 runner 稳态判据。
- `behavior_verified`：零外部注水命令、目标 CEGR 回流、气相混合闭合、压力方向和 L2 饱和度读回。
- `not_validated`：自增湿对性能的因果贡献、纯 MEA 水来源分解、真实液水/分离、压缩机湿气耐受和工程化选型。

本轮 5 A 是配置验证边界，尚未登记为正式低负荷/怠速研究 case。环境新鲜空气仍含水蒸气，因此不能把任何阴极入口或回流水分解释为仅由 MEA 产水造成。
