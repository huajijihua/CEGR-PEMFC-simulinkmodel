# Route A A8 设备/结构件 - Simulink 模块 - 参数识别表 v01

生成日期：2026-07-09  
对象模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
参数来源：当前 Route A 模型工作区与模块 Mask 参数读回，默认层为 `platform_default`。  
口径说明：本文按“四层”识别，即 `子系统/功能域 -> 设备/结构件 -> Simulink 模块 -> 模块参数`。这里的“设备/结构件”不是功能域本身，例如“阴极空气供给”是子系统，“空压机”才是设备。

## 1. 边界与归类原则

- `CathodeOutletResistance` 不归入 PEMFC 电堆本体；它是阴极出口外接管路/接口阻力，用于把电堆阴极出口接入后续出口容腔、排气和 cEGR 支路。
- `SeparatorOrCondensation` 是观察器/KPI 估算模块，不是物理水分离器本体；当前实际设备位置由 `CathodeWaterSeparator_FC` 和 `AnodeWaterSeparator_FC` 两个 FC 域 L2 压降接口表达。
- 当前水分离接口是 L2 设备占位和压降接口，不主动移除液态水。水相变只在启用 H2O 可冷凝的 FC 容腔/管段中发生。
- 本表只列与 A8 设备链、粗匹配和后续参数审计有关的关键模块参数；不展开纯显示、线束、Scope、Goto/From、注释和 Simulink 布局参数。

## 2. 子系统/功能域总览

| 子系统/功能域 | 设备/结构件 | 当前状态 | 主要 Simulink 模块 |
|---|---|---:|---|
| PEMFC 电堆与电接口 | MEA 电化学本体 | 已建 | `Membrane Electrode Assembly` |
| PEMFC 电堆与电接口 | 阳极气道 | 已建 | `Anode Gas Channels` |
| PEMFC 电堆与电接口 | 阴极气道 | 已建 | `Cathode Gas Channels` |
| PEMFC 电堆与电接口 | 电负载/电接口 | 已建 | `Electrical Load` 内部电流源、电压测量、负载请求 |
| 阳极供氢与回流 | 氢气源/储氢瓶 | 已建 | `Hydrogen Source/Fuel Tank` |
| 阳极供氢与回流 | 减压阀/供氢调压 | 已建 | `Hydrogen Source/Pressure-Reducing Valve/Valve` |
| 阳极供氢与回流 | 供氢管路 | 已建 | `Hydrogen Source/Pipe (FC)` |
| 阳极供氢与回流 | 阳极加湿器 | 已建 | `Anode Humidifier/Pipe (FC)` |
| 阳极供氢与回流 | 阳极回流容腔 | 已建 | `Recirculation/Constant Volume Chamber (FC)` |
| 阳极供氢与回流 | 阳极水分离接口 | A8 已补 | `AnodeWaterSeparator_FC` |
| 阳极供氢与回流 | 阳极排气/排氮 | 已建 | `Anode Exhaust/Pipe (FC)`、排氮阀相关模块 |
| 阴极空气供给与压缩链 | 环境空气入口 | 已建 | `Oxygen Source` 边界源 |
| 阴极空气供给与压缩链 | 压缩机入口混合器 | A8 前已有 | `CompressorInletMixer` |
| 阴极空气供给与压缩链 | 空压机 | 已建 | `Oxygen Source/Compressor`、`Compressor Map` |
| 阴极空气供给与压缩链 | 空压机出口容腔 | 已建 | `Oxygen Source/Compressor Volume` |
| 阴极空气供给与压缩链 | 中冷/后冷 L2 接口 | A8 已补 | `Intercooler_L2_Interface` |
| 阴极空气供给与压缩链 | 阴极加湿器及旁路 | A8 已补 | `Cathode Humidifier/Pipe (FC)`、`CathodeHumidifierBypass` |
| 阴极出口、排气与 cEGR | 阴极出口接口阻力 | 已建 | `CathodeOutletResistance` |
| 阴极出口、排气与 cEGR | 阴极出口容腔/三通语义 | A8 前已有并强化 | `CathodeOutletChamber` |
| 阴极出口、排气与 cEGR | 阴极水分离接口 | A8 已补 | `CathodeWaterSeparator_FC` |
| 阴极出口、排气与 cEGR | 阴极排气/背压 | 已建 | `Cathode Exhaust/Pipe (FC)`、背压边界 |
| 阴极出口、排气与 cEGR | cEGR 阀 | 已建 | `EGRValveRestriction` |
| 阴极出口、排气与 cEGR | cEGR 管路 | 已建 | `EGRPipe` |
| 阴极出口、排气与 cEGR | 冷凝/分离水 KPI 观察器 | A8 已补 | `SeparatorOrCondensation` |
| 冷却与热管理 | 冷却泵 | 已建 | `Cooling System/Pump` |
| 冷却与热管理 | 电堆冷却通道 | 已建 | `Cooling System/Fuel Cell Coolant Channels` |
| 冷却与热管理 | 散热器 | 已建 | `Cooling System/Radiator` |
| 冷却与热管理 | 空气侧换热边界 | 已建 | `Cooling System/Convective Heat Transfer` |
| 测量、诊断与审计 | 压力、流量、RH、水分 KPI | A8 已补齐关键项 | 传感器、Converter、To Workspace、审计信号 |

## 3. 模块级参数明细

### 3.1 PEMFC 电堆与电接口

#### 3.1.1 MEA 电化学本体

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| MEA 电化学本体 | `Membrane Electrode Assembly` | `N_cell` | 1 | `400` | 单电池片数 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `area_cell` | `cm^2` | `280` | 单片有效反应面积 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `t_membrane` | `um` | `125` | 膜厚 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `io` | `A/cm^2` | `1e-4` | 交换电流密度参考值 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `iL` | `A/cm^2` | `1.4` | 极限电流密度 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `alpha` | 1 | `0.7` | 电荷转移系数 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `T_cond` | `K` | `353.15` | 电导/膜水模型参考温度 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `T_stack` | `K` | `353.15` | 初始/参考电堆温度 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `D_N2` | `cm^2/s` | `1e-5` | 氮气跨膜扩散量级 |
| MEA 电化学本体 | `Membrane Electrode Assembly` | `rtype` | 枚举 | `Tabulated1D` | 膜电阻模型类型 |

#### 3.1.2 阳极气道结构

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 阳极气道 | `Anode Gas Channels` | `V0` | 模块内部单位 | `53546.242` | 阳极气道控制体积表达式读回值 |
| 阳极气道 | `Anode Gas Channels` | `area_A/B/C` | 模块内部单位 | `3200` | A/B/C 端口流通面积表达式读回值 |
| 阳极气道 | `Anode Gas Channels` | `is_cond` | 1 | `[0;0;0;0]` | 当前气道内不启用物种冷凝 |
| 阳极气道 | `Anode Gas Channels` | `tau_c` | `s` | `1e-3` | 组分/相变松弛时间 |
| 阳极气道 | `Anode Gas Channels` | `p0` | `MPa` | `0.101325` | 初始压力 |
| 阳极气道 | `Anode Gas Channels` | `T0` | `degC` | `20` | 初始温度 |
| 阳极气道 | `Anode Gas Channels` | `y0` | 1 | `[0;0;1;0]` | 初始摩尔分数，物种顺序 `[N2;O2;H2;H2O]` |

#### 3.1.3 阴极气道结构

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 阴极气道 | `Cathode Gas Channels` | `V0` | 模块内部单位 | `53546.242` | 阴极气道控制体积表达式读回值 |
| 阴极气道 | `Cathode Gas Channels` | `area_A/B/C` | 模块内部单位 | `3200` | A/B/C 端口流通面积表达式读回值 |
| 阴极气道 | `Cathode Gas Channels` | `is_cond` | 1 | `[0;0;0;0]` | 当前气道内不启用物种冷凝 |
| 阴极气道 | `Cathode Gas Channels` | `tau_c` | `s` | `1e-3` | 组分/相变松弛时间 |
| 阴极气道 | `Cathode Gas Channels` | `p0` | `MPa` | `0.101325` | 初始压力 |
| 阴极气道 | `Cathode Gas Channels` | `T0` | `degC` | `20` | 初始温度 |
| 阴极气道 | `Cathode Gas Channels` | `y0` | 1 | `[0.77846;0.21;0;0.01154]` | 初始湿空气摩尔分数 |

#### 3.1.4 电负载/电接口

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 电负载/电接口 | `Electrical Load/Controlled Current Source` | - | - | - | 按功率请求驱动电流负载 |
| 电负载/电接口 | `Electrical Load/Voltage Sensor` | - | - | - | 测量电堆端电压 |
| 电负载/电接口 | `Electrical Load/Drive Cycle Power Demand` | - | - | 参数脚本装配 | 功率请求输入，不归入电堆物理本体 |

### 3.2 阳极供氢与回流

#### 3.2.1 氢气源/储氢瓶

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 氢气源/储氢瓶 | `Hydrogen Source/Fuel Tank` | `V0` | `l` | `120` | 储氢瓶等效容积 |
| 氢气源/储氢瓶 | `Hydrogen Source/Fuel Tank` | `p0` | `MPa` | `70` | 初始储氢压力 |
| 氢气源/储氢瓶 | `Hydrogen Source/Fuel Tank` | `T0` | `degC` | `20` | 初始温度 |
| 氢气源/储氢瓶 | `Hydrogen Source/Fuel Tank` | `yH2` | 1 | `0.9997` | 氢气纯度量级 |

#### 3.2.2 减压阀/供氢调压

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 减压阀/供氢调压 | `Hydrogen Source/Pressure-Reducing Valve/Valve` | `area` | `m^2` | `pi*D^2/4` | 阀口面积表达式，由局部 Mask 变量给定 |
| 减压阀/供氢调压 | `Hydrogen Source/Pressure-Reducing Valve/Stack Pressure` | `Constant` | `MPa` | `0.06` | 目标堆侧表压偏置 |
| 减压阀/供氢调压 | `Hydrogen Source/Pressure-Reducing Valve` | `env_p` | `MPa` | `0.101325` | 环境压力叠加参考 |

#### 3.2.3 供氢管路与阳极加湿器

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 供氢管路 | `Hydrogen Source/Pipe (FC)` | `area` | `m^2` | `7.8539816e-05` | 管路流通面积，来自 `anode_tube_D=0.01 m` |
| 供氢管路 | `Hydrogen Source/Pipe (FC)` | `p0` | `MPa` | `0.101325` | 初始压力 |
| 供氢管路 | `Hydrogen Source/Pipe (FC)` | `T0` | `degC` | `20` | 初始温度 |
| 阳极加湿器 | `Anode Humidifier/Pipe (FC)` | `area` | `m^2` | `0.0019634954` | 等效管路面积 |
| 阳极加湿器 | `Anode Humidifier/Pipe (FC)` | `Dh` | `m` | `0.05` | 等效水力直径 |
| 阳极加湿器 | `Anode Humidifier/Pipe (FC)` | `length` | `m` | `0.25` | 等效长度 |
| 阳极加湿器 | `Anode Humidifier/Pipe (FC)` | `isCond` | 1 | `[0;0;0;0]` | 当前不启用管内冷凝 |

#### 3.2.4 阳极回流与水分离接口

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 阳极回流容腔 | `Recirculation/Constant Volume Chamber (FC)` | `V0` | `m^3` | `0.05^3` | 阳极回流等效容腔 |
| 阳极回流容腔 | `Recirculation/Constant Volume Chamber (FC)` | `area_A` | `m^2` | `7.8539816e-05` | 阳极回流端口面积 |
| 阳极回流容腔 | `Recirculation/Constant Volume Chamber (FC)` | `is_cond` | 1 | `[0;0;0;0]` | 当前回流容腔不启用冷凝 |
| 阳极水分离接口 | `AnodeWaterSeparator_FC` | `area` | `m^2` | `7.8539816e-05` | 阳极水分离器 L2 接口流通面积 |
| 阳极水分离接口 | `AnodeWaterSeparator_FC` | `delta_p_nominal` | `MPa` | `0.0005` | 名义压降 |
| 阳极水分离接口 | `AnodeWaterSeparator_FC` | `mdot_nominal` | `kg/s` | `0.01` | 名义质量流量 |
| 阳极水分离接口 | `AnodeWaterSeparator_FC` | `laminar_fraction` | 1 | `0.001` | 层流过渡比例 |

#### 3.2.5 阳极排气/排氮

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 阳极排气/排氮 | `Anode Exhaust/Pipe (FC)` | `area` | `m^2` | `7.8539816e-05` | 阳极尾排管路面积 |
| 阳极排气/排氮 | `Anode Exhaust/Pipe (FC)` | `Dh` | `m` | `0.01` | 管路水力直径 |
| 阳极排气/排氮 | `Anode Exhaust/Pipe (FC)` | `length` | `m` | `1` | 等效管长 |
| 阳极排气/排氮 | `Anode Exhaust/Pipe (FC)` | `extra_length` | `m` | `0.1` | 附加局部损失等效长度 |
| 阳极排气/排氮 | `Anode Exhaust/Pipe (FC)` | `isCond` | 1 | `[0;0;0;0]` | 当前不启用尾排管内冷凝 |

### 3.3 阴极空气供给与压缩链

#### 3.3.1 环境空气入口与压缩机入口混合器

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 环境空气入口 | `Oxygen Source` 边界源 | `env_p` | `MPa` | `0.101325` | 环境压力 |
| 环境空气入口 | `Oxygen Source` 边界源 | `env_T` | `degC` | `20` | 环境温度 |
| 环境空气入口 | `Oxygen Source` 边界源 | `env_yO2` | 1 | `0.21` | 环境氧气摩尔分数 |
| 环境空气入口 | `Oxygen Source` 边界源 | `env_yH20` | 1 | `0.011543638` | 环境水蒸气摩尔分数 |
| 压缩机入口混合器 | `CompressorInletMixer` | `V0` | `l` | `0.1` | 新鲜空气与 cEGR 混合容腔 |
| 压缩机入口混合器 | `CompressorInletMixer` | `area_A/B/C` | `m^2` | `0.0019634954` | 端口流通面积 |
| 压缩机入口混合器 | `CompressorInletMixer` | `is_cond` | 1 | `[0;0;0;1]` | H2O 可冷凝 |
| 压缩机入口混合器 | `CompressorInletMixer` | `tau_c` | `s` | `1` | 冷凝松弛时间 |
| 压缩机入口混合器 | `CompressorInletMixer` | `p0` | `MPa` | `0.101325` | 初始压力 |

#### 3.3.2 空压机与出口容腔

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 空压机 | `Oxygen Source/Compressor` | `area_A` | `m^2` | `0.0019634954` | 空压机 FC 端口面积 |
| 空压机 | `Oxygen Source/Compressor Map` | `comp_p_ratio_TLU` | 1 | `[1;1.25;1.5;1.75;2]` | 压比查表轴 |
| 空压机 | `Oxygen Source/Compressor Map` | `comp_rpm_TLU` | `rpm` | `[0 1800 3600]` | 转速查表轴 |
| 空压机 | `Oxygen Source/Compressor Map` | `comp_mdot_corr_TLU` | `kg/s` | `5x3 map, max 0.4` | 修正质量流量图 |
| 空压机出口容腔 | `Oxygen Source/Compressor Volume` | `V0` | `l` | `0.3` | 压缩机出口等效容腔 |
| 空压机出口容腔 | `Oxygen Source/Compressor Volume` | `area_A` | `m^2` | `0.0019634954` | 出口端口面积 |
| 空压机出口容腔 | `Oxygen Source/Compressor Volume` | `is_cond` | 1 | `[0;0;0;0]` | 当前出口容腔不启用冷凝 |

#### 3.3.3 中冷/后冷 L2 接口

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `area` | `m^2` | `0.0019634954` | 等效流通面积 |
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `delta_p_nominal` | `MPa` | `0.001` | 名义压降 |
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `mdot_nominal` | `kg/s` | `0.1` | 名义质量流量 |
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `laminar_fraction` | 1 | `0.001` | 层流过渡比例 |
| 中冷/后冷 L2 接口 | `Intercooler_L2_Interface` | `Dh` | `m` | `0.05` | 经验等效水力直径 |

#### 3.3.4 阴极加湿器及旁路

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 阴极加湿器 | `Cathode Humidifier/Pipe (FC)` | `area` | `m^2` | `0.0019634954` | 加湿器主通道等效面积 |
| 阴极加湿器 | `Cathode Humidifier/Pipe (FC)` | `Dh` | `m` | `0.05` | 等效水力直径 |
| 阴极加湿器 | `Cathode Humidifier/Pipe (FC)` | `length` | `m` | `0.25` | 等效长度 |
| 阴极加湿器 | `Cathode Humidifier/Pipe (FC)` | `extra_length` | `m` | `0.1` | 附加局部损失等效长度 |
| 阴极加湿器 | `Cathode Humidifier/Pipe (FC)` | `isCond` | 1 | `[0;0;0;0]` | 当前不启用加湿器管内冷凝 |
| 阴极加湿器旁路 | `CathodeHumidifierBypass` | `routeA_cathode_humidifier_enabled` | bool | `true` | 默认启用加湿器路径 |
| 阴极加湿器旁路 | `CathodeHumidifierBypass/Gain` | `routeA_cathode_humidifier_gain` | 1 | `1` | 旁路/启用配置增益 |

### 3.4 阴极出口、排气与 cEGR

#### 3.4.1 阴极出口接口阻力与出口容腔

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 阴极出口接口阻力 | `CathodeOutletResistance` | `area` | `m^2` | `0.0019634954` | 阴极出口接口流通面积 |
| 阴极出口接口阻力 | `CathodeOutletResistance` | `delta_p_nominal` | `MPa` | `0.001` | 名义压降 |
| 阴极出口接口阻力 | `CathodeOutletResistance` | `mdot_nominal` | `kg/s` | `0.1` | 名义质量流量 |
| 阴极出口接口阻力 | `CathodeOutletResistance` | `laminar_fraction` | 1 | `0.001` | 层流过渡比例 |
| 阴极出口容腔 | `CathodeOutletChamber` | `V0` | `l` | `0.2` | 阴极出口混合/分流容腔 |
| 阴极出口容腔 | `CathodeOutletChamber` | `area_A/B/C` | `m^2` | `0.0019634954` | 出口三通端口面积 |
| 阴极出口容腔 | `CathodeOutletChamber` | `is_cond` | 1 | `[0;0;0;1]` | H2O 可冷凝 |
| 阴极出口容腔 | `CathodeOutletChamber` | `tau_c` | `s` | `1` | 冷凝松弛时间 |
| 阴极出口容腔 | `CathodeOutletChamber` | `p0` | `MPa` | `0.101325` | 初始压力 |

#### 3.4.2 阴极水分离接口、排气与背压

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 阴极水分离接口 | `CathodeWaterSeparator_FC` | `area` | `m^2` | `0.0019634954` | 阴极水分离器 L2 接口流通面积 |
| 阴极水分离接口 | `CathodeWaterSeparator_FC` | `delta_p_nominal` | `MPa` | `0.0005` | 名义压降 |
| 阴极水分离接口 | `CathodeWaterSeparator_FC` | `mdot_nominal` | `kg/s` | `0.05` | 名义质量流量 |
| 阴极水分离接口 | `CathodeWaterSeparator_FC` | `laminar_fraction` | 1 | `0.001` | 层流过渡比例 |
| 阴极排气/背压 | `Cathode Exhaust/Pipe (FC)` | `area` | `m^2` | `0.0019634954` | 排气管路面积 |
| 阴极排气/背压 | `Cathode Exhaust/Pipe (FC)` | `Dh` | `m` | `0.05` | 排气管路水力直径 |
| 阴极排气/背压 | `Cathode Exhaust/Pipe (FC)` | `length` | `m` | `1` | 等效管长 |
| 阴极排气/背压 | `Cathode Exhaust/Pipe (FC)` | `extra_length` | `m` | `0.1` | 附加局部损失等效长度 |
| 阴极排气/背压 | `Cathode Exhaust/Stack Pressure` | `Constant` | `MPa` | `0.06 + env_p` | 背压边界量级 |

#### 3.4.3 cEGR 阀与管路

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| cEGR 阀 | `EGRValveRestriction` | `area` | `m^2` | `0.0019634954` | 阀所在管路基准面积 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_area_closed` | `m^2` | `1.9634954e-09` | 关闭工况有效面积 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_area_low` | `m^2` | `9.817477e-07` | 低 EGR 工况有效面积 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_max_area` | `m^2` | `0.0015707963` | 阀最大有效面积 |
| cEGR 阀 | `EGRValveRestriction` | `cegr_valve_min_area` | `m^2` | `1e-10` | 数值下限面积 |
| cEGR 管路 | `EGRPipe` | `area` | `m^2` | `0.0019634954` | 回流管路面积 |
| cEGR 管路 | `EGRPipe` | `Dh` | `m` | `0.05` | 回流管路水力直径 |
| cEGR 管路 | `EGRPipe` | `length` | `m` | `0.5` | 回流管路等效长度 |
| cEGR 管路 | `EGRPipe` | `extra_length` | `m` | `0.1` | 附加局部损失等效长度 |
| cEGR 管路 | `EGRPipe` | `roughness` | `m` | `1.5e-05` | 管壁粗糙度 |
| cEGR 管路 | `EGRPipe` | `isCond` | 1 | `[0;0;0;1]` | H2O 可冷凝 |
| cEGR 管路 | `EGRPipe` | `tau_c` | `s` | `1` | 冷凝松弛时间 |

#### 3.4.4 冷凝/分离水 KPI 观察器

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 冷凝/分离水 KPI 观察器 | `SeparatorOrCondensation` | `separator_l2_efficiency` | 1 | `0.5` | L2 估算水分离效率 |
| 冷凝/分离水 KPI 观察器 | `SeparatorOrCondensation` | `routeA_m_water_sep` | `kg/s` | 信号输出 | 分离/冷凝水量 KPI |
| 冷凝/分离水 KPI 观察器 | `SeparatorOrCondensation` | `source` | 文本 | `l2_saturation_excess_estimator` | 估算来源语义 |

### 3.5 冷却与热管理

#### 3.5.1 冷却泵与冷却通道

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 冷却泵 | `Cooling System/Pump` | `area` | `m^2` | `0.0019634954` | 冷却泵管路端口面积 |
| 冷却泵 | `Cooling Pump Control/Transfer Fcn` | `Numerator` | - | `[1]` | 泵控制一阶环节分子 |
| 冷却泵 | `Cooling Pump Control/Transfer Fcn` | `Denominator` | - | `[2 1]` | 泵控制一阶环节分母 |
| 电堆冷却通道 | `Cooling System/Fuel Cell Coolant Channels` | `area` | `cm^2` | `20` | 冷却通道总流通面积表达式值 |
| 电堆冷却通道 | `Cooling System/Fuel Cell Coolant Channels` | `coolant_w_channels` | `cm` | `1` | 单通道宽度量级 |
| 电堆冷却通道 | `Cooling System/Fuel Cell Coolant Channels` | `coolant_num_layers` | 1 | `20` | 冷却层数 |
| 电堆冷却通道 | `Cooling System/Fuel Cell Coolant Channels` | `coolant_num_passes` | 1 | `12` | 冷却流道折返/通过次数 |
| 冷却管路阻力 | `Cooling System/Flow Resistance (TL)` | `mdot_nominal` | `kg/s` | `0.1` | 名义冷却液流量 |
| 冷却管路阻力 | `Cooling System/Flow Resistance (TL)` | `delta_p_nominal` | `MPa` | `0.001` | 名义压降 |

#### 3.5.2 散热器与换热边界

| 设备/结构件 | Simulink 模块 | 参数 | 单位 | 当前值 | 含义 |
|---|---|---|---:|---:|---|
| 散热器 | `Cooling System/Radiator` | `radiator_L` | `m` | `1` | 散热器管长 |
| 散热器 | `Cooling System/Radiator` | `radiator_W` | `m` | `0.025` | 散热器宽度量级 |
| 散热器 | `Cooling System/Radiator` | `radiator_H` | `m` | `0.5` | 散热器高度 |
| 散热器 | `Cooling System/Radiator` | `radiator_N_tubes` | 1 | `25` | 管数 |
| 空气侧换热边界 | `Cooling System/Convective Heat Transfer` | `radiator_air_area_primary` | `m^2` | `1.223125` | 主换热面积 |
| 空气侧换热边界 | `Cooling System/Convective Heat Transfer` | `radiator_air_area_fins` | `m^2` | `11.5625` | 翅片面积 |
| 空气侧换热边界 | `Cooling System/Convective Heat Transfer` | `effective area` | `m^2` | `9.316875` | 按 `primary + 0.7*fins` 估算的有效面积 |
| 电堆温度边界 | `Cooling System/Stack Temperature` | `Constant` | `degC` | `80` | 当前冷却控制参考温度 |

### 3.6 测量、诊断与审计信号

| 功能 | 信号/模块 | 单位 | 当前状态 | 含义 |
|---|---|---:|---|---|
| 阴极入口 RH | `routeA_RH_ca_in` | 1 | A8 已补 | 阴极入口/加湿器出口相对湿度 KPI |
| 阴极出口 RH | `routeA_RH_ca_out` | 1 | A8 已补 | 阴极出口相对湿度 KPI |
| 预加湿器压力 | `routeA_p_ca_pre_humidifier` | 按传感器输出 | A8 已补 | 中冷/后冷后、阴极加湿器前压力 |
| 预加湿器温度 | `routeA_T_ca_pre_humidifier` | 按传感器输出 | A8 已补 | 中冷/后冷后、阴极加湿器前温度 |
| 预加湿器组分 | `routeA_yi_ca_pre_humidifier` | 1 | A8 已补 | 中冷/后冷后组分向量 |
| 分离/冷凝水量 | `routeA_m_water_sep` | `kg/s` | A8 已补 | 当前由 L2 饱和过量估算器输出 |
| EGR 流量 | `EGRMassFlowSensor` / `routeA_egr_mdot` | `kg/s` | 已建 | cEGR 支路质量流量 |
| 排气流量 | `ExhaustMassFlowSensor` / `routeA_exhaust_mdot` | `kg/s` | 已建 | 阴极尾排质量流量 |

## 4. 当前水相变与液态水处理状态

| 位置 | H2O 可冷凝设置 | 当前作用 |
|---|---:|---|
| `CathodeOutletChamber` | `[0;0;0;1]` | 阴极出口容腔允许水蒸气按 FC 域能力冷凝 |
| `EGRPipe` | `[0;0;0;1]` | cEGR 回流管路允许水蒸气按 FC 域能力冷凝 |
| `CompressorInletMixer` | `[0;0;0;1]` | 压缩机入口混合容腔允许 H2O 冷凝 |
| `Anode Gas Channels` | `[0;0;0;0]` | 阳极气道当前不启用冷凝 |
| `Cathode Gas Channels` | `[0;0;0;0]` | 阴极气道当前不启用冷凝 |
| `AnodeWaterSeparator_FC` | Flow Resistance | 只表达阳极水分离器设备位置和压降，不主动移水 |
| `CathodeWaterSeparator_FC` | Flow Resistance | 只表达阴极水分离器设备位置和压降，不主动移水 |
| `SeparatorOrCondensation` | MATLAB Function/KPI | 估算 `routeA_m_water_sep`，不改变物理网络状态 |

结论：A8 当前已经把设备位置、接口和 KPI 闭环放进通用平台，但水相变、液态水携带、汇集、排放和两相传输仍是后续保真度升级内容，不应在 A8 粗匹配阶段过早产品化。

## 5. 后续粗匹配优先参数

| 优先级 | 设备/结构件 | 参数组 | 建议处理 |
|---:|---|---|---|
| 1 | MEA 与气道 | `N_cell`、`area_cell`、`t_membrane`、气道 `V0/area` | 固定功率等级和反应面积量级，作为所有 BoP 粗匹配基准 |
| 2 | 空压机 | map、名义流量、压比范围 | 检查是否覆盖名义空气需求和 EGR 混合压力链 |
| 3 | 阴极出口与 cEGR | 出口阻力、EGR 阀面积、EGR 管径/长度 | 保证无 EGR、低 EGR 工况均不反向且分流比有限 |
| 4 | 中冷/后冷接口 | `delta_p_nominal`、`mdot_nominal`、`area` | 先压降匹配，不做产品级换热器标定 |
| 5 | 加湿器/旁路 | 管路压降、启用开关、RH KPI | 支撑 A9 无加湿器台架和 A10 含加湿器车载变体 |
| 6 | 水分离接口 | 阴极/阳极 `area`、`delta_p_nominal`、`mdot_nominal` | 先匹配压降和接口位置，后续再升级液态水移除 |
| 7 | 冷却系统 | 泵、冷却通道、散热器有效面积 | 保持热边界量级自洽，后续再做热管理动态标定 |
