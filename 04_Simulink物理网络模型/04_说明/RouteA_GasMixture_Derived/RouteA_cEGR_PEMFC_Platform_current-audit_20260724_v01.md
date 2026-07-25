# RouteA cEGR-PEMFC Platform Current Asset Audit

文件类型：当前资产审计（只读证据）  
日期：2026-07-24  
对象：当前 Route A `.slx`、活动 MATLAB 脚本、活动说明文件和已保存 v09 结果。

## 1. 审计结论

当前仓库具备一个官方 Gas Mixture PEMFC 派生模型和一套能完成 v09 I/P/V 矩阵的 runner，但还不能把当前活动模型称为已闭合、轻量、通用的 cEGR 平台。主要阻断项是当前 v10 Source_Conditioner 的物理端口未闭合，以及冷态初始条件求解失败；主要架构风险是参数、命令、初态和审计职责同时膨胀。

本次审计不回滚 dirty worktree，不修改 `.slx`，不覆盖 v09 结果。

## 2. 当前资产证据

### 2.1 Git 和文件状态

- 当前分支：`master`，与 `origin/master` 同步；
- 当前 worktree 有未提交的模型、参数脚本、说明文件、SATK 元数据和新增历史/汇报目录；这些改动视为用户资产；
- 最近提交为 `d4bbf3c feat(routea): implement v10 physical hot-start and command profiles`；
- 活动模型仍为 `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`。

### 2.2 官方母版与当前派生模型规模

MATLAB `model_overview(detail="full")` 读回：

| 对象 | 根级自然容器 | 结论 |
|---|---:|---|
| 官方 Gas Mixture 母版 | 11 | 结构以电堆、阴/阳极气路、热、负载和测量为中心 |
| 当前 Route A 派生模型 | 23 | 增加 cEGR、排气水分离、FCU、命令 profile、观测和 Source_Conditioner 等多层结构 |

当前根级主要容器为 `Anode_Hydrogen_BOP`、`Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Stack_Core`、`System_Control_Observability`、`Thermal_Management_BOP`、`cEGR_Mode_Selector`，方向上覆盖了系统功能，但自然边界和平台默认能力没有同步收敛。

### 2.3 当前 Source_Conditioner 读回

阴极 `blk_1606` 和阳极 `blk_1607` 都包含官方 `Reservoir (FC)`、`Mass Flow Rate Source (FC)`、`Constant Volume Chamber (FC)`、`Pressure Source (FC)` 和受控温度源。两处 `Mixing_Chamber` 都读回为三端口 chamber，但以下端口没有连接：

```text
MIn, TIn, A, B, C, pC, TC, yC_i, H
```

定向 `model_check` 结果：阴极 `blk_1606` 为 9 个 warning，阳极 `blk_1607` 为 9 个 warning；这不是单纯的显示问题。当前结构不能以编译通过代替物理端口闭合。

### 2.4 根级结构检查

当前 root `model_check(checks=["all"])` 返回 `status=warnings`、`total_warnings=77`。warning 涉及：

- 当前 Source_Conditioner chamber；
- `Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Stack_Core` 的连接器/接口；
- 官方/派生湿化器传感器；
- 阳极排气 `Pipe (FC)`；
- 阳极回流 `Constant Volume Chamber (FC)`；
- EGRPipe 和部分排气支路。

是否有一部分是 read-back 对 Variant/Simscape 连接的工具级误报，需要另立 warning ledger；但当前至少存在已被定向检查确认的真实未闭合 Source_Conditioner 端口，因此不能宣称 root 级结构健康。

### 2.5 求解器与模型状态

当前参数读回为：

```text
Solver=VariableStepAuto
StartTime=0
StopTime=2500
LoadInitialState=off
SignalLogging=on
Electrical Load/input_type=Current
Cathode Mixing_Chamber: T0=env_T, p0=env_p, V0=routeA_cathode_source_conditioner_volume_L, num_ports=three
Anode Mixing_Chamber: T0=tank_T, p0=tank_p, V0=routeA_anode_source_conditioner_volume_L, num_ports=three
```

当前模型可以完成结构 update/compile，但这只证明参数和 block 方程在编译阶段可接受，不能证明冷态初始化或短时仿真可用。

## 3. 失败证据

上一会话 `019f8cbf-8eea-70e0-9c29-3273448ad84f` 的直接诊断调用最终返回：

```text
physmod:simscape:engine:core:dae_errors:NE_DAE_IC_Failure
Solver Configuration: 初始条件求解未能收敛
```

不收敛方程包括：

- `Anode_Hydrogen_BOP/Anode Exhaust/Pipe (FC)`；
- `Anode_Hydrogen_BOP/Anode Exhaust/Purge Valve`；
- `Anode_Hydrogen_BOP/Hydrogen Source/Pressure-Reducing Valve/Valve`；
- `Cathode_Air_cEGR_BOP/EGRPipe`；
- 新增 `Anode_Source_Conditioner/Mixing_Chamber`。

关闭初始 purge 后，既有阳极排气 `Pipe/Valve` 仍出现在失败栈中。因此当前根因不能简化为 Relay 开关；它是冷态边界、既有阳极排气网络、PRV 和新增 chamber 初态之间的兼容性问题。

## 4. 脚本审计

MATLAB Code Analyzer 对平台参数脚本、profile 规范化、输入装配、study runner、初态生成和参数一致性初态脚本均返回 0 个问题。这说明脚本语法和静态质量尚可，但不能抵消运行期物理失败。

当前活动脚本体量显示职责仍然偏重：

| 文件 | 行数 | 观察 |
|---|---:|---|
| `routeA_stage1_water_ledger_from_outputs.m` | 892 | 结果审计过重，不应成为 plant 核心依赖 |
| `routeA_prepare_parameter_consistent_initial_state.m` | 840 | 初态、参数覆盖、I/P/V 分支和周期审计混在一个入口 |
| `run_routeA_electrical_boundary_study.m` | 703 | 调度、结果整形和共享水账本耦合 |
| `routeA_assess_electrical_boundary_outputs.m` | 579 | KPI、稳态门、cEGR 和边界审计集中在单文件 |
| `routeA_prepare_electrical_boundary_input.m` | 516 | 22 列命令、I/P/V 分支和多个控制域一起装配 |

当前参数脚本虽然声明了 `platform_default`，但同时包含 stack 几何、气路几何、Source_Conditioner 候选参数、控制器 tuning、Voltage 默认目标、demo 默认工况和 22 列 command baseline。它在语法上是单文件真源，在语义上仍是多个层的混合容器。

## 5. 已保存结果的边界

只读加载三份既有 v09 MAT 结果确认：

| 结果 | `passed` | `waterLedgerPassed` |
|---|---:|---:|
| Current 9 cases | true | true |
| Power 3 cases | true | true |
| Voltage 3 cases | true | true |

这些结果证明 v09 runner 和当时的模型/参数链有一组完整回归证据；它们不证明当前 v10 Source_Conditioner、v10 热初态或重置后目标架构已经通过。当前 v10 初态 MAT 尚未生成。

## 6. 差距分级

### P0：阻断当前平台声明

1. Source_Conditioner 物理端口未闭合；
2. 冷态初始条件求解失败；
3. 根级 77 个 warning 尚未形成可接受的分类 ledger。

### P1：必须在继续扩展前收敛

1. 22 列全域命令 profile 把主动命令、设备设定和研究默认值绑在一起；
2. I/P/V 作为模型 Variant 分支，导致初态和结构 checksum 复杂化；
3. 平台参数、控制调参、demo 工况和候选设备参数混在同一初始化脚本；
4. 初态生成脚本同时承担参数覆盖、负载分支、热启动、周期检测和结果摘要；
5. 水账本/气体闭合审计与正式 runner 耦合，失败分类不够分层。

### P2：后续能力

1. 显式液水库存、排液和分离效率；
2. 产品级压缩机地图、功耗和机械约束；
3. 背压 PI、完整热执行器和整车/DCDC 接口；
4. 外部案例和标定参数的独立配置包。

## 7. 审计结论和下一步

当前最合理的下一步不是继续修补单个 Pipe 或追加更多 profile 字段，而是先审阅并冻结本目录的四份平台规格。冻结后按实施计划：恢复最小官方派生 plant -> 收缩 cEGR 物理路径 -> 建立参数层 -> 统一 `I_cmd` -> 重新建立冷态和代表性 smoke。

在规格冻结前，当前 `.slx`、v09 MAT、`slprj/`、`.slxc` 和 dirty worktree 均保持原状。

