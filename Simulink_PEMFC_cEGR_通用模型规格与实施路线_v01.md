# Simulink/Simscape PEMFC-cEGR 通用模型规格与实施路线 v01

日期：2026-07-07  
阶段：路线 A 决策后规格更新、接口契约、官方基准模型派生实施路线。  
范围：2026-07-07 已决定全面转向路线 A：以 MathWorks 官方 `PEM Fuel Cell System with the Gas Mixture Domain` 为基准母版，新增 cathode-cEGR 支路；原路线 B `PEMFC_cEGR_Core_Physical_v01.slx` 留作拓扑探索成果和接口参考，不再作为主深化对象。

本文件回答“我们要建成什么模型、有哪些边界、接口如何定义、先后如何实施”。材料来源、候选模型和组件取舍见 [Simulink_PEMFC_cEGR_材料池与模型候选比较_v01.md](E:/agentwork_pemfc_cEGR_0519/Simulink_PEMFC_cEGR_材料池与模型候选比较_v01.md)。

## 1. 建模目标与边界

状态：方向已从“自建 Core Model 深化”调整为“官方 Gas Mixture PEMFC 基准模型派生”。10 kW 台架数据仍只作为实例化、smoke test 和物质流 sanity check 资料，不反向定义通用架构。

| 项目 | 已确认内容 | 建模含义 |
|---|---|---|
| 第一版目标 | 在官方无 cEGR PEMFC 系统上插入阴极尾气循环支路，先跑通 no-EGR 与低 EGR 稳态结构 | 模型继承官方 PEMFC 主系统，不重新搭建 stack、阳极、热端、电负载和基础测量 |
| 研究对象 | 阴极 cEGR 对 O2 浓度、湿度、压力、电压的影响 | 必须显式建阴极物种、湿度、压力和电堆电压耦合 |
| 建模优先级 | 优先建立系统级设备模型和方法论；性能评估与策略开发在模型成立后推进 | 第一阶段不以数据拟合或误差表为目标 |
| 物理网络状态 | 容腔压力、温度、物种库存等状态正是本模型区别于简化经验模型的核心 | 不为简化稳态而删除容腔和物种库存；稳态只是运行工况与验收方式 |
| 控制策略 | 暂不优化控制器，但保留控制接口 | EGR 阀、背压阀、入口边界、电流负载等应有命令输入或可替换接口 |
| 新鲜空气入口 | 优先继承官方 `Oxygen Source`、`Compressor Volume`、`Cathode Humidifier` 的边界结构 | Bench Configuration 可先固定/旁路部分 BOP；不先拆掉官方入口链路 |
| 加湿器 | 官方模型已含 `Cathode Humidifier`，路线 A 先保留并明确 cEGR 回注位置 | 若台架无加湿器，可在派生配置中旁路或降级，但不能在母版层面删除证据链 |
| 氢气侧 | 继承官方 `Hydrogen Source`、`Anode Humidifier`、`Anode Gas Channels`、阳极 `Recirculation` | 阳极回流只作结构参考，不误判为 cathode-cEGR |
| 冷却侧 | 继承官方 `Heat Dissipation` 和 MEA 热端结构 | 第一版只改阴极尾气路径，热端不作为首轮重构对象 |
| 数据定位 | 10 kW 台架数据只用于 smoke test、物质流 sanity check 和演示工况 | 模型体系必须可扩展到大功率电堆和车载结构，不被 10 kW 尺寸绑定 |

## 2. 模型路线分层

| 层级 | 作用 | 建模内容 | 数据角色 |
|---|---|---|---|
| `Route A Baseline Derivative` | 官方 Gas Mixture PEMFC 派生母版 | 继承官方 `FuelCell` 四物种域、MEA、阳极/阴极通道、入口/排气、热端、电负载、测量；只新增 cathode-cEGR 支路和必要接口 | 以官方示例参数与模型工作区为初值；先不依赖 10 kW 数据 |
| `Route B Archive/Reference` | 自建 Core Model 留存 | `PEMFC_cEGR_Core_Physical_v01.slx` 中的入口 mixer、出口/分离、EGR loop、背压边界、接口命名 | 只作为拓扑探索和缺口清单，不继续作为主线深化 |
| `Bench Configuration` | 10 kW 台架实例 | 入口边界源、DQ60 等效增压设备可选、无加湿器、最小供氢边界、简化冷却边界 | 只用于 smoke test、边界示例和物质流检查 |
| `Vehicle Configuration` | 车载系统扩展 | 空压机、中冷器、加湿器、完整冷却回路、控制器、大功率电堆、整车功率接口 | 需要后续供应商/文献/实验数据支撑 |
| `Scaling Rules` | 功率等级迁移 | `N_cell`、`area_cell`、流道体积、阀面积、气源能力、冷却容量、热容量、传感器量程参数化 | 不用 10 kW 数据外推为通用规律 |

## 3. Route A 推荐系统边界

```text
Environment / Air Intake Reservoir
  -> FreshAirRestriction or inlet boundary
  -> CompressorInletMixer
      <- EGR return from cathode outlet after separator and EGR valve
  -> Compressor
  -> Compressor Volume
  -> Cathode Humidifier
  -> Cathode Gas Channels.B / MEA cathode port
  -> Cathode Gas Channels.C
  -> New Cathode Outlet Chamber / Separator
  -> branch 1: Separator / EGR Valve / EGR Pipe
      -> CompressorInletMixer
  -> branch 2: Cathode Exhaust Pipe / Pressure Relief or Back-Pressure Valve
      -> Environment Reservoir

Official Hydrogen Source / Anode Humidifier / Anode Gas Channels
  -> MEA anode port
  -> Anode Exhaust and existing anode Recirculation retained as non-cathode reference

Official MEA
  -> Electrical Load
  -> Heat Dissipation
  -> Measurements
```

关键原则：

1. 阴极 cEGR 支路必须是物理网络，不用 MATLAB Function 做信号加权混合替代。
2. 气体域优先统一使用 `FuelCell` 四物种域：N2/O2/H2/H2O。
3. 第一版不拆官方主系统，只在 `Cathode Gas Channels.C` 到 `Cathode Exhaust` 之间引出 cEGR 分支。
4. 阀门和背压边界是 cEGR 策略接口，不应简化成固定 EGR 率常数。
5. 官方 `Recirculation` 是阳极氢气回流，只能参考其“主动回流源 + 容腔 + 控制”的结构，不能直接视为阴极 cEGR。
6. cEGR 回流入口优先放在压缩机前。`Air Intake` 仍是环境边界，但它不再直接等同于压缩机入口；环境新鲜空气和阴极回流尾气应先进入有限容积的 `CompressorInletMixer`，再被压缩机吸入。
7. cEGR 压力链按气体流向应整体下降：`p_cathode_out / p_outlet_chamber > p_separator / p_egr_valve_up > p_egr_valve_down > p_compressor_inlet`，其中 `p_compressor_inlet` 近似环境压力。若局部管路或阀模型导致该关系长期反向，优先检查背压边界、阀面积、压缩机吸入边界和初始化。

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
| 输出 | `egr_ratio_comp_in` | 1 或 % | 定义为 EGR 质量流量 / 压缩机总入口质量流量 | 必须输出 |
| 输出 | `egr_split_ratio_out` | 1 或 % | 定义为 EGR 质量流量 / 阴极出口总质量流量 | 建议输出，用于三通分流口径 |
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
| 阴极供气源 | 官方 `Oxygen Source`、`Mass Flow Rate Source (FC)`、`Pressure Source (FC)` 或压缩/增压设备 | 流量、p/T/含湿量、O2/N2/H2O 组分 | 路线 A 先继承官方入口链路；Bench 配置可再简化为边界源 |
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
4. 后续策略模型可以把 `egr_valve_cmd -> A_eff -> mdot_egr -> egr_ratio_comp_in / egr_split_ratio_out` 作为控制链，不直接把 EGR 率当输入。

## 7. Bench Configuration 资料定位

10 kW 台架资料保留为第一个配置场景的资料池，不作为路线 A 母版的架构依据。本轮只读确认的数据目录为：

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
| 中 | 水分离/冷凝缺少实测排水、温度或压降 | 路线 A 仍保留水管理模块，参数先用组件默认或文献范围 |
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

## 11. 路线 B 留存模型状态

本节记录 `PEMFC_cEGR_Core_Physical_v01.slx` 的已完成探索、接口命名和缺口判断。自 2026-07-07 路线决策后，它不再作为主深化对象；后续只作为路线 A 插入 cEGR 支路时的拓扑参考、接口参考和风险清单。

### 11.1 路线 B 已有交付物与边界

| 项目 | 决定 |
|---|---|
| 留存模型文件 | `04_Simulink物理网络模型/01_模型/PEMFC_cEGR_Core_Physical_v01.slx` |
| 留存参数脚本 | `04_Simulink物理网络模型/02_参数/PEMFC_cEGR_params_v01.m` |
| 初始参数形式 | `.m` 脚本返回 `P` 结构体；模型稳定后再迁移 `.sldd` |
| 旧模型边界 | 不改 `01_自吸方案/03_台架测试_10kW_简化版`；旧模型只做参数、工况和结果口径参考 |
| 当前角色 | 路线 B 结构探索成果，不再作为路线 A 的母版 |
| 主参考模型 | Gas Mixture PEMFC 官方示例，现已提升为路线 A 的基准母版 |
| 主复用库 | `FuelCell_lib` 与 `+FuelCell` 四物种 Simscape 组件 |
| 第一版供气 | 使用边界源给定 `air_mdot_in`、`air_T_in`、`air_p_in`、`air_humidity_in` |
| 第一版不纳入 | 完整空压机、车载加湿器、中冷器、整车电驱、电池和复杂控制器 |

路线 B 模型配置采用官方 Gas Mixture PEMFC 示例的变量步长 Simscape 路线：`SolverType = Variable-step`，初始 `Solver = VariableStepAuto`，`StopTime = 500` s，`RelTol = 1e-3`。这些设置可作为路线 A 派生模型的初始对照，但路线 A 应优先继承官方示例自身配置。

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

### 11.5 路线 B 原分阶段构建计划

该计划记录路线 B 当时的构建顺序，现只用于理解 `PEMFC_cEGR_Core_Physical_v01.slx` 的来源，不作为下一步执行计划。

| 阶段 | 原目标 | 原完成条件 |
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

### 11.8 路线 B 原验收预置

以下验收项是路线 B 原计划的一部分。路线 A 的正式验收以第 12.6 节为准。

1. `model_read(depth=0)` 能读到 10 个顶层子系统。
2. `model_check` 不出现断线、未连接物理端口或明显结构错误。
3. 首个稳态工况能输出 `V_stack`、`xO2_ca_in/out`、`RH_ca_in/out`、`p_ca_in/out`、`egr_mdot`、`egr_ratio`、`Q_stack`。
4. 输出中不存在 NaN/Inf，压力、温度、物种分数在合理范围。
5. EGR 阀开度增大时，`egr_mdot` 和 `egr_ratio` 的变化方向应符合阀/压差物理语义。
6. 不要求第一版完成 10 kW 数据拟合，不以误差表作为模型成立条件。

### 11.9 当前模型审查结论 v0.2

审查日期：2026-07-07  
审查对象：`04_Simulink物理网络模型/01_模型/PEMFC_cEGR_Core_Physical_v01.slx`  
配套脚本：`04_Simulink物理网络模型/02_参数/PEMFC_cEGR_params_v01.m`、`04_Simulink物理网络模型/03_脚本/run_pemfc_cegr_core_scenario_audit_v01.m`  
审查方式：MATLAB MCP / SATK `model_overview`、`model_read(depth=1)`、`model_check`、MATLAB `find_system`、4 工况 smoke run。

当前模型已经达到“规范化物理网络骨架已创建并可运行”的级别，但未达到“PEMFC-cEGR 通用规范模型完成”的级别。

| 审查项 | 当前证据 | 结论 |
|---|---|---|
| 顶层结构 | `model_overview(full)` 读到 10 个顶层子系统：`CathodeSupplyBoundary`、`CathodeInletMixer`、`PEMFCStackMEA`、`CathodeOutletAndSeparator`、`CathodeEGRLoop`、`CathodeBackPressureExhaust`、`AnodeMinimalBoundary`、`CoolingBoundary`、`ElectricalLoad`、`MeasurementsAndControlInterface` | Phase 1 已完成 |
| 官方资产复用 | MATLAB 读回 286 blocks、25 个 Simscape blocks、17 个 `FuelCell_lib` 引用；核心引用包括 `Membrane Electrode Assembly`、`Constant Volume Chamber (FC)`、`Local Restriction (FC)`、`Reservoir (FC)`、`Mass Flow Rate Source (FC)`、压力/温度/组分/质量流量传感器 | 满足“有模块必有参考”的初步要求 |
| MATLAB Function 使用 | `MATLABFcn` 和 MATLAB Function subsystem 数量均为 0 | 物理守恒主链路未退回 MATLAB Function 经验核 |
| 可运行性 | `run_pemfc_cegr_core_scenario_audit_v01` 已跑通 `no_egr_base`、`egr_low`、`egr_mid`、`bp_sensitivity` 四个 10 s smoke 工况 | 可作为初版运行骨架继续迭代 |
| 结构检查 | `model_check` 报 37 errors、70 warnings；其中大量来自 Simscape Connection Port / 子系统 Inport-Outport 的读法差异，但仍说明正式接口未清理到可交付状态 | 不能把 `model_check` 视为已通过 |
| EGR 物理语义 | `egr_low` 与 `egr_mid` 中 `egr_mdot` 分别为 0.0004、0.001 kg/s，`egr_ratio` 分别为 0.0667、0.1667；但入口/出口 O2 与 H2O 变化很弱 | 当前 EGR 更接近命令驱动的主动回流骨架，还不是由阀、压差和管网自然决定的 cEGR 物理支路 |
| 热管理 | `Q_stack` 仍由 `QStack_PlaceholderZero` 输出 0；`CoolingBoundary` 只有热质量和温度测量 | 热生成、冷却换热和能量闭合未完成 |
| 水管理 | `CathodeOutletAndSeparator/ZeroCondensate` 固定 `m_condensed=0` | 冷凝/水分离只是占位 |
| 台架边界 | 参数脚本已有 `P.scenario` 和 4 个 smoke 工况；入口/阳极/冷却/背压输入主要仍靠默认值和脚本覆盖 | 可用于 smoke test，不可用于台架结构真实性声明 |

4 工况 smoke run 的关键结果摘要：

| 工况 | `egr_cmd` | `V_stack` V | `ca_in_p` Pa | `ca_in_yO2` | `ca_in_yH2O` | `egr_mdot` kg/s | `egr_ratio` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `no_egr_base` | 0 | 76.15 | 1.0446e5 | 0.11466 | 0.093269 | 0 | 0 |
| `egr_low` | 0.2 | 76.149 | 1.0446e5 | 0.11467 | 0.093297 | 0.0004 | 0.066667 |
| `egr_mid` | 0.5 | 76.149 | 1.0446e5 | 0.11467 | 0.093294 | 0.001 | 0.16667 |
| `bp_sensitivity` | 0.5 | 76.536 | 1.3237e5 | 0.11724 | 0.073814 | 0.001 | 0.16667 |

上述结果只能证明模型能运行和输出 KPI，不能证明 cEGR 机理已经成立。特别是 EGR 增大时氧稀释、湿度回灌和压差耦合还没有形成足够清晰的物理响应。

### 11.10 路线 B 缺陷队列与可吸收经验 v0.2

以下缺陷不再作为路线 B 的主开发待办，而是路线 A 派生时必须吸收的经验和避坑项：

| 优先级 | 工作项 | 目标 | 完成条件 |
|---:|---|---|---|
| P0 | 清理接口和结构检查口径 | 区分 SATK 对 Simscape Connection Port 的误报与真实断线；补齐未使用的状态输出或删除误导性 Simulink Inport/Outport | `model_check` 不再出现真实断线；保留的未连接项有说明 |
| P0 | 修正 EGR 回流物理语义 | 当前 EGR 用 `Mass Flow Rate Source (FC)` 强制给流量，阀块更像串联限流件；应改为以阀/压差/管路阻力决定回流，或明确“主动循环泵等效”模式 | `egr_valve_cmd` 改变时，`egr_mdot` 由网络状态响应；若保留主动泵模式，文档和模型命名必须显式标注 |
| P0 | 建立无 EGR 基线的物质流检查 | 先把入口 O2、出堆 O2、水生成、电压、压力、温度范围校到物理可解释 | no-EGR 工况输出无 NaN/Inf，O2 消耗、水生成、压力方向与 MEA 反应一致 |
| P1 | 完成热生成与冷却边界 | 用 MEA 热端或能量差替换 `Q_stack=0`，并建立等效冷却换热 | `Q_stack` 非占位；`T_stack` 对电流和冷却边界有合理响应 |
| P1 | 完成水分离/冷凝占位升级 | 先做等效 separator，记录压降、冷凝效率、排水输出；后续再考虑自定义 Simscape separator | `m_condensed` 不再固定为 0；湿度输出有明确单位和语义 |
| P1 | 规范测量接口 | 将 `y_main`/`z_debug` 从纯 Mux 升级为清晰命名的信号或 bus，统一质量分数/摩尔分数/RH | 审计脚本不依赖硬编码索引解释关键变量 |
| P2 | 台架配置实例化 | 把 10 kW 台架结构作为 configuration，而不是写死进路线 A 母版 | 台架输入、边界、默认参数和通用参数分层清楚 |
| P2 | 空压机/循环泵等效模块 | 台架可先保留边界源或主动回流；后续用 DQ60 等效增压设备或成熟 compressor 参考件替换 | 压升、温升、功耗和流量边界可追溯 |

这些项不作为路线 A 下一步的执行顺序，只作为路线 A 派生建模时的检查清单：

1. 路线 A 先继承官方 no-EGR 基线，不再先修路线 B 的 no-EGR 链路。
2. cEGR 模块第一版命名为 `CompressorInletCoupledEGR`，语义是压缩机入口耦合回流；除非后续确认证据需要，不新增独立阴极回流泵。
3. 路线 A 接入 cEGR 后仍要检查 `egr_cmd -> egr_mdot -> xO2_ca_in -> V_stack/RH` 的方向性。
4. 热端、水分离和冷却边界优先继承官方模型；只有新增 cEGR 支路造成缺口时才局部扩展。

## 12. 路线 A 基准模型派生计划 v0.3

本节是后续进入 Simulink 前的主执行依据。原则是：不修改官方归档模型，不继续从路线 B 自建骨架深化；先复制官方 Gas Mixture 示例到工作区派生副本，再以最小拓扑改动加入 cathode-cEGR 支路。

### 12.1 基准模型与工作副本

| 项目 | 决定 |
|---|---|
| 官方归档母版 | `00_支撑材料/参考建模材料/05_成熟模型案例/simulink模型案例/MathWorks_Official_Examples_R2025b/01_GasMixture_PEMFuelCellSystemWithCustomLibrary/PEMFuelCellSystemWithACustomLibrary.slx` |
| 派生工作目录 | `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/` |
| 建议派生模型名 | `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx` |
| 参数起点 | 继承官方 `PEMFuelCellSystemWithACustomLibraryParameters.m` 的 model workspace 变量，再新增 `cegr_*` 参数组 |
| 禁止事项 | 不覆盖官方归档 `.slx`；不把路线 B 模型另存为路线 A；不先删除官方阳极、热端、电负载和测量结构 |

### 12.2 最小插入路径

```text
PEMFuelCellSystemWithACustomLibrary
  Oxygen Source
    Environment / Air Intake
      -> FreshAirRestriction or inherited inlet boundary
      -> New CompressorInletMixer
      -> existing Compressor
      -> existing Compressor Volume

  Cathode Gas Channels.C
    -> New CathodeOutletChamber
    -> three-way split:
         branch Exhaust -> existing Cathode Exhaust/Pipe -> Pressure Relief -> Environment
         branch EGR -> SeparatorOrCondensation -> EGRValve -> EGRPipe
                      -> New CompressorInletMixer
```

优先插入点：

1. `Cathode Gas Channels.C` 到 `Cathode Exhaust` 之间作为出口分支点。
2. 回流入口优先接到 `Oxygen Source` 内 `Air Intake` 与 `Compressor` 之间的压缩机入口混合容腔，而不是接到 `Cathode Humidifier` 后或 `Cathode Gas Channels.B` 前。
3. 保留排气支路，不能把全部阴极出口气体强制回流。
4. 不把 EGR 支路直接接到理想 `Air Intake` reservoir 上；否则环境边界会钳制压力、温度和组分，削弱甚至吞掉回流耦合。
5. 第一版 cEGR 子系统命名为 `CompressorInletCoupledEGR`。它表示“阴极出口背压 + EGR 阀/管路压降 + 压缩机入口近环境压力/吸入流量”的耦合，不表示独立阴极回流泵。

### 12.2.1 压缩机入口耦合规则

| 建模对象 | 操作规则 | 验证口径 |
|---|---|---|
| `Air Intake` | 保留为新鲜空气环境边界或 reservoir | 只提供新鲜空气，不直接作为混合节点 |
| `CompressorInletMixer` | 新增有限容积 chamber，接收新鲜空气和 EGR 回流 | 其压力应近似环境压力，组分随 EGR 改变 |
| 新鲜空气支路 | 第一版采用 `Air Intake -> CompressorInletMixer`；入口 restriction/source 后续按需求再加 | 新鲜空气流量可由压缩机总吸入需求和 EGR 回流共同决定 |
| EGR 支路 | `CathodeOutletChamber -> Separator -> EGRValve -> EGRPipe -> CompressorInletMixer` | 沿流向压力逐级下降；`egr_mdot` 由压差、阀面积和压缩机吸入状态共同决定 |
| 压缩机 | 继承官方 compressor 与 compressor map/control | 压缩机入口组分由 mixer 输出决定，压缩机出口进入官方 `Compressor Volume` |
| 传感器 | 出口容腔和压缩机入口混合腔优先复用 Chamber 自带 `pC/TC/yC_i` 输出；EGR 阀前后用 p/T sensor；RH 和冷凝质量流先作为后续 Simscape log/水管理项 | 能审计 `p_outlet > p_egr_up > p_egr_down ~ p_comp_in` 的方向性 |

### 12.3 继承与新增子系统

| 类别 | 子系统/组件 | 路线 A 处理 |
|---|---|---|
| 直接继承 | `Membrane Electrode Assembly` | 不重建；只核查参数、端口和输出语义 |
| 直接继承 | `Anode Humidifier`、`Anode Gas Channels`、`Hydrogen Source`、`Anode Exhaust`、阳极 `Recirculation` | 保持官方结构；阳极回流只作结构参考 |
| 直接继承 | `Oxygen Source`、`Cathode Humidifier`、`Cathode Gas Channels`、`Cathode Exhaust` | 保留主链路，局部拆接阴极出口和回流入口 |
| 直接继承 | `Heat Dissipation`、`Electrical Load`、`Measurements` | 保留，避免路线 B 的热端和 KPI 占位问题 |
| 新增 | `CathodeOutletChamber` | 提供出口库存、压力、温度和组分测量，必要时由 `Constant Volume Chamber (FC)` 实现 |
| 新增 | `SeparatorOrCondensation` | 第一版可用 `Pipe (FC)`/`Chamber (FC)` 冷凝能力或等效排水模块；输出 `m_condensed` |
| 新增 | `CompressorInletMixer` | 位于 `Air Intake` 与 `Compressor` 之间，混合新鲜空气和 cEGR 回流，建议由 `Constant Volume Chamber (FC)` 实现 |
| 新增 | `CompressorInletCoupledEGR` | `SeparatorOrCondensation` + `Local Restriction (FC)` + EGR pipe + flow/pressure sensors；第一版不设置独立回流泵 |
| 新增 | `RouteA_Measurements` | 输出 `V_stack`、`i_stack`、`p/T/RH/x_i`、`egr_mdot`、`egr_ratio_comp_in`、`egr_split_ratio_out`、`m_condensed`、`Q_stack` |

### 12.4 参数与初始化策略

| 参数组 | 内容 | 初始来源 |
|---|---|---|
| `stack_*` | `stack_num_cells`、`stack_area`、`stack_iL`、`stack_io`、膜厚、热参数 | 官方 model workspace |
| `cathode_*` | 阴极通道体积、管径、初始 `p/T/y0`、冷凝时间常数 | 官方 `Cathode Gas Channels` 和 `Cathode Exhaust` |
| `cegr_*` | EGR 支路管径、容积、阀 `Cd/A_min/A_max`、阀命令到面积映射、初始开度 | 路线 B 缺口经验 + `FuelCell_lib` 默认 + 工程估算 |
| `comp_inlet_*` | 压缩机入口混合腔体积、初始 `p/T/y0`、新鲜空气入口阻力或边界参数 | 官方 `Oxygen Source` + 工程估算 |
| `separator_*` | 冷凝效率、排水边界、压降、温度边界 | 第一版工程默认；后续用水分离器资料修正 |
| `bp_*` | 背压/泄压设定、环境压力、排气阀等效面积 | 官方 `Cathode Exhaust/Pressure Relief Valve` |
| `scenario_*` | `no_egr_base`、`egr_low`、`egr_mid`、`bp_sensitivity` | 官方 drive cycle 或台架代表点仅作 smoke |

初始化纪律：

1. 优先继承官方模型工作区和 solver 配置，不在派生初期改成全新 `P` 结构体。
2. 新增 cEGR 参数集中命名，不散落 base workspace。
3. 每次新增参数后用 `model_query_params` 或 MATLAB `get_param` 做读回。
4. 若官方 mask 或 model workspace 初始化限制派生，先记录耦合点，再决定是否抽出参数脚本；不直接硬改 `.slx` 内部文件。

### 12.5 分阶段执行计划

| 阶段 | 目标 | 完成条件 |
|---|---|---|
| Phase A0 | 建立派生工作副本并只读复核官方基线 | 工作副本存在；官方归档未修改；`model_overview` 能读到原顶层结构 |
| Phase A1 | 运行或计划 no-EGR 官方基线 smoke | 若用户允许运行，则完成最小 smoke；若不运行，至少完成结构检查和参数读回 |
| Phase A2 | 在 `Oxygen Source` 内拆出 `Air Intake -> Compressor` 连接并加入 `CompressorInletMixer` | 新鲜空气仍能进入 compressor；mixer 的 p/T/x_i 可读回 |
| Phase A3 | 在阴极出口加入 split、出口容腔和排气保留支路 | `Cathode Gas Channels.C`、`Cathode Exhaust`、新增出口容腔连接关系可读回 |
| Phase A4 | 加入 `CompressorInletCoupledEGR` 并回到 `CompressorInletMixer` | `egr_mdot` 非占位输出；排气支路仍存在；压缩机入口组分受回流影响 |
| Phase A5 | 加入水分离/冷凝等效与测量接口 | 第一版先完成 p/T/y_i 与 EGR 压力链诊断；RH 与 `m_condensed` 进入后续水管理细化 |
| Phase A6 | no-EGR 与低 EGR smoke 验证 | no-EGR 近似回到官方基线；低 EGR 下压缩机入口 O2 降低或湿度回灌方向可解释；若初始化阻塞，需记录失败栈并先修初值策略 |
| Phase A7 | 台架配置最小实例化 | 不拟合电压，只用 10 kW 代表点做物质流、压力和边界语义 sanity check |

### 12.6 路线 A 验收标准

1. 官方归档模型未被覆盖，所有改动只在路线 A 工作副本中发生。
2. `model_read(depth=0/1)` 能追溯 cEGR 插入点：阴极出口、separator、EGR 支路、压缩机入口混合腔、排气支路。
3. no-EGR 模式下 cEGR 支路可关闭，模型行为不应明显破坏官方基线。
4. 低 EGR 模式下 `egr_mdot > 0`，`egr_ratio` 定义为 `EGR 质量流量 / 压缩机总入口质量流量`，并可同时报告 `EGR 质量流量 / 阴极出口总质量流量` 作为分流比。
5. 输出至少覆盖 `V_stack`、`i_stack`、`p_ca_in/out`、`T_ca_in/out`、`xO2_ca_in/out`、`xH2O_ca_in/out`、`RH_ca_in/out`、`egr_mdot`、`egr_ratio_comp_in`、`egr_split_ratio_out`、`m_condensed`、`Q_stack`。
6. 不把阳极 `Recirculation` 当作 cathode-cEGR；报告中必须明确两者区别。
7. EGR 支路压力链需符合 `p_cathode_out > p_separator/egr_up > p_egr_down >= p_compressor_inlet` 的主方向；允许小幅动态波动，但不允许稳态长期反向。
8. 第一版不要求 10 kW 电压误差最小，不以误差表作为路线 A 建模完成条件。

### 12.7 当前执行记录

执行日期：2026-07-07。  
工作副本：`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`。

| 阶段 | 当前状态 | 证据 |
|---|---|---|
| Phase A0 | 已完成 | 已从官方 Gas Mixture 示例建立工作副本；官方归档未覆盖 |
| Phase A1 | 已完成结构级基线 | model workspace 能从复制目录参数脚本加载；`model_overview` 能读到官方顶层结构 |
| Phase A2 | 已完成 | `Oxygen Source` 内已形成 `Air Intake -> CompressorInletMixer -> Compressor/Compressor Map in`；入口 restriction 已暂缓以降低初始化耦合；`update diagram` 通过 |
| Phase A3 | 已完成 | 顶层已形成 `Cathode Gas Channels.C -> CathodeOutletChamber -> Cathode Exhaust.C`；排气支路保留；`update diagram` 通过 |
| Phase A4 | 已完成第一版物理闭环 | 已形成 `CathodeOutletChamber.C -> EGRMassFlowSensor -> EGRValveRestriction -> EGRPipe -> Oxygen Source.cEGR -> CompressorInletMixer.C`；`egr_mdot` 已接入 `EGR Diagnostics`；`update diagram` 通过 |
| Phase A5 | 已完成第一版诊断与等效冷凝参数化 | `PEMFuelCellSystemWithACustomLibraryParameters.m` 已新增 `cegr_*` 参数；`CathodeOutletChamber`、`EGRPipe`、`CompressorInletMixer` 已启用水为可冷凝组分；出口/入口 p/T/y_i 改用 Chamber 自带输出，EGR 阀前后压力用 PT sensor |
| Phase A6 | 已建立脚本但 smoke 未通过 | 已新增 `run_routeA_a6_smoke.m`；官方原模型 5 s smoke 可运行；Route A 当前失败于 Simscape 初始条件收敛，失败栈曾集中在 compressor map 0/0、EGRPipe、官方阳极/阴极湿度与阀件方程 |

当前模型已经进入 A6 初始化调试阶段。固定小开度 `EGRValveRestriction` 仍只是先验证压缩机入口耦合回流物理闭环，不是最终可控 EGR 阀命令接口。A6 尚未通过前，不应进入参数拟合或台架数据标定。

### 12.8 配套脚本资产

路线 A 工作副本不是单个 `.slx` 文件。官方示例自带的 `.m` 和 `.mat` 文件需要纳入版本与验证边界，否则后续初始化、示例运行和结果绘图会出现模型名或 simlog 名称错配。

| 文件 | 当前角色 | 是否当前必需 | 处理策略 |
|---|---|---:|---|
| `PEMFuelCellSystemWithACustomLibraryParameters.m` | 模型工作区初始化脚本；定义环境、stack、冷却、compressor map、电负载等参数，并加载 drive cycle | 是 | 已把 `Gas Mixture Properties` 路径改为路线 A 模型名；后续新增 `cegr_*`、`comp_inlet_*`、`separator_*` 参数应优先进入此脚本或其 Route A 派生版 |
| `PEMFuelCellSystemWithACustomLibraryDriveCycle.mat` | 官方 drive cycle 数据源，被参数脚本加载 | 是，若继续使用官方 drive-cycle 工况 | 保留；A6 smoke 可先用官方工况，台架配置阶段再引入 10 kW 代表点 |
| `run_routeA_a6_smoke.m` | Route A 专用 no-EGR/low-EGR 短仿真脚本；使用 `SimulationInput` 切换 EGR 阀面积并读取 `logsout` 诊断信号 | 是，A6 入口 | 已通过 MATLAB Code Analyzer；当前运行被 Route A 初始条件收敛阻塞，需先修初值/拓扑后再作为验收脚本 |
| `PEMFuelCellSystemWithACustomLibraryExample.m` | 官方 live example 展示脚本；会打开子系统、运行 `sim()`、调用绘图脚本 | 否 | 当前仍硬编码原模型名，不能直接作为 Route A 运行入口；后续应复制/改名为 Route A example 或替换为专用 smoke 脚本 |
| `PEMFuelCellSystemWithACustomLibraryPlot1IV.m` | i-v 与功率曲线绘图 | 否 | 当前引用原 `simlog_PEMFuelCellSystemWithACustomLibrary`；后续若复用，需迁移到 Route A simlog 名称和新增 cEGR 指标 |
| `PEMFuelCellSystemWithACustomLibraryPlot2Power.m` | stack 输出功率、compressor/pump 消耗、热耗散绘图 | 否 | 可复用为功率/寄生功耗基线图，但需迁移模型名和 simlog 路径 |
| `PEMFuelCellSystemWithACustomLibraryPlot3Efficiency.m` | 效率与 H2/O2 利用率绘图 | 否 | 可复用利用率计算逻辑；Route A 需增加 `egr_ratio_comp_in` 与 `egr_split_ratio_out` |
| `PEMFuelCellSystemWithACustomLibraryPlot4T.m` | stack、anode、cathode、coolant、radiator 温度绘图 | 否 | 可复用温度审计；Route A 需增加 compressor inlet / EGR loop 温度 |
| `PEMFuelCellSystemWithACustomLibraryPlot5Energy.m` | 氢气消耗、tank 压力和能量积分 | 否 | 可保留为氢耗审计，不是 cEGR 第一优先指标 |
| `PEMFuelCellSystemWithACustomLibraryPlot6Surge.m` | 阳极 N2/H2 浓度与 purge 行为绘图 | 否 | 只作阳极回流参考；不能误当 cathode-cEGR 后处理 |

脚本管理原则：

1. `.slx` 结构修改后，必须确认模型工作区仍能从参数脚本初始化。
2. 后续 A6 smoke 不直接调用官方 `Example.m`，除非先完成模型名、simlog 名、scope 名和新增 cEGR 指标迁移。
3. Plot 脚本可以作为后处理模板，但 Route A 至少应新增压缩机入口 O2/H2O、EGR 质量流量、出口分流比、压力链和冷凝/排水指标；RH 在第一版 smoke 中不是硬门槛。
4. 若新增 Route A 专用脚本，优先命名为 `run_routeA_*` 或 `plot_routeA_*`，避免继续沿用官方原模型名造成误调用。

### 12.9 当前不做的事

1. 不继续修路线 B 的 37 个 `model_check` errors，除非其中某条直接影响路线 A 设计判断。
2. 不从零重建 MEA、电负载、热端和官方测量结构。
3. 不把 Moist Air PEMFC 或 FCEV 作为主骨架；它们只作为加湿、冷却、BOP 和整车接口参考。
4. 不把台架 DQ60、加湿器或背压阀资料提前写死进通用母版。
5. 不在路线 A 第一版引入 AMESim；只有 Simscape 四物种网络、水分离或主动回流设备长期无法闭合时再评估。
