# Simulink/Simscape PEMFC-cEGR 路线 B 留存归档 v01

日期：2026-07-07
定位：本文件从 `Simulink_PEMFC_cEGR_通用模型规格与实施路线_v01.md` 分离出原路线 B 的结构探索记录、接口命名、审查结果和缺陷经验。路线 B 不再作为当前主建模路线；当前主线以官方 Gas Mixture PEMFC 派生路线 A 为准。

关联主文件：[Simulink_PEMFC_cEGR_通用模型规格与实施路线_v01.md](E:/agentwork_pemfc_cEGR_0519/Simulink_PEMFC_cEGR_通用模型规格与实施路线_v01.md)

## 11. 路线 B 留存模型状态

本节记录 `PEMFC_cEGR_Core_Physical_v01.slx` 的已完成探索、接口命名和缺口判断。自 2026-07-07 路线决策后，它不再作为主深化对象；2026-07-14 已移入 `99_历史归档/2026-07-14_RouteB_Core_Physical/`，后续只作为历史追溯资料，不再作为 Route A 当前排障入口。

### 11.1 路线 B 已有交付物与边界

| 项目 | 决定 |
|---|---|
| 留存模型文件 | `99_历史归档/2026-07-14_RouteB_Core_Physical/PEMFC_cEGR_Core_Physical_v01.slx` |
| 留存参数脚本 | `99_历史归档/2026-07-14_RouteB_Core_Physical/PEMFC_cEGR_params_v01.m` |
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

以下验收项是路线 B 原计划的一部分。路线 A 的正式验收以主路线文件第 11.6 节为准。

1. `model_read(depth=0)` 能读到 10 个顶层子系统。
2. `model_check` 不出现断线、未连接物理端口或明显结构错误。
3. 首个稳态工况能输出 `V_stack`、`xO2_ca_in/out`、`RH_ca_in/out`、`p_ca_in/out`、`egr_mdot`、`egr_ratio`、`Q_stack`。
4. 输出中不存在 NaN/Inf，压力、温度、物种分数在合理范围。
5. EGR 阀开度增大时，`egr_mdot` 和 `egr_ratio` 的变化方向应符合阀/压差物理语义。
6. 不要求第一版完成 10 kW 数据拟合，不以误差表作为模型成立条件。

### 11.9 当前模型审查结论 v0.2

审查日期：2026-07-07
审查对象：`99_历史归档/2026-07-14_RouteB_Core_Physical/PEMFC_cEGR_Core_Physical_v01.slx`（审查时原位于 `04_Simulink物理网络模型/01_模型/`）
配套脚本：`99_历史归档/2026-07-14_RouteB_Core_Physical/PEMFC_cEGR_params_v01.m`、`99_历史归档/2026-07-14_RouteB_Core_Physical/run_pemfc_cegr_core_scenario_audit_v01.m`
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
