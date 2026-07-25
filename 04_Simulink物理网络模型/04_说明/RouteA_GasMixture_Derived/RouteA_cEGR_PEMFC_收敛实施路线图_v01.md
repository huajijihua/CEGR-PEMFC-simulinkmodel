# Route A cEGR-PEMFC 收敛实施路线图

文件类型：后续实施、模型收敛和验证路线图  
日期：2026-07-25  
决策前置：[模型裁决与资产处置](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)

## 1. 总目标

在不重建官方案例、不复制第三套模型、不把 v09 结果冒充 v10 证明的前提下，把当前 Route A 收敛为一个可初始化、可解释、可审计的 L2 PEMFC-cEGR 系统平台。研究目标按“先物理闭合，再参数/控制，再性能矩阵，再机理扩展”推进。

本路线的活动主线只有：

- 一个主模型：`PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx`；
- 一个正式运行入口：统一 `SimulationInput`/`sim` 调度器；
- 一个主平台默认参数层：`platform_default`；
- 一个明确隔离的外部案例层：`external_case`；
- 一套分层验证证据：结构、初始化、短仿真、KPI、守恒和回归。

## 2. 阶段总表

| 阶段 | 核心任务 | 必须产物 | 出口门 |
|---|---|---|---|
| S0 决策冻结 | 固定模型、接口和资产处置 | 裁决记录、参数清单、warning ledger 草案 | 用户确认本路线；不再新增模型副本 |
| S1 物理边界收敛 | 关闭真实未连接端口，恢复单一供气边界 | 端口处置表、模型 read-back、结构检查记录 | Source_Conditioner 不再有未解释真实端口；结构 warning 可分类 |
| S2 最小 plant | 保留官方 stack/BOP，缩小 cEGR 到最小可验证路径 | 最小闭环模型记录、hash、compile/update 证据 | 无 DAE 初态失败的短 smoke |
| S3 参数和控制收敛 | 参数分层、单一 `I_cmd`、统一 case 装配 | 参数 API、case schema、兼容适配器 | Current/Power/Voltage 同一拓扑可装配 |
| S4 初态和数值收敛 | 冷态基线、热初态和边界敏感性 | v10 初态包、生成/审计记录 | 四个 Gate 2 case 全部通过 |
| S5 分层验证 | 子系统、整机、策略和回归 | 紧凑 KPI、失败栈、测试记录 | Gate 0-4 通过，才允许正式矩阵 |
| S6 CEGR 研究扩展 | 扫描回流比、背压、湿度、负载和控制策略 | 文献映射结果、敏感性/策略报告 | 每项扩展不改变平台边界和证据链 |

## 3. S0：决策冻结

### 工作内容

1. 以[模型裁决记录](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)为唯一模型版本决定；
2. 冻结 `u/w/y/z`、单位、符号、采样和单一 `I_cmd` 接口；
3. 为每个当前 block、脚本、MAT 和说明标记 `PRESERVE`、`REFACTOR`、`DEFER` 或 `HISTORICAL`；
4. 建立 warning ledger，至少包含路径、端口/警告、物理责任、处置方式、验证证据和 owner；
5. 建立参数表，记录名称、单位、来源、适用范围、写入点和默认/外部案例属性。

### 禁止事项

不改 `.slx` 结构、不生成正式矩阵、不迁移 v09 结果、不把 v2 hash 或旧初态名称写成当前事实。

### 出口条件

主模型、官方参考、v2 副本和历史资产的职责没有歧义；任何新结构请求都能判断为主线、实验或归档。

## 4. S1：物理边界收敛

### 4.1 阴极供气

先对 `Cathode_Source_Conditioner` 的混合 chamber 做逐端口 read-back。优先方案是恢复官方 Oxygen Source/Compressor/Reservoir 到 stack 的单一气体边界，并删除或停用未闭合的独立物种质量源。若保留 conditioner，必须明确每个物理端口的 owner、输入物种、能量/压力边界和初态来源，并用官方 Simscape 组件连接到唯一混合点。

### 4.2 阳极供气与排气

保留官方 Hydrogen/Fuel Tank/PRV/Anode Exhaust 语义，单独处理新 `Anode_Source_Conditioner` 与已有 Pipe、Purge Valve、PRV 的兼容关系。阳极端不能用关闭 purge 作为唯一修复；必须证明初态压力、物种库存和排气边界一致。

### 4.3 cEGR 主路径

只保留一条出口分流到入口混合的 cEGR 路径：出口 chamber -> 分流 -> 阻力/阀 -> EGR pipe -> cathode mixer。默认阀关闭或零目标时实际回流量应接近零；小目标 case 必须产生有方向、可解释的压力和组分变化。

### S1 出口

- `model_read` 能读回每个保留端口和连接；
- `model_check` warning 已分类，不再把真实未连接端口藏在 wrapper 中；
- update/compile 通过；
- 未引入 Terminator、人工质量源或 solver 放宽；
- 记录修改前后模型 hash 和差异说明。

若 S1 使 warning 增加、出现新的独立质量源或无法解释的端口 owner，停止进入 S2。

## 5. S2：最小 plant 与冷态可解性

此阶段只保留官方 stack/MEA、官方气路、最小 cEGR 支路、热边界和一个电负载边界。暂不加入完整液水库存、复杂背压控制、整车/DCDC 接口或新研究控制器。

最小 smoke 顺序：

1. `cold_idle`：默认气源、最小非零负载、cEGR=0，1 s；
2. `cold_nominal_current`：平台默认电流，10 s；
3. `cold_cegr_zero`：cEGR 拓扑启用但实际零回流，10 s；
4. `cold_cegr_small`：小回流目标，10 s。

每个 case 记录初态模式、solver、模型 hash、I/V/P、压力、温度、组分、NaN/Inf 和失败栈。任何 `NE_DAE_IC_Failure` 均退回 S1，不能通过延长仿真或放宽容差掩盖。

## 6. S3：参数与控制收敛

建议形成以下最小接口：

```matlab
platform = routeA_platform_default_parameters();
platform = routeA_apply_scaling_rule(platform, scalingRule);
caseCfg = routeA_validate_case(caseCfg, platform);
simIn = routeA_prepare_simulation_input(caseCfg, platform);
out = run_routeA_study(simIn);
report = routeA_assess_outputs(out);
```

实施顺序：

1. 先从当前参数脚本抽出来源 metadata 和层级，不先改数值；
2. 将设备几何、控制 tuning、demo 工况和研究命令分离；
3. 让 Power/Voltage 适配器只产生 `I_cmd`，保留限幅和 anti-windup；
4. 将 22 列 profile 收缩为按 case 继承的结构体，未使用字段不进入 plant；
5. 旧 runner 保留为兼容/证据入口，停止扩展；
6. 水账本、气体闭合和策略评估变为结果层插件。

S3 不得以“静态 Code Analyzer 通过”作为完成条件；必须用同一 plant 拿到 I/P/V 三个短 smoke 输出。

## 7. S4：初态与数值收敛

冷态模式用于排查边界和方程一致性；热初态只作为减少启动过渡的便利，不拥有场景命令。正式 v10 初态必须在当前主模型、当前参数链和当前拓扑 hash 下重新生成，并分别审计 Current、Power、Voltage 三个分支的模型名、schema、拓扑和元数据。

初态门禁：

- 模型名和拓扑 hash 与当前主模型一致；
- `platform_default`/`external_case` 标识正确；
- 初态不携带场景命令、cEGR 目标或功率/电压控制语义；
- 三分支都能被统一 runner 读取，旧 v09/v03 包被明确拒绝；
- 2 s 热启动 smoke 不出现 DAE failure，且与 cold case 的方向一致。

## 8. S5：验证和正式矩阵准入

验证严格按“结构 -> 子系统开环 -> 整机开环 -> 闭环策略 -> 回归矩阵”顺序。Gate 0/0.5 来源和文献口径、Gate 1 结构闭合、Gate 2 冷态稳定、Gate 3 KPI/守恒、Gate 4 动态与策略全部通过后，才允许长时间或多工况矩阵。

正式矩阵的每个结果必须包含紧凑摘要、模型 hash、参数层、case schema、solver、初态、KPI、warning/error 分类和失败栈路径。v09 结果只做历史回归对照，不与 v10 结果混写。

## 9. S6：CEGR 研究扩展顺序

研究扩展按以下最小风险顺序推进：

1. cEGR=0 与小回流：确认方向、物种和水分变化；
2. 低负载稳态：研究自湿化、氧稀释和排水风险；
3. 额定附近稳态：研究高流量、背压和辅机功耗；
4. 负载 step/ramp：研究控制跟踪和瞬态氧贫化；
5. purge、湿度、温度和背压扰动；
6. 仅在前述证据稳定后，增加策略比较或局部 COMSOL/AMESim 校核。

每个扩展都必须回到同一个 `u/w/y/z` 接口和同一 plant；文献中的影响机制是 KPI/假设来源，不自动转化为新的物理模块。

## 10. 交付物与记录规则

每阶段至少保留：变更说明、模型 hash、read-back 摘要、`model_check` 分类、最小运行结果、未解决风险和下一阶段准入结论。保留 `slprj/`、`.slxc` 和运行缓存，不把缓存清理作为验证动作；无确切用途的临时截图、CSV 或模型副本不新增。

本路线的低层细节见[平台实施计划](RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md)，测试场景和门槛见[平台测试计划](RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)。
