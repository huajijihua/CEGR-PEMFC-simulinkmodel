# Simulink/Simscape PEMFC-cEGR 通用模型规格与实施路线 v01

日期：2026-07-06  
阶段：通用模型规格、接口契约、实施路线。  
范围：本阶段仍只做规划与文档固化；不生成或修改 `.slx`；不运行仿真。

本文件回答“我们要建成什么模型、有哪些边界、接口如何定义、先后如何实施”。材料来源、候选模型和组件取舍见 [Simulink_PEMFC_cEGR_材料池与模型候选比较_v01.md](E:/agentwork_pemfc_cEGR_0519/Simulink_PEMFC_cEGR_材料池与模型候选比较_v01.md)。

## 1. 建模目标与边界

状态：方向已调整为通用 PEMFC-cEGR 系统模型体系优先；10 kW 台架数据降级为实例化、smoke test 和物质流 sanity check 资料。

| 项目 | 已确认内容 | 建模含义 |
|---|---|---|
| 第一版目标 | 以稳态性能评估和结构跑通为主；动态控制工况暂不作为目标 | 模型仍保留 Simscape 物理状态，但不以快速动态控制为验收核心 |
| 研究对象 | 阴极 cEGR 对 O2 浓度、湿度、压力、电压的影响 | 必须显式建阴极物种、湿度、压力和电堆电压耦合 |
| 建模优先级 | 优先建立系统级设备模型和方法论；性能评估与策略开发在模型成立后推进 | 第一阶段不以数据拟合或误差表为目标 |
| 物理网络状态 | 容腔压力、温度、物种库存等状态正是本模型区别于简化经验模型的核心 | 不为简化稳态而删除容腔和物种库存；稳态只是运行工况与验收方式 |
| 控制策略 | 暂不优化控制器，但保留控制接口 | EGR 阀、背压阀、入口边界、电流负载等应有命令输入或可替换接口 |
| 新鲜空气入口 | Core Model 支持边界源和增压设备两种配置 | Bench Configuration 可先用流量/温度/压力/湿度边界源；Vehicle Configuration 后续接空压机 |
| 加湿器 | Core Model 预留接口 | Bench Configuration 不纳入；Vehicle Configuration 可加入车载膜加湿器 |
| 氢气侧 | Core Model 保持可扩展阳极结构；第一配置可用最小供氢边界 | 不让阳极复杂度阻塞 cathode-cEGR 主链路 |
| 冷却侧 | Core Model 必须有热端口与冷却接口 | 第一配置可用简化热边界；后续扩展液冷网络 |
| 数据定位 | 10 kW 台架数据只用于 smoke test、物质流 sanity check 和演示工况 | 模型体系必须可扩展到大功率电堆和车载结构，不被 10 kW 尺寸绑定 |

## 2. 模型路线分层

| 层级 | 作用 | 建模内容 | 数据角色 |
|---|---|---|---|
| `Core Model` | 通用 PEMFC-cEGR 物理网络 | `FuelCell` 四物种域、MEA、阴极入口/出口容腔、EGR 阀、背压阀、管路、冷凝/分离、热端口、电端口、传感器、控制接口 | 不依赖 10 kW 数据；参数可来自官方示例、文献和工程默认 |
| `Bench Configuration` | 10 kW 台架实例 | 入口边界源、DQ60 等效增压设备可选、无加湿器、最小供氢边界、简化冷却边界 | 只用于 smoke test、边界示例和物质流检查 |
| `Vehicle Configuration` | 车载系统扩展 | 空压机、中冷器、加湿器、完整冷却回路、控制器、大功率电堆、整车功率接口 | 需要后续供应商/文献/实验数据支撑 |
| `Scaling Rules` | 功率等级迁移 | `N_cell`、`area_cell`、流道体积、阀面积、气源能力、冷却容量、热容量、传感器量程参数化 | 不用 10 kW 数据外推为通用规律 |

## 3. Core Model 推荐系统边界

```text
CathodeSupplyBoundary_or_Compressor(mdot/p, T, humidity)
  -> CathodeInletMixer / InletChamber
  -> CathodeGasChannel / MEA cathode port
  -> CathodeOutletChamber
  -> CondensationOrSeparator
  -> EGRValve
  -> CathodeInletMixer / InletChamber
  -> BackPressureValve
  -> ExhaustBoundary(p_out)

HydrogenBoundary
  -> AnodeGasChannel / MEA anode port
  -> AnodeExhaustBoundary

MEA
  -> ControlledElectricalLoad(i_cmd)
  -> ThermalPort / SimplifiedCoolingBoundary
```

关键原则：

1. 阴极 cEGR 支路必须是物理网络，不用 MATLAB Function 做信号加权混合替代。
2. 气体域优先统一使用 `FuelCell` 四物种域：N2/O2/H2/H2O。
3. 入口边界源是 Bench Configuration 的实例化方式，不是 Core Model 的上限。
4. 阀门和背压边界是 cEGR 策略接口，不应简化成固定 EGR 率常数。

## 4. 初版接口契约

| 接口类型 | 名称 | 单位 | 来源/说明 | 第一版处理 |
|---|---|---:|---|---|
| 输入 | `i_cmd` | A | 电堆负载命令 | 受控电流负载；后续可扩展功率请求 |
| 输入 | `air_mdot_in` | kg/s | 阴极供气流量边界 | Bench Configuration 使用边界源；Vehicle Configuration 可由空压机输出 |
| 输入 | `air_T_in` | K | 阴极供气温度 | 入口源/入口容腔温度 |
| 输入 | `air_p_in` | Pa | 阴极供气压力 | 入口压力边界或增压设备出口 |
| 输入 | `air_humidity_in` | kg/kg 或质量分数 | 阴极供气水分 | 模型内部优先使用质量变量，展示时输出 RH |
| 输入 | `egr_valve_cmd` | 1 或 % | EGR 阀开度/控制量 | 可变局部阻力或受控阀面积 |
| 输入 | `egr_valve_input` | 1 或 % | Bench Configuration 中实验记录的阀输入值 | 台架实例可映射到等效开口面积/流量系数 |
| 输入 | `bp_valve_cmd` | 1 或 % | 背压阀开度，如有 | 可变局部阻力 |
| 输入 | `p_exhaust` | Pa 或 kPa | 出口压力边界 | 背压/环境边界核心参数 |
| 输入 | `coolant_T` | K 或 degC | 冷却边界 | 简化热边界 |
| 输入 | `coolant_mdot` | kg/s | 冷却流量边界 | 可选；第一版可先简化 |
| 输出 | `V_stack` | V | 电堆电压 | 必须输出 |
| 输出 | `P_stack` | W | 电功率 | 必须输出 |
| 输出 | `xO2_ca_in/out` | 1 | 阴极入口/出口氧组分 | 必须输出 |
| 输出 | `xH2O_ca_in/out` | 1 | 阴极入口/出口水蒸气组分 | 必须输出 |
| 输出 | `RH_ca_in/out` | 1 或 % | 阴极入口/出口湿度 | 必须输出 |
| 输出 | `p_ca_in/out` | Pa | 阴极入口/出口压力 | 必须输出 |
| 输出 | `T_ca_in/out` | K | 阴极入口/出口温度 | 必须输出 |
| 输出 | `egr_mdot` | kg/s | EGR 支路回流质量流量 | 必须输出 |
| 输出 | `egr_ratio` | 1 或 % | 定义为 EGR 质量流量 / 阴极总入口质量流量 | 必须输出 |
| 输出 | `m_condensed` / `m_water_sep` | kg/s | 冷凝/分离水 | 若模块具备则输出 |
| 输出 | `Q_stack` | W | 电堆热流 | 建议输出 |

## 5. 设备规格初稿

| 设备 | 推荐实现 | 需要参数 | 待确认问题 |
|---|---|---|---|
| MEA/电堆 | `FuelCell_lib/elements/Membrane Electrode Assembly` | 电池片数、活性面积、膜厚、交换电流、极限电流、膜电导模型、热容量 | 先用官方示例/文献/工程默认跑通，再按目标功率等级实例化 |
| 阴极入口混合容腔 | `Constant Volume Chamber (FC)` | 容积、初始 p/T/物种、热边界 | 入口歧管/混合容积是否有几何或估算值 |
| 阴极通道 | MEA 阴极端口 + `Cathode Gas Channels` 结构 | 通道体积、流阻、初始状态 | 是否沿用官方示例集总通道，还是加入入口/出口独立容腔 |
| EGR 阀 | 优先 `Local Restriction (FC)`，必要时封装为命令到有效面积的参数化子系统 | 最大开口面积、流量系数、开度-面积关系、临界流参数 | Bench Configuration 可用目标开度/输入值/EGR 率做 sanity check，不决定通用阀模型 |
| 背压阀 | `Local Restriction (FC)` + `Reservoir (FC)` | 出口压力、阀开度、流量系数 | Bench Configuration 可先给定出口压力；后续再引入阀门细节 |
| 水分离/冷凝 | 先用 Pipe/Chamber 冷凝能力或等效冷凝排水模块 | 冷凝效率、压降、温度边界、排水逻辑 | 是否能找到四物种域可复用 separator；若无则自定义简化块 |
| 阴极供气源 | `Mass Flow Rate Source (FC)`、`Pressure Source (FC)` 或压缩/增压设备 | 流量、p/T/含湿量、O2/N2/H2O 组分 | Core Model 保留两种配置；Bench v01 可先用边界源 |
| 氢气源 | 简化 H2 source + anode exhaust | H2 压力/流量/温度、阳极出口边界 | 不研究阳极循环，避免引入氢泵/喷射器复杂性 |
| 冷却边界 | 热端口 + 热质量/温度源/简化热交换 | 冷却温度、流量、等效换热 | 是否需要液冷网络，第一版可先用等效热边界 |

## 6. 阀门模型候选与取舍

阀门建模不需要从纯经验函数开始。候选如下：

| 候选 | 域 | 证据 | 适用性 | 取舍 |
|---|---|---|---|---|
| `FuelCell_lib/elements/Local Restriction (FC)` | `FuelCell` 四物种域 | 本机 `D:\matlab2025b\toolbox\physmod\fluids\supporting_files\example_libraries\+FuelCell\+elements\LocalRestriction.ssc`；支持固定/受控 restriction area、`Cd`、最小/最大面积、choked flow 平滑 | 最匹配主气体域，可直接用于 EGR 阀、背压阀、排气阀 | 第一优先 |
| Gas Mixture PEMFC 示例中的 `Pressure Relief Valve` 子系统 | `FuelCell` 四物种域 | `PEMFuelCellSystemWithACustomLibrary/Cathode Exhaust/Pressure Relief Valve`；由 `Local Restriction (FC)` 和压力目标逻辑组成 | 适合背压阀/泄压阀结构参考 | 作为背压阀参考 |
| Foundation `Local Restriction (G)` | Foundation Gas | 官方文档说明可表示阀/孔口、受控面积和 choking | 域不一致，除非通过接口块切换到 Foundation Gas | 只做方程/参数参考 |
| Foundation `Local Restriction (MA)` / Orifice (MA) | Moist Air | 官方文档说明可表示湿空气阀/孔口和 choking | 与主 FuelCell 四物种域不一致 | 不作为主模型阀门 |
| File Exchange `GasN/LocalRestriction.ssc` | `GasN` 四物种域 | 项目内源码说明可表示阀/孔口、固定/可变面积、choked flow | 与 `FuelCell` 域相似，但需切换域或重写接口 | 作为源码交叉参考 |

阀门建模建议：

1. `egr_valve_cmd` 不直接等于面积，先通过参数化映射得到 `A_eff` 或 `CdA_eff`。
2. 目前实验记录中可用的“目标开度 6%、输入值 61%、EGR 率 14.7%”这类点，只用于 Bench Configuration 的 sanity check，不能当成全域阀门 map。
3. 若没有阀前后压力，则 EGR 阀标定会和背压边界、管路阻力耦合；第一版应把该不确定性显式保留。
4. 后续策略模型可以把 `egr_valve_cmd -> A_eff -> mdot_egr -> egr_ratio` 作为控制链，不直接把 EGR 率当输入。

## 7. Bench Configuration 资料定位

10 kW 台架资料保留为第一个配置场景的资料池，不作为 Core Model 的架构依据。本轮只读确认的数据目录为：

`E:\agentwork_pemfc_cEGR_0519\00_支撑材料\实验数据-设备说明书`

可用材料类型和用途：

- 稳态测试数据：仅用于 Bench Configuration 的 smoke test、物质流 sanity check 和演示工况。
- 电堆与推荐工况：仅用于 10 kW 实例化，不作为通用模型参数上限。
- 设备/图片/PDF：用于解释台架特殊设备和边界条件。
- 加湿器资料：位于 `加湿器数据/`，台架 v01 暂不使用，仅作为车载扩展资料。

需要注意：`DQ60氢气循环泵MAP图` 是实验中受设备限制被用作空压机替代的设备资料，其功能层面仍对应做功、升温、增压。建模时可以作为“压缩/增压设备”等效参考，但需要标明它并非标准阴极空压机 map，参数外推到车载空压机时不应直接使用。

## 8. 台架实例化注意事项

| 优先级 | 注意事项 | 处理原则 |
|---:|---|---|
| 高 | EGR 阀目标开度、输入值、EGR 率样本只能说明台架实例 | 可用于 sanity check 或临时 `CdA` 映射，不反向定义通用阀门模型 |
| 高 | 背压阀没有开度记录 | Bench Configuration 可先采用出口压力边界，后续再升级背压阀参数化 |
| 中 | 水分离/冷凝缺少实测排水、温度或压降 | Core Model 仍保留水管理模块，参数先用组件默认或文献范围 |
| 中 | 入口湿度字段 | 模型守恒优先使用含湿量/水质量分数，展示输出 RH |
| 中 | DQ60 作为空压机替代设备 | 可用于台架等效增压设备，不可直接代表车载空压机 |

## 9. 功率扩展原则

本项目不应被 10 kW 台架数据锁死。后续目标是形成可迁移的 PEMFC-cEGR 系统模型体系，支持更大功率电堆和车载结构，例如 240 kW 商用车 PEMFC 系统。

第一版模型采用如下原则：

- `N_cell`、`area_cell`、通道/歧管体积、阀面积、冷却容量、气源能力等参数必须参数化，不写死为 10 kW。
- 10 kW 数据用于验证物质流、接口、边界语义和模型能否跑通，不作为模型物理上限。
- 若台架数据不足，可以先采用官方示例参数、文献范围或工程默认值形成可运行模型，再向实验人员索取关键设备数据。
- 后续车载扩展时，再加入空压机、加湿器、中冷器、完整冷却回路、控制器和大功率电堆参数。

## 10. 暂定建模验收

第一版验收不以控制策略最优、10 kW 数据拟合或电压误差最小为目标，而以通用系统模型结构成立为目标：

1. `.slx` 中存在完整的 FuelCell 四物种物理网络、MEA、电端口、热端口、阴极 cEGR 支路、背压/排气边界和必要传感器。
2. 能运行一个代表性稳态工况，不出现结构错误、物理端口断连或明显非物理状态。
3. 输出 `V_stack`、阴极入口/出口 O2、RH、压力、温度、EGR 流量/比例、热流等关键量。
4. 后续可用 10 kW 数据做 smoke test 或子集对照；误差表不是建模第一步的完成条件。

## 11. 具体建模规划 v0.1

本节用于指导下一阶段实际创建 Simulink/Simscape 模型。当前仍不生成 `.slx`，不运行仿真；后续建模时应按本节小步执行、读回验证、再进入下一阶段。

### 11.1 第一版交付物与边界

| 项目 | 决定 |
|---|---|
| 模型文件 | `04_Simulink物理网络模型/01_模型/PEMFC_cEGR_Core_Physical_v01.slx` |
| 参数脚本 | `04_Simulink物理网络模型/02_参数/PEMFC_cEGR_params_v01.m` |
| 初始参数形式 | `.m` 脚本返回 `P` 结构体；模型稳定后再迁移 `.sldd` |
| 旧模型边界 | 不改 `01_自吸方案/03_台架测试_10kW_简化版`；旧模型只做参数、工况和结果口径参考 |
| 主参考模型 | Gas Mixture PEMFC 官方示例 |
| 主复用库 | `FuelCell_lib` 与 `+FuelCell` 四物种 Simscape 组件 |
| 第一版供气 | 使用边界源给定 `air_mdot_in`、`air_T_in`、`air_p_in`、`air_humidity_in` |
| 第一版不纳入 | 完整空压机、车载加湿器、中冷器、整车电驱、电池和复杂控制器 |

模型配置默认采用官方 Gas Mixture PEMFC 示例的变量步长 Simscape 路线：`SolverType = Variable-step`，初始 `Solver = VariableStepAuto`，`StopTime = 500` s，`RelTol = 1e-3`。若后续结构检查通过但仿真因 DAE 刚性失败，再按同一规划升级为 `daessc` 并记录原因。

### 11.2 顶层子系统

| 子系统 | 作用 | 主要端口/信号 | 主要组件来源 |
|---|---|---|---|
| `CathodeSupplyBoundary` | Bench v01 阴极入口边界源 | 输入 `air_mdot_in`、`air_T_in`、`air_p_in`、`air_humidity_in`；输出 FuelCell 气体端口 | `Mass Flow Rate Source (FC)`、`Pressure Source (FC)`、composition/humidity source 结构 |
| `CathodeInletMixer` | 新鲜空气与 EGR 回流物理混合、入口库存 | 两个气体入口、一个阴极出口、测量端口 | `Constant Volume Chamber (FC)`、`Pipe (FC)`、传感器 |
| `PEMFCStackMEA` | 电化学反应、物种消耗、水生成、电压和热生成 | 阴极/阳极气体端口、电端口、热端口、测量输出 | `FuelCell_lib/elements/Membrane Electrode Assembly` |
| `CathodeOutletAndSeparator` | 阴极出口库存、冷凝或等效水分离 | 阴极出口气体入口、EGR 支路出口、排气支路出口、排水输出 | `Constant Volume Chamber (FC)`、`Pipe (FC)`、等效 separator |
| `CathodeEGRLoop` | 阴极尾气回流与 EGR 阀控制 | 输入 `egr_valve_cmd`；输出 `egr_mdot`、回流气体端口 | `Local Restriction (FC)`、`Pipe (FC)`、质量流量传感器 |
| `CathodeBackPressureExhaust` | 背压阀、排气边界和出口压力约束 | 输入 `bp_valve_cmd`、`p_exhaust`；输出排气流量/压力 | `Local Restriction (FC)`、`Reservoir (FC)`、Pressure Relief Valve 参考结构 |
| `AnodeMinimalBoundary` | 最小阳极供氢与排气边界 | 输入 `h2_supply_*`；连接 MEA 阳极端口 | H2 source、anode exhaust、Gas Mixture 示例阳极结构 |
| `CoolingBoundary` | 第一版等效冷却边界 | 输入 `coolant_T`、可选 `coolant_mdot`；连接 MEA 热端口 | Thermal mass、temperature source、简化热交换 |
| `ElectricalLoad` | 电流负载与电功率接口 | 输入 `i_cmd`；输出 `V_stack`、`P_stack` | Simscape Electrical controlled current/load 结构 |
| `MeasurementsAndControlInterface` | 信号整理、单位转换、控制接口和调试输出 | 输出 `y`/`z` 总线或分组信号 | FuelCell sensors、PS-Simulink Converter、Bus Creator |

顶层不使用 MATLAB Function 做物种混合、EGR 比例或电压主方程。MATLAB Function 只允许用于信号整理、单位换算或命令映射，不进入物理守恒核心。

### 11.3 接口分类与命名

| 分类 | 信号 | 单位/语义 |
|---|---|---|
| `u` 控制输入 | `i_cmd` | A，电堆电流命令 |
| `u` 控制输入 | `egr_valve_cmd` | 1 或 %，EGR 阀命令，先映射为 `A_eff` 或 `CdA_eff` |
| `u` 控制输入 | `bp_valve_cmd` | 1 或 %，背压阀命令；Bench v01 可固定或旁路 |
| `w` 边界输入 | `air_mdot_in`、`air_T_in`、`air_p_in`、`air_humidity_in` | kg/s、K、Pa、kg/kg 或质量分数 |
| `w` 边界输入 | `p_exhaust` | Pa，排气/背压边界 |
| `w` 边界输入 | `coolant_T`、`coolant_mdot` | K、kg/s；第一版 `coolant_mdot` 可选 |
| `w` 边界输入 | `h2_supply_p`、`h2_supply_T`、`h2_supply_mdot` | 阳极最小供氢边界 |
| `y` 主要输出 | `V_stack`、`P_stack` | V、W |
| `y` 主要输出 | `p_ca_in/out`、`T_ca_in/out`、`RH_ca_in/out` | Pa、K、1 或 % |
| `y` 主要输出 | `xO2_ca_in/out`、`xH2O_ca_in/out` | 质量分数或摩尔分数，需在模型中统一标注 |
| `y` 主要输出 | `egr_mdot`、`egr_ratio`、`Q_stack` | kg/s、1 或 %、W |
| `z` 调试输出 | `species_inventory_*`、`dp_egr_valve`、`dp_bp_valve`、`m_condensed`、`lambda_membrane` | 仅用于读回、调试和后续模型审计 |

`egr_ratio` 固定定义为 `EGR 质量流量 / 阴极总入口质量流量`。湿度在物理网络内部优先使用水质量相关变量，展示和报告时输出 RH。

### 11.4 参数脚本结构

`PEMFC_cEGR_params_v01.m` 应返回单一 `P` 结构体，避免散落 base workspace 变量。建议结构如下：

| 字段 | 内容 | 初始来源 |
|---|---|---|
| `P.stack` | `N_cell`、`area_cell`、膜厚、交换电流、极限电流、热容量、电压模型参数 | Gas Mixture 示例、Moist Air/FCEV 方程参考、文献/工程默认 |
| `P.cathode` | 入口/出口容腔体积、初始 p/T/物种、管路长度/直径、热边界 | `FuelCell_lib` 默认、官方示例几何、工程估算 |
| `P.egr` | EGR 阀 `Cd`、`A_min`、`A_max`、命令到面积映射、回流管路参数 | `Local Restriction (FC)` 默认、台架开度样本 sanity check |
| `P.exhaust` | 背压阀参数、`p_exhaust`、排气 reservoir 设置 | Gas Mixture Pressure Relief Valve 结构、Bench 边界 |
| `P.separator` | 冷凝/分离效率、等效排水边界、压降参数 | FuelCell/GasN 冷凝逻辑、工程默认 |
| `P.anode` | H2 供应压力/温度/流量、阳极出口边界 | 官方示例最小阳极结构 |
| `P.cooling` | 冷却温度、等效换热、热质量、可选冷却流量 | 官方示例冷却结构、工程默认 |
| `P.load` | `i_cmd` 默认值、负载模式、初始电状态 | 官方示例和代表性稳态工况 |
| `P.units` | 单位说明和换算因子 | 手工维护 |
| `P.scenario.bench_v01` | 第一组 smoke-test 工况 | 10 kW 台架资料仅作边界示例 |

参数脚本不得把 10 kW 台架数据写成通用物理上限。若某参数来源不充分，先标注 `source = "example/default"` 和 `confidence = "low"`，让模型先跑通，再反向索取实验或供应商数据。

### 11.5 分阶段构建计划

| 阶段 | 目标 | 完成条件 |
|---|---|---|
| Phase 0 | 冻结端口、单位、参数命名和模型配置 | 文档接口表与参数脚本字段一致；不创建旧模型派生副本 |
| Phase 1 | 创建空模型、参数脚本、solver/config 和 10 个顶层子系统壳 | `model_read(depth=0)` 能看到 10 个顶层子系统 |
| Phase 2 | 建立无 EGR 基线链路：阴极边界源、入口容腔、MEA、电负载、冷却边界、最小阳极 | `model_check` 无断线；无 EGR 工况能完成 smoke run |
| Phase 3 | 加入阴极出口容腔、等效冷凝/水分离、EGR 阀、回流管路和入口混合闭环 | 能输出 `egr_mdot`，`egr_ratio` 按定义计算 |
| Phase 4 | 加入背压/排气边界、传感器、控制接口和输出整理 | 能输出 `V_stack`、O2/H2O/RH、p/T、EGR、热流 |
| Phase 5 | 代表性稳态工况 smoke test 和读回审计 | 结构无错误，关键状态非 NaN/Inf，物种/压力/温度方向符合物理直觉 |

每一阶段完成后必须做 read-back verification，再进入下一阶段。若某个官方块接口不符合预期，优先记录缺口并封装最小替代子系统，不直接退回旧 MATLAB Function 经验网络。

### 11.6 第一版降级与升级规则

| 情况 | 第一版处理 | 后续升级 |
|---|---|---|
| 没有现成四物种水分离器 | 用等效冷凝/排水模块，保留 `m_condensed` 输出 | 自定义 Simscape separator |
| EGR 阀实测参数不足 | 用 `Local Restriction (FC)` + 可调 `CdA_eff` | 用阀前后压差和更多开度数据修正映射 |
| 背压阀没有开度记录 | 先用出口压力边界或固定背压阀命令 | 引入背压阀参数化 |
| 压缩/增压设备数据不足 | Bench v01 使用边界源 | 接入 DQ60 等效 booster 或车载 compressor map |
| `FuelCell` 组件缺必要功能 | 先封装轻量 Simscape 组件或等效边界 | 评估 `GasN` 迁移或 AMESim |
| 动态控制过复杂 | 保留控制输入端口，先跑稳态/准稳态 | 后续加入控制器和动态工况 |

进入 AMESim 的触发条件不是“Simscape 建模变难”，而是四物种压缩机、水分离器、阀/管网或求解稳定性在 Simscape 中长期无法闭合，且自定义 Simscape 成本超过继续使用 Simulink/Simscape 的收益。

### 11.7 第一组 smoke-test 工况

第一组工况只验证模型结构和物质流，不用于标定：

| 工况 | `i_cmd` | `egr_valve_cmd` | `bp_valve_cmd` / `p_exhaust` | 目的 |
|---|---|---|---|---|
| `no_egr_base` | 中等电流默认值 | 0 | 默认排气压力 | 检查无 EGR 基线、电压、耗氧、水生成、热流 |
| `egr_low` | 同上 | 小开度 | 同上 | 检查 EGR 回流方向、O2 稀释、湿度变化 |
| `egr_mid` | 同上 | 中开度 | 同上 | 检查 `egr_ratio` 单调性和入口状态变化 |
| `bp_sensitivity` | 同上 | 中开度 | 提高背压 | 检查背压对 EGR 流量、压力链和氧浓度的影响 |

代表性数值先来自 `P.scenario.bench_v01` 的默认值和官方示例参数。10 kW 台架数据只作为边界示例和物质流 sanity check，不用于第一版误差拟合。

### 11.8 后续建模验收预置

后续 `.slx` 建成后，最低验收为：

1. `model_read(depth=0)` 能读到 10 个顶层子系统。
2. `model_check` 不出现断线、未连接物理端口或明显结构错误。
3. 首个稳态工况能输出 `V_stack`、`xO2_ca_in/out`、`RH_ca_in/out`、`p_ca_in/out`、`egr_mdot`、`egr_ratio`、`Q_stack`。
4. 输出中不存在 NaN/Inf，压力、温度、物种分数在合理范围。
5. EGR 阀开度增大时，`egr_mdot` 和 `egr_ratio` 的变化方向应符合阀/压差物理语义。
6. 不要求第一版完成 10 kW 数据拟合，不以误差表作为模型成立条件。
