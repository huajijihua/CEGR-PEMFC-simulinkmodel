# Route A A8 参数来源证据库 v01

生成日期：2026-07-09  
对象模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`  
用途：支撑 A8 参数粗匹配，不用于实验拟合，不直接改写 `platform_default`。

## 1. 来源分级

| 等级 | 来源 | 用途 | 可信度 | 使用边界 |
|---|---|---|---|---|
| S0 | MathWorks Gas Mixture / Moist Air PEMFC 官方示例 | Route A 官方母版、电堆和 BoP 基线参数 | 高 | 可作为 `platform_default` 的默认依据 |
| S1 | MathWorks FCEV Reference Application / mapped fuel cell | 百千瓦级整车燃料电池参考 | 高 | 适合功率、热流、氢耗和控制接口量级，不直接覆盖 Route A 物理网络 |
| S2 | PEMFC 系统级建模与水热管理文献 | 水热、加湿、动态模型和系统设备链 | 中-高 | 用于范围和机制，不替代官方参数脚本 |
| S3 | cEGR / 阴极循环文献 | 循环比、氧浓度、自增湿、高电位抑制和 CEGR 设备语义 | 中-高 | 用于 cEGR 结构和控制边界，不作为完整 BoP 标定表 |
| S4 | 后续公开资料补强 | 缺口参数范围 | 中 | 必须单独标注，不能覆盖 S0-S3 |

## 2. S0 官方系统级 PEMFC 参数组

### 2.1 Gas Mixture 官方示例 / Route A 母版

来源文件：

- `00_支撑材料/MathWorks_Official_Examples_R2025b/01_GasMixture_PEMFuelCellSystemWithCustomLibrary/PEMFuelCellSystemWithACustomLibraryParameters.m`
- 当前 Route A 参数脚本：`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystemWithACustomLibraryParameters.m`

| 设备/结构件 | 参数 | 值 | 单位 | 说明 |
|---|---|---:|---|---|
| PEMFC 电堆 | `stack_num_cells` | 400 | 1 | 单电池片数 |
| PEMFC 电堆 | `stack_area` | 280 | `cm^2` | 单片有效面积 |
| PEMFC 电堆 | `stack_t_membrane` | 125 | `um` | 膜厚 |
| PEMFC 电堆 | `stack_t_gdl` | 250 | `um` | GDL 厚度 |
| PEMFC 电堆 | `stack_iL` | 1.4 | `A/cm^2` | 极限电流密度 |
| PEMFC 电堆 | `stack_io` | 1e-4 | `A/cm^2` | 交换电流密度 |
| PEMFC 电堆 | `stack_alpha` | 0.7 | 1 | 电荷转移系数 |
| PEMFC 电堆 | `stack_mea_rho` | 1800 | `kg/m^3` | MEA 等效密度；原脚本注释写成 `kg/s`，按物理语义应理解为密度 |
| PEMFC 电堆 | `stack_mea_cp` | 870 | `J/(kg*K)` | MEA 等效比热 |
| 阳极管路 | `anode_tube_D` | 0.01 | `m` | 阳极管径 |
| 阴极管路 | `cathode_tube_D` | 0.05 | `m` | 阴极管径 |
| 冷却链 | `coolant_tube_D` | 0.05 | `m` | 冷却管径 |
| 散热器 | `radiator_L/W/H` | 1 / 0.025 / 0.5 | `m` | 散热器几何量级 |
| 散热器 | `radiator_N_tubes` | 25 | 1 | 冷却管数 |
| 空压机 | `comp_p_ratio_TLU` | 1-2 | 1 | 压比表 |
| 空压机 | `comp_rpm_TLU` | 0 / 1800 / 3600 | `rpm` | 转速表 |
| 空压机 | `comp_mdot_corr_TLU` | max 0.4 | `kg/s` | 修正质量流量表上限 |

该参数组不是 10 kW 小堆，而是一个约 50-120 kW 可用区间的官方系统级示例。按 `j=0.7 A/cm^2`、`0.65 V/cell` 估算约 51 kW；按 FCEV mapped 表中的高电流点，约可到 118 kW 级。

### 2.2 Moist Air 官方示例

来源文件：

- `00_支撑材料/MathWorks_Official_Examples_R2025b/02_MoistAir_PEMFuelCellSystem/PEMFuelCellSystemParameters.m`

该示例使用与 S0 Gas Mixture 示例相同的核心电堆尺寸：`400 cells x 280 cm^2`，并补充 Moist Air 域下的膜水、水扩散、加湿和水热管理参数。当前 Route A 是 Gas Mixture 四物种路线，因此 Moist Air 示例优先作为“水热机制和 BoP 架构”参考，不直接照搬域参数。

## 3. S1 FCEV Reference Application 百千瓦级参考

来源文件：

- `00_支撑材料/MathWorks_Official_Examples_R2025b/03_FCEV_ReferenceApplication/FCEV/Plant/FuelCell.ssc`
- `00_支撑材料/MathWorks_Official_Examples_R2025b/03_FCEV_ReferenceApplication/FCEV/CalMappedFuelCell/FuelCellPerformanceData.xlsx`

`FuelCell.ssc` 默认电堆参数：

| 参数 | 值 | 单位 | 说明 |
|---|---:|---|---|
| `N_cell` | 400 | 1 | 单电池片数 |
| `area_cell` | 280 | `cm^2` | 单片面积 |
| `t_membrane` | 125 | `um` | 膜厚 |
| `t_gdl_A/C` | 250 | `um` | 阳极/阴极 GDL 厚度 |
| `io` | 8e-5 | `A/cm^2` | 交换电流密度 |
| `iL` | 1.4 | `A/cm^2` | 极限电流密度 |
| `alpha` | 0.5 | 1 | 电荷转移系数 |
| `D_H2O_gdl_A/C` | 0.07 | `cm^2/s` | GDL 水蒸气扩散量级 |
| `rho_membrane` | 2000 | `kg/m^3` | 干膜密度 |
| `M_membrane` | 1.1 | `kg/mol` | 干膜等效当量 |

`FuelCellPerformanceData.xlsx` 读回摘要：

| 项 | 最小值 | 最大值 | 单位 | 说明 |
|---|---:|---:|---|---|
| `CurrentCmd` | 0.21 | 389.50 | `A` | mapped fuel cell 电流命令 |
| `TempCmd` | 50 | 100 | `degC` | 温度命令 |
| `AuxPower` | 557 | 6826 | `W` | 辅机功率 |
| `HeatFlow` | 7 | 77117 | `W` | 热流；个别高功率点有 `NaN` |
| `Voltage` | 290.83 | 473.24 | `V` | 电堆电压 |
| `H2Flow` | 2.49e-8 | 0.001634 | `kg/s` | 氢耗 |
| `P_elec = I*V` | 0.10 | 117.87 | `kW` | 表内最大电功率约 118 kW |

结论：S1 是可靠的百千瓦级官方参考，但实际最大约 118 kW，不应硬称 150 kW 完整参数组。后续若要 150 kW profile，应按缩放规则从 S1 放大，并保留“派生”标记。

## 4. S2 PEMFC 系统级建模与水热管理文献

### 4.1 100 kW 动态系统建模论文

来源文件：

- `00_支撑材料/02_PEMFC系统级建模与仿真/波动运行条件下 PEMFC 系统动态特性的仿真.pdf`

可抽取证据：

| 项 | 值 | 单位 | 页码/位置 | 用途 |
|---|---:|---|---|---|
| 测试平台功率 | 100 | `kW` | p.2 | 百千瓦级系统参考 |
| MEA 有效面积 | 186 | `cm^2` | p.2 / p.8 Table 1 | 大功率堆单片面积对照 |
| 阴极化学计量比 | 2.0 | 1 | p.5 | 空气需求量级 |
| 阳极化学计量比 | 1.3 | 1 | p.5 | 氢气供应量级 |
| 膜厚 | 25 | `um` | p.8 Table 1 | 膜厚范围参考 |
| 阴极通道体积 | 5.088 | `cm^3` | p.8 Table 1 | 通道/歧管动态体积参考 |
| 阳极通道体积 | 2.387 | `cm^3` | p.8 Table 1 | 通道/歧管动态体积参考 |
| 冷凝速率 | 100 | `s^-1` | p.8 Table 1 | 水相变动态量级参考 |
| 蒸发速率 | 1 | `atm^-1*s^-1` | p.8 Table 1 | 水相变动态量级参考 |
| 系统设备链 | 空压机、加湿器、供排气歧管、背压阀 | - | p.5-p.8 | Route A 设备链合理性参考 |

该论文同时明确：为了降低计算量，部分流量响应被一阶滞后简化；局部堵塞、淹没及详细水管理不作为其动态模型重点。这与 Route A A8 的 L2/L3 之间定位一致。

### 4.2 系统级水热管理综述

来源文件：

- `00_支撑材料/02_PEMFC系统级建模与仿真/Areviewofphysics-basedlow-temperatureproton-exchangemembranefuel cell models for system-level water andthermalmanagementstudies.pdf`
- 中文同题文件：`基于物理学的低温质子交换膜燃料电池模型综述：用于系统级水与热管理研究.pdf`

可抽取证据：

| 设备链 | 文献描述 | 对 Route A 的意义 |
|---|---|---|
| 阴极空气供应 | compressor / blower、humidifier、back-pressure valve | Route A 阴极链需要保留空压机、加湿器、背压/出口阻力 |
| 阳极供氢 | hydrogen recirculation pump or ejector、water separator、purge valve | Route A 阳极侧需要显式水分离接口和回流/排氮语义 |
| 冷却系统 | cooling pump、three-way valve、radiators | Route A 冷却泵、冷却通道、散热器属于必要系统级设备 |
| 建模层级 | 0D/1D 系统模型适合控制和系统管理 | A8 粗匹配关注收敛和平顺性，不宣称高保真瞬态 |

### 4.3 加湿器热力学模型

来源文件：

- `00_支撑材料/02_PEMFC系统级建模与仿真/用于质子交换膜燃料电池湿度控制的膜式加湿器热力学模型.pdf`

可抽取证据：

| 项 | 文献含义 | 对 Route A 的意义 |
|---|---|---|
| 关键状态 | 压力、流量、温度、相对湿度 | A8 的 `routeA_RH_ca_in/out` 和预加湿器 p/T/y_i 信号是必要 KPI |
| 加湿目标 | 膜湿度接近 100%，避免干涸和淹没 | 加湿器旁路必须保留，而不能简单删除加湿能力 |
| 建模方式 | 两控制体积、膜传递、稳态和动态仿真 | A8 当前 pass-through/pipe 是接口占位，产品级加湿器应在后续升级 |

## 5. S3 cEGR / 阴极循环文献

### 5.1 2017 双循环实验 - 小功率成体系组

来源文件：

- `00_支撑材料/03_cEGR阴极循环技术研究/2017-聚合物电解质膜燃料电池双循环实验研究.pdf`

可抽取参数组：

| 项 | 值 | 单位 | 页码/位置 | 用途 |
|---|---:|---|---|---|
| 电堆额定量级 | 10 | `kW` | p.1 / p.8 | `small_15kW_reference` 的核心来源 |
| 单电池片数 | 50 | 1 | p.1 / p.8 | 小功率堆片数 |
| 单片面积 | 261 | `cm^2` | p.1 / p.8 | 小功率堆面积 |
| 测试台最大功率 | 20 | `kW` | p.3 Table 1 | 台架能力边界 |
| 测试台最大电压/电流 | 600 / 600 | `V/A` | p.3 Table 1 | 台架电接口上限 |
| 阳极最大流量 | 250 | `L/min` | p.3 Table 1 | 供氢台架能力 |
| 阴极最大流量 | 750 | `L/min` | p.3 Table 1 | 空气台架能力 |
| 阳极最大气体温度 | 85 | `degC` | p.3 Table 1 | 热边界 |
| 阴极最大气体温度 | 80 | `degC` | p.3 Table 1 | 热边界 |
| 阳极加湿 | Bubble humidifier, dew point control | - | p.3 Table 1 | 阳极加湿参考 |
| 阴极加湿 | Membrane humidifier, dew point control | - | p.3 Table 1 | 阴极加湿参考 |
| 低负载试验电流 | 31 | `A` | p.5 | 自增湿/电压钳制试验点 |
| 对应电流密度 | 119 | `mA/cm^2` | p.5 | 低负载工况 |
| 固定新鲜空气流量 | 110 -> 20 | `L/min` | p.5-p.6 | 阴极循环与降氧测试 |
| 阴极循环泵转速 | 0 -> 3000 | `r/min` | p.5-p.6 | 循环强度参考 |
| 入口氧浓度变化 | 18.2 -> 9.8 | `%` | p.6 | cEGR 降氧效果 |
| 入口 RH | up to 98 | `%` | p.8 | 自增湿效果 |
| 31 A 名义新鲜空气 SR | 4.25 -> 1.52 | 1 | p.6 | 低负载空气裕度/降氧边界 |

这是一套完整的小功率 cEGR 参考，但它属于外部文献案例，不是 Route A 默认参数真源。用于 small 组证据和 cEGR 语义，不直接套入当前 `platform_default`。

### 5.2 2020 阴极循环高电位限制与自加湿

来源文件：

- `00_支撑材料/03_cEGR阴极循环技术研究/2020-阴极循环对氢燃料电池系统高电位限制和自加湿的影响.pdf`

可抽取证据：

| 项 | 文献含义 | 对 Route A 的意义 |
|---|---|---|
| 总进气流量 | `W_to = W_fre + W_re` | cEGR 下空压机/阴极入口必须按新鲜气 + 回流气合成计算 |
| 相对湿度 | 循环湿尾气可提高入口湿度 | 直接 RH KPI 是必要验收项 |
| 控制策略 | 低负载时降低新鲜空气并提高循环比 | A8 粗匹配不能只看新鲜空气流量 |

### 5.3 2024 CEGR 快速冷启动/怠速概念分析

来源文件：

- `00_支撑材料/03_cEGR阴极循环技术研究/2024-阴极废气再循环降低聚合物电解质膜燃料电池系统空转功率并实现快速冷启动的概念分析.pdf`

可抽取证据：

| 项 | 文献含义 | 对 Route A 的意义 |
|---|---|---|
| CEGR 组件 | control valve、water separator、collection tank、diaphragm pump | A8 阴极水分离接口和 EGR 阀是必要设备位置 |
| 回流接入点 | 回流气可接入 fresh air path，上游接入可避免额外压缩机 | Route A 当前回流到压缩机入口混合器是合理概念路线 |
| 水管理风险 | 冷新鲜气与温湿尾气混合可能冷凝，需移除液态水以保护压缩机 | A8 水分离接口和冷凝 KPI 必须保留 |
| 循环比影响 | 低电流密度时需要较高循环比例才能降低氧化学计量比 | cEGR 阀面积/控制需要后续按目标 O2 stoich 校核 |

### 5.4 2024 阴极循环耐久性与控制

来源文件：

- `00_支撑材料/03_cEGR阴极循环技术研究/2024-长期耐久性 FCV 电力系统低负荷条件下 PEMFC 阴极循环及其优化控制研究.pdf`
- `00_支撑材料/03_cEGR阴极循环技术研究/2024-阴极循环策略对质子交换膜燃料电池内部极化和外部特性的影响分析.pdf`

可抽取证据：

| 项 | 文献含义 | 对 Route A 的意义 |
|---|---|---|
| 循环比定义 | 循环气质量流量与新鲜空气质量流量的比值，或回流量与尾气量的比值，文献口径需区分 | Route A 审计必须写清 `egr_mdot / fresh_mdot` 与 `egr_mdot / outlet_mdot` 两种口径 |
| 低负载高电位 | 循环比增加可降低单体电压并影响阻抗 | cEGR 用于低负载降氧/降电位，不是全功率提高输出 |
| 动态模型 | 阴极循环泵/空压机常用一阶惯性或数据驱动 map | A8 动态只作为平顺性检查，不能过度解读为真实设备动态 |
| 试验单体 | 25 `cm^2` MEA 单体 | 可用于机理边界，不适合作为系统级参数组 |

## 6. 候选参数组

### 6.1 `small_15kW_reference`

实际证据最完整的小功率组来自 2017 双循环实验，额定堆为 10 kW，测试台上限为 20 kW。因此第一版命名建议保留 `small_15kW_reference`，但在证据库中标注“10-20 kW evidence band”。

| 子系统 | 参数组 | 建议值/范围 | 来源 | 备注 |
|---|---|---:|---|---|
| 电堆 | 片数 | 50 | 2017 双循环实验 | 成体系小功率组 |
| 电堆 | 单片面积 | 261 `cm^2` | 2017 双循环实验 | 与 Route A 280 `cm^2` 接近 |
| 电堆 | 额定功率 | 10 `kW`，台架上限 20 `kW` | 2017 双循环实验 | 作为 10-20 kW 小组 |
| 电堆 | 低负载电流密度 | 54-119 `mA/cm^2` | 2017 双循环实验 | cEGR 低负载控制证据 |
| 阴极链 | 最大空气流量能力 | 750 `L/min` | 2017 双循环实验 | 台架供应能力，不是默认空压机 map |
| 阳极链 | 最大氢气流量能力 | 250 `L/min` | 2017 双循环实验 | 台架供应能力 |
| 加湿器 | 阳极/阴极加湿 | bubble / membrane humidifier | 2017 双循环实验 | 支撑可配置加湿器能力 |
| cEGR | 循环泵转速 | 0-3000 `r/min` | 2017 双循环实验 | 只作循环强度参考 |
| cEGR | 入口氧浓度 | 约 18.6 -> 7.2 `%` | 2017 双循环实验 | 低负载降氧边界 |
| cEGR | 入口 RH | 最高约 98 `%` | 2017 双循环实验 | 自增湿效果参考 |

### 6.2 `large_150kW_reference`

官方 FCEV 数据最大约 118 kW，动态系统论文为 100 kW 平台。第一版建议把大功率证据组命名为 `large_120kW_official_reference`，并保留“可缩放到 150 kW 的目标组”。

| 子系统 | 参数组 | 建议值/范围 | 来源 | 备注 |
|---|---|---:|---|---|
| 电堆 | 片数 | 400 | MathWorks S0/S1 | 与 Route A 当前一致 |
| 电堆 | 单片面积 | 280 `cm^2` | MathWorks S0/S1 | 与 Route A 当前一致 |
| 电堆 | 极限电流密度 | 1.4 `A/cm^2` | MathWorks S0/S1 | 当前模型上限 |
| 电堆 | mapped 最大电功率 | 约 118 `kW` | FCEV `FuelCellPerformanceData.xlsx` | 百千瓦级官方证据 |
| 电堆 | 100 kW 平台面积 | 186 `cm^2` | 2020 动态仿真论文 | 另一套百千瓦系统证据 |
| 阴极链 | 阴极化学计量比 | 2.0 | 2020 动态仿真论文 | 空气需求量级 |
| 阳极链 | 阳极化学计量比 | 1.3 | 2020 动态仿真论文 | 供氢量级 |
| 水热 | 热流范围 | up to 77 `kW` | FCEV mapped 表 | 与 100 kW 级堆热管理同量级 |
| 氢耗 | 最大 H2 flow | 0.001634 `kg/s` | FCEV mapped 表 | 与 118 kW 功率量级匹配 |
| cEGR | CEGR 设备 | valve、water separator、collection tank、pump | 2024 CEGR 概念分析 | 支撑 A8 设备链 |

## 7. 当前证据缺口

| 缺口 | 当前状态 | 处理建议 |
|---|---|---|
| 15 kW 完整 BoP 产品参数 | 本地文献有 10 kW 堆和 20 kW 台架能力，但没有完整空压机 map | 小功率组先做 10-20 kW 文献组，后续按缩放规则派生 |
| 150 kW 完整物理网络参数 | 官方 mapped 数据最大约 118 kW，非完整物理网络 BoP | 大功率组先用 100-120 kW 证据，150 kW 标为缩放目标 |
| cEGR 阀门/水分离器产品参数 | 文献强调设备语义和控制效果，缺少统一压降/几何表 | A8 保持 L2 接口，后续按目标循环比和压降审计 |
| 液态水传输/移除 | 文献支持重要性，当前 Route A 只做接口和 KPI | 后续水管理升级阶段再建两相/液态水流动 |
| 加湿器产品级参数 | 文献有热力学模型，但当前 Route A 只做旁路和管路接口 | A10/A11 或后续水热阶段升级 |
