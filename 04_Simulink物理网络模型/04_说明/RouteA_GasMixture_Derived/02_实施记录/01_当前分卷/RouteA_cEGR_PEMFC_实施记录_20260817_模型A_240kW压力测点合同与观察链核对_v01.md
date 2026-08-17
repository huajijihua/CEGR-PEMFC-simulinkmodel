# 模型 A 240 kW 压力测点合同与观察链核对实施记录

日期：2026-08-17
状态：模型侧观察链和五点基线已行为验证；外部测点合同待补充，流阻重标定未启动。

## 前置决策

本记录落实 [模型 A 240 kW 压力测点核对与流阻标定实施计划 v01](../../01_当前指导/RouteA_cEGR_PEMFC_模型A_240kW压力测点核对与流阻标定实施计划_v01.md)。目标模型为 `PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01`，仅作为 `external_case`；本次未修改 `.slx`、电堆流阻、背压阀或电化学参数。

## 实际完成

1. 在 `routeA_focused_external240kw_case_factory.m` 中加入 `reference.pressureMeasurementContract`。原始表已确认“干出压力/湿入压力”为 `Pa(a)` 绝压、流量列位置为“空压机入口”；但两个压力传感器相对电堆和干湿侧部件的位置、两测点之间的部件与管段，以及流量湿干基、时间窗和不确定度仍未确认，故压力比较 `comparisonEligible=false`。
2. 在 `routeA_focused_pressure_observations.m` 中加入公共背压阀后气相节点 `EGRValveUpPTSensor.P`，并明确 `commonBackpressureAndBoundaryDrop_MPa` 是公共背压阀与后续气相边界的合并压降，不能单独解释为阀压降。
3. 在 `routeA_focused_external240kw_calibration_assessment.m` 中将未确认测点映射的压力残差限制为诊断量，不允许其触发流阻标定通过。
4. 复用既有 `run_routeA_focused_study.m` 串行 runner 执行五个 600 s 冷态 case，尾窗为 `540--600 s`，CEGR 关闭，新鲜空气质量流量为唯一供气边界。
5. 给正式 runner 增加可选的 `externalCalibrationReference` 输入。提供该外部参考时，runner 会把 `routeA_focused_external240kw_calibration_assessment` 的结果写入 `study.external240Calibration`；不提供时不影响其他 Route A 研究。

## 实际结果与验证

结果文件：[RouteA_Focused_External240kW_SelfHumidifying_PressureMappingBaseline_5Anchors_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureMappingBaseline_5Anchors_600s_20260817.mat)。五个 case 的 `simCompleted=1`、`localPassed=1`、`passed=1`；研究对象总体 `studyPassed=1`。

使用该已完成研究对象进行外部 240 kW 专用后处理，产物为 [RouteA_Focused_External240kW_PressureCalibrationAssessment_5Anchors_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_PressureCalibrationAssessment_5Anchors_20260817.mat)。其数值门通过；但 `pressureMeasurementContract.status=functional_labels_known_tap_locations_unconfirmed`，故 `comparisonEligible=0`、`pressure.passed=0`、总 `assessment.passed=0`。入口诊断 RMSE 是 `8.943 kPa`，出口诊断 RMSE 是 `0 kPa`；后者仅说明模型跟踪了当前输出设定，并非独立测量验证。电性能门未通过，温度设定写入门通过。

| j (A/cm2) | 堆通道压力 | 阴极出口容腔压力 | 阀后气相节点压力 | 堆通道至出口压降 |
|---:|---:|---:|---:|---:|
| 0.1 | 0.130695 | 0.130000 | 0.101325 | 0.000695 |
| 0.4 | 0.145493 | 0.142526 | 0.101325 | 0.002966 |
| 0.8 | 0.185761 | 0.175263 | 0.101325 | 0.010498 |
| 1.3 | 0.216505 | 0.196184 | 0.101325 | 0.020321 |
| 1.9 | 0.247865 | 0.209699 | 0.101325 | 0.038166 |

上表均为 MPa(abs)，且为尾窗平均值。阴极出口容腔压力与外部案例内暂用的出口设定相符；阀后节点均为环境绝压，证明本模型中的公共背压阀在该边界下执行出口控制。完整模型结构检查无 error；报告 63 条既有未连接物理端口 warning。模型 `Dirty=off`。

三个修改后的 MATLAB 脚本均通过 Code Analyzer，无问题；`git diff --check` 无空白错误。

## 阻塞与结论边界

当前外部五点“干出/湿入”压力已知为 `Pa(a)` 绝压，但没有传感器相对电堆和干湿侧部件的物理位置、两测点之间部件/管段、流量湿干基、时间平均区间和不确定度说明。故无法证明“干出压力”对应堆通道、压缩机排出或中冷器后，也无法证明“湿入压力”对应阴极出口容腔或阀后管路。

因此，低负荷下的入口压力差异目前只能表述为“单一 `CathodeOutletResistance` 与外部压力链可能不一致”的诊断信号，不能直接归为电堆流阻失配，更不能通过背压阀、恒定压降或人工压力源修正。本次结果不构成流阻标定、设备选型或 CEGR 性能结论。

## 下一步

待外部测点合同补齐后，先完成模型节点一一映射；只有确认外部测点等价于阴极入口与出口，才启动三个具物理位置的分段 `Flow Resistance (FC)` 改造及 P4 留出验证。

## 追加：用户确认后压力标定执行

用户确认外部“干出”紧贴电堆入口、“湿入”紧贴电堆出口，故将其作为本外部案例阴极入口/出口绝压参考。压力合同状态更新为 `user_confirmed_stack_inlet_outlet`，允许压力比较。

单一 `Flow Resistance (FC)` 原先只有额定压降可调，不能充分改变低、高流量的压降曲线形状。本次将块内字面量 `laminar_fraction` 参数化为 `cathode_channel_laminar_fraction`，接入 `focused.cathodeChannelLaminarFraction -> SimulationInput -> 模型工作区 -> CathodeOutletResistance`；模型结构未改变，默认值和外部案例冻结为 `0.50`。`cathode_channel_dp_nominal_MPa` 保持 `0.0368422 MPa`，额定流量保持 `0.27182 kg/s`。

最终五点正式结果为 [RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_f050_5Anchors_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_f050_5Anchors_600s_20260817.mat)。五例均 `simCompleted=1`、`localPassed=1`、`passed=1`；压力专用门通过，入口 RMSE `6.784 kPa`，出口控制误差 `0 kPa`。堆通道至出口压降分别为 `2.284、5.786、14.200、24.321、42.342 kPa`，相对参考的绝对误差均小于 `10 kPa`，且单调增加。

`cathodeChannelLaminarFraction=0.90` 与 `0.99` 的高负荷 `j=1.9 A/cm2` 均在约 `47 s` 因阳极通道负质量分数断言失败，故不作为候选。`0.50` 是在当前单一等效阻力模型、固定 BOP 和 600 s 冷态边界下的稳定有效参数，不代表真实层流比例。更严的 5 kPa 低负荷精度仍未达成；届时应改造为有物理位置的分段流阻，而非继续抬高该参数。

## 追加：固定边界水力筛查与公共背压阀参数链修复

本追加在用户确认“干出/湿入”紧贴电堆入口/出口后执行。目标不是再用原始五点共同变化的电流、温度和出口设定拟合压差，而是在固定边界下判断当前 Simulink 气路的压降曲线形状，并核实公共背压阀是否真正由其声明的参数控制。

### 实际模型和脚本改动

1. 读回发现公共背压阀 `CommonBackpressureValve_FC`（`blk_1137`）的控制器链使用 `common_bp_valve_*`，而内部 `Local Restriction (FC)` 的 `restriction_area`、`min_area`、`max_area` 错误复用 `cegr_valve_*`。通过模型编辑将三项改为 `common_bp_valve_open_min_area`、`common_bp_valve_open_min_area`、`common_bp_valve_max_area`。这修复了公共背压阀和 CEGR 阀面积参数未分离的缺陷；未修改 `CathodeOutletResistance`、MEA 或电化学参数。
2. 新增 [routeA_focused_external240kw_hydraulic_screen_case_factory.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_external240kw_hydraulic_screen_case_factory.m)，仅在既有外部案例工厂之上固定 `I=38 A`、`Tstack=80 C`、`p_out=0.210 MPa(abs)`、无 CEGR，并沿用五个外部新鲜空气质量流量。
3. 新增 [routeA_focused_hydraulic_screen_assessment.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/routeA_focused_hydraulic_screen_assessment.m)，由既有正式 runner 在 `sim -> assess` 后调用；其范围固定为 `model_only_fixed_boundary_hydraulic_response`，不产生设备压损标定结论。
4. [run_routeA_focused_study.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/run_routeA_focused_study.m) 增加可选 `hydraulicScreenContract`，不复制 runner 或模型。

### 验证结果

先以 `p_out=0.180 MPa(abs)`、最大流量进行了控制能力探针。修复前，即使外部案例把 `commonBackpressureValveMaxArea` 加倍，出口仍停在 `0.185329 MPa(abs)`；此结果仅用于定位参数链错误，不用于压降结论。修复后，在同一条件、加倍最大面积下出口精确达到 `0.180000 MPa(abs)`，证明公共背压阀的实际 `Local Restriction (FC)` 已由公共阀参数控制。对应结果保留为 [RouteA_Focused_External240kW_Hydraulic_BPCapacityProbe_ChainFixed_m271820_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_Hydraulic_BPCapacityProbe_ChainFixed_m271820_600s_20260817.mat)。

为避免通过非实际的阀面积扩大掩盖流阻，正式固定边界筛查采用 `p_out=0.210 MPa(abs)` 和现有公共背压阀面积。五个 600 s 冷态 case 均通过正式 `SimulationInput -> sim -> assess` 串行链，尾窗为 `540--600 s`，总耗时约 `191 s`：

| 新鲜空气流量 (kg/s) | 堆入口 (MPa abs) | 堆出口 (MPa abs) | 通道至出口压降 (kPa) | 出口误差 (kPa) |
|---:|---:|---:|---:|---:|
| 0.03396 | 0.212333 | 0.210000 | 2.333 | 0.000 |
| 0.07577 | 0.215844 | 0.210000 | 5.844 | 0.000 |
| 0.14325 | 0.224064 | 0.210000 | 14.064 | 0.000 |
| 0.19864 | 0.233790 | 0.210000 | 23.790 | 0.000 |
| 0.27182 | 0.251127 | 0.210000 | 41.127 | 0.000 |

该筛查的 `allCasesCompleted`、流量跟踪、出口跟踪、压力方向和压降单调性均通过，端点对数斜率为 `1.3796`。结果文件为 [RouteA_Focused_External240kW_HydraulicIdentification_FixedBoundary_p021_5Flows_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_HydraulicIdentification_FixedBoundary_p021_5Flows_600s_20260817.mat)。原始外部五点端点斜率约为 `0.627`，因此当前单一等效流阻在固定边界下呈现的低负荷初值偏小、高负荷斜率偏大的趋势确实存在，不能归因于背压阀控制或工况共同变化。

修复后还复核了原始 `j=1.9 A/cm2` 外部工况：[RouteA_Focused_External240kW_SelfHumidifying_PressureMapping_PostBPChainFix_j1p9_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureMapping_PostBPChainFix_j1p9_600s_20260817.mat)。该例 `simCompleted=1`、`localPassed=1`、`passed=1`，阴极出口维持 `0.209699 MPa(abs)`，通道至出口压降约 `42.3 kPa`。它证明参数链修复未破坏原高负荷外部工况的数值稳定性和出口控制。

模型完整检查无 error，报告 63 条既有未连接物理端口 warning；保存后 `Dirty=off`。新增和修改的三个 MATLAB 脚本均通过 Code Analyzer。

### 结论与未准入事项

本次已修复一个 BOP 参数链缺陷，并验证现有单一 `Flow Resistance (FC)` 的模型内压降曲线。没有修改电堆流阻拓扑。仅凭五个总压差点，入口歧管、流道、出口歧管的多个自由阻力不可辨识，故不应现在添加多个同类元件来追求拟合，也不应增加恒定压降、人工压力源或自定义拟合函数。

下一步需要获得歧管/流道几何或供应商压损数据，或至少一个堆内分段压力测点；同时确认流量湿干基和与压力相同的稳态时间窗。证据齐全后，才以官方 `Pipe (FC)` 和有来源的 `Flow Resistance (FC)` 实施最小分段结构并做训练/留出验证。此之前 CEGR 仅允许行为筛选，不形成设备选型或 CEGR 性能结论。

## 追加：OER 基准流量与单阻力联合参数复核

用户要求将 `cathode_channel_mdot_nominal_kg_s` 定义为入堆湿空气质量流量，而不是直接复用最高点的新鲜空气实测流量。按 `606` 片、`721 A`、氧气化学计量消耗 `Ncell*I/(4F)`、`OER=1.8`、`20 C/101.325 kPa(abs)/50%RH` 新鲜空气（`y_H2O=0.01153881`、`w_O2=0.23385264`）计算，额定入堆湿空气质量流量为 `0.278837 kg/s`。最高锚点实测新鲜空气流量 `0.271820 kg/s` 在同一组分假设下对应 `OER=1.7547`；低负荷实测流量对应更高 OER，因此不再用其定义本阻力的额定流量。

在该额定流量下，对 `cathode_channel_dp_nominal_MPa`、`cathode_channel_flow_area_m2` 和 `cathode_channel_laminar_fraction` 进行了联合定向复核。先以 `Δp_nom=50 kPa`、`laminar_fraction=0.80`、面积为基准/`-30%`/`+30%` 的三组固定边界端点探针运行。三组均得到相同的低、高端压降 `4.850、61.379 kPa` 和端点指数 `1.2203`，证明在当前官方 `Flow Resistance (FC)` 的额定压降和额定流量参数化下，流通面积对本案例稳态压降没有可观测独立影响，不能作为静态拟合自由度。

随后将 `Δp_nom` 调为 `30 kPa`、保持 `m_nom=0.278837 kg/s`、面积 `0.00403765 m2`、`laminar_fraction=0.80`。固定边界五流量结果为 `2.910、6.851、14.617、22.853、36.830 kPa`，端点指数 `1.2204`；其高端对齐后仍不能抬高低端。原始五锚点正式复核结果为 [RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_mnomOER18_f080_dp030_5Anchors_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_mnomOER18_f080_dp030_5Anchors_600s_20260817.mat)：五例均数值完成，入口压降为 `2.851、6.791、14.738、23.288、37.790 kPa`，入口 RMSE `5.977 kPa`，出口控制误差 `0 kPa`。原始 `j=1.9 A/cm2` 电流边界单例也完成，压降 `37.790 kPa`，证明 `laminar_fraction=0.80` 在本候选组中未引发此前高层流份额的阳极负质量分数错误。

因此当前 `external_case` 默认有效参数更新为：`Δp_nom=30 kPa`、`m_nom=0.278837 kg/s`、`flow_area=0.00403765 m2`、`laminar_fraction=0.80`。这是单一官方等效流阻元件在已声明外部边界下的联合有效参数组，不是实际通道几何、层流比例或设备选型结论。它改善了高负荷和总 RMSE，但未消除低负荷残差；继续通过面积、额定流量或更高层流份额调参没有证据表明可达到严格全段拟合。
