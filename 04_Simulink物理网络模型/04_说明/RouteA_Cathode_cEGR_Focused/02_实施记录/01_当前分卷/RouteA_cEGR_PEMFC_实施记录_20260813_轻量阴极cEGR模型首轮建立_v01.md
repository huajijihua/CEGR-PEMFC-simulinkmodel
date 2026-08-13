# Route A cEGR-PEMFC 实施记录：轻量阴极 cEGR 模型首轮建立

日期：2026-08-13  
范围：独立轻量模型副本、阳极流量/背压替代边界、恒温热边界、聚焦 runner 和首轮代表性 case。  
源模型：`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
聚焦模型：`04_Simulink物理网络模型/01_模型/RouteA_Cathode_cEGR_Focused/PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`

## 1. 资产处置

- 通过 MATLAB/Simulink 官方复制接口建立聚焦模型副本；未修改源模型结构。
- 源模型文件存在且读回 `Dirty=off`。
- 聚焦模型保存于独立目录，最终读回 `Dirty=off`。
- 中间复制 stage 已删除；`.slxc` 仅为运行缓存，不作为正式模型资产。

## 2. 已实施结构

- 完整保留 `Cathode_Air_cEGR_BOP`，包括空气源、混合器、压缩机、加湿器、cEGR 阀和 EGR 管。
- 完整保留 `Cathode_Exhaust_Backpressure_Water`，包括阴极出口腔体、cEGR 分流、背压阀和当前水观测器。
- 完整保留 `Stack_Core`、MEA、阳极/阴极气体通道、电气端口和 MEA 热容。
- 移除完整 `Anode_Hydrogen_BOP`，改为上游氢气 Reservoir + Mass Flow Rate Source + 阳极通道 + 出口 Pipe/定压 Reservoir。
- 移除完整 `Thermal_Management_BOP`，以 Heat Flow Rate Sensor 和可输入 Temperature Source 连接 MEA 热端口与固定电堆热节点。
- 保留 I/P/V 电负载、空气控制、加湿器控制、cEGR 比例控制和阴极背压调节。
- 删除阳极控制相关 Goto，使用 Terminator 明确标记不适用的阳极 profile 字段。
- 增加 `Q_stack=0` 的聚焦诊断替代源；它不是冷却热流结果。

## 3. 阳极边界裁决

最初的“入口定压 + 出口定压”方案不作为默认边界：

- 等压 20 degC 诊断运行至 `171.846816 s` 后，`Stack_Core/Anode Gas Channels/Anode` 出现负质量分数断言。
- 入口升压的定压方案在冷态初始化阶段触发 DAE 初值不收敛。
- 改为入口质量流量、出口阳极背压后，180 s 诊断和 600 s 正式 case 均未再出现阳极负质量分数或 DAE 断言。

当前首轮默认值：阳极供氢储库压力 `0.3 MPa(abs)`、阳极入口质量流量 `0.001 kg/s`、出口背压 `0.101325 MPa(abs)`、边界温度 `20 degC`、H2 摩尔分数 `0.9997`。入口流量是研究假设，不是产品供氢标定。

## 4. 正式 runner 与验证

正式入口：`03_脚本/RouteA_Cathode_cEGR_Focused/run_routeA_focused_study.m`。两例均采用 `VariableStepAuto`、`RelTol=AbsTol=1e-3`、`MaxStep=5 s`、冷态启动、`600 s` 研究时长和 `540--600 s` 尾窗。

| Case | cEGR 实际混合基 | V | P | lambda | 阀压差 | 稳态/水观测 |
|---|---:|---:|---:|---:|---:|---|
| Current 100 A, 80 degC, cEGR=0 | 约 `6.04e-7` | 410.051 V | 41.0051 kW | 2.99823 | 0.0608531 MPa | strict steady / collected |
| Current 100 A, 80 degC, cEGR=0.3 | 0.300000 | 405.862 V | 40.5862 kW | 2.49157 | 0.0606614 MPa | strict steady / collected |

在 `cEGR=0.3` case 中，新鲜空气基比例为 `0.428571`。压缩机入口混合器水相观测为冷凝率约 `3.29445e-6 kg/s`、饱和度约 `1.54755`；压缩机容积的冷凝率为 0，符合当前压缩机容积 `is_cond` 未开启的模型边界，不能解释为空压机无液滴风险。

两例均为 `simCompleted=true`、`passed=true`，并通过电边界、cEGR、气相闭合、氧供给、压差方向、阀面积、压缩机流量跟踪和严格稳态门。该证据属于 focused model 的行为验证，不是完整模型等价验证或工程验证。

## 5. 结构检查与剩余风险

- `model_check(root, all)` 返回 `status=warnings`、`total_warnings=63`；警告主要是 SATK 对 Simscape conserving ports、Variant 和合法边界端口的读回误报，未报告 error severity。
- MATLAB 静态检查的 focused 参数、case、路径、assessor 和水观测脚本无 error 级问题。
- 尚未完成 focused model 与完整模型在完全相同边界下的逐信号等价对照。
- 水观测只闭合气相冷凝流率和饱和度，不闭合液水库存、液滴携带、排液、分离效率或空压机可靠性。
- 模型没有空压机/泵寄生功率，因此当前 P 是堆功率，不是净功率。
- `80 degC` 固定热边界已完成首轮执行，但温度矩阵和阳极入口质量流量范围尚未形成研究结论。

状态：`implemented_structurally_verified_executed_behavior_verified_for_scope_not_validated_for_engineering`。
