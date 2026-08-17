# Route A cEGR-PEMFC 聚焦模型 P4 阀门被动式膜加湿 L2 接口配置实施记录

日期：2026-08-14  
状态：完成；配置 B 为 L2 气路接口，非跨膜换湿模型

## 1. 前置决策

- 当前规划真源：[两种阀门被动架构聚焦模型改造实施方案](../../01_当前指导/RouteA_cEGR_PEMFC_两种阀门被动架构_聚焦模型改造实施方案_v01.md)。
- 用户已确认第一版气相分离边界不移除水蒸气、不改变气相组分；配置 B 先实现干湿侧 L2 接口，不能用于 A/B 换湿性能排序。
- 单一正式模型和单一正式 runner 原则保持不变。

## 2. 实际完成的工作

1. 在正式模型 `PEMFuelCellSystem_Cathode_cEGR_Focused_v01.slx` 的 `Cathode_Exhaust_Backpressure_Water` 中，建立湿侧 L2 主链：

   ```text
   CathodeOutletChamber
    -> CommonBackpressureValve_FC
    -> MembraneHumidifierWet_L2_FC
    -> CommonGasPhaseBoundary_FC
    -> return/exhaust split
   ```

2. 干侧保留 `Cathode Humidifier/Pipe (FC)`，并通过现有 `cathode.humidifierEnabled=0` 命令链维持 `MIn=0`；它不是跨膜换湿模型。
3. 首次将湿侧实现为 `Pipe (FC)`。该实现引入未标定气体容积、热端口和水状态，5 A 冷启动发生 `physmod:simscape:engine:core:dae_errors:NE_DAE_IC_Failure`。将管段初始压力临时接入 runner 也不能消除该物理初始条件失败，且该变量在共享输入适配器计算模型校验和前不可解析。
4. 删除上述未闭合的储能建模尝试，最终将湿侧收敛为官方 `Flow Resistance (FC)`。该元件无内部储气、传热或冷凝状态，参数复用已存在的 `cathode_separator_area`、`cathode_separator_dp_nominal`、`cathode_separator_mdot_nominal`、`cathode_separator_laminar_fraction`；没有新增设备标定参数。
5. 更新 `run_routeA_focused_study.m`：study 的 `architectureId` 和 `architecture` 来自 case，并禁止单个 study 混合架构标识。
6. 更新 `routeA_focused_water_observations.m`：湿侧 L2 流阻返回 `not_applicable_L2_no_storage`，不被误记为缺失的冷凝或饱和数据。其他气相节点继续使用实际 Simscape 日志计算饱和度。

## 3. 读回和结构验证

- `model_read` 读回 `CommonBackpressureValve_FC.B -> MembraneHumidifierWet_L2_FC.A -> CommonGasPhaseBoundary_FC.A`，并确认分离边界下游仍接回流和排放支路。
- `MembraneHumidifierWet_L2_FC` 读回为 `FuelCell_lib/elements/Flow Resistance (FC)`，四项参数均为已存在的 `cathode_separator_*` 写入点。
- `model_check(all)` 在工作区作用域无 error；仅保留既有 `Cathode Exhaust/Pipe (N Gas)1` 的物理端口检查误报。根作用域同样没有 error，保留 63 条既有物理端口误报。
- MATLAB 保存正式模型后 `Dirty=off`。
- 相关 MATLAB 脚本静态分析无错误；`run_routeA_focused_study.m` 和 `routeA_focused_water_observations.m` 仅有旧的、已不再需要的 Code Analyzer 抑制标记提示。

## 4. 执行和行为证据

正式 runner：`03_脚本/RouteA_Cathode_cEGR_Focused/run_routeA_focused_study.m`。

| 结果文件 | 工况 | 执行结果 | 关键读回 |
|---|---|---|---|
| `RouteA_Focused_P4_external_membrane_L2_60s_validation_20260814.mat` | 5 A，60 s，`cEGR=0`，`MIn=0` | 通过 | 阴极出口压力 `0.154481 MPa(abs)`；气相质量闭合通过；湿侧状态为 `not_applicable_L2_no_storage` |
| 同上 | 5 A，60 s，`cEGR=0.05`，`MIn=0` | 执行完成但未稳态 | 实际 CEGR 比 `0.0482354`；气相质量闭合通过 |
| `RouteA_Focused_P4_external_membrane_L2_small_cegr_180s_validation_20260814.mat` | 5 A，180 s，尾窗 150--180 s，`cEGR=0.05`，`MIn=0` | 严格稳态通过 | 实际 CEGR 比 `0.0499983`；总质量基 `r_split=0.0504`；回流/排放为 `8.3337e-04/1.57e-02 kg/s`；最大尾窗相对变化 `2.9601e-05` |

180 s 通过 case 的压力链读回为：阴极出口 `0.1545 MPa(abs)`、压缩机入口 `0.1013 MPa(abs)`、出口至压缩机入口裕度 `0.0532 MPa`。七个有内部气相状态的观测节点最大饱和度为 `0.465283`，均未超过 1。外部注水使能命令为 0；Faraday 派生 MEA 水为 `1.8655e-04 kg/s`，回流水蒸气为 `1.2403e-05 kg/s`，出口水蒸气为 `2.4585e-04 kg/s`，混合水蒸气残差为 `-3.7888e-10 kg/s`。

## 5. 结论和未决项

本阶段完成了配置 B 的气相 L2 湿侧接口、公共气路位置和结果标识，并证明其在代表性小回流工况下可冷启动、闭合和稳态运行。它不表示已经建立膜加湿器，也不证明膜两侧温湿压降、跨膜传质、跨膜热传递、液水、真实分离或压缩机湿气耐受。

在没有双侧膜组件或受控跨膜传递合同前，配置 A/B 的换湿性能、净功率、成本、耐久和设备选型均不可排序。P5 还需要用户冻结低负荷/怠速的供气边界、环境基线和研究矩阵，之后才能开始正式性能研究。
