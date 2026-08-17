# Route A cEGR-PEMFC 系统可读化结构图

文件类型：当前可读化交付规划与边界  
日期：2026-08-12  
适用资产：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`

## 1. 目的

为用户建立一个面向设备、流向和研究边界的阅读层，使其能够提出完整的建模研究需求，而不必直接解读 Simulink 的层级、信号线或控制模块。

首版交付物为：

`03_审计与研究/RouteA_cEGR_PEMFC_系统可读化结构图_v01.html`

它是活动 Route A 主模型的可读化投影，不参与仿真、不写入参数、不修改 `.slx`，也不替代 P&ID、硬件图纸或安全设计文件。

## 2. 阅读模型

页面默认以电堆为中心，按四类信息表达：

1. 实线物理流：空气、氢气、尾气/cEGR、水、热/冷却液和电能；
2. 绿色虚线：控制命令与测量关系，不表达管路；
3. 设备节点：只保留用户可讨论的系统对象，不显示 Simulink 的中间转换、Goto/From 和日志块；
4. 节点详情：现实职责、当前模型表达、系统关系和不可外推的工程边界。

首版视图包括完整系统、阴极与 cEGR、阳极供氢、热管理、控制与测量。每个设备节点可点击，并通过键盘访问。

## 3. 结构真源与映射规则

图中内容必须来自当前主模型及其已登记的架构，不得由面板控件、历史模型或外部案例反推。首版对应关系如下：

| 可读节点 | 当前主模型容器或官方组件 |
|---|---|
| PEM 燃料电池堆 | `Stack_Core` 中官方 MEA/阳极/阴极气体通道 |
| 空气供给与混合 | `Cathode_Air_cEGR_BOP/Oxygen Source`、`CompressorInletMixer` |
| 阴极加湿 | `Cathode_Air_cEGR_BOP/Cathode Humidifier` |
| cEGR 阀与管路 | `EGRValveRestriction/Open/LocalRestriction`、`EGRPipe`、阀前后压力传感器 |
| 阴极排气与水 | `Cathode_Exhaust_Backpressure_Water`、`Pressure Relief Valve`、`SeparatorOrCondensation` |
| 阳极供氢、循环与吹扫 | `Anode_Hydrogen_BOP` 中 Hydrogen Source、Pressure-Reducing Valve、Recirculation、Purge Valve |
| 热管理 | `Thermal_Management_BOP` 中 Pump、Radiator、Heat Dissipation |
| 控制与观测 | `System_Control_Observability/FCU_BoP_Control` 与唯一 `I_cmd` 电负载接口 |

## 4. 使用边界

1. 用户以页面中的设备、流向、控制目的和“当前不应外推的结论”描述需求；Agent 据此回查模型路径、参数和观测接口。
2. 用户希望讨论阀门时，应先描述其运行目的、介质、流量/压差、连续或开关、故障安全位和需要的测量；具体器件类型随后由设备映射审计确定。
3. 页面中“水管理”“压缩机”“循环装置”等称谓描述系统职责，不能被解释为已经完成具体型号、尺寸、材料、Cv/Kv、效率或安全合规选型。
4. 任何活动模型拓扑、控制接口或保真度变化后，必须同步更新本页面、此映射表和实施记录；未读回模型不得仅修改图面文字。

## 5. 后续集成门槛

首版保持独立 HTML，以避免在模型接口稳定前与 MATLAB 面板形成第二套维护链。满足以下条件后，才可从 `RouteA_Panel_v01` 增加“系统结构”入口：

1. 节点与模型路径的映射保持可审计；
2. 页面中的设备状态可由已注册观测量提供，而不是重复计算或伪造状态；
3. 可编辑参数仍只通过 `simCase -> SimulationInput -> .slx` 的正式链写入；页面只读展示或导航；
4. 若加入运行态高亮，必须有独立的观测契约与单工况行为验证。

在此之前，页面只承担需求澄清、模型审查和硬件映射讨论入口。
