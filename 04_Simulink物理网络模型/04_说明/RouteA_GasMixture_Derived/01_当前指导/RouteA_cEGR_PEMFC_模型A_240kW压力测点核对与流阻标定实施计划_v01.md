# 模型 A 240 kW 压力测点核对与流阻标定实施计划

文件类型：当前指导、外部案例压力链实施计划
日期：2026-08-17
状态：用户已确认干出/湿入紧贴电堆入口/出口；P0--P2 已完成，P3a 固定边界水力筛查已完成并发现单一等效流阻曲线与五点实测趋势不一致；P3b 结构改造尚不准入。

## 1. 目标与边界

目标模型固定为 `PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01`，仅作为 `external_case`。本计划只收口无 CEGR、`606 x 380 cm2`、`0.1--1.9 A/cm2` 下的主气路压力测点、压差映射和等效流阻；不修改电化学参数，不推导压缩机效率、中冷器换热、液水分离或 CEGR 性能。

所有运行复用 [run_routeA_focused_study.m](../../../../03_脚本/RouteA_Cathode_cEGR_Focused/run_routeA_focused_study.m) 的 `SimulationInput -> sim -> assess` 串行链。每例为 600 s 冷态，尾窗固定为 `540--600 s`。新鲜空气质量流量保持为唯一供气边界，公共背压阀只跟踪出口压力，CEGR 关闭。

## 2. 测点合同

| 规范量 | 当前模型节点 | 单位 | 状态 |
|---|---|---:|---|
| 压缩机入口 | `CompressorInletMixer.p_I` | MPa(abs) | 已读回 |
| 压缩机排出 | `Compressor Volume.p_I` | MPa(abs) | 已读回 |
| 中冷器后 | `IntercoolerOutletPTSensor.P` | MPa(abs) | 已读回 |
| 堆阴极通道容积 | `Cathode Gas Channels/Cathode.p_I` | MPa(abs) | 已读回，候选堆入口 |
| 阴极出口容腔 | `CathodeOutletChamber.p_I` | MPa(abs) | 已读回，公共背压阀上游 |
| 公共背压阀后气相节点 | `EGRValveUpPTSensor.P` | MPa(abs) | 已接入观察；包含后续气相边界压损 |
| 外部“干出压力” | 紧贴电堆阴极入口，用户确认 | Pa(a)，绝压 | 作为堆入口参考 |
| 外部“湿入压力” | 紧贴电堆阴极出口，用户确认 | Pa(a)，绝压 | 作为堆出口参考 |
| 外部新鲜空气流量 | 表头为“空压机入口流量”；湿干基未提供 | kg/h、g/s | 仅沿用既有边界值 |

原始表已确认压力为 `Pa(a)`，且压力对标为“干出/湿入”。用户已确认干出紧贴电堆入口、湿入紧贴电堆出口，故本外部案例将二者分别映射到阴极通道压力和阴极出口容腔压力。空压机入口流量的湿干基、时间平均区间和传感器不确定度仍为结论不确定度，不阻止本轮半定量压力标定。

## 3. 执行阶段

### P0：外部测点合同冻结

将上述外部证据写入 `reference.pressureMeasurementContract`。用户确认后状态为 `user_confirmed_stack_inlet_outlet`，`comparisonEligible=true`；压力评估同时保留流量湿干基和测量不确定度的剩余边界。

出口门：外部“入口/出口”各有唯一模型节点、单位和物理位置映射；没有映射则停止在 P2，不改模型流阻。

### P1：模型观察链核对

读回现有六个压力节点及相邻压差，确认公共背压阀下游节点和中冷器后节点在结果对象中可用。不得为观测方便改变流阻、阀面积或背压控制器。

出口门：每个节点均有真实 Simscape 路径、单位、尾窗统计和结果字段；公共背压阀后读数的合并物理含义明确。

### P2：五点基线映射

在 `j=[0.1,0.4,0.8,1.3,1.9] A/cm2` 读取完整压力链。比较只发生在外部测点与确认等价的模型节点之间；不等价时修正数据映射或报告系统压损，不把残差写入 `CathodeOutletResistance`。

出口门：五点的质量流量、温度、组分、绝压、压差方向和压力路径均可追溯；给出“测点不等价”或“可以进入 P3”的唯一结论。

### P3a：固定边界水力响应筛查（已完成）

保持五个实测新鲜空气流量，固定电流 `38 A`、堆温 `80 C`、阴极出口 `0.210 MPa(abs)`、无 CEGR。该筛查只剥离原始五点中电流、温度和出口设定共同变化的影响，确认当前模型中“流量 -> 堆入口至出口压降”的内部响应；不得以此替代设备压损实测或用于重新拟合。

当前单一 `CathodeOutletResistance` 的固定边界端点指数为 `Delta p ~ m^1.380`，而五个外部锚点为约 `Delta p ~ m^0.627`。二者差异说明原压力残差不只是公共背压阀跟踪或各工况边界共同变化造成；现有单一等效流阻的曲线形状不足以解释全范围测点。

### P3b：分布式流阻结构改造准入（未通过，不改模型）

当前仅有堆入口/出口总压差和五个流量点。若直接新增入口歧管、流道、出口歧管三个自由 `Flow Resistance (FC)`，其参数对总压差不可辨识，会把同一残差任意分配给多个元件。因此本阶段不改电堆流阻拓扑，不加入恒定压降偏置、人工压力源、自定义函数，也不由背压阀补偿入口压差。

下列任一组证据齐全后才能进入结构改造：

1. 入口/出口歧管和流道的有效长度、流通面积、液压直径或压降供应商数据；或
2. 至少一个堆内分段压力测点；并同时确认五点流量的湿干基和与压力测点相同的稳态时间窗。

获准后的最小拓扑只允许使用官方气体元件：有明确几何的歧管采用 `Pipe (FC)`；流道或无法由几何充分定义的段采用带来源说明的 `Flow Resistance (FC)`；保留现有 `Cathode Gas Channels` 和公共背压 `Local Restriction (FC)`。没有瞬态压力数据时不新增容积腔，不分段或复制 MEA 电化学核心。

出口门：每一阻力段均有唯一物理位置、来源和可辨识参数；结构读回、`model_check` 0 error、`Dirty=off`、气相闭合与压力方向均通过。

### P4：压力标定和留出验证（等待 P3b 准入）

获准后，以 `j=[0.1,0.8,1.9] A/cm2` 选择受物理约束的分段流阻参数，`j=[0.4,1.3] A/cm2` 留出验证。每次只调整一组命名流阻参数，读回 `SimulationInput -> 参数桥 -> 模型块` 的实际值。只有两点留出结果满足门限后才允许全五点复核。

本轮半定量压力门为：出口误差不超过 `max(3 kPa,2%)`；每点入口绝压及对应压降误差不超过 `10 kPa`；压降随流量单调增加，压力方向和流量跟踪正确。`5 kPa` 是后续分布式流阻模型的加严目标，不作为当前单一等效阻力的通过条件。

### P5：收口与后续准入

压力门通过后冻结流阻参数，重新开始电化学最小参数扩展评估。P3b 未准入或压力门未通过时，CEGR 只允许方向性行为筛选，不得形成压力、设备能力或工程选型结论。

## 4. 当前未决项

当前单一等效阻力的外部案例有效参数组为：`cathode_channel_dp_nominal_MPa=0.0300`、`cathode_channel_mdot_nominal_kg_s=0.278837`、`cathode_channel_flow_area_m2=0.00403765`、`cathode_channel_laminar_fraction=0.80`。其中额定流量由 `606` 片、`721 A`、`OER=1.8` 和 `20 C/50%RH` 新鲜空气组分计算，是高负荷入堆湿空气质量流量；流通面积在 `-30%` 到 `+30%` 扰动下的压降结果完全相同，故不把它作为本块的静态压降拟合自由度。该组将五锚点入口 RMSE 降至 `5.977 kPa`，但低负荷残差仍约 `-7.15 kPa`，不解释为真实流道雷诺数、实际几何或材料本征量。固定边界筛查表明其流量斜率仍无法同时贴合低、高负荷锚点；在 P3b 准入前不得再增加自由流阻参数以追求更低 RMSE。

## 5. 2026-08-17 实际执行快照

在无 CEGR、测得新鲜空气流量边界、600 s 冷态、`540--600 s` 尾窗下，五个压力锚点均经正式 `SimulationInput -> sim -> assess` 串行链完成，所有 case 的 `simCompleted`、`localPassed` 和 `passed` 均为真。结果文件为 [RouteA_Focused_External240kW_SelfHumidifying_PressureMappingBaseline_5Anchors_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureMappingBaseline_5Anchors_600s_20260817.mat)。

用户已确认干出/湿入是紧贴电堆的进出口测点后，压力合同更新为 `comparisonEligible=true`。初始五点结果为 [RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_f050_5Anchors_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_f050_5Anchors_600s_20260817.mat)：`cathode_channel_dp_nominal_MPa=0.0368422`、`cathode_channel_laminar_fraction=0.50`，入口 RMSE 为 `6.784 kPa`。当前有效参数组的五点复核结果为 [RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_mnomOER18_f080_dp030_5Anchors_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_SelfHumidifying_PressureCalibrated_mnomOER18_f080_dp030_5Anchors_600s_20260817.mat)，入口 RMSE 为 `5.977 kPa`。两例的出口误差均为 `0 kPa`，因为背压阀跟踪外部湿入压力设定；其仅验证控制跟踪，而非独立预测精度。整体电性能标定仍未通过。

| j (A/cm2) | 压缩机排出 | 中冷器后/堆通道 | 阴极出口容腔 | 公共背压阀后气相节点 | 堆通道至出口压降 | 公共背压阀及边界合并压降 |
|---:|---:|---:|---:|---:|---:|---:|
| 0.1 | 0.130730 | 0.130695 | 0.130000 | 0.101325 | 0.000695 | 0.028675 |
| 0.4 | 0.145665 | 0.145493 | 0.142526 | 0.101325 | 0.002966 | 0.041201 |
| 0.8 | 0.186378 | 0.185761 | 0.175263 | 0.101325 | 0.010498 | 0.073938 |
| 1.3 | 0.217690 | 0.216505 | 0.196184 | 0.101325 | 0.020321 | 0.094859 |
| 1.9 | 0.250084 | 0.247865 | 0.209699 | 0.101325 | 0.038166 | 0.108374 |

所有压力为 MPa(abs)。模型中的阴极出口容腔压力精确跟踪了当前外部案例的“出口压力”设定；阀后观测点稳定为环境绝压，且该点包含公共背压阀和后续气相边界的合并损失。因此，公共背压阀不是修复低负荷入堆压力残差的自由度。

模型侧压力链与外部测点已按用户确认等价。当前有效参数组的五点压降为 `2.851、6.791、14.738、23.288、37.790 kPa`，对应参考 `10.000、14.474、21.053、28.553、36.842 kPa`；高负荷已显著改善，但低负荷初值仍偏小。固定边界筛查已将该形状失配从背压控制问题中分离出来，故原先宽松的 `10 kPa` 绝对误差门不作为“压力标定完成”的判据。`0.90` 和 `0.99` 的层流份额会在原始 `j=1.9 A/cm2` 工况约 46--47 s 触发阳极负质量分数断言，故明确排除。下一步不是继续改变这一个块的面积或额定流量，而是按 P3b 补足结构可辨识证据。

## 6. 2026-08-17 固定边界水力筛查与背压参数链修复

`CommonBackpressureValve_FC` 的控制器原本使用 `common_bp_valve_*`，但其内部 `Local Restriction (FC)` 的最小/最大面积却错误引用 `cegr_valve_*`。已将块 `blk_1137` 的 `restriction_area`、`min_area`、`max_area` 分别改为 `common_bp_valve_open_min_area`、`common_bp_valve_open_min_area`、`common_bp_valve_max_area`，公共背压阀与 CEGR 阀的面积参数由此完全分离。该项是 BOP 参数链缺陷修复，不是对电堆流阻的拟合。

在修复后、固定 `p_out=0.210 MPa(abs)` 的五流量筛查中，公共背压阀均跟踪出口压力，堆通道至出口压降为：

| 新鲜空气流量 (kg/s) | 堆入口 (MPa abs) | 堆出口 (MPa abs) | 堆通道至出口压降 (kPa) |
|---:|---:|---:|---:|
| 0.03396 | 0.212333 | 0.210000 | 2.333 |
| 0.07577 | 0.215844 | 0.210000 | 5.844 |
| 0.14325 | 0.224064 | 0.210000 | 14.064 |
| 0.19864 | 0.233790 | 0.210000 | 23.790 |
| 0.27182 | 0.251127 | 0.210000 | 41.127 |

五例均完成、流量跟踪、压力方向和压降单调性通过；这些结果仅证明当前模型的内部水力行为和背压控制链可执行。结果文件为 [RouteA_Focused_External240kW_HydraulicIdentification_FixedBoundary_p021_5Flows_600s_20260817.mat](../../../../03_结果/RouteA_Cathode_cEGR_Focused/RouteA_Focused_External240kW_HydraulicIdentification_FixedBoundary_p021_5Flows_600s_20260817.mat)。
