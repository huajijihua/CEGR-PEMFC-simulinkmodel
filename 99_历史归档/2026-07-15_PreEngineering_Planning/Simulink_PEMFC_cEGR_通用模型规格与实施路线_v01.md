# Simulink/Simscape PEMFC-cEGR 通用模型规格与实施路线 v01

日期：2026-07-07；状态核查更新：2026-07-15
阶段：路线 A 决策后规格更新、接口契约、官方基准模型派生实施路线。
范围：当前唯一 Simulink 主线为路线 A：以 MathWorks 官方 `PEM Fuel Cell System with the Gas Mixture Domain` 为基准母版，在 `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/` 中维护唯一模型 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`。根层 Simscape Variant Subsystem 以 `routeA_cegr_enabled` 在直接回流和官方无限流阻隔离之间编译期切换。原路线 B `PEMFC_cEGR_Core_Physical_v01.slx` 已归档到 `99_历史归档/2026-07-14_RouteB_Core_Physical/`，不再作为当前建模、计算、排障或默认参考对象。

本文件回答“我们要建成什么模型、有哪些边界、接口如何定义、先后如何实施”。材料来源、候选模型和组件取舍见 [Simulink_PEMFC_cEGR_材料池与模型候选比较_v01.md](../../00_支撑材料/RouteA_材料池与模型候选比较_v01.md)。

## 0. 剥离原则与参数来源分层

当前 Route A 的核心任务不是把已有产品资料参数化，而是建立不受劣质、不稳定、不可信产品数据污染的通用系统仿真平台。后续所有建模动作先执行“剥离”：公司/历史/台架资料只作为背景、外部案例或后续 sanity check，不进入默认平台参数、默认模型架构或默认验收标准。

这里的“剥离”只针对公司临时资料、10 kW 台架、DQ60、旧标定结果等低可信产品参数，不针对 MathWorks 官方案例和官方库块。Route A 的高质量来源应是更高比例复用官方系统级 PEMFC 案例、官方 FuelCell 组件、官方 BOP/solver/工作区配置，再用文献量级和工程经验补齐 cEGR 特有支路。纯手搓只允许作为官方资产覆盖不到的最小必要补丁。

参数来源分为三层：

| 层级 | 角色 | 允许来源 | 禁止事项 |
|---|---|---|---|
| `platform_default` | 默认运行真源 | MathWorks 官方案例、公开文献量级、工程经验自洽匹配 | 不读取 10 kW 台架、DQ60、公司临时资料或旧标定结果 |
| `scaling_rule` | 功率等级迁移规则 | 电堆面积/片数、流量、容积、阀面积、冷却能力等物理量级缩放 | 不把单一产品数据外推成通用规律 |
| `external_case` | 外部案例/历史资料 | 10 kW 台架、DQ60、旧简化台架模型、公司资料、旧审计结果 | 默认禁用；不得参与 Route A 默认初始化链 |

## 1. 建模目标与边界

状态：方向已从“自建 Core Model 深化”调整为“官方 Gas Mixture PEMFC 基准模型派生”。10 kW 台架数据、DQ60、公司临时资料和旧标定结果只作为 `external_case`，不反向定义通用架构、默认参数或验收标准。

| 项目 | 已确认内容 | 建模含义 |
|---|---|---|
| 第一版目标 | 在官方无 cEGR PEMFC 系统上插入阴极尾气循环支路，先跑通 no-EGR 与低 EGR 稳态结构 | 模型继承官方 PEMFC 主系统，不重新搭建 stack、阳极、热端、电负载和基础测量 |
| 研究对象 | 阴极 cEGR 对 O2 浓度、湿度、压力、电压的影响 | 必须显式建阴极物种、湿度、压力和电堆电压耦合 |
| 建模优先级 | 优先建立系统级设备模型和方法论；性能评估与策略开发在模型成立后推进 | 第一阶段不以数据拟合或误差表为目标 |
| 物理网络状态 | 容腔压力、温度、物种库存等状态正是本模型区别于简化经验模型的核心 | 不为简化稳态而删除容腔和物种库存；稳态只是运行工况与验收方式 |
| 控制策略 | 暂不优化控制器，但保留控制接口 | EGR 阀、背压阀、入口边界、电流负载等应有命令输入或可替换接口 |
| 新鲜空气入口 | 优先继承官方 `Oxygen Source`、`Compressor Volume`、`Cathode Humidifier` 的边界结构 | 外部案例配置可固定/旁路部分 BOP；不先拆掉官方入口链路 |
| 加湿器 | 官方模型已含 `Cathode Humidifier`，路线 A 先保留并明确 cEGR 回注位置 | 若台架无加湿器，可在派生配置中旁路或降级，但不能在母版层面删除证据链 |
| 氢气侧 | 继承官方 `Hydrogen Source`、`Anode Humidifier`、`Anode Gas Channels`、阳极 `Recirculation` | 阳极回流只作结构参考，不误判为 cathode-cEGR |
| 冷却侧 | 继承官方 `Heat Dissipation` 和 MEA 热端结构 | 第一版只改阴极尾气路径，热端不作为首轮重构对象 |
| 数据定位 | 10 kW 台架数据只用于显式 `external_case` smoke test、物质流 sanity check 和演示工况 | 模型体系必须可扩展到大功率电堆和车载结构，不被 10 kW 尺寸绑定 |

## 2. 模型路线分层

| 层级 | 作用 | 建模内容 | 数据角色 |
|---|---|---|---|
| `Route A Baseline Derivative` | 官方 Gas Mixture PEMFC 派生母版 | 继承官方 `FuelCell` 四物种域、MEA、阳极/阴极通道、入口/排气、热端、电负载、测量；只新增 cathode-cEGR 支路和必要接口 | 以官方示例参数与模型工作区为初值；先不依赖 10 kW 数据 |
| `Route B Archive/Reference` | 自建 Core Model 归档 | `99_历史归档/2026-07-14_RouteB_Core_Physical/PEMFC_cEGR_Core_Physical_v01.slx` 中的入口 mixer、出口/分离、EGR loop、背压边界、接口命名 | 仅作历史追溯；当前不再默认查阅或用于排障 |
| `Bench External Case` | 10 kW 台架外部案例 | 入口边界源、DQ60 等效增压设备可选、无加湿器、最小供氢边界、简化冷却边界 | 默认禁用；只用于显式 smoke test、边界示例和物质流检查 |
| `Vehicle Configuration` | 车载系统扩展 | 空压机、中冷器、加湿器、完整冷却回路、控制器、大功率电堆、整车功率接口 | 需要后续供应商/文献/实验数据支撑 |
| `Scaling Rules` | 功率等级迁移 | `N_cell`、`area_cell`、流道体积、阀面积、气源能力、冷却容量、热容量、传感器量程参数化 | 不用 10 kW 数据外推为通用规律 |

路线 B 的完整留存记录已分离至 [Simulink_PEMFC_cEGR_路线B留存归档_v01.md](Simulink_PEMFC_cEGR_路线B留存归档_v01.md)。2026-07-14 已将路线 B 模型、参数脚本、旧审计脚本和旧整改要求移入 `99_历史归档/2026-07-14_RouteB_Core_Physical/`。主文件只保留路线 B 的历史定位；后续 Route A 工作不再默认查路线 B 文件，只在需要解释早期决策来源时追溯。

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
| 输入 | `air_mdot_in` | kg/s | 阴极供气流量边界 | `external_case` 可使用边界源；Vehicle Configuration 可由空压机输出 |
| 输入 | `air_T_in` | K | 阴极供气温度 | 入口源/入口容腔温度 |
| 输入 | `air_p_in` | Pa | 阴极供气压力 | 入口压力边界或增压设备出口 |
| 输入 | `air_humidity_in` | kg/kg 或质量分数 | 阴极供气水分 | 模型内部优先使用质量变量，展示时输出 RH |
| 输入 | `egr_valve_cmd` | 1 或 % | EGR 阀开度/控制量 | 可变局部阻力或受控阀面积 |
| 输入 | `egr_valve_input` | 1 或 % | `external_case` 中实验记录的阀输入值 | 外部案例可映射到等效开口面积/流量系数 |
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
| EGR 阀 | 优先 `Local Restriction (FC)`，必要时封装为命令到有效面积的参数化子系统 | 最大开口面积、流量系数、开度-面积关系、临界流参数 | `external_case` 可用目标开度/输入值/EGR 率做 sanity check，不决定通用阀模型 |
| 背压阀 | `Local Restriction (FC)` + `Reservoir (FC)` | 出口压力、阀开度、流量系数 | `external_case` 可先给定出口压力；后续再引入阀门细节 |
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
2. 目前实验记录中可用的“目标开度 6%、输入值 61%、EGR 率 14.7%”这类点，只用于 `external_case` 的 sanity check，不能当成全域阀门 map。
3. 若没有阀前后压力，则 EGR 阀标定会和背压边界、管路阻力耦合；第一版应把该不确定性显式保留。
4. 后续策略模型可以把 `egr_valve_cmd -> A_eff -> mdot_egr -> egr_ratio_comp_in / egr_split_ratio_out` 作为控制链，不直接把 EGR 率当输入。

## 7. External Case 资料隔离

10 kW 台架资料已从当前工作树外置归档，只保留外部案例语义，不作为 Route A 母版的架构依据、默认参数来源或默认验收标准。历史只读确认的数据目录原为：

`E:\agentwork_pemfc_cEGR_0519\00_支撑材料\实验数据-设备说明书`

当前默认平台不要求该目录存在；若后续确需 10 kW 外部案例回放，应先从外部归档恢复资料，并保持显式 `external_case` 开关。

可用材料类型和用途：

- 稳态测试数据：仅用于显式启用的 `external_case` smoke test、物质流 sanity check 和演示工况。
- 电堆与推荐工况：仅用于 10 kW 外部案例，不作为通用模型参数上限或默认真源。
- 设备/图片/PDF：用于解释台架特殊设备和边界条件。
- 加湿器资料：位于 `加湿器数据/`，台架 v01 暂不使用，仅作为车载扩展资料。

需要注意：`DQ60氢气循环泵MAP图` 是实验中受设备限制被用作空压机替代的设备资料，其功能层面仍对应做功、升温、增压。它只能作为 `external_case` 的背景说明或显式回放依据，不得进入 Route A 默认 compressor/BOP 参数，也不得外推成车载空压机 map。

## 8. 平台默认参数治理

| 优先级 | 治理项 | 处理原则 |
|---:|---|---|
| 高 | `platform_default` 与 `external_case` 严格分离 | 默认初始化链只加载官方案例、文献量级和工程经验匹配参数 |
| 高 | EGR 阀目标开度、输入值、EGR 率样本只能说明台架实例 | 可用于外部案例 sanity check，不反向定义通用阀门模型 |
| 高 | 背压阀没有开度记录 | 默认平台采用官方泄压/背压结构和工程量级；外部案例可另设出口压力边界 |
| 中 | 水分离/冷凝缺少实测排水、温度或压降 | Route A 仍保留水管理模块，参数先用组件默认或文献范围 |
| 中 | 入口湿度字段 | 模型守恒优先使用含湿量/水质量分数，展示输出 RH |
| 中 | DQ60 作为空压机替代设备 | 仅可用于外部案例说明，不可代表默认 BOP 或车载空压机 |

## 9. 功率扩展原则

本项目不应被 10 kW 台架数据锁死。后续目标是形成可迁移的 PEMFC-cEGR 系统模型体系，支持更大功率电堆和车载结构，例如 240 kW 商用车 PEMFC 系统。

第一版模型采用如下原则：

- `N_cell`、`area_cell`、通道/歧管体积、阀面积、冷却容量、气源能力等参数必须参数化，不写死为 10 kW。
- 10 kW 数据只用于显式 `external_case` 验证物质流、接口、边界语义和模型能否跑通，不作为模型物理上限。
- 若产品/台架数据不足，默认平台仍采用官方示例参数、文献范围或工程默认值形成可运行模型，不向劣质数据妥协。
- 后续车载扩展时，再加入空压机、加湿器、中冷器、完整冷却回路、控制器和大功率电堆参数。

## 10. 暂定建模验收

第一版验收不以控制策略最优、10 kW 数据拟合或电压误差最小为目标，而以通用系统模型结构成立为目标：

1. `.slx` 中存在完整的 FuelCell 四物种物理网络、MEA、电端口、热端口、阴极 cEGR 支路、背压/排气边界和必要传感器。
2. 能运行一个代表性稳态工况，不出现结构错误、物理端口断连或明显非物理状态。
3. 输出 `V_stack`、阴极入口/出口 O2、RH、压力、温度、EGR 流量/比例、热流等关键量。
4. 后续可用 10 kW 数据做显式 `external_case` smoke test 或子集对照；误差表不是建模第一步的完成条件。

## 11. 路线 A 基准模型派生计划 v0.3

本节是后续进入 Simulink 前的主执行依据。原则是：不修改官方归档模型，不继续从路线 B 自建骨架深化；先复制官方 Gas Mixture 示例到工作区派生副本，再以最小拓扑改动加入 cathode-cEGR 支路。若 MathWorks 官方 PEMFC、FuelCell 库块、BOP 或后处理示例已有可复用结构，应优先迁移和封装；只有 cEGR 专属拓扑、接口语义或官方案例缺口才允许手工搭建。

### 11.1 基准模型与工作副本

| 项目 | 决定 |
|---|---|
| 官方归档母版 | `00_支撑材料/MathWorks_Official_Examples_R2025b/01_GasMixture_PEMFuelCellSystemWithCustomLibrary/PEMFuelCellSystemWithACustomLibrary.slx` |
| 派生模型目录 | `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/` |
| Route A 脚本目录 | `04_Simulink物理网络模型/03_脚本/RouteA_GasMixture_Derived/` |
| Route A 说明目录 | `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/` |
| Route A 规范基础模型 | 唯一模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；`routeA_cegr_enabled` 在 update-diagram 时选择 cEGR 直连或 no-cEGR 隔离 |
| 参数起点 | 继承官方 `PEMFuelCellSystemWithACustomLibraryParameters.m` 的 model workspace 变量，再新增 `cegr_*` 参数组 |
| 模式差异 | `cEGR_Mode_Selector/withCEGR_PassThrough` 保留跨子系统回流直连；`noCEGR_Isolation` 以官方 `Infinite Flow Resistance (FC)` 隔离该连接，使回流质量流量为零，同时保留原阴极主排气支路 |
| 禁止事项 | 不覆盖官方归档 `.slx`；不把路线 B 模型另存为路线 A；不先删除官方阳极、热端、电负载和测量结构 |

### 11.2 最小插入路径

```text
PEMFuelCellSystemWithACustomLibrary
  Oxygen Source
    Environment / Air Intake
      -> FreshAirRestriction or inherited inlet boundary
      -> New CompressorInletMixer
      -> existing Compressor
      -> existing Compressor Volume

  Cathode Gas Channels.C
    -> New CathodeOutletResistance
    -> New CathodeOutletChamber
    -> three-way split:
         branch Exhaust -> existing Cathode Exhaust/Pipe -> Pressure Relief -> Environment
         branch EGR -> CathodeWaterSeparator_FC -> EGRValve -> EGRPipe
                      -> New CompressorInletMixer

  Anode Gas Channels.C
    -> AnodeWaterSeparator_FC
    -> existing anode Recirculation.R
```

优先插入点：

1. `Cathode Gas Channels.C` 到 `Cathode Exhaust` 之间作为出口分支点。
2. 回流入口优先接到 `Oxygen Source` 内 `Air Intake` 与 `Compressor` 之间的压缩机入口混合容腔，而不是接到 `Cathode Humidifier` 后或 `Cathode Gas Channels.B` 前。
3. 保留排气支路，不能把全部阴极出口气体强制回流。
4. 不把 EGR 支路直接接到理想 `Air Intake` reservoir 上；否则环境边界会钳制压力、温度和组分，削弱甚至吞掉回流耦合。
5. 第一版 cEGR 子系统命名为 `CompressorInletCoupledEGR`。它表示“阴极出口背压 + EGR 阀/管路压降 + 压缩机入口近环境压力/吸入流量”的耦合，不表示独立阴极回流泵。

### 11.2.1 压缩机入口耦合规则

| 建模对象 | 操作规则 | 验证口径 |
|---|---|---|
| `Air Intake` | 保留为新鲜空气环境边界或 reservoir | 只提供新鲜空气，不直接作为混合节点 |
| `CompressorInletMixer` | 新增有限容积 chamber，接收新鲜空气和 EGR 回流 | 其压力应近似环境压力，组分随 EGR 改变 |
| 新鲜空气支路 | 第一版采用 `Air Intake -> CompressorInletMixer`；入口 restriction/source 后续按需求再加 | 新鲜空气流量可由压缩机总吸入需求和 EGR 回流共同决定 |
| EGR 支路 | `CathodeOutletChamber -> EGRMassFlowSensor -> CathodeWaterSeparator_FC -> EGRValve -> EGRPipe -> CompressorInletMixer` | 沿流向压力逐级下降；`egr_mdot` 由压差、阀面积和压缩机吸入状态共同决定 |
| 压缩机 | 继承官方 compressor 与 compressor map/control | 压缩机入口组分由 mixer 输出决定，压缩机出口进入官方 `Compressor Volume` |
| 传感器 | 出口容腔和压缩机入口混合腔优先复用 Chamber 自带 `pC/TC/yC_i` 输出；EGR 阀前后用 p/T sensor；RH 和冷凝质量流先作为后续 Simscape log/水管理项 | 能审计 `p_outlet > p_egr_up > p_egr_down ~ p_comp_in` 的方向性 |

### 11.3 继承与新增子系统

| 类别 | 子系统/组件 | 路线 A 处理 |
|---|---|---|
| 直接继承 | `Membrane Electrode Assembly` | 不重建；只核查参数、端口和输出语义 |
| 直接继承 | `Anode Humidifier`、`Anode Gas Channels`、`Hydrogen Source`、`Anode Exhaust`、阳极 `Recirculation` | 保持官方主结构；阳极回流只作结构参考，不能误判为 cathode-cEGR |
| 直接继承 | `Oxygen Source`、`Cathode Humidifier`、`Cathode Gas Channels`、`Cathode Exhaust` | 保留主链路，局部拆接阴极出口和回流入口 |
| 直接继承 | `Heat Dissipation`、`Electrical Load`、`Measurements` | 保留，避免路线 B 的热端和 KPI 占位问题 |
| 新增 | `CathodeOutletChamber` | 提供出口库存、压力、温度和组分测量，必要时由 `Constant Volume Chamber (FC)` 实现 |
| 新增 | `CathodeOutletResistance` | 位于官方 `Cathode Gas Channels` 容腔与新增出口容腔之间，用 `Flow Resistance (FC)` 提供 `dp -> mdot` 关系，避免两个库存容腔零阻抗直连导致初始化方程奇异或强耦合 |
| 新增 | `CathodeWaterSeparator_FC` | 位于 `EGRMassFlowSensor` 与 `EGRValveRestriction` 之间；A8 第一版采用 `Flow Resistance (FC)` 表达 FC 域水分离器 L2 压降接口，避免未标定库存状态导致 IC failure |
| 新增 | `AnodeWaterSeparator_FC` | 位于 `Anode Gas Channels.C` 到 `Recirculation.R` 的阳极回流支路；A8 第一版采用 `Flow Resistance (FC)` 表达阳极半封闭回路的水分离接口 |
| 新增 | `SeparatorOrCondensation` | MATLAB Function KPI observer；只根据出口 `p/T/y_i` 与 EGR/排气流量估算 `routeA_m_water_sep`，不作为物理管路设备，也不改写气体组分 |
| 新增 | `CompressorInletMixer` | 位于 `Air Intake` 与 `Compressor` 之间，混合新鲜空气和 cEGR 回流，建议由 `Constant Volume Chamber (FC)` 实现 |
| 新增 | `CompressorInletCoupledEGR` | `CathodeWaterSeparator_FC` + `Local Restriction (FC)` + EGR pipe + flow/pressure sensors；第一版不设置独立回流泵 |
| 新增 | `RouteA_Measurements` | 输出 `V_stack`、`i_stack`、`p/T/RH/x_i`、`egr_mdot`、`egr_ratio_comp_in`、`egr_split_ratio_out`、`m_condensed`、`Q_stack` |

### 11.4 参数与初始化策略

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

### 11.5 分阶段执行计划

Route A 后续不按“直接代入台架参数”推进，而按“通用平台参数治理、基底多工况验证、边界驱动探明、控制开放度治理、主模型入口收口后，再派生台架配置与车载配置”的层级推进。A8 设备链补齐后，已按 Phase A9 完成当前 50 kW 通用平台的参数表、缩放规则和验证闭环治理；A9.5-A9.9 已完成多工况、边界、执行器、FCU/BoP 和背压接口审计。Phase A10 先收口主模型、参数脚本、长期 runner、阶段审计入口和模型内可视化。无 cEGR / 有 cEGR 是同一模型的编译期物理变体，不是台架或车载派生；随后才进入 A11/A12 结构配置派生：

| 层级 | 角色 | 阴极侧结构 | 参数原则 |
|---|---|---|---|
| `RouteA_Platform` | 通用 PEMFC-cEGR 系统平台 | 空压机/增压源、可选中冷、可选加湿器、电堆、背压/排气、水汽分离、cEGR 阀和回流支路 | `platform_default`；官方案例、文献量级、工程经验匹配 |
| `Bench_Config_v1` | 第一版台架测试结构配置 | 空压机/等效供气、中冷器、电堆、阀门、水汽分离器、cEGR；无加湿器 | 仍用通用默认参数；不读取 10 kW 数据，不追求产品拟合 |
| `Vehicle_Config_v1` | 后续车载结构配置 | 空压机、中冷器、加湿器、电堆、阀门、水汽分离器、cEGR，并逐步补完整 BOP/控制接口 | 采用 `scaling_rule` 和可替换设备性能接口，不绑定公司临时资料 |

关键门槛：只有当模型结构和模块语义足以支撑“基于设备性能的燃料电池阴极尾气循环系统模型”时，才进入详细参数表、性能曲线或设备匹配；若结构不足，只允许使用经验默认参数跑通和审计，不做伪精细标定。

| 阶段 | 目标 | 完成条件 |
|---|---|---|
| Phase A0 | 建立派生工作副本并只读复核官方基线 | 工作副本存在；官方归档未修改；`model_overview` 能读到原顶层结构 |
| Phase A1 | 运行或计划 no-EGR 官方基线 smoke | 若用户允许运行，则完成最小 smoke；若不运行，至少完成结构检查和参数读回 |
| Phase A2 | 在 `Oxygen Source` 内拆出 `Air Intake -> Compressor` 连接并加入 `CompressorInletMixer` | 新鲜空气仍能进入 compressor；mixer 的 p/T/x_i 可读回 |
| Phase A3 | 在阴极出口加入 split、出口容腔和排气保留支路 | `Cathode Gas Channels.C`、`Cathode Exhaust`、新增出口容腔连接关系可读回 |
| Phase A4 | 加入 `CompressorInletCoupledEGR` 并回到 `CompressorInletMixer` | `egr_mdot` 非占位输出；排气支路仍存在；压缩机入口组分受回流影响 |
| Phase A5 | 加入水分离/冷凝等效与测量接口 | 第一版先完成 p/T/y_i 与 EGR 压力链诊断；RH 与 `m_condensed` 进入后续水管理细化 |
| Phase A6 | no-EGR 与低 EGR smoke 验证 | no-EGR 近似回到官方基线；低 EGR 下压缩机入口 O2 降低或湿度回灌方向可解释；若初始化阻塞，需记录失败栈并先修初值策略 |
| Phase A7 | 平台结构充分性审计与参数层剥离 | 判定当前模型是否足以支撑设备性能型 PEMFC-cEGR；默认参数来源分层清楚；旧台架案例保持默认禁用 |
| Phase A8 | 通用平台设备链补齐 | 阴极主链、cEGR 支链、阳极基本气路、冷却基本回路和 KPI 测量接口完整；加湿器可旁路，水汽分离器/中冷器有 L2 等效接口 |
| Phase A9 | 参数表、缩放规则和验证闭环治理 | 以 `400 cells x 280 cm^2`、约 50 kW 通用平台为当前内核；每类参数有来源层级、单位、适用范围、模块路径、关键计算包络和可替换接口；smoke/audit 脚本收敛为少数规范入口 |
| Phase A9.5 | 基底模型多工况仿真测试 | 使用 A9 参数基线构造 3 个负载档 x 3 个 EGR 档共 9 个稳态功能性工况；小/中/大负载在不同 EGR 下取一致电流密度或等效功率目标；验收计算收敛、KPI 有限、压力链合理、EGR 方向性和负载趋势 |
| Phase A9.6 | 边界驱动与气路传递审计 | 只读盘点电负载、气体组分、气体温压状态和气体质量流量边界；区分外部输入、设备参数、初始条件、测量量和物理网络求解结果；形成控制开放度缺口表 |
| Phase A9.7 | 控制执行器与宏观边界量化关系审计 | 用 `SimulationInput` 扰动功率、OER setpoint、cEGR 阀面积、加湿器 gain 和冷却 setpoint；量化执行入口对流量、EGR、O2/H2O、RH、水 KPI 和功率跟踪的影响；不调 PID、不新增控制器、不保存 `.slx` |
| Phase A9.8 | FCU/BoP 控制接口显式化 | 在模型内新增/整理空气和 cEGR 控制接口：空气侧支持 `target_mdot`、`target_oer`、`direct_cmd`；cEGR 侧新增顶层 `FCU_BoP_Control`，支持 `target_ratio` 与 `direct_area`；脚本改为工况设定和审计入口 |
| Phase A9.9 | 阴极背压/出口压力控制接口规整 | 将现有 `Pressure Relief Valve` 明确为目标压力驱动的 backpressure regulator；新增 `routeA_target_p_ca_out_MPa` 工况接口并审计目标压力到出口压力的响应 |
| Phase A10 | Route A 主模型与复用入口收口 | 整理主模型顶层操作/诊断可视化、参数脚本分区、日常 demo runner、A10 收口审计和阶段脚本分类；不新增物理机理、不重调控制器 |
| Phase A10.1 | Route A 收口强化 | 在 A10 入口基础上补齐设备语义、参数 profile 边界、模型可读性和紧凑回归记录；不进入 A11 台架配置、不做产品拟合 |
| Phase A11 | `Bench_Config_v1` 台架结构配置 | 在 A10 收口后，形成无加湿器阴极结构配置；空压机/中冷器/电堆/阀门、水汽分离器、cEGR 和背压边界链路明确；不读取旧台架数据 |
| Phase A12 | `Vehicle_Config_v1` 车载结构配置 | 在 A10/A11 收口后，形成含加湿器车载结构配置；逐步补完整 BOP 接口和功率等级 scaling；仍不绑定公司临时产品参数 |

A9.5 初始工况矩阵不作为产品性能声明，只作为 A9 通用基底模型的功能性仿真验收。负载档位在不同 EGR 档下保持一致，优先沿用 A9 公式包络中的三档电流密度；若当前模型仍采用官方功率命令链路，则脚本可由电流密度换算等效目标功率后驱动模型，并在结果中回报实际电流、实际功率和实际电压。

| 负载档 | 电流密度 | 电堆电流 | 等效功率量级 | 运行边界原则 |
|---|---:|---:|---:|---|
| 小电流 | `0.2 A/cm^2` | `56 A` | `~17.5 kW` | 较低温度、较低压力、较大计量比、较低冷却流量 |
| 中电流 | `0.7 A/cm^2` | `196 A` | `~51 kW` | A9 名义点附近，温压、计量比和冷却采用平台名义设置 |
| 大电流 | `1.2 A/cm^2` | `336 A` | `~78 kW` | 较高温度、较高压力、较小但仍有裕度的计量比、较高冷却流量 |

| EGR 档 | 初始阀面积比例 | 验收方向 |
|---|---:|---|
| no-EGR | `1e-6` | `egr_ratio_comp_in` 接近零，压缩机入口组分近似无回流影响 |
| low-EGR | `5e-4` | 同一负载下 EGR 指标高于 no-EGR，压力链和 KPI 仍有限 |
| mid-EGR | `2e-3` | 同一负载下 EGR 指标高于 low-EGR，压缩机入口 O2 下降或湿度回灌方向可解释 |

A9.5 输出应以 summary table 为主，默认包含：case id、负载档、EGR 档、目标功率或目标电流密度、实际功率、实际电流、stack 电压、`egr_ratio_comp_in`、`egr_split_ratio_out`、阴极入口/出口压力与温度、RH、分离水 KPI、热量估算、压力链布尔值、KPI 有限性布尔值、失败栈摘要。默认不导出全量 timeseries；若确需保留仿真数据，应放入任务专用输出目录，并区分 summary 与 slim MAT 数据。

### 11.6 路线 A 验收标准

1. 官方归档模型未被覆盖，所有改动只在路线 A 工作副本中发生。
2. `model_read(depth=0/1)` 能追溯 cEGR 插入点：阴极出口、separator、EGR 支路、压缩机入口混合腔、排气支路。
3. no-EGR 模式下 cEGR 支路可关闭，模型行为不应明显破坏官方基线。
4. 低 EGR 模式下 `egr_mdot > 0`，`egr_ratio` 定义为 `EGR 质量流量 / 压缩机总入口质量流量`，并可同时报告 `EGR 质量流量 / 阴极出口总质量流量` 作为分流比。
5. 输出至少覆盖 `V_stack`、`i_stack`、`p_ca_in/out`、`T_ca_in/out`、`xO2_ca_in/out`、`xH2O_ca_in/out`、`RH_ca_in/out`、`egr_mdot`、`egr_ratio_comp_in`、`egr_split_ratio_out`、`m_condensed`、`Q_stack`。
6. 不把阳极 `Recirculation` 当作 cathode-cEGR；报告中必须明确两者区别。
7. EGR 支路压力链需符合 `p_cathode_out > p_separator/egr_up > p_egr_down >= p_compressor_inlet` 的主方向；允许小幅动态波动，但不允许稳态长期反向。
8. 第一版不要求 10 kW 电压误差最小，不以误差表作为路线 A 建模完成条件。
9. A7 不验收产品拟合或台架误差，只验收默认平台参数治理、源头隔离、粗量级匹配和 KPI 语义完整性。
10. A7 之后的详细参数设置必须通过结构充分性门槛：若缺少中冷器、水汽分离器、阀门、旁路、阳极基本气路、冷却基本回路或关键 KPI 接口，则先补结构，不做精细参数化。
11. A8 设备链补齐后，A9 当前平台参数治理已完成第二轮收口；进入配置派生前必须完成 A9.5-A9.9 和 A10 主模型入口收口。
12. A9.5 不验收产品拟合或台架误差，只验收 9 个功能性工况的可计算性、关键 KPI 有限性、压力链合理性、EGR 档位方向性和负载趋势一致性。
13. A9.6 不修改 `.slx`，只验收边界输入清单、气路节点传递关系、现有测量口径和控制接口缺口是否讲清楚。
14. 台架版和车载版必须继承同一套通用平台参数基线与缩放规则，再做 A11/A12 结构改版。
15. 无 cEGR / 有 cEGR 必须作为同一模型的规范物理变体表达，共享 `platform_default`、顶层子系统语义和非 cEGR 网络；差异只允许位于明确标记的 `cEGR_Mode_Selector` 回流隔离接口。台架版和车载版仍必须作为通用平台配置或变体表达，不复制出互相割裂的模型；台架版无加湿器应通过旁路/禁用实现，不能从通用平台删除加湿器能力。
16. A10 验收主模型与复用入口，不验收产品拟合或新控制性能：顶层操作/诊断标注可读回，参数脚本分区清楚，`run_routeA_platform_demo.m` 可作为日常入口，`run_routeA_a10_entrypoint_audit.m` 可完成 preflight、demo、A9.8 最小回归和 A9.9 名义压力回归。

### 11.7 当前执行记录

首次执行日期：2026-07-07；A9 收尾复验日期：2026-07-10；A9.5 多工况仿真测试日期：2026-07-10；A9.6 边界驱动审计日期：2026-07-10；A10.1 收口强化日期：2026-07-14；A10.3 单模型全工况复验日期：2026-07-15。<br>
工作副本：`04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；无/有 cEGR 由 `routeA_cegr_enabled` 控制的 `cEGR_Mode_Selector` 变体提供。

| 阶段 | 当前状态 | 证据 |
|---|---|---|
| Phase A0 | 已完成 | 已从官方 Gas Mixture 示例建立工作副本；官方归档未覆盖 |
| Phase A1 | 已完成结构级基线 | model workspace 能从复制目录参数脚本加载；`model_overview` 能读到官方顶层结构 |
| Phase A2 | 已完成 | `Oxygen Source` 内已形成 `Air Intake -> CompressorInletMixer -> Compressor/Compressor Map in`；入口 restriction 已暂缓以降低初始化耦合；`update diagram` 通过 |
| Phase A3 | 已完成 | 顶层已形成 `Cathode Gas Channels.C -> CathodeOutletChamber -> Cathode Exhaust.C`；排气支路保留；`update diagram` 通过 |
| Phase A4 | 已完成第一版物理闭环 | 已形成 `CathodeOutletChamber.C -> EGRMassFlowSensor -> EGRValveRestriction -> EGRPipe -> Oxygen Source.cEGR -> CompressorInletMixer.C`；`egr_mdot` 已接入 `EGR Diagnostics`；`update diagram` 通过 |
| Phase A5 | 已完成第一版诊断与等效冷凝参数化 | `PEMFuelCellSystemWithACustomLibraryParameters.m` 已新增 `cegr_*` 参数；`CathodeOutletChamber`、`EGRPipe`、`CompressorInletMixer` 已启用水为可冷凝组分；出口/入口 p/T/y_i 改用 Chamber 自带输出，EGR 阀前后压力用 PT sensor |
| Phase A6 | 已通过第一轮分层 smoke | `run_routeA_a6_smoke.m` gated smoke 已通过：`no_egr_isolated`、`no_egr_closed_valve`、`low_egr` 均通过 0.1/5/30 s。关键结构修复是在 `Cathode Gas Channels.C` 与 `CathodeOutletChamber.A` 之间加入 `CathodeOutletResistance`，避免两个 `Constant Volume Chamber (FC)` 零阻抗直连。低 EGR 面积已降为 `cegr_valve_area_frac_low = 5e-4`，30 s 时 `egr_ratio_comp_in ≈ 0.0168` |
| Phase A6.5 | 已完成 A6 收口审计 | 已新增 `ExhaustMassFlowSensor` 与 `Exhaust_mdot_ToWorkspace`，用于真实计算 `egr_split_ratio_out = egr_mdot / (egr_mdot + exhaust_mdot)`。`run_routeA_a6_5_audit.m` 已完成 5 点阀面积扫描：`[1e-6, 5e-4, 1e-3, 2e-3, 5e-3]` 均通过 30 s；`egr_mdot` 单调增加、压缩机入口 O2 单调下降、压力链通过。RH 与冷凝排水仍标记为 `not_available_direct_signal`，不作为 A6 硬门槛 |
| Phase A7 | 已完成收口审计 | `run_routeA_a7_platform_audit.m` 已通过 MATLAB Code Analyzer 并完成只读审计：`platform_default` 层与 `external_case` 默认禁用成立；旧 10 kW 台架回放默认以 `RouteA:ExternalCase:Disabled` 拒止；18/18 顶层必需块、5/5 `Oxygen Source` 关键块和 cEGR 连接读回通过；粗量级匹配显示约 51 kW 名义平台、压缩机 map 最大约 0.4 kg/s、名义空气需求约 0.056 kg/s、余量约 7.14 |
| Phase A8 | 已完成设备链补齐审计 | 已新增 `Intercooler_L2_Interface`、`CathodeWaterSeparator_FC`、`AnodeWaterSeparator_FC`、`SeparatorOrCondensation` KPI observer、`CathodeHumidifierBypass`、直接 `routeA_RH_ca_in/out` 和 `routeA_m_water_sep`。`run_routeA_a8_device_chain_audit.m` 已通过：5 项 A8 缺口全部关闭；`no_egr_closed_valve`、`low_egr_humidifier_on`、`low_egr_humidifier_bypass` 三组 30 s smoke 均通过；压力链、KPI 有限性和非负性通过 |
| Phase A9 | 已完成第二轮参数治理审计 | 已新增 `RouteA_A9_50kW平台参数治理_v01.md`、`RouteA_A9_50kW平台参数治理_第二轮_v01.md` 和 `run_routeA_a9_parameter_governance_audit.m`；第二轮将第一轮 3 个 warning 收敛为 50 kW 平台默认参数：`anode_tube_D=0.02 m`、`cathode_separator_mdot_nominal=0.10 kg/s`、`cegr_valve_area_frac_max=0.02`。A9 审计已通过：A8 三组 30 s 回归、`nominal_50kW_steady`、`max_cegr_area_sanity` 和第二轮硬门槛均通过 |
| Phase A9.5 | 已完成基底模型多工况仿真测试 | 已新增 `run_routeA_a9_5_multicase_functional_test.m` 和 `RouteA_A9_5_基底模型多工况仿真测试_v01.md`。9 个功能性稳态工况全部 30 s 通过：no-EGR、low-EGR、mid-EGR 分别覆盖低/中/高负载；`cases=9/9`、`trend=1`、`no_egr_close=1`、EGR 档位单调性和功率负载单调性均通过。A9.5 后重跑 `run_routeA_a9_parameter_governance_audit.m`，A9 回归仍为 `passed=1` |
| Phase A9.6 | 已完成第一轮边界驱动与气路传递审计 | 已新增 `run_routeA_a9_6_boundary_drive_audit.m` 和 `RouteA_A9_6_边界驱动与气路传递审计_v01.md`。只读审计生成 20 个边界项、13 个气路节点和 8 个控制接口缺口；`no_egr_nominal_load` 与 `mid_egr_nominal_load` 两个 30 s 证据工况通过；确认当前直接边界为功率命令、外界/氢源组分与状态、阀面积、加湿器 gain 和设备参数，阴阳极计量比、目标 EGR ratio、真实入口温压和目标质量流量控制尚未独立暴露 |
| Phase A9.7 | 已完成控制执行器与宏观边界量化关系审计 | 已新增 `run_routeA_a9_7_actuator_boundary_sensitivity_audit.m` 和 `RouteA_A9_7_控制执行器与宏观边界量化关系审计_v01.md`。17 个 30 s 工况全部完成，`generated=1`、`passed=1`；功率需求、OER setpoint、cEGR 阀面积和加湿器 gain 的关系检查通过。冷却 setpoint 仅作为短时 advisory，不作为热稳态硬结论 |
| Phase A9.8 | 已完成第一轮 FCU/BoP 控制接口显式化 | 已新增 `FCU_BoP_Control`、空气控制三模式、cEGR 目标 ratio/直接面积两模式、`EGRValveRestriction.AR` 受控面积接线和 `run_routeA_a9_8_fcu_bop_control_audit.m`。`FCU_BoP_Control` 结构检查 healthy；A9.8 矩阵已按 case filter 拆批完成 15/15，聚合结果 `generated=1`、`passed=1`；三档 `target_mdot`、三档 `target_oer`、三档 `target_egr_ratio`、五档 `direct_area` 和 nominal 组合工况均通过 |
| Phase A9.9 | 已完成第一轮阴极背压/出口压力控制接口规整 | 已将 `Cathode Exhaust/Stack Pressure` 从固定 `0.06` 改为 `routeA_target_p_ca_out_MPa - env_p`，保留官方 `Pressure Relief Valve` 作为目标压力驱动的 backpressure regulator；新增 `run_routeA_a9_9_backpressure_control_audit.m` 和审计文档。三点压力目标 0.145/0.161325/0.180 MPa 均通过，`generated=1`、`passed=1` |
| Phase A10 | 已完成入口收口 | 新增 `run_routeA_platform_demo.m`、`run_routeA_a10_entrypoint_audit.m` 和 `RouteA_A10_主模型与复用入口收口_v01.md`；`run_routeA_platform_demo.m` 已通过名义 50.96 kW 工况，`run_routeA_a10_entrypoint_audit.m` 已通过 preflight、demo、A9.8 三个最小工况和 A9.9 名义压力回归 |
| Phase A10.1 | 已完成收口强化 | 模型顶层操作注释更新为 `RouteA Operator A10.1`；参数脚本补充 air/compressor、cEGR、backpressure、water-management、anode、cooling 和 FCU-BoP control 的 profile 边界注释；A10 说明补充设备语义、L2 接口边界和紧凑回归口径；项目非官方支撑材料范围内未发现 `slprj/` 或 `.slxc` |
| Phase A10.3 | 已完成单模型全工况收口 | 根层 `cEGR_Mode_Selector` 以 `routeA_cegr_enabled` 在直连与官方无限流阻隔离间编译期切换；`run_routeA_fullcase_study.m` 的 9 个 120 s 工况全部通过，no-cEGR 实际回流为零，0.10/0.30 均跟踪，尾段实测 `lambda_ca_in > 1` |
| Phase A11 | 待启动 | 在通用平台上形成无加湿器 `Bench_Config_v1`，只作为结构配置，不做台架参数拟合 |
| Phase A12 | 待启动 | 在通用平台上形成含加湿器的 `Vehicle_Config_v1`，逐步引入车载 BOP 和功率等级缩放 |

当前 A6 的核心结论不是单纯数值容差问题，而是物理网络拓扑问题。官方 `Cathode Gas Channels` 本身是 `Constant Volume Chamber (FC)`；新增 `CathodeOutletChamber` 也是库存容腔。分层诊断显示：`no_egr_isolated` 与保留 `CompressorInletMixer` 的 no-EGR 可计算；只要把 `CathodeOutletChamber` 直接插入 `Cathode Gas Channels.C -> Cathode Exhaust` 主路径，即使不接 EGR 传感器、阀、管和入口回流，也会 IC failure。加入 `Flow Resistance (FC)` 后，完整 closed-valve 回路可计算，说明该流阻承担的是系统级 ODE/DAE 网络中必要的流量-压差关系，而不是为了“调参”硬凑收敛。

A6 当前已收口为“官方 Route A 默认模型上的 cEGR 物理拓扑与低/中 EGR 扫描成立”。它不代表 EGR 阀、出口分离器、冷凝排水、台架背压或控制策略已经完成标定。A7 已收口为“默认参数层隔离、外部案例拒止、平台最小结构读回和 stack/BOP/cEGR 粗量级匹配通过”。A8 已收口为“通用平台设备链缺口补齐”：显式中冷/后冷 L2 接口、阴极 EGR 与阳极回流两侧 FC 域水分离接口、可配置加湿器旁路、直接 RH KPI 和冷凝/分离水 KPI 均已具备模型内命名块、信号和 30 s smoke 证据。`SeparatorOrCondensation` 当前只作为 KPI observer，不替代物理设备接口。A9 已收口为“50 kW 通用平台参数基线与验证入口治理完成”：以 `400 cells x 280 cm^2` 电堆和约 50 kW 名义点为内核，第二轮将 `anode_tube_D=0.02 m`、`cathode_separator_mdot_nominal=0.10 kg/s`、`cegr_valve_area_frac_max=0.02` 作为当时的默认基线。A10.3 为覆盖 0.30 回流目标，将后者更新为 `0.05`，并用全工况 runner 复验。`run_routeA_a9_parameter_governance_audit.m` 保留 A9 历史证据，不再单独定义当前研究入口。A9.5 已收口为“基底模型 9 点多工况功能性仿真通过”：no-EGR、low-EGR、mid-EGR 分别覆盖低/中/高负载，全部 30 s 达到稳态，EGR 档位方向性和功率负载趋势通过；A9.5 后 A9 回归仍通过。A9.6 已完成第一轮只读边界驱动审计：功率命令、外界/氢源组分与状态、阀面积、加湿器 gain 和设备参数是当前主要开放入口；气体质量流量由物理网络求解。A9.7 已完成控制执行器与宏观边界量化关系审计：功率需求、OER setpoint、cEGR 阀面积和加湿器 gain 的方向性均已用 17 个短工况量化验证。A9.8 已完成第一轮 FCU/BoP 控制接口显式化：空气目标质量流量、OER 和 direct command 已进入模型内 compressor command/rpm 链路；cEGR 目标 ratio 和 direct_area 已进入 `FCU_BoP_Control -> EGRValveRestriction.AR` 链路。A9.9 已完成阴极出口压力/背压设定接口规整：现有 `Pressure Relief Valve` 明确为目标压力驱动的 backpressure regulator，`routeA_target_p_ca_out_MPa` 可直接设置阴极出口压力目标。A10/A10.1 已把这些能力收口为清晰的主模型入口、参数入口、demo runner、回归 runner、模型内操作说明和参数 profile 边界；A10.1 的紧凑回归只验收被过滤工况的完成性和 KPI 有限性，不把 A9.8 单工况 filter 输出中的全矩阵分类 `passed=0` 误判为失败。阳极 lambda/purge、阀开度型背压 PI 变体和完整热管理 FCU 仍是 A11/A12 之后的扩展项。

### 11.8 配套脚本资产

路线 A 工作副本不是单个 `.slx` 文件，但目录边界必须清楚。2026-07-14 起，`01_模型/RouteA_GasMixture_Derived/` 只保留模型本体和模型工作区直接依赖的初始化伴随文件；运行/审计脚本移到 `03_脚本/RouteA_GasMixture_Derived/`；阶段说明移到 `04_说明/RouteA_GasMixture_Derived/`；官方原始 example/plot 脚本已移入 `99_历史归档/2026-07-14_RouteA_Official_Example_Scripts/`，避免误当当前入口。

| 文件 | 当前角色 | 是否当前必需 | 处理策略 |
|---|---|---:|---|
| `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystemWithACustomLibraryParameters.m` | 模型工作区初始化脚本；定义环境、stack、冷却、compressor map、电负载等 `platform_default` 参数，并加载官方 drive cycle | 是 | 与 `.slx` 同目录保留；默认层仍不读取外部案例数据 |
| `01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystemWithACustomLibraryDriveCycle.mat` | 官方 drive cycle 数据源，被参数脚本加载 | 是，若继续使用官方 drive-cycle 工况 | 与参数脚本同目录保留；10 kW 代表点不得接入默认初始化链 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_platform_demo.m` | Route A A10 后的日常仿真入口；设置名义工况、调用 `sim()`、输出 `routeA_platform_demo_summary` | 是，长期入口 | 默认 50.96 kW、target_mdot、target_egr_ratio、target_p_ca_out、加湿器 gain 和冷却 setpoint 均走模型工作区变量；不导出 CSV/图片/全量 timeseries |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_a10_entrypoint_audit.m` | Route A A10 主模型与复用入口收口审计；检查主模型入口、参数变量、可视化注释、demo runner、A9.8/A9.9 最小回归 | 是，A10 收口入口 | 输出 `routeA_a10_entrypoint_audit`；用于确认 A10 没有把计算搬到脚本，也没有破坏 A9.8/A9.9 控制接口 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_fullcase_study.m` | 单模型全工况研究入口 | 是，唯一研究入口 | 每 case 重载模型并在 update-diagram 时选择变体；覆盖低/中/高负载与 no-cEGR/0.10/0.30，验收功率、回流、主排气和实测氧计量比 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_*.m` | A6-A9.9 阶段回归和排障脚本 | 是，阶段证据/回归入口 | 已从模型目录移出；脚本运行时会显式定位并加载 `01_模型/RouteA_GasMixture_Derived/` 下的模型 |
| `04_说明/RouteA_GasMixture_Derived/RouteA_*.md` | Route A 阶段审计和说明文档 | 是，说明入口 | 已从模型目录移出；保留 A8-A10 设备链、参数治理、边界、控制和背压接口证据 |
| `03_脚本/RouteA_GasMixture_Derived/run_routeA_a7_bench_sanity.m` | 旧 10 kW 外部案例 sanity 草稿入口 | 否，默认禁用 | 不是 A7 主入口；只允许作为显式 `external_case` 回放工具。脚本默认报错，只有显式设置 `routeA_enable_external_case_bench_10kw = true` 后才运行 |
| `99_历史归档/2026-07-14_RouteA_Official_Example_Scripts/PEMFuelCellSystemWithACustomLibraryExample.m` | 官方 live example 展示脚本归档 | 否 | 硬编码原模型名，不作为 Route A 运行入口；仅作官方原始后处理参考 |
| `PEMFuelCellSystemWithACustomLibraryPlot1IV.m` | i-v 与功率曲线绘图 | 否 | 当前引用原 `simlog_PEMFuelCellSystemWithACustomLibrary`；后续若复用，需迁移到 Route A simlog 名称和新增 cEGR 指标 |
| `PEMFuelCellSystemWithACustomLibraryPlot2Power.m` | stack 输出功率、compressor/pump 消耗、热耗散绘图 | 否 | 可复用为功率/寄生功耗基线图，但需迁移模型名和 simlog 路径 |
| `PEMFuelCellSystemWithACustomLibraryPlot3Efficiency.m` | 效率与 H2/O2 利用率绘图 | 否 | 可复用利用率计算逻辑；Route A 需增加 `egr_ratio_comp_in` 与 `egr_split_ratio_out` |
| `PEMFuelCellSystemWithACustomLibraryPlot4T.m` | stack、anode、cathode、coolant、radiator 温度绘图 | 否 | 可复用温度审计；Route A 需增加 compressor inlet / EGR loop 温度 |
| `PEMFuelCellSystemWithACustomLibraryPlot5Energy.m` | 氢气消耗、tank 压力和能量积分 | 否 | 可保留为氢耗审计，不是 cEGR 第一优先指标 |
| `PEMFuelCellSystemWithACustomLibraryPlot6Surge.m` | 阳极 N2/H2 浓度与 purge 行为绘图 | 否 | 只作阳极回流参考；不能误当 cathode-cEGR 后处理 |

脚本管理原则：

1. `.slx` 结构修改后，必须确认模型工作区仍能从参数脚本初始化。
2. 后续 A6 smoke 不直接调用官方 `Example.m`，除非先完成模型名、simlog 名、scope 名和新增 cEGR 指标迁移。
3. Plot 脚本可以作为后处理模板，但 Route A 至少应新增压缩机入口 O2/H2O、EGR 质量流量、出口分流比、压力链、RH 和冷凝/排水指标。
4. 若新增 Route A 专用脚本，优先命名为 `run_routeA_*` 或 `plot_routeA_*`，避免继续沿用官方原模型名造成误调用。

### 11.9 当前不做的事

1. 不继续修路线 B 的 37 个 `model_check` errors，除非其中某条直接影响路线 A 设计判断。
2. 不从零重建 MEA、电负载、热端和官方测量结构；不把“剥离公司劣质参数”误读为“削弱官方案例复用”。
3. 不把 Moist Air PEMFC 或 FCEV 作为主骨架；它们只作为加湿、冷却、BOP 和整车接口参考。
4. 不把台架 DQ60、加湿器、背压阀资料、10 kW workbook、旧标定 CSV 或公司临时资料写进通用母版默认参数。
5. 不在路线 A 第一版引入 AMESim；只有 Simscape 四物种网络、水分离或主动回流设备长期无法闭合时再评估。
