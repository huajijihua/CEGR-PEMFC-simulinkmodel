# Route A cEGR-PEMFC 聚焦模型 P1 官方模块与端口审计

日期：2026-08-14
状态：已完成只读审计；未修改正式模型、runner 或参数；未运行研究仿真。

## 前置决策

- [两种阀门被动架构聚焦模型改造实施方案](../../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md) 的 P0.5 已由用户确认。
- 本轮固定为 L2 气相热湿-压力筛选：分离边界不移除水蒸气、不修改气相组分；潜在冷凝不代表液水库存或分离效率。
- 配置 B 在本轮只允许建立双侧 L2 接口，不做跨膜换湿性能排序。

## 实际工作和读回证据

审计对象为 `04_Simulink物理网络模型/01_模型/RouteA_Cathode_cEGR_Focused/PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`。使用 MATLAB R2025b 的官方 MATLAB MCP/SATK 完成 `model_overview`、`model_read`、参数读回和本机官方库检索；同时读取正式聚焦 runner 的 case adapter 与性能指标脚本。

| 对象 | 已读回事实 | P2 处置 |
|---|---|---|
| `Stack_Core/CathodeOutletChamber` | 官方 `Constant Volume Chamber (FC)`；有气体端口 `A/B/C` 和状态输出 `pC/TC/yC_i` | 保留为阴极出口库存节点；公共背压置于其下游 |
| `CathodeWaterSeparator_FC` | 官方 `Flow Resistance (FC)`，仅有气体端口 `A/B`；参数为标称压降、标称流量、密度、层流比例和面积 | 不再称为真实分离器；作为 L2 气相分离边界的压损候选 |
| `EGRValveRestriction/Open/LocalRestriction` | 官方 `Local Restriction (FC)`，端口为气体 `A/B` 与面积物理信号 `AR`；面积、最小/最大开度和管径已有唯一参数写入点 | 保留为回流支路 CEGR 阀 |
| `Cathode Exhaust/Pressure Relief Valve` | 当前为带掩码的子系统，参数包括 `D`、`r_min`、`r_max`、`p_range`；其气体路径接在排放支路，压力命令经物理信号端口写入 | 不得改名为公共背压阀；P2 需单独建立公共主干背压语义，并保留排放低压边界 |
| 当前 `Cathode Humidifier` | `Pipe (FC)` 加 `MIn` 水质量注入、RH 传感器和比例控制 | 配置 A 必须旁路并令外部注水为零；不能当作膜加湿器 |
| 膜加湿器候选 | 本机 `FuelCell_lib` 仅命中 MEA 与湿度传感器；`fl_lib/Moist Air` 仅命中湿空气性质工具，未发现可与 `FuelCell` 四物种气体域直接连接的双侧膜加湿器 | 配置 B 首轮为干侧/湿侧 L2 边界接口；跨膜水/热传递为 `not_implemented` |

## 当前真实测点与缺口

| 状态量 | 已有真实测点或结果写入 | 缺口 |
|---|---|---|
| `m_dot` | EGR 支路和排放支路各有 `Mass Flow Rate Sensor (FC)`；空压机入口质量流量送入控制器与结果契约 | 当前流量位置不是分离后支路；需在 P2 后重新定义 `r_split` |
| `p_abs/T/y_i/RH` | 阴极出口经现有转换链写出 `routeA_p_outlet`、`routeA_T_outlet`、`routeA_yi_outlet`、`routeA_RH_ca_out`；中冷器出口有 P/T 与湿度传感器；阀上下游各有 P/T 传感器 | 公共背压前后、分离边界前后、分离后两支路组分未观测 |
| 配置 B 双侧状态 | 无 | 干侧和湿侧入口/出口的 `p_abs`、`T`、`y_i`、`m_dot`、压降和跨膜水/热量均需建立；跨膜量本轮保持未实现 |

`routeA_focused_performance_metrics.m` 已将当前 `r_split` 标为“模型中回流/排放支路总质量流量口径”，并将干基比例标为缺少支路组分而不可用；水指标仍明确为气相饱和/冷凝观察。这些定义在 P2 前不提升为分离后物理量。

## 验证结果

- 模型保存状态：`Dirty=off`。
- 配置：`StopTime=100`，`Solver=VariableStepAuto`。
- `model_check(all)`：0 error，63 个 `unconnected_port` warning。警告主要涉及 Simscape 子系统接口与未闭合的现有端口；本轮未将其解释为结构健康通过。P2 结构改造后必须重新运行检查、识别新增项并对每项分类。
- 未执行 `sim` 或正式研究 case，因此无 `executed`、`behavior_verified` 或工程验证结论。

## 完成状态和未决项

P1 的审计目标已完成：可复用块、端口语义、参数写入点、气体域兼容性和观测缺口均已登记。P2 准入成立，但仅限公共出口拓扑的最小结构改造。P2 不得引入液水质量状态、气相组分修改、独立回流泵、MATLAB Function 核心气路物理或配置 B 的跨膜传质/传热代理。
