# P5 空压机图谱编辑器实施记录

## 交付范围

- 在既有“系统设备参数设置”页新增空压机图谱入口，使用独立、可调整大小的表格编辑器处理转速轴、压比轴和修正质量流量矩阵。
- 不修改 Route A `.slx` 拓扑，不开放水蒸气饱和压力等物性表，也不开放其他设备曲线。

## 实际实现

1. `routeA_simCase_template` 的 `controls.devices.cathode.compressorMap` 以 `platform_default` 的官方图谱作为默认值，包含 `rpm_TLU`、`p_ratio_TLU`、`mdot_corr_TLU`、来源和 schema 版本。
2. 新增 `routeA_validate_compressor_map`，要求两条轴均至少有两个点、有限；转速非负且严格递增；压比不小于 1 且严格递增；质量流量非负；矩阵尺寸严格等于 `numel(p_ratio_TLU) x numel(rpm_TLU)`。
3. `routeA_prepare_electrical_boundary_input` 在同一 `SimulationInput` 中写入 `comp_rpm_TLU`、`comp_p_ratio_TLU`、`comp_mdot_corr_TLU`；`context` 回填本次图谱和实际转速范围，避免引用模型工作区基线图谱。
4. `routeA_compressor_map_editor` 提供轴表、流量矩阵、同步增删行列、恢复官方默认值、预览曲线和应用/取消。编辑过程不修改模型；仅“应用图谱”通过完整校验后写回主面板 `draftSimCase`。
5. 参数注册表和能力矩阵新增图谱三数组；三项共用一个面板入口，并明确为“原子三数组提交”。设备页可编辑注册项由 26 增至 29。

## 验证证据

| 验证 | 实际结果 |
|---|---|
| 静态检查 | 新增编辑器、图谱校验器及改动的模板/校验/输入装配/注册表/面板/契约测试均无 Code Analyzer warning；面板仅保留既有 4 条变量增长 info。 |
| 面板契约测试 | `run_routeA_p1_panel_contract_tests` 通过；`ACTIVE=71`，图谱三数组具备 UI、`simCase` 路径和写入点；重复转速和矩阵尺寸错误均被拒止。 |
| `SimulationInput` 读回 | 自定义图谱 `rpm=[0 2100 4200]`、`p_ratio=[1;1.4;1.8;2.2]`、`mdot` 尺寸 `4x3` 可从 `SimulationInput.Variables` 读回，模型 `Dirty=off`。 |
| 编辑器 smoke | 自动取消和自动“应用图谱”均完成；默认图谱返回 `accepted=1`，尺寸 `5x3`。 |
| 端到端仿真 | Current 100 A、60 s、默认图谱：`passed_with_warnings`，尾窗电压 `409.2823 V`；编辑图谱：`passed_with_warnings`，尾窗电压 `409.2776 V`；两例电流均为 `100 A`，电压差 `-0.0047 V`，确认图谱替换可执行并产生有限响应。 |
| 观测和模型状态 | 两例均经 `routeA_panel_extract_results` 通过 22 项观测契约；正式模型保持 `Dirty=off`。 |

## 未决边界

- 本阶段只验证图谱输入链、严格校验、结果有限性及小幅图谱扰动的可观测响应；未建立真实空压机厂家图谱的标定或外推可信区间。
- 其他设备特性曲线仍未开放；后续须按同样的“数组契约、独立响应证据、编辑器和端到端验证”门槛逐项评估。
