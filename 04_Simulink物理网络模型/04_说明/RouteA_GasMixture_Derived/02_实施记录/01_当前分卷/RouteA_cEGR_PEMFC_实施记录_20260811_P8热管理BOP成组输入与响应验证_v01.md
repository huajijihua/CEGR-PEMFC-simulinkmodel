# Route A cEGR-PEMFC P8 热管理 BOP 成组输入与响应验证

## 1. 实施范围

- 路线：Route A 官方 Gas Mixture PEMFC 派生平台。
- 模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`。
- 保持不变：passive cEGR、cold-start、L2 水管理和现有物理拓扑。
- 本次新增能力：冷却通道几何、散热器核心几何及散热器热容量的成组设备输入。
- 模型文件未做结构修改，MATLAB 读回 `Dirty=off`。

## 2. 真实模型引用与契约

### 2.1 冷却通道几何

| simCase 字段 | 单位 | 模型引用 | 物理含义 | 默认/候选范围 |
|---|---:|---|---|---:|
| `controls.devices.thermal.coolantGeometry.channelWidth_cm` | cm | `coolant_w_channels` | 方形冷却通道宽度，同时作为水力直径 | 1 / 0.2--2 |
| `...numLayers` | - | `coolant_num_layers` | 堆内冷却层数 | 20 / 1--100，整数 |
| `...numPasses` | - | `coolant_num_passes` | 每层冷却通道走向数 | 12 / 1--50，整数 |
| `...tubeDiameter_m` | m | `coolant_tube_D` | 泵和流阻支路的冷却管径 | 0.05 / 0.01--0.10 |

派生关系沿用官方模型：`channelLength_cm = sqrt(stack.area_cm2)*numPasses`，`channelArea_cm2 = channelWidth_cm^2*numLayers`，`channelDh_cm = channelWidth_cm`，泵/流阻面积为 `pi*tubeDiameter_m^2/4`。长度和通道面积由模型块表达式直接使用，不作为冗余工作区写入量。

### 2.2 散热器核心与热容量

| simCase 字段 | 单位 | 模型引用/派生写入 | 物理含义 | 默认/候选范围 |
|---|---:|---|---|---:|
| `controls.devices.thermal.radiatorCore.length_m` | m | `radiator_L` | 散热器管流动长度 | 1 / 0.2--2 |
| `...width_m` | m | `radiator_W` | 管宽度 | 0.025 / 0.005--0.10 |
| `...height_m` | m | 派生 `radiator_air_area_primary`、`radiator_air_area_fins`、`radiator_tube_Leq` | 核心总高度 | 0.5 / 0.10--1.0 |
| `...tubeCount` | - | `radiator_N_tubes` | 冷却管数量 | 25 / 2--100，整数 |
| `...tubeHeight_m` | m | `radiator_tube_H` | 单管高度 | 0.0015 / 5e-4--1e-2 |
| `...finSpacing_m` | m | 派生 `radiator_air_area_fins` | 翅片间距 | 0.002 / 5e-4--1e-2 |
| `...finEfficiency` | - | `radiator_eta_fin` | 翅片有效换热效率 | 0.7 / 0.3--1 |
| `...wallThickness_m` | m | `radiator_t_wall` | 散热器壁厚 | 1e-4 / 1e-5--1e-3 |
| `...density_kg_m3` | kg/m^3 | `radiator_rho` | 散热器材料密度 | 2700 / 500--5000 |
| `...specificHeat_J_kgK` | J/(kg*K) | `radiator_cp` | 散热器材料比热 | 910 / 300--1500 |

官方派生式为：

- `gap_H = (H - N_tubes*tube_H)/(N_tubes-1)`，并要求 `gap_H > 0`；
- `primaryArea = 2*(N_tubes-1)*W*(L+gap_H)`；
- `N_fins = (N_tubes-1)*L/finSpacing`；
- `finArea = 2*N_fins*W*gap_H`；
- `tube_Leq = 2*(H + 20*tube_H*N_tubes)`；
- 对流块使用 `primaryArea + eta_fin*finArea`；热容块使用 `(primaryArea+finArea)*wallThickness*density` 与 `specificHeat`。

`radiator_H`、`radiator_N_fins`、`radiator_fin_spacing`、`radiator_gap_H` 等未被当前模型直接引用的工作区叶子未作为独立 SimulationInput 写入目标；它们只通过成组输入参与实际引用量派生。

## 3. 实现位置

- 默认层：`routeA_platform_default_parameters.m` 增加冷却通道宽度和散热器几何/材料字段。
- simCase：`routeA_simCase_template.m` 增加 `controls.devices.thermal.coolantGeometry` 与 `radiatorCore`。
- 校验：`routeA_validate_case.m`、`routeA_prepare_electrical_boundary_input.m` 增加范围、整数、核心高度约束和派生关系校验。
- SimulationInput：`setDevicePerformanceVariables` 写入 4 个冷却真实引用量、8 个散热器真实标量及 4 个散热器派生引用量；未改物理连接。
- 前端：`RouteA_Panel_v01.m` 在设备页增加两个成组区块，恢复默认、同步、禁用和 `captureDeviceControls` 均为原子成组处理。
- 能力矩阵/目录：`routeA_p1_panel_capability_matrix.m` 和 `routeA_parameter_registry.m` 增加 14 个热管理面板字段及其模型映射说明。

## 4. 契约测试

入口：`run_routeA_p1_panel_contract_tests.m`。

实测结果：`passed=1`，`modelPanelAuditPassed=1`，模型工作区目录计数 `138`。测试覆盖：

- 面板字段到 `simCase.controls.devices.thermal` 的读回；
- 非法散热器核心几何（高度不足）和非法冷却层数拒绝；
- 散热器派生面积/等效长度进入 `SimulationInput`；
- 设备默认恢复不改变电边界命令；
- 原有电边界、空气控制、cEGR、压缩机图谱和分离器契约回归。

## 5. 短动态热响应验证

正式 runner：`run_routeA_p8_thermal_bop_validation.m`。工况为 Current `100 A`、cold-start、passive cEGR disabled、20 s、5 s ramp；每个工况独立调用同一 `SimulationInput` 装配链并读取 `logsout` 和 `simlog_PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.Thermal_Management_BOP.Cooling_System`。

四个工况均 `simCompleted=1`、`finiteSignals=1`：

| 工况 | 真实写入读回 | 关键结果 |
|---|---|---|
| baseline | `A_primary=1.22313 m^2`，`A_fin=11.5625 m^2`，`Leq=2.5 m`，热质量 `3.45212 kg` | 堆温尾均值 `22.4444 degC`，冷却侧压降尾均值 `1.03831e-15 MPa` |
| radiator_area_up | `A_primary=1.59063 m^2`，`A_fin=22.1181 m^2`，`Leq=2.8 m` | 堆温尾均值变化 `-0.2026 degC`，方向与增强换热一致 |
| thermal_mass_up | 热质量 `5.17818 kg` | 堆温尾段升温斜率相对基线变化 `-8.4349e-4 degC/s`，体现热惯性方向 |
| coolant_diameter_up | `coolant_tube_D=0.07 m` | 冷却通道压力损失变化 `-2.9187e-17 MPa`；该低流量短窗下接近零，保留为待高流量/长时标定项 |

Simscape 直接读回的字段包括散热器管内温度、热流、质量流量、压降，堆内冷却通道温度、质量流量、压降，泵流量，热质量温度和对流热流。当前结果用于“输入写入 + 独立热响应存在性/方向性”验证，不把短窗结果升级为稳态标定或产品级性能声明。

## 6. 未解决风险

1. 当前短动态热管理流量非常低，冷却管径对压降的灵敏度接近数值零；需要后续高负载或延长研究时长验证压降方向。
2. 面板字段范围是平台候选筛选范围，不是产品设计包络，也未替代几何、材料或风扇标定。
3. 观测注册表中的冷却侧响应仍保持“待确认”语义；本次直接 Simscape 读回已形成证据，但尚未将其纳入通用面板结果契约。
