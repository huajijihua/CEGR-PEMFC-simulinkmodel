# Route A A10 主模型与复用入口收口 v01

对象模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`（有 cEGR）和 `PEMFuelCellSystem_GasMixture_noCEGR_RouteA_v01.slx`（无 cEGR）
阶段定位：A10 不再代表台架配置派生，而是 Route A 通用 PEMFC-cEGR 平台的主模型、参数入口、运行入口和可视化入口收口。A10.1 是进入 A11 前的收口强化轮，重点补齐设备语义、参数边界和模型可读性，不新增产品拟合。

## 1. 主模型结构

Route A 当前保持一套统一的 `platform_default` 参数链、设备子系统边界和控制语义；为稳态基线提供两份规范模型，而不复制台架版或车载版模型。物理主线和控制入口分工如下：

| 区域 | 作用 |
|---|---|
| `Oxygen Source` | 环境空气、压缩机入口混合、压缩机和空气控制链；空气控制支持 `target_mdot`、`target_oer`、`direct_cmd` |
| `Cathode Gas Channels -> CathodeOutletChamber -> Cathode Exhaust` | 阴极主流道、出口库存、排气和目标压力驱动背压调节 |
| `EGRMassFlowSensor -> CathodeWaterSeparator_FC -> EGRValveRestriction -> EGRPipe -> Oxygen Source.cEGR` | 阴极尾气循环支路 |
| `FCU_BoP_Control` | cEGR ratio/阀面积控制接口；不承担空气压缩机控制和背压压力调节 |
| `Cathode Humidifier` | 阴极加湿器与旁路 gain 接口 |
| `Measurements` 与 Route A KPI 信号 | stack 电流、电压、功率、温度、RH、压力、EGR ratio、分离水等输出 |

### 1.2 A10.1 设备语义边界

| 对象 | 当前计算口径 | A10.1 边界 |
|---|---|---|
| 压缩机入口混合 | `Air Intake + Oxygen Source.cEGR -> CompressorInletMixer -> Compressor` | 压缩机入口总流量包含新鲜空气和回流气，不把 fresh-air command 等同于阴极总供氧 |
| cEGR 控制 | `target_ratio` 或 `direct_area` 进入 `FCU_BoP_Control -> EGRValveRestriction.AR` | `target_ratio` 定义为 EGR 质量流量 / 压缩机入口总质量流量，不是出口分流比 |
| 背压控制 | `routeA_target_p_ca_out_MPa` 驱动官方 `Pressure Relief Valve` | 这是目标压力接口，不是阀开度 PI 标定模型 |
| 中冷/水分离 | `Intercooler_L2_Interface`、`CathodeWaterSeparator_FC`、`AnodeWaterSeparator_FC` | 当前是 L2 压降/KPI 接口，不写成完整高保真换热器或液态水分离器 |
| `SeparatorOrCondensation` | 根据出口 `p/T/y_i` 和 EGR/排气流量估算分离/冷凝水 KPI | 只做审计 observer，不改写物理网络内气体组分 |

### 1.1 双基础模型

| 基础模型 | cEGR 物理连接 | 使用边界 |
|---|---|---|
| `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` | `Cathode_Air_cEGR_BOP.Conn5` 与 `Cathode_Exhaust_Backpressure_Water.Conn1` 直接物理连接，保留水分离、EGR 阀、回流管和压缩机入口混合链 | 有 cEGR 稳态与控制研究；默认 `target_ratio=0.02` |
| `PEMFuelCellSystem_GasMixture_noCEGR_RouteA_v01.slx` | 在同一跨子系统接口间串入官方 `Infinite Flow Resistance (FC)`，块名 `NoCEGR_CathodeIsolation`，使整条 cEGR 支路零质量流量 | 无 cEGR 稳态基线；阴极出口仍通过既有 `Cathode_Exhaust_Backpressure_Water` 主排气支路离开系统 |

两者共享同一参数初始化脚本、顶层子系统封装和非 cEGR 物理网络。无 cEGR 基线不用极小阀面积近似关闭，以避免把数值零交叉问题误判为结构差异。

## 2. 长期入口

| 文件 | 角色 | 使用场景 |
|---|---|---|
| `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystemWithACustomLibraryParameters.m` | 模型工作区默认参数源 | 平台初始化、默认工况、控制接口变量 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_platform_demo.m` | 日常仿真入口 | 实验人员或建模人员快速运行名义 PEMFC-cEGR 工况 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_steady_state_cegr_comparison.m` | 双基础模型稳态入口 | 顺序运行 120 s 无 cEGR / 有 cEGR 工况，并验收功率稳态、零回流和目标回流 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_a10_entrypoint_audit.m` | A10 收口审计入口 | 检查主模型入口、demo、A9.8/A9.9 最小回归 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_a9_parameter_governance_audit.m` | 参数治理回归入口 | 验证 `platform_default`、external-case guard 和 50 kW 参数门槛 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_a9_8_fcu_bop_control_audit.m` | FCU/BoP 控制回归入口 | 验证空气/cEGR 控制接口 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_a9_9_backpressure_control_audit.m` | 背压接口回归入口 | 验证目标阴极出口压力接口 |

A6-A9.7 脚本保留为阶段证据和排障入口，本轮不移动路径，避免破坏历史引用。

### 1.3 A10.2 顶层架构封装

A10.2 在不改变物理方程、设备参数、控制律和 `platform_default` 参数语义的前提下，完成当前主模型的设备语义封装。根层保留 `Solver Configuration` 作为仿真基础设施，设备/功能域固定为：

| 顶层子系统 | 责任边界 | 关键接口 |
|---|---|---|
| `Stack_Core` | MEA、阳极/阴极流道、阴极出口容腔、出口阻力和堆热接口 | 阳极/阴极气体端口、cEGR 取气端口、热端口、电气端口 |
| `Cathode_Air_cEGR_BOP` | 新鲜空气、压缩机、入口混合、阴极加湿、cEGR 阀和回流管 | `routeA_egr_valve_area_cmd`、压缩机入口流量/压力、阀前后压力 |
| `Cathode_Exhaust_Backpressure_Water` | 阴极排气、出口压力调节、排气/EGR 流量测量和水分离接口 | 堆出口气体端口、`routeA_p_outlet`、`routeA_cegr_mdot`、`routeA_m_water_sep` |
| `Anode_Hydrogen_BOP` | 储氢、阳极加湿、回流、阳极排气和阳极水分离 | 阳极气体端口、N2/purge 观察输出 |
| `Thermal_Management_BOP` | 原有散热和冷却回路 | 堆热端口，保留 `routeA_stack_temperature_set_C` 接口 |
| `System_Control_Observability` | FCU-BoP 控制、Electrical Load、Measurements、Scope、Display、ToWorkspace 和诊断终止器 | 仅暴露既有控制/观测信号，不引入新控制律 |

cEGR 跨边界仍按物理责任拆分：阴极出口容腔、EGR 流量测量和水分离属于 `Cathode_Exhaust_Backpressure_Water`；EGR 阀、回流管、入口混合和压缩属于 `Cathode_Air_cEGR_BOP`。`System_Control_Observability` 只承载控制和观测对象，不复制或重建物理块。

脚本中的模型块路径统一由 `03_脚本/RouteA_GasMixture_Derived/routeA_block_paths.m` 集中维护；Simscape 功率日志由 `routeA_simscape_log_mea.m` 兼容 `Stack_Core/Membrane_Electrode_Assembly` 层级。A6 临时探针继续只在内存中修改并在每个 probe 后从磁盘重载，A10 日常入口不保存仿真期间的临时布局变化。

## 3. 操作入口与控制量

日常工况优先通过模型工作区变量设置，不直接改物理模块参数：

| 变量 | 含义 | 默认 |
|---|---|---:|
| `drive_cycle_power` | 功率请求，单位沿用官方示例 kW 量级 | nominal 50.96 kW |
| `routeA_air_control_mode_id` | 空气控制模式：1 target_mdot，2 target_oer，3 direct_cmd | 1 |
| `routeA_target_mdot_comp_inlet` | 压缩机入口总质量流量目标 | 0.045 kg/s |
| `routeA_target_oer` | 阴极氧过量系数目标 | 2.5 |
| `routeA_compressor_cmd_direct` | 空压机开环命令 | 0.5 |
| `routeA_egr_control_mode_id` | cEGR 控制模式：1 target_ratio，2 direct_area | 1 |
| `routeA_target_egr_ratio_comp_in` | EGR 质量流量 / 压缩机入口总质量流量 | 0.02 |
| `routeA_egr_valve_area_direct` | cEGR 阀开环面积 | `2e-3 * cegr_pipe_area` |
| `routeA_target_p_ca_out_MPa` | 阴极出口绝对压力目标 | `env_p + 0.06` |
| `routeA_cathode_humidifier_gain` | 阴极加湿器启用/旁路 gain | 1 |
| `routeA_stack_temperature_set_C` | 冷却系统 stack 温度目标接口 | 80 degC |

## 4. KPI 输出

`run_routeA_platform_demo.m` 默认输出 `routeA_platform_demo_summary`，至少包含：

| KPI | 说明 |
|---|---|
| `actualPowerKW` | 电堆实际输出功率 |
| `compressorCmd` / `compressorRpmCmd` | 空压机控制命令和转速命令 |
| `compInletMdotKgS` | 压缩机入口总质量流量 |
| `egrRatioCompIn` | 压缩机入口 EGR ratio |
| `egrValveAreaCmd` | cEGR 阀面积命令 |
| `pCaOutMPa` | 阴极出口压力 |
| `RHCaIn` / `RHCaOut` | 阴极入口/出口相对湿度 |
| `mWaterSep` | L2 分离水/冷凝水 KPI |

## 5. 当前未做事项

1. A10 不做无加湿器台架配置；该任务顺延为 A11。
2. A10 不做含加湿器车载配置；该任务顺延为 A12。
3. A10 不重新标定空气、cEGR 或背压控制器 PI 增益。
4. A10 不新增阳极 lambda/purge 闭环、阀开度型背压 PI 变体或完整热管理 FCU。
5. A10 不移动 A6-A9 阶段脚本，只在文档中明确它们的长期角色。
6. A10.1 不把短时冷却 setpoint advisory 扩展成完整热管理控制器。

## 6. 验收方式

运行：

```matlab
run('04_Simulink物理网络模型/03_脚本/RouteA_GasMixture_Derived/run_routeA_platform_demo.m')
run('04_Simulink物理网络模型/03_脚本/RouteA_GasMixture_Derived/run_routeA_a10_entrypoint_audit.m')
run('04_Simulink物理网络模型/03_脚本/RouteA_GasMixture_Derived/run_routeA_steady_state_cegr_comparison.m')
```

通过条件：

- demo runner 完成名义 50.96 kW 工况，`routeA_platform_demo_summary.passed == true`。
- A10 审计中 preflight、demo、A9.8 最小回归、A9.9 名义压力回归均通过。
- `model_read(depth=0/1)` 可读回 Route A 操作注释、`FCU_BoP_Control`、空气控制、背压目标和 EGR 阀受控面积链路。
- 双基础模型对比中无 cEGR 的 `egr_ratio_comp_in` 为零，有 cEGR 的比值收敛到设定值，且两者电堆功率尾段稳定。

## 7. A10.1 收口强化记录

执行日期：2026-07-14。

本轮处理：

- 模型顶层操作注释更新为 `RouteA Operator A10.1`，明确日常入口、cEGR 链路、FCU-BoP 控制模式、背压接口和 L2 设备边界。
- 参数脚本补充 profile 注释，标出 air/compressor、cEGR、backpressure、humidification/water-management、anode、cooling 和 FCU-BoP control 的默认层级与 A11/A12 覆盖边界。
- A10 紧凑回归使用拆分/过滤工况，避免每次收口都跑完整 A9.8 矩阵；A9.8 单工况 filter 输出中的全矩阵分类 `passed=0` 不作为本轮失败，A10 审计只验收被过滤工况的 `simCompleted` 与 `kpiFiniteOk`。

本轮已验证：

| 检查 | 结果 |
|---|---|
| 模型目录洁净度 | `01_模型/RouteA_GasMixture_Derived/` 只保留 `.slx`、参数脚本和 drive cycle |
| 非官方生成缓存 | 项目非官方支撑材料范围内未发现 `slprj/` 或 `.slxc` |
| Route A 脚本 `checkcode` | 14 个 `run_routeA_*.m` 无 parse/syntax 问题 |
| `run_routeA_platform_demo.m` | 通过，名义 50.96 kW 工况完成，KPI 有限 |
| `run_routeA_a10_entrypoint_audit.m` | 通过，preflight、demo、A9.8 三个最小工况和 A9.9 名义压力回归均通过 |

## 8. A10.2 收口验证记录

执行日期：2026-07-14。

| 检查 | 结果 |
|---|---|
| `model_overview(detail="full")` | 根层读回五个设备域加 `System_Control_Observability`，`Solver Configuration` 仍在根层 |
| 结构持久化读回 | 保存后关闭并从 `.slx` 重载，控制观测容器、FCU、出口压力转换器和堆温度块均可读回，Dirty=`off` |
| `model_check(["all"])` | 无 error-level 问题；保留 65 条 warning-level 物理连接端口诊断，根层 `model_read` 与仿真连接证据一致，未将 warning 伪报为零告警 |
| 全 Route A `.m` `checkcode` | 无 error 级静态问题；仅保留少量历史临时探针变量提示和未使用参数提示 |
| `run_routeA_platform_demo.m` | `passed=1`，50.96 kW 名义工况完成，功率、压缩机、cEGR、背压、RH 和分离水 KPI 有限 |
| `run_routeA_a10_entrypoint_audit.m` | `generated=1 passed=1`；preflight、demo、A9.8 三个最小工况和 A9.9 三个压力工况全部完成 |

A10.2 不改变 A10.1 已冻结的参数来源、控制边界和 A11/A12 研究范围；后续设备配置仍通过 `platform_default` / `external_case` 明确分层。

## 9. 双基础模型稳态验证记录

执行日期：2026-07-15。无 cEGR 直接使用近零阀面积时出现连续零交叉的数值求解问题，因此没有将该数值现象当作结构结论；改为在完整且已读回的 cEGR 跨子系统物理接口串入官方 `Infinite Flow Resistance (FC)`。这只切断回流支路，未删除主排气路径或改变其他子系统耦合。

| 工况 | 120 s 末值 | 稳态判据 |
|---|---|---|
| 无 cEGR | `P=50.96 kW`，功率尾段跨度 `1.80e-11 kW`，`egr_ratio=0`，排气 `0.04901 kg/s` | 通过：回流严格关闭，主排气仍有限 |
| 有 cEGR | `P=50.96 kW`，功率尾段跨度 `9.34e-11 kW`，`egr_ratio=0.0200002`，排气 `0.0482054 kg/s` | 通过：目标回流比 0.02，最后 10 s 比值跨度 `2.38e-7` |

`model_check(["all"])` 对两个顶层模型均无 error-level 问题；仍有 65 条 warning-level 物理端口诊断，这是普通 Subsystem 边界下该检查器不能完整追踪 Simscape 守恒连接的已知限制。已由根层连接读回和上述两套独立仿真结果交叉验证，未将 warning 伪报为零告警。
