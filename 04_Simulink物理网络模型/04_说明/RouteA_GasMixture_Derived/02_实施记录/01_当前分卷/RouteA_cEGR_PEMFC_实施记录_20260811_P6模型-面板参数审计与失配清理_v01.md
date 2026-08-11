# P6 模型-面板参数审计与失配清理实施记录

## 前置决策

- 现行输入能力边界见 `01_当前指导/RouteA_cEGR_PEMFC_P5_仿真平台前端输入能力_v01.md`。
- Route A 保持被动 cEGR、cold-start-only 和 L2 水管理；本次不修改 `.slx` 拓扑。

## 实际完成工作

1. 新增 `routeA_audit_parameter_inventory.m`。该函数从当前模型工作区、`Simulink.findVars` 与参数注册表生成 `01_当前指导/RouteA_cEGR_PEMFC_模型-面板参数汇总表_v01.md`，逐项记录默认值摘要、物理角色、块引用、面板页签、写入目标和状态。
2. “系统模型参数”页改为直接显示 138 个模型工作区变量，而不是仅显示注册表推定目录。每一行显示模型变量、物理角色、类型/尺寸、默认摘要、模型引用、面板状态、关联面板参数和代表模块。
3. 删除 3 个无效可写入口：`intercooler_cond_tau`、`cathode_separator_D`、`cathode_separator_length`。三项同时从 `simCase` 模板、验证器、`SimulationInput` 装配、设备页数值框、能力矩阵和契约测试移除；注册表保留为 `unresolved` 目录项，明确当前没有活动块参数绑定。
4. 电流和功率时序命令虽未由 `Simulink.findVars` 展开到普通块参数，但通过 FuelCell 库封装电负载边界生效。审计器将二者标为 `library_boundary_verified`，不作为失配项。

## 验证证据

| 验证 | 实际结果 |
|---|---|
| 模型工作区审计 | 138 个模型工作区变量；86 个被模型直接引用或经库封装边界验证；68 个活动面板参数；活动写入目标未引用数为 0；42 个真实模型参数保持目录只读。 |
| 电流边界实际响应 | Current 130 A、60 s：`passed_with_warnings`，尾窗电流 `130 A`，电压 `405.517 V`，功率 `52.7172 kW`。 |
| 功率边界实际响应 | Power 45 kW、60 s：尾窗功率 `45 kW`，电流 `110.32 A`，电压 `407.907 V`；该工况状态为 `completed_acceptance_failed`，但足以确认功率命令写入并被电负载边界接收。 |
| 面板与输入契约 | `run_routeA_p1_panel_contract_tests` 通过：21 个非法输入拒止、设备页共享草稿回读通过、压缩机图谱契约通过。 |
| 模型状态 | 验证后正式模型 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01` 为 `Dirty=off`。 |

## 未决项

- 42 个模型真实参数已完整可见但未全部开放。下一轮只能从其中有明确参数来源、范围、`simCase` 字段、`SimulationInput` 写入链和独立响应验证的参数开始，优先评估阴极/阳极分离器实际面积和层流分数，再评估热管理 BOP。
- 本次未补建 `intercooler_cond_tau` 或分离器直径/长度的模型物理块；若未来需要这些物理量，必须先修改模型结构并重新完成模型-面板审计。
