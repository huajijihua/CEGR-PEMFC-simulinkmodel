# Route A 阴极 cEGR 聚焦 runner

本目录只服务 `RouteA_Cathode_cEGR_Focused` 轻量研究模型，不修改或替代
`RouteA_GasMixture_Derived` 的完整系统 runner。

## 正式入口

| 文件 | 职责 |
|---|---|
| `routeA_focused_paths.m` | 解析轻量模型、源模型和共享脚本路径 |
| `routeA_focused_parameter_defaults.m` | 提供固定阳极边界和恒温边界默认值 |
| `routeA_focused_case_template.m` | 返回轻量模型 case 输入模板 |
| `routeA_focused_case_adapter.m` | 接受聚焦 case 或标准 Route A `simCase` 并统一到 runner 输入 |
| `routeA_focused_parameter_bridge.m` | 将标准阳极/热管理输入映射到简化后的真实模型写入点 |
| `run_routeA_focused_study.m` | 通过 `SimulationInput` 串行执行一组同类 I/P/V case |
| `routeA_focused_assess_outputs.m` | 复用阴极/电边界审计并取消不适用的阳极吹扫门 |
| `routeA_focused_performance_metrics.m` | 计算电流密度、功率密度、双口径回流率和混合点氧分压 |
| `routeA_focused_performance_analysis.m` | 汇总多 case 性能比较准入和排除原因 |
| `routeA_focused_water_observations.m` | 提取气相冷凝和饱和度证据，不声称液水闭合 |

## 输入接口

- 标准 `Route A simCase`：`controls.electrical`、`controls.cathode`、`controls.cegr`、`controls.anode`、`controls.thermal`、`controls.stack` 和 `controls.devices` 可直接传入；建议先用 `routeA_simCase_template` 和 `routeA_validate_case`。
- 原生聚焦 case：使用 `boundary`、`air`、`cathode`、`cegr`、`anode`、`thermal`、`stack`、`devices` 和 `focused` 字段。
- `thermal.stackTemperatureSet_C` 映射到 `focused_stack_temperature_C`；`anode.sourcePressure_MPa_abs`、`anode.sourceTemperature_C` 和 `anode.h2MoleFraction` 分别映射到聚焦氢源压力、边界温度和组分。
- 阳极入口由 `focused.anodeInletMdot_kg_s` 控制；标准 `anode.inletPressure_MPa_abs`、阳极加湿、阳极回流、阳极吹扫以及冷却液/散热器参数会保留在桥接报告中，但标记为 `not_applicable`，不会伪装成已接入的物理量。

## 输出接口

- `study.cases(k).performance.electrical`：I/V/P、单电池电压、电流密度和功率密度。
- `study.cases(k).performance.cegr`：目标值、`r_mix=m_cegr/m_mix`、`r_fresh=m_cegr/m_fresh`、回流流量、阀面积和压差。
- `study.cases(k).performance.cathode`：压缩机入口混合点压力、温度、组分、氧过量系数、RH、氧分压和气相闭合状态。
- `study.cases(k).performance.thermal`：固定温度设定、实际堆温和温差；固定温度边界不等同于冷却系统热流结果。
- `study.cases(k).performance.water`：混合点气相冷凝率和饱和度；液水库存、输运、排液、分离效率和空压机寄生功率仍未闭合。
- `study.cases(k).parameterBridge`：每个参数的真实写入点、映射状态和不适用原因。

第一阶段已完成聚焦模型本身的 I/P/V、空气控制模式和低负荷代表性验证；完整模型逐信号等价对照仍是独立门槛。
