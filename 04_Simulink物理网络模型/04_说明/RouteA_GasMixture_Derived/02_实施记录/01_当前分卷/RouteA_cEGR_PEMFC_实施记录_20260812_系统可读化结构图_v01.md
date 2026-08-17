# Route A cEGR-PEMFC 实施记录：系统可读化结构图 v01

日期：2026-08-12  
前置决策：[模型裁决与资产处置](../../01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)、[系统可读化结构图规划与边界](../../01_当前指导/RouteA_cEGR_PEMFC_系统可读化结构图_规划与边界_v01.md)

## 实际完成

1. 新建 `03_审计与研究/RouteA_cEGR_PEMFC_系统可读化结构图_v01.html`，以设备与平面流向替代 Simulink 层级阅读。
2. 图中包含阴极新鲜空气/压缩机前混合/cEGR、阳极供氢/循环/吹扫、排气与水管理、热管理、唯一电负载接口和 FCU 控制观测。
3. 页面提供完整系统、阴极与 cEGR、阳极供氢、热管理、控制与测量五个视图；设备节点支持点击和键盘访问。
4. 每个节点显示现实职责、当前模型表达、系统关系及不可外推的工程边界。该表达明确标出阴极水管理为 L2 代理、cEGR 阀为连续可调局部阻力加一阶执行器、cEGR 管路当前绝热、空压机尚非选型级模型等限制。

## 读回依据

2026-08-12 通过 MATLAB/Simulink 读取活动模型 `PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01`：

- 根级容器包含 `Anode_Hydrogen_BOP`、`Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Stack_Core`、`System_Control_Observability`、`Thermal_Management_BOP` 与 `cEGR_Mode_Selector`；
- cEGR 支路读回为 `EGRValveRestriction/Open/LocalRestriction (FC)`、`EGRPipe (FC)`、阀上/下游压力温度传感器和 compressor-inlet mixer；
- cEGR 控制读回为实际质量流比反馈、PI、执行器、一阶限幅和阀面积命令；
- 阳极读回为 Hydrogen Source、Pressure-Reducing Valve、Recirculation、Purge Valve；热管理读回为 Pump 与 Radiator。

## 验证

- 页面源文件读回，HTML 仅包含本地 CSS/JavaScript，无运行模型或写盘动作；
- MATLAB 读回正式模型 `Dirty=off`；
- `model_check(unconnected_lines)` 返回 `healthy`；
- 未运行本次页面对应的仿真，因此页面内容属于结构已读回，不构成新增物理行为验证或硬件选型验证。

## 未决项

1. 未接入 `RouteA_Panel_v01`，避免在模型接口稳定前增加 UI 维护链；
2. 当前为静态结构阅读层，不显示某次仿真的实时状态或结果高亮；
3. 设备型号、材料、尺寸、传感器规格、故障安全与 P&ID 仍需后续硬件映射工作包闭环。

## 2026-08-12 视觉重构

用户评审认为首版的平面布局和设备表达不足以承担“帮助理解系统”的任务。已在不修改模型映射与工程边界的前提下，重构同一 HTML：

1. 以电堆为中心，阴极空气/cEGR 位于上方、阳极供氢与循环位于下方、排气水管理和热管理位于右侧、FCU 位于独立控制层；
2. 使用差异化设备轮廓表达压缩机、混合腔、加湿器、阀门、电堆、储氢、循环装置、水管理、泵/散热器和负载接口，避免以同形矩形替代设备；
3. 节点详情改为“现实中做什么 / 当前模型如何表达 / 你可以这样提出研究需求 / 当前边界”，将阅读结果直接转化为用户可表达的建模问题；
4. 保留五个聚焦视图和节点交互；控制线与物理流严格分色分型。

本次仍为可读层重构，不修改 `.slx`、参数链或仿真行为；后续视觉验收以用户在本地浏览器打开的实际效果为准。

## 2026-08-12 阴极拓扑纠正与版式重绘

用户用论文结构图指出此前图面错误地表达了阴极回流支路。随后重新读取活动模型的物理连接，并重绘同一 HTML。

模型读回确认的阴极主线为：

```text
Air Intake
  -> CompressorInletMixer
  -> Compressor
  -> Compressor Volume / Intercooler_L2_Interface
  -> Cathode Humidifier
  -> Stack cathode
  -> CathodeOutletChamber
       -> Pressure Relief Valve -> exhaust
       -> Local Restriction (FC) + EGRPipe (FC) -> CompressorInletMixer
```

纠正内容：

1. cEGR 明确从 `CathodeOutletChamber` 分流，经 `EGRValveRestriction/Open/LocalRestriction` 和 `EGRPipe` 返回 `CompressorInletMixer`；不再画为经背压/排气阀后折返。
2. `SeparatorOrCondensation` 明确画为阴极出口状态导出的 `m_water_sep` L2 估算，不作为串联在 cEGR 主回流上的实体水分离器。
3. 图面改为论文式单主通道 + 单回流支路 + 分支排气的 P&ID 阅读逻辑；传感器改为小尺寸 P/T/RH/y 标记，说明内容移至下方 Inspector。
4. 阳极、热管理、电负载和 FCU 降为不干扰阴极主线的辅助区。

本次模型读回属于结构验证；未修改 `.slx`，也未新增仿真或硬件选型结论。

## 2026-08-12 浏览器视觉验收与 SVG 缺陷修复

实际验收：通过本地 HTTP 预览打开同一 HTML，使用浏览器截图检查总览和“阴极气路与 cEGR”视图，并点击 `cEGR 阀与管路` 节点读回 Inspector。

发现并修复：

1. 去除不兼容的 SVG `context-stroke` marker，改为固定尺寸、按介质着色的三角箭头；同时修复出口到背压阀存在的旁路连线。
2. 将 cEGR 阀放到“出口容腔 -> 阀/管路 -> 压缩机前混合腔”的实际回流线上。
3. 为水管理估算线和控制/测量虚线显式声明 `fill:none`；此前浏览器把开放路径错误填充为黑色三角形，造成页面大面积遮挡。

验收结果：截图中无黑色填充块或大面积遮挡；阴极主通道保持单一直线；出口分为背压排气和 cEGR 回流两条支路；`m_water_sep` 仍以独立 L2 估算表示；阴极视图筛选和 cEGR 阀节点 Inspector 交互正常。未修改 `.slx`，未新增仿真或硬件选型结论。
