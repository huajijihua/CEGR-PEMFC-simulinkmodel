# 模型 A 240 kW 自增湿半定量标定与低负荷 CEGR 筛选实施记录

日期：2026-08-17
状态：已完成压力链准入、压力锚点运行和 CEGR 行为筛选；电化学绝对误差门未通过，未完成性能标定。

## 前置决策

本记录落实 [两种阀门被动架构与聚焦模型改造实施方案](../../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md) 的模型 A 外部案例边界。目标模型为 `PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01`，仅作为 `external_case`，不写入 `platform_default`。研究边界为 606 片、380 cm2/片、无 CEGR、`0.1--1.9 A/cm2` 稳态。旧台架 CSV 仅为温度轨迹参考。

## 实际改动与读回

- 保留唯一正式 runner [run_routeA_focused_study.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/run_routeA_focused_study.m)，运行链仍为 `SimulationInput -> sim -> assess`，所有批次串行运行。
- 新增 [routeA_focused_external240kw_case_factory.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_external240kw_case_factory.m)，统一生成 19 点极化、5 点压力锚点及低负荷 CEGR case；新增 [routeA_focused_external240kw_calibration_assessment.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_external240kw_calibration_assessment.m) 和 [routeA_focused_cegr_screen_assessment.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_cegr_screen_assessment.m)。
- 环境水蒸气由 `20 degC`、`101.325 kPa(abs)`、`50% RH` 的唯一环境 RH 输入计算为 `y_H2O=0.01154`；`humidifierEnabled=0`。无 CEGR 时固定新鲜空气质量流量，未以 OER 或总入口流量充当输入边界。
- `common_bp_valve_max_area` 与 `cegr_valve_max_area` 已在默认值、case、参数桥和模型工作区拆分。公共背压阀采用独立的面积限幅积分控制，`max area=0.00134 m2`；CEGR 阀不再共享该标定参数。
- 模型工作区读回：`N_cell=606`、`area_cell=380 cm2`、`iL=2.5 A/cm2`、`t_membrane=125 um`、`stack_io=3e-10 A/cm2`、`stack_alpha=0.85`。模型经 MATLAB 保存后为 `Dirty=off`；`model_check(all)` 为 0 error，仍有 63 条既有非阻塞警告。

## 准入和压力结果

每个 case 均为 600 s 冷态，使用 `540--600 s` 尾窗。`j=1.3 A/cm2` 的三例准入试验显示，通道额定压降增加 20% 时通道压降由 `20.33` 增至 `24.40 kPa`，出口压力仍跟踪；中冷器额定压降增加 20% 时中冷器上游压损由 `1.19` 增至 `1.42 kPa`，下游入堆、出口和通道压降不变。该试验通过了压力作用位置和方向检查。

| `j` (A/cm2) | 新鲜空气 (kg/s) | 目标/实际入口 (MPa abs) | 目标/实际出口 (MPa abs) | 入口误差 (kPa) |
|---:|---:|---:|---:|---:|
| 0.1 | 0.03396 | 0.14000 / 0.13070 | 0.13000 / 0.13000 | -9.31 |
| 0.4 | 0.07577 | 0.15700 / 0.14549 | 0.14253 / 0.14253 | -11.51 |
| 0.8 | 0.14325 | 0.19632 / 0.18576 | 0.17526 / 0.17526 | -10.55 |
| 1.3 | 0.19864 | 0.22474 / 0.21650 | 0.19618 / 0.19618 | -8.23 |
| 1.9 | 0.27182 | 0.24654 / 0.24787 | 0.20970 / 0.20970 | +1.32 |

出口压力误差均接近零，五点通道压降 `0.70, 2.97, 10.50, 20.32, 38.17 kPa` 单调增加。高负荷入口和压降满足 10 kPa 门；低中负荷两点超出逐点 10 kPa 门 1.51 和 0.55 kPa。因此不增加静态压降或伪物理补偿，保持高负荷 `36.8422 kPa @ 0.27182 kg/s` 标定值，并将低负荷残差归为测点区段或未建模歧管损失不确定性。压力门结论为：出口控制通过，五点逐点入口绝对误差门未完全通过。

## 电化学标定结果

先以低中负荷筛选 `stack_io`，再以中高负荷筛选 `stack_alpha`，最终以训练点 `j=[0.1,0.2,0.4,0.7,1.0,1.3,1.6,1.9] A/cm2` 联合复核。`stack_io=3e-10 A/cm2`、`stack_alpha=0.85` 使 19 点极化曲线单调下降，所有工况均完成，数值、稳态、气相闭合及固定温度设定检查通过。

11 个留出点的 `Vcell` RMSE 为 `62.36 mV`，最大绝对误差 `90.87 mV`，分别超过 `50 mV`、`80 mV` 门限。允许调节的 `io/alpha` 不能同时消除低负荷正误差和高负荷负误差；按既定边界未改动湿度、膜厚、导电率表或 `iL`。故该参数对只作为本模型的临时有效参数，用于后续机制筛选，不能称为材料本征参数或 240 kW 电性能标定成功。

## 低负荷 CEGR 行为筛选

在上述临时参数冻结后，已完成 `j=0.1`、`0.4 A/cm2`，每点 `r_split=0/2/5/10%` 的八例 600 s case。所有 case 完成且数值检查通过，固定了对应无 CEGR 新鲜空气流量。实际 `r_split` 与命令一致，回流增加会提高阴极入口 RH 与压缩机入口饱和度，并降低 `pO2` 与露点裕度。

| `j` (A/cm2) | 命令/实际 `r_split` | 阴极入口 RH | `pO2` (kPa) | 露点裕度 (degC) | 压缩机入口饱和度 |
|---:|---:|---:|---:|---:|---:|
| 0.1 | 0 / 0.00% | 19.92% | 21.278 | 10.71 | 0.501 |
| 0.1 | 10 / 10.36% | 24.58% | 20.721 | 8.02 | 0.606 |
| 0.4 | 0 / 0.00% | 14.16% | 21.278 | 10.63 | 0.503 |
| 0.4 | 10 / 10.12% | 26.84% | 20.129 | 1.62 | 0.907 |

以上仅验证当前 L2 气相模型中 CEGR 的方向性机制和目标分流跟踪。没有外部 CEGR 数据，且分离边界不建模液水移除、压缩机为质量流量源、中冷器为纯流阻，因此不得将该结果用于 CEGR 性能标定、液水判断、压缩机湿气耐受、效率/功率或工程设备选型。

## 结果产物与未决项

- [压力准入扰动结果](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_AdmissionPerturbations_j1p3_600s_20260817.mat)
- [五点压力标定结果](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_5Anchors_600s_20260817.mat)
- [19 点电化学结果](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_ElectrochemistryFinal19_600s_20260817.mat)
- [八点低负荷 CEGR 筛选结果](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_CEGRLowLoadScreen_8Cases_600s_20260817.mat)

下一步不是扩大 CEGR 工况或宣称设备容量。需要先补充至少一类可归因的极化或电阻数据，再决定是否扩展电化学自由度；同时确认外部压力测点的物理区段，才可解释低负荷压力残差。

## 阴极气体温度边界修复（2026-08-17，实际执行）

前置决策：依据 [两种阀门被动架构与聚焦模型改造实施方案](../../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md) 的模型 A 气相热边界限制，修复“固定堆温不等于固定阴极气体温度”的缺口；不添加自定义函数，不把中冷器流阻误写为换热器。

- 在 `PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01/Cathode_Air_cEGR_BOP/Oxygen Source` 内，删除 `Compressor Volume` 热端口上的 `Perfect Insulator`，替换为官方 `Temperature Source`：`Cathode_Gas_Temperature_Boundary`。其温度参数直接引用模型工作区 `focused_cathode_inlet_temperature_C`，单位为 `degC`。
- case 契约增加 `focused.cathodeGasTemperature_C`；外部 240 kW factory 仅按电流密度插值 CSV 的阴极入口气体温度。旧 CSV 的入口 RH 仍不写入模型，`humidifierEnabled=0` 保持不变。
- 完成一个无 CEGR 的正式回归例：`j=0.1 A/cm2`、`38 A`、CSV OER=5 所得新鲜空气 `0.041256422 kg/s`、出口压力 `133.825 kPa(abs)`、气体温度边界 `58.9 degC`、堆温边界 `61.1 degC`、600 s 冷态、尾窗 `540--600 s`。结果文件为 [ThermalBoundaryRegression j0p1](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_ThermalBoundaryRegression_j0p1_600s_20260817.mat)。

| 读回量 | 尾窗结果 |
|---|---:|
| 压缩机入口混合点温度 | `19.971 degC` |
| 压缩机排出温度 | `58.900 degC` |
| 流阻后温度 | `59.006 degC` |
| 阴极通道温度 | `59.394 degC` |
| 阴极出口温度 | `59.368 degC` |
| 固定堆温 | `61.100 degC` |
| 阴极入口/出口 RH | `8.329% / 50.132%` |
| 新鲜/入堆水蒸气质量流率 | `2.98583e-4 / 2.98457e-4 kg/s` |
| 实际氧计量比 | `5.053` |
| 气相闭合、严格稳态 | 通过、通过 |

`model_check(all)` 为 0 error、63 条既有非阻塞端口警告；MATLAB 保存后模型 `Dirty=off`。出口温度没有用人为边界钳制到 CSV 的 `56 degC`，而是从 `58.9 degC` 入堆气体边界和 `61.1 degC` 固定堆温自然计算得到。前述低负荷 CEGR 数值筛选使用了约 `47.33 degC` 的阴极出口温度，不再可用于湿化、电性能或 CEGR 能力比较；待在当前温度边界下重算后，才可恢复 CEGR 研究。

## 水蒸气质量流率结果契约更新（2026-08-17，实际执行）

依据“相对湿度仅展示和冷凝判断，水蒸气质量流率为计算主力”的决定，正式 runner 不改变模型方程或气体边界，而更新结果计算口径：

- [routeA_assess_electrical_boundary_outputs.m](../../../../03_脚本/RouteA_GasMixture_Derived/routeA_assess_electrical_boundary_outputs.m) 从 `routeA_mdot_species_ca_in_ts` 的第 4 组分提取 `m_H2O`，写入 `tail.inletWaterVaporMdot_kg_s`；严格/工程稳态判据由 `cathodeInletRH` 改为 `cathodeInletWaterVaporMdot_kg_s`。
- [routeA_focused_performance_metrics.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_performance_metrics.m) 和汇总/CEGR 筛选对象新增新鲜、入堆、出口三处水蒸气质量流率。RH 保留在结果对象供展示，字段声明为 `display_only; not a mass or steady-state basis`。
- 冷凝筛选没有使用 RH 阈值；其原有方法继续以混合点水蒸气摩尔分数、绝压和温度导出水蒸气分压、饱和度和露点。

用同一 `j=0.1 A/cm2`、无 CEGR、600 s 回归复核覆盖温度边界结果文件。case 通过、严格稳态通过、气相闭合通过；稳态对象含 `cathodeInletWaterVaporMdot_kg_s`，不含 `cathodeInletRH`。尾窗水蒸气质量流率为：新鲜空气 `2.98583142e-4 kg/s`、阴极入口 `2.98456942e-4 kg/s`、阴极出口 `1.90561467e-3 kg/s`。四个改动脚本均通过 MATLAB Code Analyzer，未产生 error 或 warning。

## 当前收口状态（2026-08-17，覆盖本记录早期结果表述）

本段追加的实际结果优先于本文开头的阶段性筛选记录。无 CEGR 的 240 kW 极化标定已经重新完成：模型内 `Membrane Electrode Assembly` 直接读回为 `N_cell=606`、`area_cell=380 cm2`、膜厚 `125 um`、`stack_iL=2.5 A/cm2`、`stack_io=2e-14 A/cm2`、`stack_alpha=1` 和 2.5 倍导电率表。正式 [19 点标定结果](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_ElectrochemistryCalibratedFinal19_600s_20260817.mat) 的全量 `Vcell` RMSE 为 `10.172 mV`，11 个留出点 RMSE 为 `8.725 mV`、最大绝对误差为 `15.492 mV`；所有 case 完成且极化曲线单调下降。

压力仍只达到“出口控制和趋势筛选”状态，未完成真实流阻标定。已保留的证据为 [压力参数扰动准入](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_AdmissionPerturbations_j1p3_600s_20260817.mat) 和 [五点压力筛选](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_mnomOER18_f080_dp030_5Anchors_600s_20260817.mat)。它们证明通道阻力和中冷器阻力的作用区段可区分、出口背压可跟踪，但低流量压降形状误差仍未消除。

在气体温度边界修复前完成的全部低负荷 CEGR 结果，包括本记录早期表中的 RH、露点和分流数值，现统一标记为 `invalid_for_CEGR_comparison_due_to_prethermal_boundary`，不再作为湿化、电性能或能力上限结论。本收口提交只保留温度边界与水蒸气质量流率契约的 [无 CEGR 回归结果](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_ThermalBoundaryRegression_j0p1_600s_20260817.mat)；CEGR 需在该边界下另行重算。

### MEA 参数路径复核

MEA 掩码的 `io` 和 `alpha` 已恢复为模型工作区变量 `stack_io`、`stack_alpha`，保存值分别为 `2e-14 A/cm2` 和 `1`；runner 保留相同变量的 `SimulationInput` 写入，以支持后续受控再标定。最后一次 `j=0.1 A/cm2`、无 CEGR、600 s 回归读回参数桥写入 `2e-14/1`，`Vcell=0.799644 V`、入堆水蒸气 `2.98456942e-4 kg/s`，严格稳态和气相闭合均通过。冷态初始化仍报告温度源与压缩机容腔温度约束的优先级松弛；因尾窗通过，该项登记为初始化剩余风险，不作为热管理能力结论。
