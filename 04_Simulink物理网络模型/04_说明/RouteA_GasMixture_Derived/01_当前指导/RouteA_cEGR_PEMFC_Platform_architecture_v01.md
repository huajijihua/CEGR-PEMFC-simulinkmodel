# RouteA cEGR-PEMFC Platform Architecture v01

文件类型：平台架构规格（已通过 S2/S3 验证）  
日期：2026-07-24（初稿）；2026-07-27（更新：S2/S3 验证完成）  
前置文档：[系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)、[CEGR 文献研究与模型映射](../03_审计与研究/RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)

## 1. 架构原则

1. 电堆/MEA 是系统锚点；BOP 的存在理由是为电堆提供反应物、排出产物、管理水和热，而不是把平台变成 BOP 控制器集合。
2. 四物种 `FuelCell` 气体域是当前 cEGR 主域。官方 Gas Mixture PEMFC 示例是母版和结构参照，`FuelCell_lib` 是优先复用库。
3. 物理网络、控制器、测量和研究调度分层。逻辑分层不要求立即拆成多个 `.slx`，但每一层必须有清晰接口。
4. 容腔、管路、局部阻力和传感器只有在物理上承担库存、压降、传输或测量职责时才保留；不能为填充接口而新增块。
5. 一个物理 plant 只保留一个内部 `I_cmd` 负载端口。Power/Voltage 是输入适配或控制策略，不是复制 plant 拓扑的理由。
6. 每个研究变量只能有一个权威写入点。实际流量、压力、温度和组分只能由物理网络输出，不由脚本伪造为测量结果。

## 2. 目标顶层分解

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

| 顶层容器 | 物理/逻辑职责 | 默认保真度 |
|---|---|---|
| `Stack_Core` | 官方 MEA、阳极/阴极通道、反应物消耗、水生成、电压和热端 | 官方 L2 |
| `Cathode_Supply` | 新鲜空气边界、压缩机或等效供气、入口容腔、加湿和入口测量 | 官方结构 + L2 接口 |
| `Cathode_Exhaust_cEGR` | 阴极出口、分流点、cEGR 阀/管路/混合点、排气背压和水分离接口 | cEGR L2 |
| `Anode_Supply_Recirculation` | 氢源、减压、入口调理、阳极回流、吹扫和出口测量 | 官方结构 + L2 接口 |
| `Thermal_Management` | MEA 热端、冷却/散热等效网络和温度测量 | L2 等效 |
| `Electrical_Load_Interface` | `I_cmd` 到 Simscape 负载的唯一适配；P/V 控制器不改变 plant 气热拓扑 | L2 |
| `Control_Interface` | 空气、背压、湿度、cEGR、回流、吹扫和热控制器 | L2 接口 |
| `Observability_and_Audit` | `y`、`z`、日志、守恒和限幅诊断 | L2 审计 |

目标顶层容器数量不是硬性数字；硬性要求是每个容器有单一自然职责，且任何新增容器都必须对应可验证的物理状态或控制边界。

## 3. 气路拓扑

### 3.1 阴极新鲜空气路径

目标路径为：

```text
Fresh-Air Reservoir
    -> optional Compressor / Flow Boundary
    -> Cathode Inlet Mixer
    -> Cathode Humidifier
    -> Cathode Gas Channels
    -> Cathode Exhaust Chamber
```

新鲜空气的 `N2/O2/H2O` 组成优先通过一个有明确组成参数的官方 Reservoir 或官方气体边界表达。除非研究问题确实是独立物种注入，不得用三个并列 Mass Flow Rate Source 代替一个可解释的气体边界。

### 3.2 cEGR 路径

在 Simulink/Simscape 中，cEGR 首先是一个气路系统，不是一个把系统影响统一打包的“效果模块”。它的物理闭环是阴极出口气体分流、流量控制设备和阴极入口混合；回流气体的 `x_i`、温度、压力和湿度来自阴极出口网络。文献中关于氧稀释、自增湿、排水、低负荷高电位、动态饥饿和冷启动的结论只用于定义研究目标、控制设定值和验证 KPI。

默认 cEGR 为压差驱动的被动回流路径：

```text
Cathode Exhaust Chamber
    -> Water/Condensation Boundary (when supported)
    -> cEGR Local Restriction / Valve
    -> cEGR Pipe or Manifold
    -> Cathode Inlet Mixer
```

默认路径必须保留排气支路，不能用强制质量流源把尾气流量直接写成 cEGR 实际流量。若后续研究主动循环泵，必须建立独立的 `Active_cEGR` 配置，明确泵功率、源边界和压差语义，不与被动阀路径混用。该边界来自 CEGR 文献中“增湿/氧稀释/排水/寄生功耗”之间的共同权衡，详见[文献研究与模型映射](../03_审计与研究/RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)。

若研究需要以回流比、氧分压或电压作为上层目标，控制器必须把目标转换为阀开度、泵速、背压或其他实际执行器命令；不得把目标值直接写成回流质量流量或回流组分。定义：

```text
cegr_ratio_actual = abs(mdot_cegr) / max(abs(mdot_cathode_mixer_in), epsilon)
```

必须同时记录 `mdot_fresh`、`mdot_cegr`、混合器入口总流量、湿/干基回流比、`lambda_fresh`、`lambda_mix`、入口 `pO2`/O2/N2/H2O 分数、RH、阀前后压力、阀开度和排气流量。`cegr_enabled=false` 只用于拓扑隔离回归；性能对照应优先保留 cEGR 拓扑而将 `cegr_ratio_cmd=0`。不同论文的回流比口径不得直接混用。

### 3.3 阳极路径

阳极默认保留官方 Hydrogen Source、Pressure-Reducing Valve、Anode Gas Channels、Anode Exhaust、Recirculation 和 Purge 语义。Source_Conditioner 只有在存在已定义的独立设备边界和已闭合初态方案时才允许加入；当前 v10 的多物种独立质量源 + 未闭合 Mixing_Chamber 不作为目标架构。

## 4. 负载与控制架构

### 4.1 单一内部负载接口

```text
User Study Command
    -> boundary adapter
        Current: I_cmd = I_ref
        Power:   I_cmd = P_ref / max(V_stack, V_floor)
        Voltage: I_cmd = controller(V_ref - V_stack)
    -> Electrical_Load_Interface
    -> Stack electrical port
```

Power 和 Voltage 的输入适配可以作为 Simulink 控制子系统或 runner 生成的 profile，但必须共享同一个电堆物理负载接口。Voltage controller 的状态应位于同一个控制子系统中，采用 `mode` 参数选择，不用 Variant Subsystem 造成三种结构 checksum。

### 4.2 控制域边界

控制器只接收 `y`，输出 `u`，并将限幅、anti-windup、模式和故障状态显式记录。以下量不能直接当作控制器输入：未经传感器定义的内部 chamber 状态、脚本根据命令推算的实际流量、或从历史 MAT 文件回填的测量值。

## 5. 参数架构

参数按来源和生命周期分层，不按旧阶段编号或单次案例命名：

| 层 | 内容 | 是否默认加载 |
|---|---|---|
| `official_base` | 官方 Gas Mixture 示例的结构/求解器/基础参数 | 是，作为参考真源 |
| `platform_default` | 与官方结构自洽的通用平台参数、单位和范围 | 是 |
| `scaling_rule` | 单池数、有效面积、额定电流/功率迁移规则 | 由研究显式启用 |
| `study_command` | 时间变化的负载、气路、cEGR、热和控制命令 | 每次 study 显式提供 |
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

允许保留官方块所需的兼容标量别名，但别名只能由一个参数装配入口产生，不能在多个脚本和 base workspace 中分别覆盖。`P` 结构体、demo 默认值、控制器调参和设备物理参数不得继续混在一个无边界的初始化脚本中。

## 6. 状态与求解器架构

1. 冷态 nominal 是活动 Route A 的唯一验证路径；热启动不属于当前活动能力。
2. 初态只描述 plant 的结构兼容性和已声明的基准工作点，不锁定后续研究的电流、功率、电压、cEGR、空气、压力、湿度或热命令。
3. I/P/V 由同一 `I_cmd` 接口处理，不生成活动分支 MOP；已有 v10 bundle 只作历史兼容缓存。
4. 活动 study 合同固定 `StartTime=0`、`LoadInitialState=off`、求解器名称、容差和 `MaxStep`；不存在 OperatingPoint 绝对快照时间与逻辑研究时间的活动混用。

## 7. 观测和审计架构

至少需要以下审计链：

- 电边界：命令、实际 I/V/P、限幅和控制误差；
- 气体：各入口/出口总质量流、物种分数、压力、温度和 RH；
- cEGR：目标、实际、阀前后压差、排气与回流分流；
- 水：气相水、冷凝/分离输出和适用范围说明；
- 热：电堆温度、热流和冷却侧响应；
- 守恒：质量、物种和能量残差；
- 故障：初始化不收敛、限幅、NaN/Inf、端口 warning、solver warning。

水账本和守恒审计是结果层能力，不应反向替代 plant 的物理闭合。审计失败时 runner 应分类失败原因，并保留 case-level KPI；不能把复杂审计脚本直接塞进物理模型或静默放宽模型失败。
