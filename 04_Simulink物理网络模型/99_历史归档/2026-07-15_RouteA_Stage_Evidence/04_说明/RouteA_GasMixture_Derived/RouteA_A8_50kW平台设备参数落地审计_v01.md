# Route A A8 50 kW 平台设备参数落地审计 v01

生成日期：2026-07-09  
对象模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
目标：以 `400 cells x 280 cm^2` 电堆为固定内核，审计当前 MathWorks Gas Mixture 官方示例参数和 A8 设备链接口是否能组成一套自洽的 50 kW 级通用平台。  
边界：本文件只做参数落地分析，不修改 `.slx`，不修改 `platform_default`，不引入旧台架、DQ60、10 kW workbook 或 CSV 作为默认真源。

## 1. 审计结论先行

当前 Route A A8 平台应定义为“50 kW 名义、中等功率、可向 70-80 kW 高功率包络检查”的通用系统平台，而不是十几千瓦小平台，也不是几百千瓦大平台。

| 结论项 | 判断 |
|---|---|
| 电堆内核 | `400 cells x 280 cm^2` 来自 MathWorks 官方示例，作为当前平台默认真源应保留 |
| 名义功率点 | 取 `j=0.7 A/cm^2`、`V_cell=0.65 V`，约 `50.96 kW`，适合作为 BoP 参数匹配主点 |
| 高功率包络 | 取 `j=1.0-1.2 A/cm^2`，约 `67-78 kW`，用于检查空压机、冷却、管路裕度 |
| 低负载 CEGR 包络 | 取 `j=0.05-0.2 A/cm^2`，约 `4.6-17.5 kW`，用于低负载降氧、自增湿和高电位抑制 |
| 供氧系统 | 空压机 map 对 50 kW 名义点裕度约 `7.14x`，数值稳定但不代表真实产品动态 |
| 供氢系统 | 氢瓶和供氢能力足够；阳极 10 mm 低压流速估算偏高，后续 A9 应重点复核 |
| 冷却系统 | 官方散热器和冷却链可支撑几十千瓦量级；高功率包络仍需后续稳态仿真验证 |
| CEGR | 拓扑和接口完整；阀面积、水分离器、混合容腔仍是 L2/占位参数，不能当产品标定 |
| 水管理 | A8 已具备冷凝位置、分离接口和水量 KPI；主动液态水移除留到后续保真度升级 |

## 2. 三档计算包络

计算常数：`N=400`，`A_cell=280 cm^2`，`F=96485.33212 C/mol`，空气氧质量分数取 `0.232`。  
功率只用于设备量级审计，非拟合结果。

| 包络 | 电流密度 `j` | 电流 | 单体电压假设 | 电功率 | 氢耗 | 氧耗 | 水生成 | 空气需求 `lambda_O2=2` | 空压机裕度 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `low_load_cegr_low` | 0.05 `A/cm^2` | 14 A | 0.82 V | 4.59 kW | 0.059 g/s | 0.464 g/s | 0.523 g/s | 0.0040 kg/s | 99.9x |
| `low_load_cegr_high` | 0.20 `A/cm^2` | 56 A | 0.78 V | 17.47 kW | 0.234 g/s | 1.857 g/s | 2.091 g/s | 0.0160 kg/s | 25.0x |
| `nominal_50kW` | 0.70 `A/cm^2` | 196 A | 0.65 V | 50.96 kW | 0.819 g/s | 6.500 g/s | 7.319 g/s | 0.0560 kg/s | 7.14x |
| `high_power_envelope_1p0` | 1.00 `A/cm^2` | 280 A | 0.60 V | 67.20 kW | 1.170 g/s | 9.286 g/s | 10.456 g/s | 0.0801 kg/s | 5.00x |
| `high_power_envelope_1p2` | 1.20 `A/cm^2` | 336 A | 0.58 V | 77.95 kW | 1.404 g/s | 11.143 g/s | 12.547 g/s | 0.0961 kg/s | 4.16x |

管路和热负荷派生：

| 包络 | 阴极 50 mm 管流速，按 `rho_air=1 kg/m^3` | 阳极 10 mm 管流速，按 `rho_H2=0.08 kg/m^3` | 散热负荷，`eta=55%` | 散热负荷，`eta=60%` |
|---|---:|---:|---:|---:|
| `low_load_cegr_low` | 2.0 m/s | 9.3 m/s | 3.8 kW | 3.1 kW |
| `low_load_cegr_high` | 8.2 m/s | 37.2 m/s | 14.3 kW | 11.6 kW |
| `nominal_50kW` | 28.5 m/s | 130.4 m/s | 41.7 kW | 34.0 kW |
| `high_power_envelope_1p0` | 40.8 m/s | 186.2 m/s | 55.0 kW | 44.8 kW |
| `high_power_envelope_1p2` | 48.9 m/s | 223.5 m/s | 63.8 kW | 52.0 kW |

解释：

- 阴极 50 mm 管对 50 kW 名义点流速合理，对高功率包络仍可接受，但尺寸偏“平台友好”。
- 阳极 10 mm 管若按低压氢气估算流速偏高；实际模型中存在压力调节、回流和高压源，不能只用低压估算否定，但它应进入 A9 重点复核。
- 空压机裕度来自 `comp_mdot_corr_TLU` 上限 `0.4 kg/s` 与 `lambda_O2=2` 空气需求的比值。它说明当前平台容易收敛，但不说明空压机效率和动态真实。

## 3. 电化学性能与电堆本体

| 设备/结构件 | Simulink 模块 | 关键参数 | 当前值 | 来源层级 | 匹配计算 | 标签 | A9 去向 |
|---|---|---|---:|---|---|---|---|
| MEA 电化学本体 | `Membrane Electrode Assembly` | `N_cell` | 400 | S0 官方 | 与 50 kW 名义点直接匹配 | 保留 | 固定平台内核 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `area_cell` | 280 `cm^2` | S0 官方 | `I_nom=0.7*280=196 A` | 保留 | 固定平台内核 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `iL` | 1.4 `A/cm^2` | S0 官方 | 名义点为极限电流密度 50%，高包络 1.2 仍低于上限 | 保留 | 作为高功率边界 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `io` | 1e-4 `A/cm^2` | S0 官方 | 控制电压极化量级，不参与 BoP 流量闭合 | 保留 | 后续电压参数治理 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `alpha` | 0.7 | S0 官方 | 与官方 Gas Mixture 示例一致 | 保留 | 后续电压参数治理 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `t_membrane` | 125 `um` | S0 官方 | 比部分文献薄膜保守，但官方示例一致 | 保留 | profile 可选项 |
| 阳极气道 | `Anode Gas Channels` | `V0`, `area_A/B/C` | 53546.242, 3200 | S0 官方表达式 | 与 `400 cells x 280 cm^2` 同源 | 保留 | 暂不缩放 |
| 阴极气道 | `Cathode Gas Channels` | `V0`, `area_A/B/C` | 53546.242, 3200 | S0 官方表达式 | 与 `400 cells x 280 cm^2` 同源 | 保留 | 暂不缩放 |
| 气道冷凝设置 | `Anode/Cathode Gas Channels` | `is_cond` | `[0;0;0;0]` | S0/A8 当前策略 | 电堆内暂不建液态水相变 | 仅占位 | 水管理升级 |
| 电接口 | `Electrical Load` | 功率请求和电流源 | 参数脚本装配 | S0 官方 | 支撑 drive cycle 仿真 | 保留 | 后续稳态工况补充 |

电堆本体结论：当前电化学内核应保持官方参数，不能为了“十几千瓦”回改片数或面积。后续如果要 profile，应通过 A9 缩放规则显式派生，不污染 `platform_default`。

## 4. 供氢与基础氢气循环

| 设备/结构件 | Simulink 模块 | 关键参数 | 当前值 | 来源层级 | 匹配计算 | 标签 | A9 去向 |
|---|---|---|---:|---|---|---|---|
| 储氢瓶 | `Hydrogen Source/Fuel Tank` | `tank_p` | 70 MPa | S0 官方 | 对名义氢耗 0.819 g/s 裕度充分 | 保留 | 不作为台架边界 |
| 储氢瓶 | `Hydrogen Source/Fuel Tank` | `tank_V` | 120 L | S0 官方 | 适合车载/平台仿真，不影响短时收敛 | 保留 | 车载 profile 可保留 |
| 氢气纯度 | `Hydrogen Source/Fuel Tank` | `tank_yH2` | 0.9997 | S0 官方 | 近纯氢边界 | 保留 | 可作为默认 |
| 减压阀 | `Hydrogen Source/Pressure-Reducing Valve/Valve` | `area=pi*D^2/4` | 局部 Mask | S0 官方结构 | 当前未形成平台层显式参数 | 证据不足 | A9 参数显式化候选 |
| 堆侧压力偏置 | `Hydrogen Source/Pressure-Reducing Valve/Stack Pressure` | `Constant` | 0.06 MPa + `env_p` | S0 官方 | 与阴极背压量级一致 | 保留 | 后续压力链统一 |
| 供氢管路 | `Hydrogen Source/Pipe (FC)` | `anode_tube_D` | 0.01 m | S0 官方 | 低压估算名义流速 130 m/s，偏高 | 建议调整 | A9 重点复核 |
| 阳极加湿器 | `Anode Humidifier/Pipe (FC)` | `Dh`, `area`, `length` | 0.05 m, 0.001963 m2, 0.25 m | S0 官方/L2 | 面积远大于 10 mm 供氢管，动态语义偏粗 | 仅占位 | A10/A11 或水热升级 |
| 阳极回流容腔 | `Recirculation/Constant Volume Chamber (FC)` | `V0` | `0.05^3 m^3` | S0 官方结构 | 提供基础回流库存 | 仅占位 | 后续回流器模型 |
| 阳极水分离接口 | `AnodeWaterSeparator_FC` | `mdot_nominal` | 0.01 kg/s | A8 L2 | 名义氢耗约 0.000819 kg/s，仅为其 8.2% | 保留 | 保留 L2 接口 |
| 阳极水分离接口 | `AnodeWaterSeparator_FC` | `delta_p_nominal` | 0.0005 MPa | A8 L2 | 按氢耗估算压降低于 0.01 kPa，不构成阻塞 | 保留 | 后续主动排水 |
| 阳极尾排/排氮 | `Anode Exhaust/Pipe (FC)` | `Dh`, `length` | 0.01 m, 1 m | S0 官方 | 与供氢管同径，支持排氮/尾排路径 | 保留 | 后续 purge 策略 |

供氢结论：

- 氢源和减压语义足够支撑 50 kW 平台。
- 阳极 10 mm 管径是最需要复核的供氢参数。它来自官方示例，当前不直接改，但 A9 应把阳极管径、压力、回流量、排氮流量一起审计。
- 阳极水分离器目前是“位置 + 压降接口”，不是主动液态水移除设备。

## 5. 供氧、空压机、中冷和加湿

| 设备/结构件 | Simulink 模块 | 关键参数 | 当前值 | 来源层级 | 匹配计算 | 标签 | A9 去向 |
|---|---|---|---:|---|---|---|---|
| 环境空气 | `Oxygen Source` 边界 | `env_p`, `env_T`, `env_yO2`, `env_RH` | 0.101325 MPa, 20 degC, 0.21, 0.5 | S0 官方 | 标准湿空气边界 | 保留 | 工况层参数 |
| 压缩机入口混合器 | `CompressorInletMixer` | `V0` | 0.1 L | A6/A8 平台接口 | 对稳态影响小，提供 cEGR 混合库存 | 仅占位 | 后续动态复核 |
| 压缩机入口混合器 | `CompressorInletMixer` | `is_cond` | `[0;0;0;1]` | A8 水管理 | 混合冷凝位置合理 | 保留 | 水管理升级 |
| 空压机 | `Oxygen Source/Compressor` | 端口面积 | 0.001963 m2 | S0 官方 | 与 50 mm 阴极管一致 | 保留 | 暂不调整 |
| 空压机 map | `Oxygen Source/Compressor Map` | `comp_mdot_corr_TLU` | max 0.4 kg/s | S0 官方 | 名义空气需求 0.056 kg/s，裕度 7.14x | 保留 | A9 可设效率/map profile |
| 空压机 map | `Oxygen Source/Compressor Map` | `comp_p_ratio_TLU` | 1-2 | S0 官方 | 覆盖常规 PEMFC 阴极压力 | 保留 | 压力链仿真验证 |
| 出口容腔 | `Oxygen Source/Compressor Volume` | `V0` | 0.3 L | S0 官方 | 提供压缩机出口库存 | 保留 | 动态不作产品级解释 |
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `mdot_nominal` | 0.1 kg/s | A8 L2 | 覆盖高功率包络 0.0961 kg/s | 保留 | 保留 L2 接口 |
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `delta_p_nominal` | 0.001 MPa @ 0.1 kg/s | A8 L2 | 名义估算 0.314 kPa，高包络约 0.924 kPa | 保留 | 后续换热器标定 |
| 阴极加湿器 | `Cathode Humidifier/Pipe (FC)` | `Dh`, `length` | 0.05 m, 0.25 m | S0/A8 接口 | 与阴极 50 mm 管同径，压降温和 | 保留 | A11 水热升级 |
| 阴极加湿器旁路 | `CathodeHumidifierBypass` | `routeA_cathode_humidifier_enabled` | true | A8 配置 | 默认平台保留加湿能力 | 保留 | A10 旁路配置 |

供氧结论：

- 对 50 kW 平台，空压机流量能力明显充足，利于数值稳定和工况扫描。
- 当前空压机不应解释为真实 50 kW 产品空压机，尤其效率、喘振和转速动态没有被严格标定。
- 中冷/后冷 L2 接口的名义流量 0.1 kg/s 正好覆盖高功率包络，是 A8 中匹配度较好的新增参数。

## 6. 冷却与热管理

| 设备/结构件 | Simulink 模块 | 关键参数 | 当前值 | 来源层级 | 匹配计算 | 标签 | A9 去向 |
|---|---|---|---:|---|---|---|---|
| 冷却通道 | `Cooling System/Fuel Cell Coolant Channels` | `coolant_w_channels` | 1 cm | S0 官方 | 与电堆几何同源 | 保留 | 暂不缩放 |
| 冷却通道 | `Cooling System/Fuel Cell Coolant Channels` | `coolant_num_layers` | 20 | S0 官方 | 与 400 片堆热管理量级匹配 | 保留 | 后续热仿真验证 |
| 冷却通道 | `Cooling System/Fuel Cell Coolant Channels` | `coolant_num_passes` | 12 | S0 官方 | 提供通道长度/压降量级 | 保留 | 暂不调整 |
| 冷却泵 | `Cooling System/Pump` | `coolant_tube_D` | 0.05 m | S0 官方 | 与阴极/冷却主流道同径 | 保留 | 后续流量控制 |
| 冷却管路阻力 | `Cooling System/Flow Resistance (TL)` | `mdot_nominal` | 0.1 kg/s | S0 官方 | 对 40-60 kW 热负荷偏保守，需仿真确认 | 证据不足 | A9 热管理重点 |
| 散热器 | `Cooling System/Radiator` | `radiator_L/W/H` | 1 / 0.025 / 0.5 m | S0 官方 | 几何量级适中 | 保留 | 后续热稳态校核 |
| 散热器 | `Cooling System/Radiator` | `radiator_N_tubes` | 25 | S0 官方 | 与散热面积计算闭合 | 保留 | 暂不调整 |
| 换热边界 | `Cooling System/Convective Heat Transfer` | 有效面积 | 约 9.3169 m2 | S0 官方计算 | 对 34-42 kW 名义热负荷需仿真确认 | 保留 | 后续稳态温度闭环 |
| 温度边界 | `Cooling System/Stack Temperature` | `Constant` | 80 degC | S0 官方 | 典型 PEMFC 工作温度 | 保留 | 工况层参数 |

冷却结论：

- 散热器几何和有效面积来自官方示例，适合作为通用平台基线。
- `coolant_mdot_nominal=0.1 kg/s` 可能偏低或只是局部阻力基准，不能单独当作真实冷却流量能力。
- 后续必须用稳态温度收敛和热负荷平衡检查冷却链，而不是只看几何参数。

## 7. CEGR、阴极出口和水管理接口

| 设备/结构件 | Simulink 模块 | 关键参数 | 当前值 | 来源层级 | 匹配计算 | 标签 | A9 去向 |
|---|---|---|---:|---|---|---|---|
| 阴极出口接口阻力 | `CathodeOutletResistance` | `mdot_nominal` | 0.1 kg/s | A8/S0 L2 | 覆盖高功率空气包络 0.0961 kg/s | 保留 | 保留 L2 接口 |
| 阴极出口接口阻力 | `CathodeOutletResistance` | `delta_p_nominal` | 0.001 MPa | A8/S0 L2 | 名义估算 0.314 kPa，高包络 0.924 kPa | 保留 | 后续压力链验证 |
| 阴极出口容腔 | `CathodeOutletChamber` | `V0` | 0.2 L | A6/A8 平台接口 | 出口三通库存，支撑 EGR/排气分流 | 保留 | 动态复核 |
| 阴极出口容腔 | `CathodeOutletChamber` | `is_cond` | `[0;0;0;1]` | A8 水管理 | 阴极出口冷凝位置合理 | 保留 | 水管理升级 |
| 阴极水分离接口 | `CathodeWaterSeparator_FC` | `mdot_nominal` | 0.05 kg/s | A8 L2 | 名义空气 0.056 kg/s 接近，略低；高包络超过 | 保留 | A9 复核为 0.1 kg/s 候选 |
| 阴极水分离接口 | `CathodeWaterSeparator_FC` | `delta_p_nominal` | 0.0005 MPa | A8 L2 | 名义估算 0.627 kPa，高包络 1.847 kPa | 保留 | 后续按压降目标调 |
| 阴极排气管 | `Cathode Exhaust/Pipe (FC)` | `Dh`, `length` | 0.05 m, 1 m | S0 官方 | 与阴极主管一致，流速合理 | 保留 | 车载/台架配置再分化 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_area_closed` | 1.96e-9 m2 | A6 smoke | 用于 no-EGR 近关断 | 保留 | 工况控制参数 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_area_low` | 9.82e-7 m2 | A6 smoke | 用于低 EGR smoke，不是产品阀门标定 | 仅占位 | A9 循环比标定 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_max_area` | 0.001571 m2 | A8 上限 | 约为 0.8 倍 50 mm 管面积，偏宽裕 | 建议调整 | 后续按目标 EGR 比收紧 |
| cEGR 管路 | `EGRPipe` | `Dh`, `length` | 0.05 m, 0.5 m | A6/A8 平台接口 | 与阴极主管同径，数值稳定 | 保留 | 布置 profile 可调 |
| cEGR 管路 | `EGRPipe` | `isCond`, `tau_c` | `[0;0;0;1]`, 1 s | A8 水管理 | 回流湿气可冷凝 | 保留 | 水管理升级 |
| 水量观察器 | `SeparatorOrCondensation` | `separator_l2_efficiency` | 0.5 | A8 KPI | 不改变物理网络，只估算 `routeA_m_water_sep` | 仅占位 | 主动排水模型前保留 |
| RH KPI | `routeA_RH_ca_in/out` | 信号 | 已补 | A8 KPI | 支撑自增湿/干涸/过湿审计 | 保留 | 后续验收必测 |

CEGR 结论：

- CEGR 设备链与用户当前拓扑规划一致：阴极出口容腔分出排气和 EGR，EGR 经水分离接口/阀/管路回到压缩机入口混合器。
- 低负载 CEGR 包络下，新鲜空气需求很小，空压机裕度极大；控制重点不是“供不上气”，而是氧浓度、回流湿度、冷凝和高电位抑制。
- `cegr_valve_area_low` 和 `cegr_valve_max_area` 目前只是让 smoke 工况和结构闭环成立。下一阶段要把目标循环比、压差、阀开度关系单独参数化。

## 8. 参数落地清单

| 子系统 | 当前可作为 50 kW 平台默认保留 | 当前仅 L2/占位 | 建议进入 A9 的参数 |
|---|---|---|---|
| 电化学 | `stack_num_cells`, `stack_area`, `stack_iL`, `stack_t_membrane`, `stack_io`, `stack_alpha` | 气道内水相变关闭 | 电压参数治理、可选高性能膜 profile |
| 供氢 | `tank_p`, `tank_V`, `tank_yH2`, 堆侧压力偏置 | 阳极加湿器、回流容腔、阳极水分离器主动排水 | `anode_tube_D`, 减压阀面积显式化、purge 策略 |
| 供氧 | 环境边界、空压机 map、阴极 50 mm 管、中冷 L2 名义流量 | 压缩机入口混合器动态、加湿器产品性能 | 空压机 map 缩放/效率、加湿器压降和 RH 动态 |
| 冷却 | 散热器几何、换热面积、80 degC 工作温度 | 冷却泵真实控制与流量能力 | 冷却流量、热稳态验收、散热器 UA |
| CEGR | 出口容腔、EGR 管路、冷凝位置、RH KPI | EGR 阀面积、水量观察器、水分离器主动移水 | 目标 EGR 比、阀开度-流量关系、液态水移除 |

## 9. 后续执行建议

1. 保留当前 `platform_default` 作为 50 kW 通用平台基线，不做立即参数改动。
2. 在 A9 前或 A9 初始阶段新增一个只读计算脚本或表格化规则，用同一组公式自动输出三档包络 KPI，避免每次手算。
3. A9 参数治理优先级：
   - 优先级 1：阳极管径/压力/回流/排氮统一审计。
   - 优先级 2：CEGR 阀面积与目标循环比关系。
   - 优先级 3：冷却流量、散热器 UA、热稳态收敛。
   - 优先级 4：空压机 map 缩放和效率边界。
   - 优先级 5：加湿器、水分离器、液态水传输升级。
4. 后续仿真验证应新增一个 `nominal_50kW_steady` 工况，和现有 `no_egr_closed_valve`、`low_egr_humidifier_on`、`low_egr_humidifier_bypass` 共同组成 A8/A9 验收入口。

## 10. 本轮不做事项

- 不修改 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`。
- 不修改 `PEMFuelCellSystemWithACustomLibraryParameters.m`。
- 不把小功率文献或 FCEV mapped 数据迁入默认参数。
- 不把 L2 水分离接口描述成主动液态水移除模型。
- 不把当前瞬态响应解释为真实设备动态性能。
