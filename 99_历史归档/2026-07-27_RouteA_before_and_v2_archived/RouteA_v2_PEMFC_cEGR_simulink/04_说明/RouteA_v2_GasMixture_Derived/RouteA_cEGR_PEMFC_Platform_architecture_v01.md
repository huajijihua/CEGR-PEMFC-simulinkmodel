# RouteA cEGR-PEMFC Platform Architecture v01

文件类型：RouteA_v2 平台架构规格
日期：2026-07-24
副本范围：RouteA_v2 独立模型树；原 RouteA 仅作为来源和对照，不在本目录内修改。
前置文档：[系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)、[CEGR 文献研究与模型映射](RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)
执行入口：[实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)、[RouteA_v2_Execution_Record](../RouteA_v2_Execution_Record/README.md)

本文件定义 RouteA_v2 的自然物理边界、逻辑容器、端口语义、状态和参数边界。目标容器是职责约束，不是要求一次性把当前模型从 23 个容器强行压缩成 8 个块；任何结构变化必须按实施计划的小步闭环执行。

## 1. 架构原则

1. 电堆/MEA 是系统锚点；BOP 的存在理由是提供反应物、排出产物、管理水和热，而不是把平台变成 BOP 控制器集合；
2. 四物种 `FuelCell` 气体域是当前 cEGR 主域。官方 Gas Mixture PEMFC 示例是母版和结构参照，`FuelCell_lib` 是优先复用库；
3. 物理网络、控制器、测量和研究调度分层。逻辑分层不要求立即拆成多个 `.slx`，但每层必须有可读的接口；
4. 容腔、管路、局部阻力和传感器只有在承担库存、压降、传输或测量职责时才保留；不能为填充接口而新增块；
5. 一个 physical plant 只保留一个内部 `I_cmd` 负载端口。Power/Voltage 是输入适配或控制策略，不是复制 plant 拓扑的理由；
6. 每个研究变量只有一个权威写入点。实际流量、压力、温度和组分只能由物理网络输出，脚本不能伪造测量结果；
7. cEGR 影响项不等同于 cEGR 物理控制结构。影响项通过研究模式、控制目标和 KPI 表达，气路仍由出口分流、执行设备和入口混合闭合；
8. 每次结构修改必须有前后 read-back、`model_check`、最小运行或明确失败证据，并写入阶段记录。

## 2. 目标逻辑分解与当前模型映射

### 2.1 目标逻辑容器

```text
RouteA_PEMFC_cEGR_Platform
|-- Stack_Core
|-- Cathode_Supply
|-- Cathode_Exhaust_cEGR
|-- Anode_Supply_Recirculation
|-- Thermal_Management
|-- Electrical_Load_Interface
|-- Control_Interface
`-- Observability_and_Audit
```

| 目标逻辑容器 | 自然职责 | 默认保真度 |
|---|---|---|
| `Stack_Core` | 官方 MEA、阳极/阴极通道、反应物消耗、水生成、电压和热端 | 官方 L2 |
| `Cathode_Supply` | 新鲜空气边界、压缩机或等效供气、入口容腔、加湿和入口测量 | 官方结构 + L2 接口 |
| `Cathode_Exhaust_cEGR` | 阴极出口、分流点、cEGR 阀/管路/混合点、排气背压和水边界 | cEGR L2 |
| `Anode_Supply_Recirculation` | 氢源、减压、入口调理、阳极回流、吹扫和出口测量 | 官方结构 + L2 接口 |
| `Thermal_Management` | MEA 热端、冷却/散热等效网络和温度测量 | L2 等效 |
| `Electrical_Load_Interface` | `I_cmd` 到 Simscape 负载的唯一适配 | L2 |
| `Control_Interface` | 空气、背压、湿度、cEGR、回流、吹扫和热控制器 | L2 接口 |
| `Observability_and_Audit` | `y`、`z`、日志、守恒和限幅诊断 | L2 审计 |

### 2.2 当前 v2 复制基线的关系

当前 v2 模型读回显示总计 23 个容器，且至少包含以下主要职责块：

| 当前 v2 容器 | 目标逻辑归属 | 当前处理 |
|---|---|---|
| `Stack_Core` | `Stack_Core` | `PRESERVE`，先做接口和状态读回 |
| `Cathode_Air_cEGR_BOP` | `Cathode_Supply` + 部分 `Cathode_Exhaust_cEGR` | `PRESERVE/REFACTOR`，按物理端口拆责 |
| `Cathode_Exhaust_Backpressure_Water` | `Cathode_Exhaust_cEGR` | `PRESERVE/REFACTOR`，保留排气、背压和实际水边界 |
| `Anode_Hydrogen_BOP` | `Anode_Supply_Recirculation` | `PRESERVE/REFACTOR`，不新增无证据 Source_Conditioner |
| `Thermal_Management_BOP` | `Thermal_Management` | `PRESERVE`，核对热状态和控制边界 |
| `System_Control_Observability` | `Control_Interface` + `Observability_and_Audit` | `REFACTOR`，分开命令、测量和审计 |
| `cEGR_Mode_Selector` | `Control_Interface` | `REFACTOR`，只选择执行设备配置，不生成第二套气路 |
| 其余已读回容器 | 按端口和物理职责归类 | 逐项写入 Phase 0/1 记录，不凭名称直接判定 |

这里的“目标逻辑归属”不是当前结构已经满足的证明，也不是要求一次性重排全部层级。RouteA_v2 的第一步是建立完整的当前容器/端口/状态映射，再决定哪些容器需要合并、分责、保留或暂缓。

## 3. 气路拓扑和接口契约

### 3.1 阴极新鲜空气路径

```text
Fresh-Air Reservoir
    -> optional Compressor / Flow Boundary
    -> Cathode Inlet Mixer
    -> Cathode Humidifier
    -> Cathode Gas Channels
    -> Cathode Exhaust Chamber
```

新鲜空气的 `N2/O2/H2O` 组成优先通过一个有明确组成参数的官方 Reservoir 或官方气体边界表达。除非研究问题确实是独立物种注入，不得用三个并列 Mass Flow Rate Source 代替一个可解释的气体边界。

### 3.2 cEGR 物理路径

在 Simulink/Simscape 中，cEGR 首先是气路系统，而不是把系统影响统一打包的效果模块。其物理闭环是：

```text
Cathode Exhaust Chamber
    -> outlet split / exhaust branch
    -> Passive local restriction / valve
       or Active pump + defined pressure/power boundary
    -> cEGR pipe or manifold
    -> Cathode Inlet Mixer
```

默认优先闭合压差驱动的被动路径：

- 实际回流量由出口和入口之间的压力状态、阀开度和局部阻力共同决定；
- 回流组分、温度、压力和湿度来自阴极出口网络；
- 必须保留排气支路，不能用强制质量流源直接写入实际 `mdot_cegr`；
- 研究上层回流比、O2 分压或电压目标时，控制器将目标转换为阀开度、泵速、背压或旁路命令；
- 主动泵是独立设备配置，必须显式表达泵功率、压差、动态和保护边界，不与被动阀路径混用。

### 3.3 cEGR 端口和变量

| 变量 | 来源 | 语义 | 是否可由脚本直接写入 |
|---|---|---|---|
| `cegr_ratio_cmd` | 研究 case/控制器 | 上层设定值或目标 | 可以作为命令输入，但必须经控制器/执行器转换 |
| `cegr_valve_cmd` | 控制器 | 阀开度或等效阻力命令 | 可以 |
| `cegr_pump_cmd` | 控制器 | 主动泵命令 | 仅主动配置开放 |
| `mdot_cegr` | cEGR 物理支路 | 实际回流质量流量 | 不可以，必须来自网络 |
| `x_i_cegr` | 阴极出口/回流支路 | 实际回流组分 | 不可以，必须来自网络 |
| `mdot_fresh` | 新鲜空气支路 | 新鲜空气总流量 | 不可以，必须来自网络 |
| `mdot_mix_in` | 混合点 | 混合器入口总流量 | 不可以，必须来自网络 |
| `pO2_ca_in`、`RH_ca_in` | 阴极入口测量/转换 | 实际入口状态 | 不可以用命令值替代 |

至少发布以下派生量，并明确基准：

```text
cegr_ratio_wet = abs(mdot_cegr) / max(abs(mdot_mix_in), epsilon)
cegr_to_fresh_ratio = abs(mdot_cegr) / max(abs(mdot_fresh), epsilon)
```

湿基和干基不能混写；`lambda_fresh`、`lambda_mix`、`pO2_ca_in`、`yO2_ca_in` 和 `RH_ca_in` 必须分开。

### 3.4 阳极路径

阳极默认保留官方 Hydrogen Source、Pressure-Reducing Valve、Anode Gas Channels、Anode Exhaust、Recirculation 和 Purge 语义。`Source_Conditioner` 只有在端口职责、设备边界和初态都闭合后才允许加入目标路径；当前 v10 多物种独立质量源 + 未闭合 Mixing_Chamber 不作为默认目标架构。

## 4. 负载和控制架构

```text
User Study Command
    -> boundary adapter
        Current: I_cmd = I_ref
        Power:   I_cmd = P_ref / max(V_stack, V_floor)
        Voltage: I_cmd = controller(V_ref - V_stack)
    -> Electrical_Load_Interface
    -> Stack electrical port
```

Power 和 Voltage 的适配可以位于 Simulink 控制子系统或 runner 装配的 profile 中，但必须共享同一个电堆物理负载接口。一个 study 只能选择一种用户侧边界类型；不能因为换输入类型就复制气路、热路或电堆拓扑。

控制器只接收 `y`，输出 `u`，并显式记录限幅、anti-windup、mode 和故障状态。未经传感器定义的 chamber 状态、脚本根据命令推算的实际流量以及历史 MAT 回填的测量值不能直接作为默认反馈。

## 5. 参数和来源架构

| 层 | 内容 | 是否默认加载 |
|---|---|---|
| `official_base` | 官方 Gas Mixture 示例的结构/solver/基础参数 | 是，作为参考真源 |
| `platform_default` | 与官方结构自洽的通用 L2 参数、单位和范围 | 是 |
| `scaling_rule` | 单池数、有效面积、额定电流/功率迁移规则 | 研究显式启用 |
| `study_command` | 时间变化的负载、空气、背压、cEGR、热和控制命令 | 每个 study 显式提供 |
| `external_case` | 台架、DQ60、历史标定或外部数据 | 否，显式开关才加载 |
| `calibration` | 经批准的参数识别结果及适用范围 | 否，单独案例 |

目标参数对象按设备分组：

```matlab
platform.stack
platform.cathode
platform.cegr
platform.anode
platform.thermal
platform.electrical
platform.numerics
platform.observability
```

官方块所需的兼容标量别名可以保留，但只能由一个参数装配入口产生。`P` 结构体、demo 默认值、控制器调参、设备物理参数和命令 profile 不得继续混在多个 base-workspace 写入点。

## 6. 状态、初态和数值边界

1. 冷态 nominal 是第一等价验证路径；热启动只是加速工具；
2. 初态只描述 plant 的结构兼容性和已声明的基准工作点，不锁定后续研究命令；
3. 先保留一个 canonical hot-start operating point；I/P/V 通过同一 `I_cmd` 处理，不生成三套 MOP 真源；
4. 如果工具限制导致需要分支匹配，分支文件必须标为兼容缓存，不标成三个平台初态；
5. `StartTime=0`、solver 名称、容差、`MaxStep`、快照绝对时间和逻辑研究时间分开记录；
6. DAE/代数环风险在结构修改前识别，物理端口不能用占位连接隐藏；
7. 任何初态失败都保留最小复现输入、失败栈和模型 hash，直到专门阶段关闭。

## 7. 观测和审计架构

至少需要以下审计链：

- 电边界：命令、实际 I/V/P、限幅和控制误差；
- 气体：各入口/出口总质量流、物种分数、压力、温度和 RH；
- cEGR：目标、实际、阀/泵前后压差、排气与回流分流、泵功耗（若适用）；
- 水：气相水、冷凝/分离输出和适用范围；
- 热：电堆温度、热流和冷却侧响应；
- 守恒：质量、物种和能量残差；
- 故障：初始化不收敛、限幅、NaN/Inf、端口 warning 和 solver warning。

水账本和守恒审计是结果层能力，不反向替代 plant 物理闭合。审计失败时 runner 应分类失败原因，并保留 case-level KPI；不能把复杂审计脚本塞进物理模型或静默放宽模型失败。

## 8. 结构修改准则和架构验收

结构修改前必须说明目标问题、目标子系统、允许修改范围、禁止修改范围、保持不变的假设和验收检查。以下是 RouteA_v2 的硬性架构约束：

1. 当前模型容器数量可以暂时多于目标逻辑容器数量，但每个额外容器必须有物理、控制、测量或兼容职责；
2. 现有 cEGR 主气路不因文献影响项而整体替换；先修未闭合端口、重复边界和执行器语义；
3. 实际流量、压力、温度和组分只有一个物理输出真源；
4. 所有 active physical ports 要么连接到真实设备，要么明确列为合法 plant 边界；
5. 结构、参数、控制和结果层不能在同一轮无记录地混改；
6. 目标架构只有在 Phase 1 的结构读回、Phase 2 的参数审计和 Phase 5 的代表性运行都满足后，才允许晋级为 v2 平台基线。
