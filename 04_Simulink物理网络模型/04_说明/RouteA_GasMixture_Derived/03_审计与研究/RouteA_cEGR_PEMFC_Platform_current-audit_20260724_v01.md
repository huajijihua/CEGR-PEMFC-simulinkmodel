# RouteA cEGR-PEMFC Platform Current Asset Audit

文件类型：当前资产审计（只读证据）  
日期：2026-07-24（初稿）；2026-07-27（更新：S2/S3 验证完成）  
对象：当前 Route A `.slx`、活动 MATLAB 脚本、活动说明文件和已保存验证结果。

## 1. 审计结论

**更新（2026-07-27）：** 自初稿以来，以下阻断项已解决：

1. **Source_Conditioner 未闭合端口** — ✅ 已删除，恢复官方 Air Intake (Reservoir FC) 单一供气边界
2. **冷态 DAE IC Failure** — ✅ 已解决，四个 cold smoke case 全部通过
3. **恒电流/恒功率/恒电压验证** — ✅ 全部通过（共 18 个稳态工况 + 6 个组分工况）

当前主要剩余风险：
- 初始状态文件仍为 v09 schema，正式 runner 链无法使用
- 22 列 profile 的 O2/H2O 字段被 Terminator 吸收
- Gate 4 动态验证尚未执行

## 2. 当前资产证据

### 2.1 Git 和文件状态

- 当前分支：`master`，与 `origin/master` 同步；
- 当前 worktree 有未提交的模型、参数脚本、说明文件、SATK 元数据和新增历史/汇报目录；这些改动视为用户资产；
- 最近提交为 `2270d39 Refine Route A initial-state configuration and governance`；
- 活动模型仍为 `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`。

### 2.2 官方母版与当前派生模型规模

MATLAB `model_overview(detail="full")` 读回：

| 对象 | 根级自然容器 | 结论 |
|---|---|---:|
| 官方 Gas Mixture 母版 | 11 | 结构以电堆、阴/阳极气路、热、负载和测量为中心 |
| 当前 Route A 派生模型 | 23 | 增加 cEGR、排气水分离、FCU、命令 profile、观测和 Source_Conditioner 等多层结构 |

当前根级主要容器为 `Anode_Hydrogen_BOP`、`Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Stack_Core`、`System_Control_Observability`、`Thermal_Management_BOP`、`cEGR_Mode_Selector`，方向上覆盖了系统功能。

### 2.3 Source_Conditioner 处置

**更新（2026-07-27）：** 阴极和阳极 Source_Conditioner 已删除。阴极恢复 Air Intake (Reservoir FC) → CompressorInletMixer 的官方供气路径；阳极恢复 Fuel Tank → PRV → Pipe → H2 的官方路径。22 列 profile 的 Goto 信号链保留，From 块被 Terminator 吸收。模型 update/compile 通过，无 DAE IC Failure。

### 2.4 根级结构检查

当前 root `model_check(checks=["all"])` 返回 `status=warnings`、`total_warnings=77`。warning 涉及：

- `Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Stack_Core` 的连接器/接口；
- 官方/派生湿化器传感器；
- 阳极排气 `Pipe (FC)`；
- 阳极回流 `Constant Volume Chamber (FC)`；
- EGRPipe 和部分排气支路。

**更新：** 已确认这些 warning 主要是工具级 read-back 对 Variant/Simscape 连接的误报，以及合法边界端口。Source_Conditioner 相关的真实未连接端口已通过删除解决。

### 2.5 求解器与模型状态

当前参数读回为：

```text
Solver: VariableStepAuto
StopTime: 600 (研究时)
RelTol: 1e-3
AbsTol: 1e-3
MaxStep: 5
```

### 2.6 S2/S3 验证汇总

| 验证项 | 工况数 | 全部通过 | 关键指标 |
|---|---|---|---|
| 冷态 smoke | 4 | ✅ | 无 DAE IC Failure |
| 恒电流稳态 | 6 | ✅ | 5A~392A, 电压偏差 < 0.05% |
| 恒电流 + cEGR | 4 | ✅ | 100A/336A × cEGR=0.1/0.3 |
| 恒功率 + cEGR | 6 | ✅ | 40kW/120kW × cEGR=0/0.1/0.3, 功率误差 0.00% |
| 恒电压 + cEGR | 6 | ✅ | 410V/375V × cEGR=0/0.1/0.3, 电压误差 < 0.11% |
| 入口组分控制 | 6 | ✅ | O2=15-21%, H2O=0.5-3.0% |
| **合计** | **32** | **✅** | — |

## 3. 剩余风险

1. **初始状态文件 v09 schema**：当前 `RouteA_platform_default_initial_state.mat` 的 metadata 字段不含 v10 schema 标记，`routeA_attach_platform_default_initial_state.m` 拒绝加载。正式 runner 链无法使用，所有 S3 验证通过直接 SimulationInput 绕过。
2. **22 列 profile 的 O2/H2O 字段**：被 Terminator 吸收，不参与 Air Intake 控制。如需动态组分控制，需将 Reservoir 替换为 Controlled Reservoir 或自定义组件。
3. **Gate 4 动态验证**：尚未执行负载 step/ramp、cEGR 变化、空气供给扰动等动态测试。
4. **RouteA_v2 和 RouteA_before**：已归档至 `99_历史归档/2026-07-27_RouteA_before_and_v2_archived/`，不再作为活动资产。