# Route A cEGR-PEMFC 官方引射器模块审计与 FuelCell 域适配裁决

文件类型：当前指导、官方能力审计和引射器建模路线裁决
日期：2026-08-14
状态：已完成官方文档、R2025b 安装库和当前模型域审计；未修改正式 `.slx`。

## 1. 结论

MathWorks Simscape Fluids 已提供成熟的官方引射器模块：

| 模块 | 官方库路径 | 物理域 | 官方示例 |
|---|---|---|---|
| `Ejector (G)` | `SimscapeFluids_lib/Gas/Turbomachinery/Ejector (G)` | Gas | `EjectorGExample` |
| `Ejector (MA)` | `SimscapeFluids_lib/Moist Air/Turbomachinery/Ejector (MA)` | Moist Air | `EjectorMAExample` |

两个块均有三个 conserving ports：

```text
A = primary inlet  动力流入口
S = secondary inlet 吸入流入口
B = outlet          混合/扩压出口
```

官方块从 R2023a 起提供。`Ejector (MA)` 在 R2024b 增加了夹带水滴建模能力。

但是，当前 Route A 主模型使用的是 `FuelCell.FuelCell` 自定义四物种域，而官方引射器使用 `Gas` 或 `Moist Air` conserving domain。官方块不能直接连接到当前 `FuelCell` 物理端口。因此结论是：

```text
官方引射器模块已经存在；
可以直接建立官方域独立可行性模型；
不能直接插入当前 FuelCell 四物种主模型；
集成模型需要 FuelCell 域适配或独立代理接口。
```

## 2. 官方模块的实际能力

### 2.1 `Ejector (G)`

官方文档说明该块：

- 用高压 primary flow 经过收缩-扩张喷嘴形成低压高速射流；
- 通过端口 `S` 吸入低压 secondary flow；
- 在混合腔中完成一维动量和能量混合；
- 通过扩压段恢复出口压力；
- 支持 primary flow 和 secondary flow 临界/亚临界运行；
- 通过喷嘴喉面积、喷嘴面积比、混合腔面积比和多项效率参数描述设备。

官方块的重要参数包括：

```text
Primary nozzle throat area
Area ratio of nozzle exit to throat
Area ratio of mixing chamber to throat
Minimum area ratio of secondary throat to primary throat
Efficiency for primary flow through nozzle
Efficiency for secondary suction flow
Efficiency for primary flow expansion
Efficiency for mixing
Cross-sectional area at ports A/B/S
```

该块的主要假设是理想气体、一维、稳态、绝热，并使用经验效率描述喷嘴、吸入、膨胀和混合损失；官方文档明确提示反向流工况结果可能不准确。

### 2.2 `Ejector (MA)`

`Ejector (MA)` 与 `Ejector (G)` 的结构和参数基本对应，但作用于 Moist Air 域：

- primary、secondary 和 outlet 都是 Moist Air conserving ports；
- 两股流必须包含相同的 moist-air species，但组成可以不同；
- 可用于湿空气回流和空气引射；
- R2024b 支持在 Moist Air Properties 中启用夹带水滴。

这对阴极尾气中水蒸气和液滴风险具有参考价值，但 Moist Air 域不自动等价于 Route A 当前要求的 `N2/O2/H2O` 四物种 FuelCell 网络。

## 3. R2025b 本机证据

当前 MATLAB R2025b 安装库中已读回：

```text
D:\matlab2025b\toolbox\physmod\fluids\library\m\SimscapeFluids_lib.slx
```

实际块路径为：

```text
SimscapeFluids_lib/Gas/Turbomachinery/Ejector (G)
SimscapeFluids_lib/Moist Air/Turbomachinery/Ejector (MA)
```

MATLAB 读回的组件路径为：

```text
fluids.gas.turbomachinery.ejector
fluids.moist_air.turbomachinery.ejector
```

两个块的物理端口布局均为 1 个输入端和 2 个输出/物理端口，分别对应官方文档中的 `A`、`B`、`S`。

官方文档页面提供了 `EjectorGExample` 和 `EjectorMAExample` 的 Open Model 入口。本次 MATLAB 会话中 `openExample('simscapefluids/EjectorGExample')` 和 `openExample('simscapefluids/EjectorMAExample')` 未解析到本地示例元数据，因此本记录不声称已在本机会话执行官方示例；官方块本体和官方文档能力已直接读回。

## 4. 与当前 Route A 模型的域兼容性

当前聚焦模型的气路使用：

```text
FuelCell.FuelCell conserving ports
N2/O2/H2/H2O mixture
```

官方引射器使用：

```text
Gas conserving ports
或 Moist Air conserving ports
```

这三种 domain 不是同一个 conserving-port 类型，不能通过普通连接线直接连接。具体风险包括：

- `Gas` 域的物种组成语义不能直接承载当前 FuelCell 四物种状态；
- `Moist Air` 域的湿空气组分语义不能直接替代 FuelCell 中独立的 O2/N2/H2O 回流守恒；
- 用 Simulink 信号把压力、温度或流量传过去，只能构成边界代理，不是耦合的物理气路；
- 用 `Local Restriction (FC)`、Pipe 和混合室拼接，也不能产生官方引射器的喷嘴、超声速射流、吸入喉部、混合和扩压压力恢复行为。

因此，当前项目不应直接把 `Ejector (G)` 或 `Ejector (MA)` 放进 `FuelCell` 网络并声称已完成引射器物理。

## 5. 三条官方可行建模路线

### 路线 A：官方 Gas/Moist Air 独立引射器可行性模型

直接使用官方块建立小型独立模型：

```text
Primary source -> Ejector A
Secondary low-pressure source -> Ejector S
Ejector B -> backpressure/load network
```

用途：

- 检查动力压力、吸入压力和出口背压是否落在引射器工作区；
- 扫描喉部面积、面积比和效率；
- 获得 primary flow、secondary flow、出口压力、引射比和临界/亚临界边界；
- 为 FuelCell 域适配提供初始尺寸和参数范围。

限制：它不是当前 PEMFC 四物种主模型的闭环仿真。

### 路线 B：FuelCell 域引射器适配组件

这是 Route A 主模型的推荐集成路线。采用官方 Ejector (G) 的成熟结构和方程方法，但在 `FuelCell.FuelCell` 域中重新实现物理组件：

```text
FuelCell primary inlet  A
FuelCell secondary inlet S
FuelCell mixed outlet   B
```

适配组件必须保留：

- 主喷嘴喉部面积；
- 喷嘴出口/喉部面积比；
- 混合腔/喉部面积比；
- 次级吸入喉部最小面积比；
- 喷嘴、吸入、膨胀和混合效率；
- FuelCell 气体组分、温度、压力、质量流量和能量流；
- 临界/亚临界状态及反向流限制。

这不是 MATLAB Function。应使用受控的 Simscape 组件和项目允许的 `FuelCell` 自定义库扩展，并先建立参数合同和单组件测试。

### 路线 C：整段阴极气路迁移到 Moist Air

使用 `Ejector (MA)`，把引射器和阴极 BOP 建在 Moist Air 域。

这条路线可以快速验证湿空气引射器和夹带水滴，但会改变 Route A 当前的四物种主线，不能作为当前 cEGR 主模型的默认路线。只能作为独立对照或方法验证模型。

## 6. 对当前 cEGR 的推荐连接方式

推荐的 FuelCell 域目标结构为：

```text
空压机出口/中冷器后
 -> Ejector A 主流入口

阴极出口
 -> 公共背压边界
 -> 水汽分离气相边界
 -> Ejector S 吸入入口

Ejector B 出口
 -> 自增湿配置：阴极入口
 -> 膜加湿配置：膜加湿器干侧 -> 阴极入口
```

这是一种“后压缩机引射式 cEGR”，不能与当前“空压机入口阀门回流”共用同一个回流位置。两者应作为不同架构配置：

```text
Passive_Valve_PostSeparatorGas_CompressorInlet
Passive_Ejector_PostSeparatorGas_PostCompressorCathodeInlet
```

## 7. 引射器适配的参数合同

进入正式 FuelCell 域组件前，至少需要冻结：

| 参数组 | 参数 |
|---|---|
| 几何 | 喉部面积、喷嘴出口面积比、混合腔面积比、A/B/S 截面积 |
| 性能 | 主流喷嘴效率、次级吸入效率、射流膨胀效率、混合效率 |
| 动力边界 | 主流 P/T/组分/质量流量、空压机出口位置 |
| 吸入边界 | 阴极尾气 P/T/组分/允许含液率、分离后状态 |
| 出口边界 | 引射器出口压力、阴极入口或膜加湿器干侧压力、下游压损 |
| 状态 | 临界、亚临界、次级反向流、主流堵塞和失效切除 |
| 验证 | 引射比、出口压力恢复、质量/组分/能量闭合和反向流行为 |

## 8. 对项目的执行建议

1. 不影响 Codex 当前阀门模型工作，先把阀门被动式作为共同基线。
2. 单独建立官方 `Ejector (G)` 或 `Ejector (MA)` 小型可行性模型，验证压力和引射比工作区。
3. 不把官方 G/MA 块直接接入当前 `FuelCell` 模型。
4. 如果官方独立模型证明压力窗口存在，再建立 `FuelCell` 域 Ejector 适配组件。
5. 适配组件通过单组件结构、组分守恒、能量守恒、临界/亚临界和反向流测试后，再接入两种 PEMFC 湿化配置。
6. 引射器研究作为第三个被动架构轴，和阀门被动式、自增湿/膜加湿轴分开比较。

## 9. 官方来源

- [Ejector (G)](https://www.mathworks.com/help/hydro/ref/ejectorg.html)
- [Ejector (MA)](https://www.mathworks.com/help/hydro/ref/ejectorma.html)
- [Gas Library Turbomachinery](https://www.mathworks.com/help/hydro/gas_turbomachinery.html)
- [Moist Air Library Turbomachinery](https://www.mathworks.com/help/hydro/ma_turbomachinery.html)
- 官方示例入口：`EjectorGExample`、`EjectorMAExample`
