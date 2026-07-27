# R00 Baseline and Interface Freeze

记录编号：`R00_baseline_and_interface_freeze_20260724_v01`
阶段：Phase 0
状态：`IN_PROGRESS`
日期：2026-07-24
目标：固化 RouteA_v2 独立工作树、当前模型读回基线、接口草案和后续文献/结构工作的边界。
对应计划：[RouteA_v2 实施计划](../RouteA_v2_GasMixture_Derived/RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)

## 1. 本次范围

本记录只覆盖 v2 目录分离后的来源核对、当前基线读回和文档边界整理。不修改 `.slx` 结构、不修改原 RouteA、不复制正式 v09/v10 结果、不清理缓存。

## 2. 已核对的基线

| 项目 | 事实 |
|---|---|
| v2 工作树 | `E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\` |
| v2 模型 | [`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx`](../../01_模型/RouteA_v2_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01.slx) |
| 模型根名称 | `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v2_v01` |
| 当前结构读回 | 总计 23 个容器；主要职责块见架构规格 |
| v2 模型 hash | `0211A2FEE5BE4DA06A792ADBA80CC49CC34A4FEC65A854A7B5097F5B82DC81EB` |
| 当前结构检查 | `model_check(all)` 读回 77 个 warning；属于复制基线，不是通过 |
| update/compile | 本记录阶段未完成 v2 运行验证 |
| 冷态 smoke | 未完成；旧 RouteA 的 `NE_DAE_IC_Failure` 尚未证明可迁移或已修复 |
| 结果资产 | 未复制 v09/v10 formal 结果；v2 `05_结果` 保持结果摘要边界 |
| 原 RouteA | 保持在 `04_Simulink物理网络模型/`，只作来源/对照/历史证据 |

上述事实来自 v2 根 README、模型 read-back 和本轮目录审查；未完成的项目保持 `NOT_RUN`，不因模型可读或脚本静态检查而升级。

## 3. 初步资产处置

| 资产/问题 | 初步标签 | 当前决定 | 关闭条件 |
|---|---|---|---|
| 官方 Gas Mixture/FuelCell 四物种域、MEA | `PRESERVE` | 作为物理主域和官方结构参照 | Phase 1 端口/参数读回 |
| 当前电堆、热端、阴极/阳极气路 | `PRESERVE/REFACTOR` | 先保留，再按自然职责收敛 | Phase 1 结构证据 |
| 当前 cEGR 主气路 | `PRESERVE` | 保留出口分流 -> 执行器 -> 入口混合的主链 | cEGR 物种/质量闭合 |
| `Cathode_Air_cEGR_BOP` | `PRESERVE/REFACTOR` | 按供气与 cEGR 职责拆读，不整体推倒 | Phase 0/1 映射 |
| `Cathode_Exhaust_Backpressure_Water` | `PRESERVE/REFACTOR` | 保留排气/背压/水边界，核查液水语义 | Phase 1/5 |
| `Anode_Hydrogen_BOP` | `PRESERVE/REFACTOR` | 保留已闭合官方语义，暂不新增源 | Phase 1 |
| 两侧 `Source_Conditioner` | `REFACTOR` | 逐端口识别设备边界、混合、测量或历史接口 | Phase 0.5/1 |
| I/P/V runner | `PRESERVE/REFACTOR` | 暂作兼容证据入口，Phase 3 再统一 | Phase 3 |
| v09 formal MAT | `HISTORICAL` | 只作旧结构证据 | 不转为 v2 通过证据 |
| v10 初态和失败证据 | `HISTORICAL` | 记录失败边界，不自动迁移 | v2 冷态/热态运行 |

## 4. 当前接口冻结草案

1. plant 内部只保留一个 `I_cmd`；Current/Power/Voltage 是用户侧输入适配，不是三套 plant；
2. cEGR 的 `cegr_ratio_cmd` 只能是上层 setpoint，实际 `mdot_cegr`、组分、温度和 RH 必须来自物理网络；
3. `u` 记录主动命令，`w` 记录边界/扰动，`y` 只发布实际传感器量，`z` 记录审计真值；
4. `mdot_fresh`、`mdot_cegr`、`mdot_mix_in`、湿/干基回流比、`lambda_fresh`、`lambda_mix`、`pO2_ca_in` 和 `RH_ca_in` 不得互相替名；
5. 影响项（氧稀释、自增湿、排水、低负荷高电位、动态饥饿、寄生功耗、冷启动）先作为研究问题/KPI，不自动扩展 cEGR 物理结构。

## 5. Phase 0 尚未收口项

- [ ] 完整列出当前 23 个容器的职责、父子位置、端口和参数来源；
- [ ] 对所有 `model_check` warning 建立类型、位置、合法性和责任模块 ledger；
- [ ] 完成两侧 `Source_Conditioner` 端口逐项物理解释；
- [ ] 固定 Phase 0.5 的首个闭环用例、被动/主动设备配置和 KPI；
- [ ] 用户确认可以按当前边界进入 Phase 1 结构修改。

## 6. 本次结论

RouteA_v2 的独立工作树和基本接口方向已经建立，但 Phase 0 尚未通过。下一步只能继续做资产/接口/文献证据收口；不能把本记录的复制基线、77 个 warning 或脚本静态检查写成模型运行成功。
