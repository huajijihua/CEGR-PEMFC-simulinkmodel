# Route A cEGR-PEMFC 实施记录：四个会议问题研究与冷凝风险筛选

日期：2026-08-14  
目标：用聚焦模型回答被动 cEGR/背压控制、压缩机压力边界、空压机前冷凝和防冷凝设计四个会议问题。  
模型：`PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx`  
runner：`run_routeA_focused_study.m`

## 1. 本轮实施

- 新增 `routeA_focused_pressure_observations.m`，从现有 Simscape log 读取压缩机入口混合点、压缩机容积排出、冷却器后传感器和阴极出口腔体压力/温度。
- 新增 `routeA_focused_anti_condensation_analysis.m`，计算水蒸气分压、饱和压力、饱和度、露点、露点裕度、所需升温、蒸汽降低比例和液水去除筛选代理。
- 将压力链与防冷凝结果接入 `routeA_focused_assess_outputs.m`、`routeA_focused_performance_metrics.m` 和 `routeA_focused_performance_analysis.m`。
- 复用官方 `FuelCell_lib/elements/Flow Resistance (FC)` 处理模式，将 `CathodeOutletResistance` 的 `delta_p_nominal`、`mdot_nominal` 和 `area` 改为 `cathode_channel_dp_nominal_MPa`、`cathode_channel_mdot_nominal_kg_s` 和 `cathode_channel_flow_area_m2` 三个可标定变量；默认值保持原 L2 接口值。
- 修正聚焦参数桥接：阴极源温度通过 `env_T` 进入当前 Air Intake/气路初态；实际入口压力默认取环境绝对压力并同步混合器/EGR 管初态。旧阴极源压力命令列被结构读回确认曾经由 Terminator 吸收，非环境压力 override 不纳入工程结论。
- 没有对 `.slx` 进行结构编辑；模型 `Dirty=off`，checksum 为 `652D323D-5E96292F-979D5198-5E667C40`。

## 2. 执行配置

- 初始化：`cold_start_only`、`LoadInitialState=off`。
- 求解器：`VariableStepAuto`、`RelTol=1e-3`、`AbsTol=1e-3`、`MaxStep=5 s`。
- 正式时长：`600 s`，尾窗 `[540,600] s`。
- 正式矩阵：最终接口修正后执行 5 个 cEGR/背压 case、4 个源温度 case、5 个露点阈值 case、2 个低负荷 case和 1 个标准 `simCase` bridge case，均 `simCompleted=1` 且 `passed=1`。
- `model_check(root, all)`：`63` 条 warning、无 error severity；warning ledger 范围未扩大。
- MATLAB Code Analyzer：本轮新增/修改脚本无 error；仅保留已有 ToWorkspace/Simscape logging 相关运行 warning。

## 3. 主要证据

### 3.1 被动阀、背压和压力边界

`40 kW / OER=3.0 / 背压=0.1613 MPa(abs)`：

- `cEGR=0.1`：实际 `r_mix=0.10000`、回流量 `0.00415051 kg/s`、阀面积分数 `0.09166`、阀压差 `0.060747 MPa`。
- `cEGR=0.3`：实际 `r_mix=0.30000`、`r_fresh=0.42857`、回流量 `0.0125449 kg/s`、阀面积分数 `0.28235`、阀压差 `0.060620 MPa`。
- `cEGR=0.3` 时压缩机容积排出 `0.162401 MPa(abs)`，冷却器后 `0.162226 MPa(abs)`，阴极出口 `0.161966 MPa(abs)`，压缩机后裕度 `0.261 kPa`。
- 同一 case 的 `Stack_Core/Cathode Gas Channels/Cathode` 容积平均压力为 `0.162183 MPa(abs)`；相对于阴极出口腔体的通道压降为 `0.2169 kPa`，相对于冷却器后供气压力的系统入口到出口压降为 `0.2605 kPa`。
- 等效阴极流阻敏感性：`cathode_channel_dp_nominal_MPa=0.001/0.01/0.03` 时，实际冷却器后到出口总压降分别为 `0.261/2.236/6.786 kPa`，压缩机后压力分别为 `0.162226/0.164208/0.168774 MPa(abs)`。

背压目标 `0.13 / 0.1613 / 0.18 MPa(abs)`、`cEGR=0.3` 时，压缩机后裕度分别约 `0.224 / 0.261 / 0.283 kPa`，阀压差约 `0.029441 / 0.060620 / 0.079309 MPa`。

### 3.2 冷凝和低负荷

- 默认 `40 kW / cEGR=0.3 / 源温度=20 degC`：混合点温度 `41.692 degC`、露点 `49.583 degC`、露点裕度 `-7.891 degC`、饱和度 `1.49796`、冷凝率 `2.856e-6 kg/s`。
- `5 A / cEGR=0.3`：混合点温度 `38.908 degC`、露点 `41.584 degC`、露点裕度 `-2.676 degC`、饱和度 `1.15310`、冷凝率 `7.622e-7 kg/s`。
- `5 A / cEGR=0`：混合点饱和度约 `0.50095`，冷凝率为 `0`。

### 3.3 升温门槛

`40 kW / cEGR=0.3 / 背压=0.1613 MPa(abs)`：

- 源温度 `35 degC`：露点裕度 `-0.299 degC`，冷凝率 `1.582e-7 kg/s`；
- 源温度 `37 degC`：露点裕度 `+0.738 degC`，冷凝率 `0`；
- 源温度 `40 degC`：露点裕度 `+2.341 degC`，冷凝率 `0`；
- 源温度 `60/80 degC`：裕度继续增加，但仅属于当前环境/气路边界代理，不是局部加热器额定设计。

## 4. 结论与未决风险

- 当前模型可证明被动 cEGR 在指定边界下能够按目标比例跟踪，回流方向由阴极出口到压缩机入口混合点。
- 结构复核确认 `Cathode Gas Channels` 仍是单个 Constant Volume Chamber；当前已按官方 FC 域模式加入可标定等效 Flow Resistance，但入口/出口歧管和分布式流道摩擦仍未显式建模。
- 没有主动泵时，压缩机前回流仍是当前模型可解释的研究路线；压缩机后回流的工程可行性必须使用标定后的等效阴极流阻再裁决，不能用默认 `0.26 kPa` 读回余量放行。
- 当前模型可以识别和计算空压机前气相冷凝代理，但不可以把该结果表述为液滴实际进入空压机的质量流率。
- 压力不是单独由 `PV=nRT` 后处理得到：容积内状态方程与网络的质量/能量守恒、管路/阀压降和压缩机图谱共同联立求解；报告中的压降是压力状态读回后的差值。
- 防冷凝优先采用 EGR 支路保温/再热、露点裕度闭环、低点排液和液滴捕集；分离器不能替代降低水蒸气分压的热湿控制。
- 尚未闭合真实加热器、换热器、分离器效率、液水库存/输运/排液、压缩机允许含液率、压缩机/泵寄生功率和耐久性。

详细结论见 `03_审计与研究/RouteA_Cathode_cEGR_Focused_四个问题研究结论_v01.md`。

状态：`implemented_structurally_verified_executed_behavior_verified_for_focused_scope_not_validated_for_engineering`。

口径后续裁决：本记录中的 `r_mix` 和 `r_fresh` 保留为本轮历史执行证据；2026-08-14 工程化架构规划将分流点 `r_split` 设为后续架构回流能力主指标。新指标已在聚焦 runner 中建立并通过独立 smoke，但本记录的历史矩阵不改标为 `r_split`。
