# Simulink/Simscape PEMFC-cEGR 材料池与模型候选比较 v01

日期：2026-07-06  
阶段：材料池盘点、功能比较、可复用性判断。  
范围：MATLAB/Simulink/Simscape 优先；不生成或修改 `.slx`；不引入 COMSOL；AMESim 仅作为后续不足时的备选。

本文件只回答“有哪些成熟材料、候选模型和可复用组件”。通用模型规格、接口契约、台架/车载/功率扩展路线已拆分到 [Simulink_PEMFC_cEGR_通用模型规格与实施路线_v01.md](E:/agentwork_pemfc_cEGR_0519/Simulink_PEMFC_cEGR_通用模型规格与实施路线_v01.md)。

## 1. 结论先行

新一代 PEMFC-cEGR 模型不应继续以旧简化 MATLAB Function 经验模型为主骨架。当前材料池已经足以支撑一条 Simscape 物理网络路线：

1. 主骨架优先采用 MathWorks 官方 `PEM Fuel Cell System with the Gas Mixture Domain` / 本机 `FuelCell` 自定义四物种气体域路线。
2. 电堆/MEA 优先采用本机官方示例库中的 `+FuelCell/+elements/MEA.ssc` 思路：电化学电压、H2/O2 消耗、水生成、膜水传输和反应热在 Simscape 组件内闭合。
3. 阴极管路、阀、容腔、传感器、源边界优先使用同一四物种气体域的官方 `FuelCell` 示例组件；若官方组件粒度不足，再参考本地 MathWorks File Exchange/GitHub 模型 `Fuel-Cell-Vehicle-Model-Simscape-25.2.1.5` 的 `GasN` 组件。
4. Powertrain Blockset / FCEV Reference Application 更适合整车能量管理、控制接口、HIL 和 mapped fuel cell 对照，不建议作为 cathode-cEGR 物理网络主骨架。
5. 旧简化台架模型只保留为边界条件、参数、工况和结果审计来源，不作为新模型的物理核心。

暂不建议进入 AMESim。理由是：本机 Simscape 已有四物种气体域、MEA、电堆热端口、管路/容腔/节流/源/传感器、自定义 compressor 参考件，足以先完成 PEMFC-cEGR 的设备级骨架。只有当四物种压缩机、冷凝分离器或 cEGR 支路在 Simscape 中无法稳定闭合，且自定义 Simscape 组件投入超过收益时，再启动 AMESim 备选评估。

## 2. 已确认材料池

| 编号 | 材料 | 类型 | 本地状态与获取方式 | 许可证/复用风险 | 初步价值 |
|---|---|---|---|---|---|
| A1 | `D:\matlab2025b\toolbox\physmod\fluids\supporting_files\example_libraries\FuelCell_lib.slx` 与 `+FuelCell` 源码 | MathWorks 官方示例库 / 自定义 Simscape 域 | 本机已有，随 MATLAB/Simscape Fluids 安装 | MathWorks 产品内使用，适合项目内参考和派生建模 | 最高。四物种 FuelCell 域、MEA、Chamber、Pipe、Restriction、sources、sensors 可直接支撑 cEGR 物理网络 |
| A2 | MathWorks 文档：`PEM Fuel Cell System with the Gas Mixture Domain` | 官方帮助文档 / 示例说明 | 已通过 MATLAB 示例打开并归档到 `MathWorks_Official_Examples_R2025b/01_GasMixture_PEMFuelCellSystemWithCustomLibrary` | 官方文档，适合引用方法和架构 | 最高。明确说明气体混合域可配置任意物种，示例包含 PEMFC stack、氢气回流、氧气消耗、水生成 |
| A3 | MathWorks 文档：`PEM Fuel Cell System` / moist air 路线 | 官方帮助文档 / 示例 | 已通过 MATLAB 示例打开并归档到 `MathWorks_Official_Examples_R2025b/02_MoistAir_PEMFuelCellSystem` | 官方文档，适合引用方法和架构 | 中高。设备链完整，含压缩机、背压阀、加湿/冷却等架构；但 cEGR 需要显式 O2/N2/H2O 回流，Moist Air 路线需谨慎 |
| A4 | Simscape Foundation Moist Air / Gas / Thermal Liquid 库 | 官方基础库块 | 本机已有，路径在 `D:\matlab2025b\toolbox\physmod\simscape\library\m\+foundation\...` | 官方库块 | 中高。适合边界、基础管路、湿空气、热液冷却，但不能单独解决 PEMFC 四物种 cEGR |
| A5 | Powertrain Blockset FCEV Reference Application | 官方 Reference Application | 已通过 `openExample("autoblks/FCEVRefApplicationExample")` 打开并归档到 `MathWorks_Official_Examples_R2025b/03_FCEV_ReferenceApplication` | 官方参考应用 | 中。适合整车控制、能量管理、mapped/detailed fuel cell 对照，不宜直接搬成台架物理网络 |
| A6 | `Fuel-Cell-Vehicle-Model-Simscape-25.2.1.5` | MathWorks File Exchange/GitHub 自定义 Simscape 模型 | 项目内已有；含 `Fuel_Cell_Vehicle.prj`、`Models/ssc_car_fuel_cell_1motor.slx`、`Libraries/Components` | `LICENSE.md` 限定与 MathWorks 产品/服务配合使用，AS IS；可在本项目 MATLAB/Simulink 环境内参考复用 | 高。`GasN` 四物种域、compressor、pipe、restriction、reservoir、fuel cell voltage、membrane water 等对 cEGR 极有参考价值 |
| A7 | 当前简化台架模型 `01_自吸方案/03_台架测试_10kW_简化版` | 项目已有 Simulink/MATLAB Function 标定型模型 | 本地已有，可运行，含 29 工况审计链 | 自研资产 | 只做边界/参数/审计基准。不能作为新一代设备级物理网络主骨架 |
| A8 | 论文/社区 Simulink PEMFC/FCHEV 模型 | 社区/论文模型 | 未作为本轮优先下载对象 | 许可证、方程完整性和可维护性不确定 | 低到中。只用于补充某个方程或参数范围，不作为骨架 |

## 3. 关键候选模型比较

| 候选 | 架构性质 | 气体/物种 | 主要方程或物理内核 | 对 cEGR 的适配性 | 取舍 |
|---|---|---|---|---|---|
| 官方 Gas Mixture PEMFC / 本机 `FuelCell` 示例库 | Simscape 自定义物理域 + 设备网络 | 四物种：N2/O2/H2/H2O；水可冷凝 | 质量守恒、能量守恒、物种守恒、Nernst 电压、活化/欧姆/浓差损失、H2/O2 消耗、水生成、膜水迁移、反应热 | 强。cEGR 的核心就是阴极尾气中 O2/N2/H2O 的回流、稀释、冷凝和压力耦合 | 推荐为主骨架 |
| 官方 Moist Air PEMFC System | Simscape 物理网络 + 完整 BOP 示例 | 阴极常用 moist air；阳极/阴极分网络 | Stack、compressor、back pressure valve、humidifier、cooling、load/control 等系统级结构完整 | 中。设备链很完整，但 cEGR 若要求显式 O2/N2/H2O 回流，需要确认物种表达和接口转换 | 架构参考，不作为 cEGR 首选气体域 |
| Powertrain Blockset FCEV Reference Application | 整车 reference application | 多数用于整车和 mapped/detailed fuel cell 变体 | 车速工况、能量管理、功率分配、控制和 HIL 框架 | 中低。它解决整车策略，不直接解决阴极尾气循环物理网络 | 控制接口/整车扩展参考 |
| MathWorks File Exchange `Fuel-Cell-Vehicle-Model-Simscape` | 自定义 `GasN` 域 + 整车燃料电池动力系统 | N2/O2/H2/H2O；自定义多物种气体域 | `GasN` 管路、容腔、局部阻力、compressor、传感器；fuel cell voltage、membrane water、membrane diffusion | 强。与 cEGR 物种需求高度一致，但整车动力系统需剥离，compressor 是简化经验映射 | 重要备选和组件参考 |
| 当前简化台架模型 | Simulink MATLAB Function 标定型 | 主要由工况输入和函数计算表达 | 标定式压力、电压、温度、膜水/氧气敏感性修正 | 中。对已有台架数据、参数、边界条件非常有价值，但不是设备级物理网络 | 只做基准，不做主骨架 |

## 4. 设备级取舍矩阵

| 设备/功能 | 推荐来源 | 备选来源 | 物理内核关注点 | 取舍 |
|---|---|---|---|---|
| PEMFC 电堆/MEA | 官方 `+FuelCell/+elements/MEA.ssc` | File Exchange `+gn_supplement/+fuel_cell/cell_voltage.ssc`、`membrane_water.ssc` | Nernst 电压、损失模型、H2/O2 反应、水生成、膜水扩散/电渗拖曳、反应热 | 直接采用官方 MEA 思路，必要时借鉴 File Exchange 膜水细节 |
| 阴极气体域 | 官方 Gas Mixture / `FuelCell` 四物种域 | File Exchange `GasN.ssc` | O2/N2/H2O 质量分数、压力、温度、能量流、物种流、水冷凝 | 选定单一四物种域，避免 Moist Air 与 GasN/FuelCell 混搭 |
| 新鲜空气/入口边界 | 官方 `MassFlowSource`、`PressureSource`、传感器 | Foundation sources；当前台架工况 | 入口流量、压力、温度、湿度/水分、O2/N2 比例 | 第一配置采用可控边界源，预留 compressor 接口 |
| 空压机/增压设备 | File Exchange `GasN/BasicCompressor.ssc`；Powertrain/FCEV compressor 架构 | 当前 DQ60 map 数据、Autoblks compressor data 模板 | 压比、校正流量、校正转速、效率、功耗、出口温升 | 台架 v01 可先用边界源；策略版再接 compressor/map |
| EGR 阀/背压阀/节流 | 官方 `LocalRestriction.ssc`、Gas Mixture 压力释放阀结构 | File Exchange `GasN/LocalRestriction.ssc`；Foundation local restriction | 可变开度、孔口流、临界/非临界流、压降、焓流 | 直接复用或封装为可控阀 |
| 歧管/容腔 | 官方 `Chamber.ssc`、Foundation constant volume chamber | File Exchange `GasN/Reservoir.ssc` | 容积库存、压力动态、温度动态、物种混合 | 直接复用，作为压力链和物种库存核心 |
| 管路 | 官方 `Pipe.ssc` | File Exchange `GasN/Pipe.ssc` | 摩擦压降、壁面换热、气体库存、物种输运、冷凝 | 先短管/集总管路，后续再加分段 |
| EGR 混合点 | 官方 chamber/tee/pipe 网络组合 | File Exchange GasN network | 新鲜空气与尾气物种混合、温度混合、压力平衡 | 用物理网络混合，避免 MATLAB Function 信号混合核 |
| 冷凝/水分离器 | 官方 FuelCell 域水冷凝能力 | File Exchange `GasN/Pipe` 冷凝逻辑；必要时自定义 Simscape separator | 水蒸气饱和、冷凝质量转移、液水排出、压降 | 台架 v01 可先做等效分离器/冷凝边界；若缺块则自定义 Simscape |
| 加湿器 | 官方 PEMFC System humidifier 架构 | File Exchange `static_humidifier.ssc` | 膜加湿、热湿交换、压降 | 台架 v01 不纳入，车载扩展保留接口 |
| 中冷器/换热器 | Simscape Thermal Liquid / heat exchanger 组件；官方 PEMFC System cooling 架构 | 当前简化模型冷却曲线 | 气侧/液侧换热、压降、热容、环境散热 | 第一配置用电堆热端口 + 冷却边界；后续扩展中冷器 |
| 冷却系统 | 官方 MEA 热端口 + Thermal Liquid 网络 | 当前冷却流量/换热标定数据 | 反应热、堆温、冷却液流量、散热 | 直接接 Simscape 热/热液网络或等效热边界 |
| 电负载/功率接口 | Simscape Electrical + Simulink 控制 | 当前电流工况输入 | 电流控制、电压输出、功率、效率 | 第一配置用受控电流/负载，整车后续再扩展 |
| 传感器与控制接口 | 官方 FuelCell/GasN sensors、PS-Simulink Converter | 当前数据字段 | 压力、温度、质量流量、物种分数、RH、电压、电流 | 直接复用，接口定义见规格路线文档 |

## 5. 气体域取舍

cEGR 模型的硬要求不是“有空气管路”，而是能显式描述阴极尾气回流后 O2、N2、H2O 的守恒与混合。因此气体域优先级如下：

1. 首选：官方 Gas Mixture / `FuelCell` 四物种域。理由是它直接服务 PEMFC 示例，并在本机以 Simscape 源码和示例库形式存在。
2. 备选：File Exchange `GasN` 域。理由是它同样显式跟踪 N2/O2/H2/H2O，且提供 compressor、pipe、restriction、reservoir 等组件，适合作为补充组件或实现参考。
3. 谨慎使用：Moist Air。理由是它适合湿空气和常规 HVAC/管路，但 cEGR 要求对氧气稀释、氮气回流和水蒸气/冷凝进行统一物种核算；若使用 Moist Air，必须证明 O2/N2/H2O 语义没有被简化掉。
4. 不建议：纯 Simulink MATLAB Function 中的经验流量/氧浓度计算作为主网络。理由是守恒、压力库存、能量和物种耦合会被人为拆散，难以支撑策略研究。

## 6. 深入 Simulink/Simscape 模型盘点

盘点日期：2026-07-06  
工具：Codex MATLAB MCP，MATLAB R2025b，`model_overview`、`model_read`、MATLAB `find_system`、源码检索。  
动作边界：只读盘点；未运行仿真；未修改 `.slx`；未构建 File Exchange 派生库。

| 模型 | 位置 | Solver / StopTime | 结构规模 | 复用价值 | 风险 |
|---|---|---|---:|---|---|
| Gas Mixture PEMFC 自定义库示例 | `MathWorks_Official_Examples_R2025b/01_GasMixture_PEMFuelCellSystemWithCustomLibrary/PEMFuelCellSystemWithACustomLibrary.slx` | `VariableStepAuto` / `2500` | 约 2619 blocks；约 89 个 Simscape-like blocks | 最高。已使用 `FuelCell_lib` 四物种域和 `Membrane Electrode Assembly`，适合作为 PEMFC-cEGR 的主参考骨架 | 现有 `Recirculation` 是阳极氢气回流，不是阴极 cEGR；需要新建阴极尾气回流支路 |
| Moist Air PEMFC 系统示例 | `MathWorks_Official_Examples_R2025b/02_MoistAir_PEMFuelCellSystem/PEMFuelCellSystem.slx` | `VariableStepAuto` / `2500` | 约 2597 blocks；约 84 个 Simscape-like blocks | 高。BOP 组织、加湿器、冷却、排气、压力释放阀结构成熟 | 气体域是 Moist Air/trace gas，做 cathode-cEGR 物种守恒时不如四物种 Gas Mixture 直接 |
| FCEV Reference Application 顶层 | `03_FCEV_ReferenceApplication/FCEV/System/FCEvReferenceApplication.slx` | `VariableStepAuto` / `2474` | 约 1130 blocks | 中。用于整车系统接口、控制器、驾驶循环、能量管理参考 | 顶层是整车壳，不是台架物理网络 |
| FCEV Electric Plant | `03_FCEV_ReferenceApplication/FCEV/Plant/FCElectricPlant.slx` | `VariableStepAuto` / `2474` | 约 5679 blocks；约 201 个 Simscape-like blocks | 中。功率接口、冷却功耗、电气系统联动有参考价值 | 过大，含电池、电机、整车热管理；直接搬入台架会引入大量无关复杂性 |
| FCEV `SSCFuelCell.slx` | `03_FCEV_ReferenceApplication/FCEV/Plant/SSCFuelCell.slx` | `VariableStepAuto` / `10.0` | 约 2600 blocks；约 101 个 Simscape-like blocks | 中高。适合学习燃料电池子模型和整车接口封装 | 仍是 Moist Air 路线，不宜作为 cEGR 物种网络主骨架 |
| File Exchange `ssc_car_fuel_cell_1motor.slx` | `Fuel-Cell-Vehicle-Model-Simscape-25.2.1.5/Models/ssc_car_fuel_cell_1motor.slx` | `daessc` / `195` | 约 6249 blocks；约 111 个 Simscape-like blocks | 源码价值高，尤其 `GasN` 四物种域、compressor、pipe、restriction、reservoir、fuel cell voltage/membrane 组件 | 当前未构建 `GasN_lib`、`gn_supplement_lib`、`customMath_lib` 派生库，模型不能视为即开即用 |

### 6.1 Gas Mixture 示例关键结构

- `Membrane Electrode Assembly`：引用 `FuelCell_lib/elements/Membrane Electrode Assembly`，端口包括阳极、阴极、电端口、热端口，以及阳极/阴极 `mdot`、`T`、`x_i` 物种信号。
- `Cathode Gas Channels`：内部是 `Constant Volume Chamber (FC)`，即有库存、压力、温度、物种组成和热端口，不是纯信号混合。
- `Cathode Humidifier`：由 `Pipe (FC)`、`Composition and Humidity Sensor (FC)`、湿度控制和质量流量注入组成。
- `Cathode Exhaust`：由 `Pipe (FC)`、`Reservoir (FC)`、环境热交换和 `Pressure Relief Valve` 组成。
- `Recirculation`：由 `Constant Volume Chamber (FC)`、`Mass Flow Rate Source (FC)` 和前馈控制组成，但当前用于阳极氢气回流。

对 cEGR 的判断：MEA、FuelCell 四物种域、阴极容腔、阴极管路、排气边界、传感器、热端口结构可直接复用；阴极尾气回流、水分离器、台架入口边界和背压阀组合需要基于 `FuelCell_lib` 的 Pipe/Chamber/LocalRestriction/Source 自建。

### 6.2 Moist Air / FCEV 示例定位

Moist Air PEMFC 和 FCEV `SSCFuelCell` 的电堆方程成熟，适合对照 MEA 方程、膜水机理、冷却系统、加湿器、压力释放阀、测量和电流控制接口。但其系统气体域依赖 Moist Air/trace gas 组织，不建议作为 cathode-cEGR 主骨架。

### 6.3 File Exchange / GitHub 模型定位

项目内 `Fuel-Cell-Vehicle-Model-Simscape-25.2.1.5` 当前不能视为完整即开即用模型，因为加载时出现派生库缺失警告：

- `GasN_lib`
- `gn_supplement_lib`
- `customMath_lib`

但源码价值仍然很高：

- `+GasN/GasN.ssc`：N2/O2/H2/H2O 多物种理想气体域，水可冷凝。
- `+GasN/Pipe.ssc`、`Chamber.ssc`、`LocalRestriction.ssc`、`Reservoir.ssc`：具备物种、能量、压力动态和冷凝逻辑。
- `+GasN/BasicCompressor.ssc`：包含压比、校正流量、校正转速、polytropic 压缩过程和功率耦合，是目前最有价值的空压机参考。
- `+gn_supplement/+fuel_cell/cell_voltage.ssc`、`membrane_water.ssc`、`membrane_diffusion.ssc`：可作为电压与膜水方程交叉参考。

后续若要继续使用这套模型，应在单独工作副本中执行 Simscape library build，再做完整结构读回，不直接污染原始归档。

## 7. 路线摘要

深入盘点后，不应直接复制任何一个现成模型作为最终模型。更稳妥的路线是：

1. 以 Gas Mixture PEMFC 示例为主参考，抽取四物种域、MEA、阴极容腔、管路、排气、传感器和热端口组织方式。
2. 去掉或旁路与台架不符的车载加湿器、阳极复杂回流和完整整车动力系统。
3. 新建通用 cathode-cEGR 物理网络：入口边界、入口混合容腔、阴极通道、出口容腔、冷凝/水分离模块、EGR 阀、背压/排气边界。
4. 参数初值优先来自官方示例、成熟组件默认值、文献范围和工程默认；10 kW 台架只作为后续配置场景和 sanity check。
5. File Exchange/GitHub 的 `GasN` 只作为 compressor、管路、冷凝和膜水方程参考；除非后续证明官方 `FuelCell` 域组件不足，否则不切换主气体域。

当前判断：Simulink/Simscape 支撑仍然足够，不需要进入 AMESim。具体模型规格、接口契约和实施路线见 [Simulink_PEMFC_cEGR_通用模型规格与实施路线_v01.md](E:/agentwork_pemfc_cEGR_0519/Simulink_PEMFC_cEGR_通用模型规格与实施路线_v01.md)。

## 8. 主要证据链接

- MathWorks：[`PEM Fuel Cell System with the Gas Mixture Domain`](https://www.mathworks.com/help/hydro/ug/fuel-cell.html)
- MathWorks：[`PEM Fuel Cell System`](https://www.mathworks.com/help/simscape/ug/pem-fuel-cell-system.html)
- MathWorks：[`FCEV Reference Application`](https://www.mathworks.com/help/autoblks/ug/fuel-cell-electric-vehicle-reference-application.html)
- MathWorks：[`Local Restriction (G)`](https://www.mathworks.com/help/simscape/ref/localrestrictiong.html)
- MathWorks：[`Local Restriction (MA)`](https://www.mathworks.com/help/simscape/ref/localrestrictionma.html)
- MathWorks File Exchange：[`Fuel Cell Vehicle Model in Simscape`](https://www.mathworks.com/matlabcentral/fileexchange/82340-fuel-cell-vehicle-model-in-simscape)
- GitHub：[`mathworks/Fuel-Cell-Vehicle-Model-Simscape`](https://github.com/mathworks/Fuel-Cell-Vehicle-Model-Simscape)

## 9. 本地证据路径

- `E:\agentwork_pemfc_cEGR_0519\00_支撑材料\参考建模材料\05_成熟模型案例\simulink模型案例\MathWorks_Official_Examples_R2025b\01_GasMixture_PEMFuelCellSystemWithCustomLibrary`
- `E:\agentwork_pemfc_cEGR_0519\00_支撑材料\参考建模材料\05_成熟模型案例\simulink模型案例\MathWorks_Official_Examples_R2025b\02_MoistAir_PEMFuelCellSystem`
- `E:\agentwork_pemfc_cEGR_0519\00_支撑材料\参考建模材料\05_成熟模型案例\simulink模型案例\MathWorks_Official_Examples_R2025b\03_FCEV_ReferenceApplication`
- `D:\matlab2025b\toolbox\physmod\fluids\supporting_files\example_libraries\FuelCell_lib.slx`
- `D:\matlab2025b\toolbox\physmod\fluids\supporting_files\example_libraries\+FuelCell\FuelCell.ssc`
- `D:\matlab2025b\toolbox\physmod\fluids\supporting_files\example_libraries\+FuelCell\+elements\MEA.ssc`
- `D:\matlab2025b\toolbox\physmod\simscape\library\m\+foundation\+moist_air`
- `D:\matlab2025b\toolbox\physmod\simscape\library\m\+foundation\+gas`
- `D:\matlab2025b\toolbox\physmod\simscape\library\m\+foundation\+thermal_liquid`
- `D:\matlab2025b\toolbox\autoblks\autoblksreference\autoblkFcEvTruckStart.m`
- `D:\matlab2025b\toolbox\autoblks\autoblksreference\autoblkVirtualFCEvStart.m`
- `E:\agentwork_pemfc_cEGR_0519\00_支撑材料\参考建模材料\05_成熟模型案例\simulink模型案例\Fuel-Cell-Vehicle-Model-Simscape-25.2.1.5`
- `E:\agentwork_pemfc_cEGR_0519\01_自吸方案\03_台架测试_10kW_简化版`
