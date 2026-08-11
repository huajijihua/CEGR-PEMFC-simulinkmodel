# Simscape Fluids 燃料电池气路组件复用调查与建模建议 v01

文件类型：支撑材料 / 官方组件复用依据

日期：2026-07-30
适用范围：PEMFC 系统级气路、阴极尾气循环（cEGR）、阳极回流/排放、空气供给、背压和气体测量

本文件只整理官方 MATLAB/Simulink/Simscape 资产及其对燃料电池气路的复用意义，不替代当前 Route A 决策真源，不直接规定当前 `.slx` 必须如何修改，也不把库中参数自动提升为 `platform_default`。

## 1. 调查结论

1. 本机 MATLAB R2025b（25.2）已安装 Simscape Fluids（25.2）。官方 `SimscapeFluids_lib.slx` 的 `Gas` 和 `Moist Air` 分支都包含阀门、节流孔、压力控制和单向控制组件，足以覆盖燃料电池气路的大部分 L2 设备级需求。
2. 官方 Gas Mixture PEMFC 示例已经把压力调节阀、阴极背压释放阀、阳极 purge valve、压缩机、管路、容腔、湿度/组分传感器和四物种气体域组织成可读的系统级气路。它是当前 Route A 最重要的气路结构参考。
3. `FuelCell_lib.slx` 不是通用气体阀门库，而是官方 PEMFC 自定义四物种 `FuelCell (FC)` 域的组件库。它包含 `Local Restriction (FC)`、`Pipe (FC)`、`Constant Volume Chamber (FC)`、源、传感器和 MEA；没有一个名为通用 `Valve` 的独立块。
4. `SimscapeFluids_lib` 中的 `(G)`、`(MA)` 块不能仅凭名称直接接入当前 `FuelCell (FC)` 端口。后续复用必须先核对 conserving port 的物理域、物种定义、压力参考、单位和初始条件；需要时应使用 `FuelCell_lib` 中域一致的限制元件或建立经过验证的接口。
5. 对 cEGR，阀门/局部阻力应属于真实气路：阴极出口分流 -> 阀或局部限制 -> 管路/容腔 -> 阴极入口混合 -> 排气。`cegr_ratio_cmd` 只能作为目标或控制命令，实际回流质量流量、组分、温度、压力和湿度必须从物理网络读回。

## 2. 证据和边界

### 2.1 本机只读盘点

本次盘点使用 MATLAB MCP 连接本机 MATLAB GUI，会话内只读执行 `which`、`load_system`、`find_system`、`get_param`，并检索已归档官方示例脚本。没有修改 `.slx`、没有保存库文件、没有运行当前 Route A 仿真。

| 项目 | 已确认内容 |
|---|---|
| MATLAB / Simulink | R2025b，25.2 |
| Simscape Fluids | 已安装，25.2 |
| 官方通用流体库 | `D:\matlab2025b\toolbox\physmod\fluids\library\m\SimscapeFluids_lib.slx` |
| 官方 FuelCell 自定义库 | `D:\matlab2025b\toolbox\physmod\fluids\supporting_files\example_libraries\FuelCell_lib.slx` |
| Gas Mixture PEMFC 示例快照 | `01_GasMixture_PEMFuelCellSystemWithCustomLibrary/` |
| Moist Air PEMFC 示例快照 | `02_MoistAir_PEMFuelCellSystem/` |
| 本次验证等级 | 库树和示例源码存在性已读回；当前 Route A 端口兼容性和运行闭环未在本次调查中重新验证 |

### 2.2 来源层级

| 标签 | 含义 | 本文件中的用途 |
|---|---|---|
| `OFFICIAL_LIBRARY` | MathWorks 随 MATLAB/Simscape Fluids 安装的库块 | 组件能力和接口候选 |
| `OFFICIAL_EXAMPLE` | MathWorks 官方 PEMFC 示例或其本地快照 | 系统气路拓扑、设备组合和观测方式 |
| `CURRENT_ROUTEA` | 当前 Route A 活动模型和现行说明 | 约束后续落地范围，不等于本次已验证 |
| `EXTERNAL_CASE` | 台架、DQ60、旧标定或历史资料 | 不能作为默认平台参数来源 |
| `UNVERIFIED` | 仅有库树、源码或结构证据，没有当前模型仿真证据 | 必须保持较弱结论，不写成已闭环能力 |

## 3. `SimscapeFluids_lib.slx` 气路组件

库入口：

```text
SimscapeFluids_lib
```

### 3.1 Gas 域（`G`）

入口：

```text
SimscapeFluids_lib/Gas/Valves & Orifices
```

已读回的主要组件：

| 类别 | 组件 |
|---|---|
| Directional Control Valves | `2-Way Directional Valve (G)`、`3-Way Directional Valve (G)`、`4-Way 3-Position Directional Valve (G)` |
| Directional / protection | `Check Valve (G)`、`Pilot-Operated Check Valve (G)` |
| Flow Control Valves | `Ball Valve (G)`、`Gate Valve (G)`、`Poppet Valve (G)`、`Temperature Control Valve (G)` |
| Pressure Control Valves | `Pressure Reducing Valve (G)`、`Pressure Relief Valve (G)` |
| Restriction | `Orifice (G)` |

适用方向：把气体网络作为干气或一般多组分气体的设备级流动网络时，可用这些块表达开关、旁通、调节、限压、泄压和孔口流动。能否用于当前 PEMFC 气路，仍取决于是否与目标网络的 `G` conserving port 和气体属性一致。

### 3.2 Moist Air 域（`MA`）

入口：

```text
SimscapeFluids_lib/Moist Air/Valves & Orifices
```

已读回的主要组件：

| 类别 | 组件 |
|---|---|
| Directional Control Valves | `2-Way Directional Valve (MA)`、`3-Way Directional Valve (MA)`、`4-Way 2-Position Directional Valve (MA)`、`4-Way 3-Position Directional Valve (MA)` |
| Directional / protection | `Check Valve (MA)`、`Pilot-Operated Check Valve (MA)` |
| Flow Control Valves | `Ball Valve (MA)`、`Gate Valve (MA)`、`Poppet Valve (MA)`、`Temperature Control Valve (MA)` |
| Pressure Control Valves | `Pressure Compensator Valve (MA)`、`Pressure Reducing Valve (MA)`、`Pressure Relief Valve (MA)` |
| Restriction | `Orifice (MA)` |

适用方向：常规湿空气阴极供气、加湿器、压缩机出口、背压控制和水蒸气相关的气路参考。若当前模型使用的是 `FuelCell (FC)` 四物种域，`MA` 块不能被视为直接替换件；它首先是湿空气域的组件候选和架构参考。

### 3.3 基础元素和测量块

`SimscapeFluids_lib` 中的基础元素还包括：

- `Gas/Elements/Flow Resistance (G)`、`Local Restriction (G)`、`Pipe (G)`、`Constant Volume Chamber (G)`、`Reservoir (G)`；
- `Moist Air/Elements/Flow Resistance (MA)`、`Local Restriction (MA)`、`Pipe (MA)`、`Constant Volume Chamber (MA)`、`Reservoir (MA)`；
- 对应的压力、温度、流量和热力性质传感器；
- `Physical Signals` 中用于将控制器输出接到物理信号控制口的转换、限幅和运算块。

在气路研究中，`Local Restriction` 或 `Orifice` 通常比直接使用一个抽象的 Simulink `Switch` 更接近阀门的物理含义：流量由压差、有效面积/流量系数、泄漏和开度动态共同决定。

## 4. `FuelCell_lib.slx` 的可复用边界

入口：

```text
D:\matlab2025b\toolbox\physmod\fluids\supporting_files\example_libraries\FuelCell_lib.slx
```

### 4.1 已读回的 FC 域组件

| 类别 | 组件 |
|---|---|
| Gas elements | `Absolute Reference (FC)`、`Cap (FC)`、`Constant Volume Chamber (FC)`、`Flow Resistance (FC)`、`Infinite Flow Resistance (FC)`、`Local Restriction (FC)`、`Pipe (FC)`、`Reservoir (FC)` |
| Fuel-cell core | `Membrane Electrode Assembly` |
| Sensors | `Composition and Humidity Sensor (FC)`、`Mass Flow Rate Sensor (FC)`、`Pressure and Temperature Sensor (FC)`、`Thermodynamic Properties Sensor (FC)`、`Velocity Sensor (FC)`、`Volumetric Flow Rate Sensor (FC)` |
| Sources | `Mass Flow Rate Source (FC)`、`Pressure Source (FC)`、`Volumetric Flow Rate Source (FC)` |
| Utilities | `Gas Mixture Properties (FC)`、`Interface (FC-G)` |

### 4.2 对燃料电池气路的意义

`FuelCell_lib` 的价值在于物种守恒和 PEMFC 组件语义，而不是提供全部工业阀型：

1. `Membrane Electrode Assembly` 连接阳极/阴极气体状态、电端口和热端口，负责电化学反应、水生成/传输及相关状态交换；
2. `Constant Volume Chamber (FC)`、`Pipe (FC)` 和 `Reservoir (FC)` 可以承载气体库存、压力、温度和四物种混合；
3. `Local Restriction (FC)` 可作为域一致的节流/阀等效元件，参数含常面积/可变面积、最小/最大面积、流量系数和层流过渡相关设置；
4. `Composition and Humidity Sensor (FC)`、`Mass Flow Rate Sensor (FC)` 和压力温度传感器可以直接支撑 cEGR 物种、湿度、流量和压差观测；
5. `Interface (FC-G)` 表明 FC 域与 Gas 域之间存在专门的接口语义，不能靠普通连接线或 Simulink 信号线替代。

## 5. 官方 PEMFC 案例提供的气路建模模式

### 5.1 Gas Mixture PEMFC 自定义库案例

资料入口：[Gas Mixture PEMFC 官方示例快照](01_GasMixture_PEMFuelCellSystemWithCustomLibrary/)

示例说明明确给出：自定义域包含 `N2/O2/H2/H2O` 四物种；阳极有压力调节、回流和 purge；阴极有压缩机、加湿器、阴极气体通道和背压释放阀。示例脚本还单独打开并检查：

- `Cathode Exhaust/Pressure Relief Valve`；
- `Hydrogen Source/Pressure-Reducing Valve`；
- `Anode Exhaust` 与 purge 相关结构；
- `Cathode Gas Channels`、`Cathode Humidifier` 和冷却系统。

这些结构可以复用为气路组织模式，但要区分其职责：

| 案例结构 | 物理职责 | 对 cEGR 的可复用意义 |
|---|---|---|
| Pressure-Reducing Valve | 高压氢源降压到堆入口压力 | 阀门参数、压力控制和初始条件处理参考；不是 cEGR 阀本身 |
| Pressure Relief Valve | 维持阴极出口/堆内背压并排放 | 可作为 cEGR 排气支路的背压边界参考 |
| Purge Valve | 阳极惰性物种累积时短时排放 | 控制语义和物种损失审计参考；不能直接当阴极回流阀 |
| Compressor + Pipe/Chamber | 增压、流量、库存和温度响应 | 阴极新鲜空气边界与 cEGR 混合点的设备组织参考 |
| Cathode Gas Channels | 阴极气体状态与 MEA 交换 | cEGR 回流必须最终进入同一物理气体网络，而不是另建信号混合核 |

### 5.2 Moist Air PEMFC 系统案例

资料入口：[Moist Air PEMFC 官方示例快照](02_MoistAir_PEMFuelCellSystem/)

该案例适合参考：

- 湿空气阳极/阴极网络的分区方式；
- 压缩机、加湿器、Pipe、背压释放阀和冷却系统的 BOP 组织；
- `Pipe_MA` 和气体组分/湿度的观测路径；
- 压力调节、加湿和热管理对阴极气路的耦合。

它不自动成为 cEGR 的主气体域。若研究目标要求对 `O2/N2/H2O` 进行统一物种守恒，必须先证明 Moist Air 的物种表达、接口和水状态满足当前研究问题。

## 6. PEMFC 气路组件选型矩阵

| 研究功能 | 首选组件/模式 | 直接复用条件 | 当前建议 |
|---|---|---|---|
| cEGR 开关 | `2-Way Directional Valve (G/MA)` 或域一致的 `Local Restriction (FC)` | 物理域一致；控制端口、泄漏和开度语义已读回 | 先保留当前 FC 域气路，优先验证域一致的限制元件 |
| cEGR 连续调节 | `Orifice (G/MA)`、`Local Restriction (G/MA/FC)` | 有开度/面积到流量系数的参数依据，且实际流量来自压差 | 推荐作为被动 cEGR 的首个设备候选 |
| cEGR 旁通/三通切换 | `3-Way Directional Valve (G/MA)` | 三个流体端口的连接拓扑和中间状态明确 | 仅在确有旁通/排气分支需求时引入 |
| 阴极背压 | `Pressure Relief Valve (G/MA)` 或现有域一致背压结构 | 出口排放边界和压力设定有明确来源 | 与 cEGR 回流阀分开建模、分开观测 |
| 氢源减压 | `Pressure Reducing Valve (G/MA)` 或官方 FC 示例同类结构 | 高压源、设定压力和下游库存均闭合 | 作为阳极供氢参考，不与 cEGR 混用 |
| 防倒流 | `Check Valve (G/MA)` 或 FC 域等效结构 | 回流方向与初始压差明确 | 需要时用于支路保护，先做最小 smoke |
| 管路库存 | `Pipe (FC/G/MA)` | 域、长度、直径、粗糙度、热边界有依据 | 直接复用官方 Pipe 结构，避免信号延迟替代库存 |
| 混合/缓冲 | `Constant Volume Chamber (FC/G/MA)` | 体积、初始压力、温度和物种组成可解释 | cEGR 入口混合优先使用物理容腔/网络 |
| 气体观测 | FC 域组分/湿度、质量流量、压力温度传感器 | 输出语义、单位和方向已读回 | 将目标值、命令值、实际值分开登记 |

### 6.1 选择原则

1. **先选物理域，再选阀型。** `FC`、`G`、`MA` 是不同的 conserving-port 语义；不能因为块名相同就直接替换。
2. **先选气路职责，再选组件。** cEGR 阀、阴极背压阀、阳极 purge valve 和氢源减压阀的边界条件与控制目标不同，不能合并为一个泛化阀门。
3. **优先局部阻力/孔口模型闭合被动回流。** 只要研究目标是回流比例、氧稀释、湿度和压力耦合，先用真实压差驱动的限制元件；不要用质量流量源直接指定实际 cEGR 流量。
4. **需要工业阀型参数时再升级。** Ball/Gate/Poppet/Temperature Control 等组件适合有 `Cv/Kv`、泄漏、开度特性和执行器数据的场景；缺乏数据时，名称更具体不等于模型更可信。
5. **阀门不是独立的控制器。** 控制器输出只能改变阀的开度、设定值或执行器状态；阀前后压力、流量、温度和组分必须通过物理网络产生。

## 7. 面向 Route A 的推荐复用路线

### 7.1 保持的主线

- 唯一活动系统模型仍是官方 Gas Mixture PEMFC 派生的 Route A 模型；本文件不创建第二个 `.slx`。
- 官方 `FuelCell_lib` 的 MEA、FC 域 Pipe/Chamber/Reservoir/Restriction、源和传感器继续作为主气路物理内核。
- `SimscapeFluids_lib` 的 Gas/Moist Air 阀门作为组件行为、参数化和 BOP 架构参考；只有通过端口域检查后才能进入当前模型。
- cEGR 仍是一条物理气路：阴极出口分流 -> 阀/阻力 -> 管路/容腔 -> 阴极入口混合 -> 剩余气体排放。

### 7.2 后续最小落地顺序

1. 对当前 Route A 的 cEGR 入口、出口、阀/限制元件和混合点做 `model_read`/参数读回，记录每个 conserving port 的真实物理域和方向。
2. 先选一个被动 cEGR 配置：域一致的 `Local Restriction (FC)` 或当前已存在的等效阀门结构；不同时引入 G/MA 阀、主动泵和新的质量流源。
3. 固定 `cEGR=0`、小幅非零 cEGR 两个最小 case，检查阀前后压力、实际回流量、混合入口流量、O2/N2/H2O、温度和湿度。
4. 仅当上述 case 的物理路径和初始条件闭合后，再评估是否需要直接采用 `2-Way Directional Valve`、`Orifice` 或 `Pressure Relief Valve` 的 G/MA 版本。
5. 若要引入 `Cv/Kv`、泄漏、开度动态或阀执行器，先建立参数来源、单位、适用范围和单阀 smoke test，再进入正式模型。

## 8. 验收和审计要求

本资料本身的“已确认”只表示库树/源码/示例结构已读回，不表示组件已经在当前 Route A 中运行通过。后续组件接入至少需要：

| 检查层 | 必须读回或验证的内容 |
|---|---|
| 结构 | 组件路径、引用库、端口数量和 conserving-port 类型；无悬空物理端口 |
| 参数 | 开度/面积、`Cv/Kv`、泄漏、压力设定、时间常数、单位和来源 |
| 物理语义 | 流向、压差、临界/非临界流、气体组分、水蒸气/液水处理和热端口 |
| 控制接口 | 命令值、实际开度、限幅、阀前后状态和实际质量流量分别登记 |
| 最小运行 | `cEGR=0` 与小幅非零 case 的初始条件、压力、流量、组分和温湿度响应 |
| 结论等级 | 区分“库块存在”“结构接入”“短 smoke 通过”“正式矩阵通过” |

### 当前未验证事项

- `SimscapeFluids_lib` 的 `(G)` 或 `(MA)` 阀门尚未在本次调查中直接接入并运行当前 Route A 的 `FuelCell (FC)` 气路；
- 具体 cEGR 阀的 `Cv/Kv`、泄漏比例、开度特性和动态参数尚未形成 `platform_default` 来源链；
- 官方示例的压力调节/释放阀结构可以作为参考，但其参数不能直接迁移为当前平台或外部台架案例的默认值；
- 本次调查没有改变任何 `.slx`、模型参数、运行脚本或正式验证结果。

## 9. 关联资料

- [官方示例材料池 README](README.md)
- [Gas Mixture PEMFC 示例说明脚本](01_GasMixture_PEMFuelCellSystemWithCustomLibrary/PEMFuelCellSystemWithACustomLibraryExample.m)
- [Moist Air PEMFC 示例说明脚本](02_MoistAir_PEMFuelCellSystem/PEMFuelCellSystemExample.m)
- [Route A 材料池与模型候选比较](../RouteA_材料池与模型候选比较_v01.md)
- [Route A 模型裁决与资产处置](../../04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)
- [Route A cEGR 当前路线图](../../04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)
