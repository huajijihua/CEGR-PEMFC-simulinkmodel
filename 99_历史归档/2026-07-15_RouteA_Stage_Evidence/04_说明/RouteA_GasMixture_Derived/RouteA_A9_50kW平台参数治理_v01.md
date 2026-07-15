# RouteA A9 50 kW 平台参数治理 v01

日期：2026-07-09  
对象模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
治理入口：`run_routeA_a9_parameter_governance_audit.m`

## 1. 定位

A9 的任务是把当前 RouteA_A8 的 50 kW 通用平台参数治理成可读回、可计算、可审计、可验证的基线。A9 不直接派生台架版或车载版，不把旧 10 kW 台架、DQ60、workbook 或 CSV 迁入 `platform_default`，也不在第一轮修改 `.slx` 或默认参数值。

当前固定内核：

| 项 | 值 | 说明 |
|---|---:|---|
| 电堆片数 | 400 | MathWorks Gas Mixture 官方示例派生 |
| 单片面积 | 280 `cm^2` | 当前 50 kW 平台核心尺寸 |
| 名义电流密度 | 0.7 `A/cm^2` | A9 主匹配点 |
| 名义电流 | 196 `A` | `280*0.7` |
| 名义单片电压 | 0.65 `V` | 粗匹配包络 |
| 名义电功率 | 约 50.96 `kW` | `400*196*0.65` |

## 2. A9 审计入口

`run_routeA_a9_parameter_governance_audit.m` 作为 A9 主入口，执行以下检查：

| 层级 | 检查内容 | 通过标准 |
|---|---|---|
| 参数隔离 | `routeA_parameter_layer`、`external_case` 默认拒止、参数脚本默认数据读取 | `platform_default` 成立；外部案例默认禁用；参数脚本不读 CSV/XLSX/旧台架 |
| 公式包络 | `low_load_cegr`、`nominal_50kW`、`high_power_envelope` | 功率、流量、热负荷、速度、压降和裕度均有限；名义点约 50 kW；高功率空压机裕度大于 2 |
| 参数归类 | 五类子系统参数标签 | A8 新增参数全部归入设备/模块；标签只使用统一集合 |
| A8 回归 | A8 三个 smoke 工况 | `run_routeA_a8_device_chain_audit.m` 仍通过 |
| 名义稳态 | `nominal_50kW_steady` | 30 s 仿真完成；压力链、RH、水量 KPI 和热量估算有限且非负 |

统一标签：

| 标签 | 含义 |
|---|---|
| `保留` | 当前可作为 50 kW `platform_default` 基线保留 |
| `建议调整` | 当前可运行，但 A9/A11 前应形成调整候选 |
| `仅占位` | 只表达结构或 L2 接口，不代表产品级性能 |
| `证据不足` | 模型内存在结构，但平台层缺少显式参数或证据 |
| `进入profile` | 默认值暂不改，后续通过 `scaling_rule/profile` 管理 |

## 3. 五类子系统治理

### 3.1 电化学性能

| 设备/结构件 | 模块 | 参数 | 当前治理标签 | A9 处理 |
|---|---|---|---|---|
| MEA | `Membrane Electrode Assembly` | `stack_num_cells` | 保留 | 固定为 400，不为小功率案例回改 |
| MEA | `Membrane Electrode Assembly` | `stack_area` | 保留 | 固定为 280 `cm^2` |
| MEA | `Membrane Electrode Assembly` | `stack_iL` | 保留 | 作为高功率包络边界 |
| MEA | `Membrane Electrode Assembly` | `stack_t_membrane` | 进入profile | 后续高性能膜或水热升级时单独 profile |

结论：电化学内核继续采用官方示例派生参数，A9 不调整电堆片数和面积。

### 3.2 供氢与基础回流

| 设备/结构件 | 模块 | 参数 | 当前治理标签 | A9 处理 |
|---|---|---|---|---|
| 储氢瓶 | `Hydrogen Source/Fuel Tank` | `tank_p`、`tank_V` | 保留 | 短时平台仿真裕度足够 |
| 供氢管路 | `Hydrogen Source/Pipe (FC)` | `anode_tube_D` | 建议调整 | 10 mm 低压氢估算流速偏高，列为 A9 重点复核 |
| 减压阀 | `Hydrogen Source/Pressure-Reducing Valve/Valve` | 局部 mask 面积 | 证据不足 | 后续显式化为平台参数候选 |
| 阳极水分离接口 | `AnodeWaterSeparator_FC` | `anode_separator_*` | 保留/仅占位 | 只代表 L2 压降接口，不声明主动排水 |

结论：A9 第一优先级是把阳极管径、压力、回流和 purge 语义统一审计。当前不删除官方阳极结构，也不把水分离器写成主动移水模型。

### 3.3 供氧与空压机

| 设备/结构件 | 模块 | 参数 | 当前治理标签 | A9 处理 |
|---|---|---|---|---|
| 空压机 map | `Oxygen Source/Compressor Map` | `comp_mdot_corr_TLU` | 进入profile | 对 50 kW 名义点裕度偏大，但保留官方基线 |
| 阴极主管 | `Cathode Humidifier/Pipe (FC)` | `cathode_tube_D` | 保留 | 50 mm 管径支持当前平台流量 |
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `intercooler_*` | 保留/仅占位 | `0.1 kg/s` 名义流量覆盖高功率包络 |
| 阴极加湿旁路 | `CathodeHumidifierBypass` | `routeA_cathode_humidifier_*` | 保留 | A10 台架旁路使用；平台默认仍启用加湿器 |

结论：空压机 map 暂不替换，A9 只建立空气需求、压比、map 裕度和效率边界的审计规则。

### 3.4 冷却与热管理

| 设备/结构件 | 模块 | 参数 | 当前治理标签 | A9 处理 |
|---|---|---|---|---|
| 冷却管路 | `Cooling System/Fuel Cell Coolant Channels` | `coolant_tube_D` | 保留 | 50 mm 管径暂保留 |
| 散热器 | `Cooling System/Radiator` | `radiator_air_area_primary`、`radiator_air_area_fins` | 证据不足 | 需通过名义热负荷和高功率热负荷审计 |

结论：A9 先要求热稳态 KPI 有限和量级可解释，不把当前冷却动态解释为产品级热管理响应。

### 3.5 CEGR 与水管理

| 设备/结构件 | 模块 | 参数 | 当前治理标签 | A9 处理 |
|---|---|---|---|---|
| 出口容腔 | `CathodeOutletChamber` | `cathode_outlet_chamber_V` | 保留 | 作为出口库存和 p/T/y_i 读回节点 |
| cEGR 管路 | `EGRPipe` | `cegr_pipe_D`、`cegr_pipe_length` | 保留/进入profile | 管径暂保留，长度后续按布置 profile |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_area_closed` | 保留 | no-EGR 近关断工况 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_area_low` | 仅占位 | 只用于低 EGR smoke，不是阀门标定 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_max_area` | 进入profile | 后续按目标 EGR 比收紧 |
| 阴极水分离接口 | `CathodeWaterSeparator_FC` | `cathode_separator_*` | 保留/仅占位/进入profile | 保留 L2 接口，`mdot_nominal` 需复核 |
| 水量 KPI 观察器 | `SeparatorOrCondensation` | `separator_l2_efficiency` | 仅占位 | 只估算 `routeA_m_water_sep`，不改变物理网络 |

结论：A9 不升级两相水传输。液态水相变、传输和主动移除应进入后续水管理阶段。

## 4. 公式包络

审计脚本固定三档计算包络：

| 工况 | 电流密度 | 单片电压 | 用途 |
|---|---:|---:|---|
| `low_load_cegr` | 0.20 `A/cm^2` | 0.78 `V` | 低负载 cEGR、自增湿、高电位抑制边界 |
| `nominal_50kW` | 0.70 `A/cm^2` | 0.65 `V` | 主要设备匹配点 |
| `high_power_envelope` | 1.20 `A/cm^2` | 0.58 `V` | 空压机、冷却、管路裕度检查 |

注意：当前官方 `drive_cycle_power` 入口按 kW 数值量级使用；`nominal_50kW_steady` 写入约 `51`，不是 `51000`。若误按 W 写入，会把工况变成 51 MW 量级并触发初始化失败。

计算项包括：

- 电功率、堆电流、氢耗、氧耗、水生成量。
- `lambda_O2=2` 下的空气需求。
- 阴极 50 mm 管和阳极 10 mm 管的速度估算。
- 按 55% 电效率估算的热负荷。
- 中冷接口、阴极水分离接口、阳极水分离接口的名义压降量级。
- 空压机 map 最大流量相对空气需求的裕度。

## 5. 验收与后续

A9 第一轮收口条件：

1. `run_routeA_a9_parameter_governance_audit.m` 可运行并生成 `routeA_a9_parameter_governance_audit`。
2. 参数隔离、公式包络、参数归类、A8 回归和 `nominal_50kW_steady` 均通过。
3. 文档明确哪些参数保留，哪些进入 profile，哪些只是 L2/占位。
4. 不修改 `.slx`，不改默认参数值，不引入旧台架默认依赖。

A9 完成后再决定第二轮是否修改默认参数。优先候选顺序：

1. 阳极管径/压力/回流/purge。
2. CEGR 阀面积与目标循环比关系。
3. 冷却流量、散热器 UA、热稳态收敛。
4. 空压机 map 缩放和效率边界。
5. 加湿器、水分离器、液态水传输升级。

## 6. 本轮验证记录

执行入口：`run_routeA_a9_parameter_governance_audit.m`  
执行结果：`passed=1`

| 检查项 | 结果 | 关键证据 |
|---|---:|---|
| Code Analyzer | 通过 | `checkcode` 无问题 |
| 参数隔离 | 通过 | `layer=platform_default`；`external_case_enabled=0`；旧台架默认依赖为 0 |
| 公式包络 | 通过 | `nominal_50kW` 为 51 kW；名义空气需求 0.0560 kg/s；空压机裕度 7.14 |
| 参数归类 | 通过 | 38 个治理项均可归类；A8 新增参数全部覆盖 |
| A8 回归 | 通过 | A8 三组 30 s smoke 全部通过 |
| `nominal_50kW_steady` | 通过 | 目标功率 51 kW；实际功率 51 kW；压力链、RH、水量 KPI 均有限且非负 |

审计警告不阻塞 A9 第一轮收口：

- `anode_tube_velocity_high_at_nominal`：阳极 10 mm 管径在低压估算下速度偏高，是下一轮参数调整候选。
- `cathode_separator_nominal_flow_close_to_air_demand`：阴极水分离接口 `0.05 kg/s` 接近名义空气需求，应进入 profile 复核。
- `cegr_max_valve_area_is_broad_upper_bound`：`cegr_valve_max_area` 只是宽裕上限，后续应按目标 EGR 比收紧。

## 7. 第二轮收口记录

第二轮详见：`RouteA_A9_50kW平台参数治理_第二轮_v01.md`。

第二轮已将第一轮 3 个 warning 转为参数调整和审计硬门槛：

| 参数 | 第一轮 | 第二轮 |
|---|---:|---:|
| `anode_tube_D` | 0.01 `m` | 0.02 `m` |
| `cathode_separator_mdot_nominal` | 0.05 `kg/s` | 0.10 `kg/s` |
| `cegr_valve_max_area` | `0.8*cegr_pipe_area` | `0.02*cegr_pipe_area` |

第二轮 `run_routeA_a9_parameter_governance_audit.m` 执行结果：`passed=1`。第二轮硬门槛结果：名义阳极低压氢估算速度 32.587 `m/s`，阴极水分离器名义流量裕度 1.7846，高功率流量裕度 1.041，CEGR 最大阀面积比 0.02，`max_cegr_area_sanity` 通过。
