# 聚焦模型湿化架构拆分裁决实施记录

日期：2026-08-14  
前置决策：[两种阀门被动架构聚焦模型改造实施方案](../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md)

## 实际发现

通过 MATLAB/Simulink `model_read` 读取 `PEMFuelCellSystem_Cathode_cEGR_Focused_v01` 的 `Cathode_Exhaust_Backpressure_Water`，确认当前连接为：

```text
CommonBackpressureValve_FC -> MembraneHumidifierWet_L2_FC -> CommonGasPhaseBoundary_FC -> return/exhaust split
```

`MembraneHumidifierWet_L2_FC` 的实际 ReferenceBlock 是 `FuelCell_lib/elements/Flow Resistance (FC)`，仅有两个 `FuelCell` 气体端口。模型中没有与其相连的干侧气路、跨膜水通量、跨膜热通量或膜参数。

## 裁决与处置

用户确认不再把两种湿化方式混在一条物理链中。后续建立两个独立模型：

```text
PEMFuelCellSystem_Cathode_cEGR_SelfHumidifying_v01.slx
PEMFuelCellSystem_Cathode_cEGR_ExternalMembraneHumidifier_v01.slx
```

两者使用一个正式研究 runner 和同一 case/结果契约；每次 study 只能锁定一个模型。原始单一模型和 P4 结果不删除，P4 被重新分类为“L2 湿侧接口试验”，不再作为配置 B 或 A/B 比较证据。原 P3 结果是湿侧 L2 插入前的无外部 `MIn` 注水气相链试验；模型 A 建成后需重新执行。

## 验证状态与未决项

- 本次完成：`structurally_verified` 的模型读回和当前指导更新。
- 本次未执行：新模型复制、结构改造、模型检查或仿真。
- 模型 A 的外部加湿器物理移除、模型 B 的受控 Simscape 双侧膜加湿器，以及二者的冷态 smoke 均为后续任务。
- 模型 B 的跨膜传质/传热系数、有效面积、两侧压降和热容参数必须在组件实施前登记来源、单位、适用范围和不确定性；没有这些合同不得输出 A/B 性能排序。
