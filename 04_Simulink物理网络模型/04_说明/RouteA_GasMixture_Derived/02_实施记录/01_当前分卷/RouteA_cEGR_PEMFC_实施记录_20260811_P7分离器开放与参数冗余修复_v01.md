# P7 分离器开放与参数冗余修复实施记录

## 范围

- 依据 P6 模型-面板参数审计，先评估并开放阴极/阳极分离器实际被模型引用的流通面积和层流分数。
- 同时检查工作区名称、实际块引用、默认参数层和 `SimulationInput` 写入是否存在同一物理量的重复入口。
- 本次不修改 Route A `.slx` 物理拓扑；热管理 BOP 只做准入评估，不越过现有证据开放数值框。

## 实际完成工作

1. 在 `platform_default -> simCase -> routeA_validate_case -> SimulationInput` 链中新增四项设备输入：`device.cathode.separatorArea_m2`、`device.cathode.separatorLaminarFraction`、`device.anode.separatorArea_m2`、`device.anode.separatorLaminarFraction`。
2. 四项均直接写入对应的 `CathodeWaterSeparator_FC` 或 `AnodeWaterSeparator_FC` 的模型工作区变量。面积范围为 `[1e-8, 0.1] m^2`，层流分数范围为 `[0, 1]`；默认值来自当前官方 Gas Mixture 示例派生参数层。
3. 设备页新增阴极与阳极分离器的面积/层流分数输入框，恢复设备默认值、共享草稿回读、设备目录和 P1 面板契约同步更新。
4. 修复 cEGR 管路几何双变量不一致：`cegr_pipe_D` 与 `cegr_pipe_area` 都被模型使用，但原设备页只写直径。现在直径是唯一可编辑源，`SimulationInput` 同步写入 `cegr_pipe_area = pi*D^2/4`。
5. 移除默认参数层中未被模型引用的阴极/阳极分离器直径/长度，以及散热器 `H_m`/`N_fins`。模型工作区中仍保留的同名遗留变量在汇总表中明确标为 `workspace_only`，不再作为平台默认设备性能。
6. `routeA_audit_parameter_inventory` 增加命名与冗余审计表，明确区分已解决的派生几何关系、未接入遗留几何、命令配置遗留影子变量和未绑定热管理元数据。

## 验证证据

| 验证 | 实际结果 |
|---|---|
| 分离器块读回 | 阴极 `CathodeWaterSeparator_FC` 与阳极 `AnodeWaterSeparator_FC` 均直接引用各自的 `area` 和 `laminar_fraction` 工作区变量。 |
| 默认 60 s 工况 | Current 100 A：`passed_with_warnings`，尾段电压 `409.2231 V`，功率 `40.9223 kW`。 |
| 阴极面积扰动 | 面积减半至 `9.817477e-4 m^2`：`passed_with_warnings`，尾段电压 `409.224099 V`，功率 `40.922410 kW`，阴极出口压力 `0.16215635 MPa`。 |
| 阴极层流分数扰动 | 层流分数增至 `0.1`：`passed_with_warnings`，尾段电压 `409.223107 V`，功率 `40.922311 kW`。 |
| 阳极面积扰动 | 面积减半至 `1.570796e-4 m^2`：`passed_with_warnings`，尾段电压 `409.223900 V`，功率 `40.922390 kW`。 |
| 阳极层流分数扰动 | 层流分数增至 `0.1`：`passed_with_warnings`，尾段电压 `409.223085 V`，功率 `40.922308 kW`。 |
| cEGR 派生几何 | 设备页直径 `0.06 m` 在 `SimulationInput` 中读回 `cegr_pipe_D=0.06`、`cegr_pipe_area=0.00282743338823 m^2`，等于 `pi*D^2/4`。 |
| 面板契约 | `run_routeA_p1_panel_contract_tests` 通过，包含四项新增字段、范围拒止、设备页回读和默认恢复。 |
| 模型-面板审计 | 138 个工作区变量；72 个活动面板参数；37 个模型实际引用但尚未开放；活动写入目标未引用数为 0。 |
| 模型状态 | 所有验证后 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01` 为 `Dirty=off`。 |

## 热管理 BOP 准入结论

- 当前被模型引用的冷却通道参数为 `coolant_num_layers`、`coolant_num_passes`、`coolant_tube_D`、`coolant_w_channels`。其中前三项具有默认参数来源，但 `coolant_w_channels` 尚未进入统一默认参数层，且四项必须维持共同的流道几何关系。
- 当前被模型引用的散热器参数包括 `radiator_L`、`radiator_N_tubes`、`radiator_W`、`radiator_tube_H`、`radiator_tube_Leq`、空气换热面积、材料热容/密度、壁厚和翅片效率。只有部分量有默认来源，尚未形成成组范围、联动约束和独立响应验证。
- 因此热管理 BOP 本轮维持目录只读。下一轮须先定义“冷却通道几何组”和“散热器核心/热容组”的规范输入、派生关系、范围及稳态热响应验收工况，再开放前端输入。
