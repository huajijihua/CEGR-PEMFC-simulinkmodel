# RouteA cEGR-PEMFC Platform Implementation Plan v01

文件类型：RouteA_v2 平台实施主计划（受控修订）
日期：2026-07-24
状态：执行入口已建立；Phase 0/0.5 尚未收口，不表示模型已通过验证。
副本范围：RouteA_v2 独立模型树；原 RouteA 只作为来源、对照和历史证据，不在本计划下修改。
前置文档：[系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)、[架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)、[测试计划](RouteA_cEGR_PEMFC_Platform_test-plan_v01.md)、[CEGR 文献研究与模型映射](RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)
执行记录入口：[RouteA_v2_Execution_Record](../RouteA_v2_Execution_Record/README.md)

## 1. 本文件的责任

本文件是接下来 RouteA_v2 建模、参数治理、runner 收敛和验证推广的唯一阶段执行计划。它回答“先做什么、允许改什么、以什么证据收口、失败后能否继续”；它不替代系统规格、架构规格或测试计划，也不记录尚未发生的执行结果。

任何 RouteA_v2 的 `.slx` 结构修改、活动参数入口修改、控制接口修改或正式仿真，都必须先指明所属 Phase，并在执行前后写入 `RouteA_v2_Execution_Record`。没有记录、没有读回和没有最小必要验证的工作，只能标记为候选变更，不能称为阶段完成。

本计划遵循以下边界：

1. RouteA_v2 不是回退到官方案例重新建模，而是“官方案例 + CEGR 文献 + 当前 RouteA 现状”的证据保留式收敛；
2. 当前 RouteA 已完成的官方 Gas Mixture/FuelCell 气体域、MEA、电堆热端、cEGR 主气路、BOP、控制、runner 和观测资产先读回、分类，再定点修改；
3. cEGR 的物理本体仍是“阴极出口气体分流 -> 阀/泵/阻力设备 -> 阴极入口混合”，氧稀释、自增湿、排水、低负荷高电位、动态饥饿、寄生功耗和冷启动是研究影响项与 KPI，不是另造的 cEGR 效果模块；
4. 只有一个当前 RouteA_v2 `.slx` 和一个物理 plant；Current、Power、Voltage 以及不同 cEGR 研究用途通过配置或控制器适配表达，不复制 plant；
5. 一条主执行链顺序修改同一个活动模型；不通过并行 agent 同时写同一个 `.slx`、参数真源或活动 runner；
6. 编译通过、静态检查通过或脚本装配成功，均不能替代冷态初始条件和短仿真证据。

## 2. 阶段总览与当前状态

阶段顺序固定为：

```text
Phase 0 -> Phase 0.5 -> Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5
                 |              |         |         |         |
                 +--------------+---------+---------+---------+-- 每阶段都要写执行记录并通过门禁
```

| 阶段 | 主要责任 | 当前状态 | 允许进入的工作 | 执行记录 |
|---|---|---|---|---|
| Phase 0 | 资产、接口和现状基线冻结 | `IN_PROGRESS` | 只读盘点、接口表、warning ledger、来源核对 | `R00_baseline_and_interface_freeze_20260724_v01.md`、`R00_document_review_20260724_v01.md` |
| Phase 0.5 | CEGR 文献证据和模型映射 | `IN_PROGRESS` | 文献精读、变量口径、首个用例和资产处置 | `R00_5_cegr_literature_mapping_20260724_v01.md` |
| Phase 1 | 物理拓扑和未闭合接口收敛 | `PENDING` | 通过 Phase 0/0.5 后的小步 `.slx` 修改 | 按模板新建 `R01_*.md` |
| Phase 2 | `platform_default` 参数单一真源 | `PENDING` | 参数入口、来源元数据、兼容适配器 | 按模板新建 `R02_*.md` |
| Phase 3 | I/P/V 和气路控制接口收缩 | `PENDING` | 同一 plant 的命令适配和控制反馈 | 按模板新建 `R03_*.md` |
| Phase 4 | runner、结果和失败分类收口 | `PENDING` | `SimulationInput`、结果摘要和审计插件 | 按模板新建 `R04_*.md` |
| Phase 5 | 分层验证、回归和推广 | `PENDING` | 代表性 case、动态 case、矩阵和版本晋级 | 按模板新建 `R05_*.md` |

`IN_PROGRESS` 只表示该阶段仍在处理，不等于通过。只有执行记录中同时出现“输入已核对、执行已完成、证据可定位、出口条件逐项判定、未决项已分类”，阶段才可以标为 `PASSED` 或 `PASSED_WITH_OPEN_RISKS`。

## 3. 每个阶段的统一执行闭环

所有阶段都按下列顺序执行，不能把多个未收口问题混成一次大改：

1. **准入核对**：读取当前 v2 模型、相关脚本、前置文档、上一阶段记录和 Git dirty 状态；确认 RouteA 原目录不在本次写入范围；
2. **目标定位**：记录目标模型/子系统/脚本、允许修改范围、禁止修改范围、保持不变的假设、预期影响和回滚边界；
3. **小步执行**：一轮只处理一个明确问题，例如一个物理端口组、一个参数写入点或一个 runner 契约；
4. **read-back**：用 `model_overview`、`model_read`、参数查询或脚本扫描读回实际结果；不以 UI 画面或代码意图代替读回；
5. **结构检查**：结构变更后执行 `model_check`，区分继承 warning、合法边界端口、真实未连接端口和新产生的 warning；
6. **最小必要验证**：先做 update/compile，再做与本轮问题直接相关的最小 smoke；若涉及初态或求解器，必须保留失败栈；
7. **保存与磁盘核对**：模型修改必须显式保存，并核对文件时间、大小或 hash；脚本和文档修改必须读回关键段落；
8. **记录与收口**：把实际变更、证据路径、结果、未决项和下一步准入条件写入阶段记录，再决定继续、暂停、回滚或降级结论。

不能把 `model_check` 的 warning 数量下降、Code Analyzer 为 0、模型能 update 或 v09 结果存在，单独写成 RouteA_v2 运行通过。

## 4. Phase 0：资产、接口和现状基线冻结

**目标：** 建立 RouteA_v2 的唯一工作边界和可审计基线，不修改 `.slx` 结构。

**进入条件：** RouteA_v2 独立目录已建立；当前 v2 模型、脚本、说明文件和结果目录可定位；RouteA 原目录保持来源/对照边界。

**执行内容：**

1. 记录 v2 模型路径、模型根名称、顶层容器、脚本入口、参数资产、兼容初态和当前结果状态；
2. 建立官方母版、当前 RouteA 和 RouteA_v2 的来源关系；v09/v10 结果只标记为历史或失败证据，不移植为 v2 通过证据；
3. 对当前资产标记 `PRESERVE`、`REFACTOR`、`DEFER`、`HISTORICAL`，至少覆盖 `Cathode_Air_cEGR_BOP`、`Cathode_Exhaust_Backpressure_Water`、`Anode_Hydrogen_BOP`、`Stack_Core`、`Thermal_Management_BOP`、`System_Control_Observability`、`cEGR_Mode_Selector` 和两侧 `Source_Conditioner`；
4. 冻结 `u/w/y/z` 接口、单位、方向、采样和“命令值/网络实际值”的区别；
5. 建立 warning ledger：每条 warning 都有位置、类型、是否合法边界、责任模块、处理决定和验证状态；
6. 记录当前初态、求解器、update/compile、`NE_DAE_IC_Failure` 和短 smoke 的事实，不在本阶段试图修复它们。

**本阶段允许：** 只读模型审查、脚本/路径检查、文档更新、接口表、warning ledger 和失败证据整理。
**本阶段禁止：** 新增 Source_Conditioner、修改气路拓扑、增加 command 字段、用 Terminator 掩盖活动物理端口、修改 RouteA 原模型。

**出口条件：**

- v2 资产清单和四类处置标签完整；
- `u/w/y/z`、cEGR 实际量和 I/P/V 内部接口没有互相矛盾的定义；
- warning ledger 能区分继承问题与本轮新增问题；
- 记录中列出所有阻塞 Phase 0.5/Phase 1 的未决项；
- 用户确认规格包可以按当前边界进入文献准入阶段。

**当前判定：** `IN_PROGRESS`。已完成 v2 目录分离、模型/脚本/文档来源核对和基础模型读回；接口处置表与 warning ledger 尚未作为完整收口证据固化。

## 5. Phase 0.5：CEGR 文献证据和模型映射

**目标：** 把文献结论变成可执行的物理边界、变量口径、研究问题和验证工况，不把论文影响项误写成 cEGR 物理控制结构。

**进入条件：** Phase 0 的当前资产和接口基线已可读；本地直接 CEGR 文献和官方 Gas Mixture/FuelCell 参考资产已定位。

**执行内容：**

1. 对本地 8 篇直接 CEGR 文献逐篇记录对象规模、气路结构、设备/执行器、状态变量、控制对象、工况范围、观测量、模型假设和不可迁移参数；
2. 对补充论文记录其证据等级和可用边界，不把单池、单堆或单一功率等级参数直接写入 `platform_default`；
3. 固定 cEGR 物理链：阴极出口气体分流 -> 被动阀/局部阻力或主动泵 -> 管路/容腔 -> 阴极入口混合；回流组分、温度、压力和湿度必须由出口网络产生；
4. 固定 `mdot_fresh`、`mdot_cegr`、`mdot_mix_in`、湿/干基回流比、`lambda_fresh`、`lambda_mix`、`pO2_ca_in`、`yO2_ca_in` 和 `RH_ca_in` 的定义；
5. 形成“文献机制 -> RouteA 变量 -> 当前模块 -> 最小验证工况 -> 证据等级”的映射；
6. 只选择一个首个闭环用例，例如低负荷 O2 分压/湿度权衡；冷启动、液水、主动泵功耗和动态饥饿先作为后续专项，不同时开放；
7. 对每个拟修改模块给出证据来源、物理职责、验证目标和暂停条件。

**出口条件：**

- 文献证据矩阵和逐篇精读记录可追溯到本地 PDF 或官方资料；
- 首个研究用例、执行器配置和 KPI 已确定；
- cEGR 的命令、实际流量和实际组分没有直接替代关系；
- 当前模块处置表没有“无来源、无职责、无验证目标”的待修改项；
- 用户确认后才允许进入 `.slx` 结构修改。

**当前判定：** `IN_PROGRESS`。第一轮文献矩阵和物理口径已形成，但首个闭环用例、逐篇参数可迁移性和当前 Source_Conditioner 端口映射仍需在记录中收口。

## 6. Phase 1：物理拓扑和未闭合接口收敛

**目标：** 在保留当前 RouteA cEGR 主气路和官方物理资产的前提下，解决真实未闭合接口、重复边界和不清晰的设备语义。

**进入条件：** Phase 0 和 Phase 0.5 通过；Phase 1 的修改清单、回滚点和最小验证 case 已写入记录。

**执行顺序：**

1. 对两侧 `Source_Conditioner` 逐个端口读回，说明端口代表的物理边界、混合点、测量量、连接器还是历史遗留；
2. 先处理一个端口组，再做 read-back 和 `model_check`，不得整体删除或整体复制；
3. 保留阴极出口分流、阀/阻力、cEGR 管路、入口混合和排气支路的因果链；
4. 清理并列强制物种源、重复入口边界或把实际流量写死的接口，仅在接口职责已证实时修改；
5. 对每轮修改执行 update/compile 和与该端口组对应的冷态/热态最小 smoke；
6. 显式保存 v2 模型，记录结构摘要、warning 变化、初态结果和失败分类。

**保留边界：** 官方 MEA/气体域、电堆热端、当前 cEGR 主气路、已解释的 BOP 和观测资产优先保留。
**暂缓边界：** 产品级 compressor/pump map、完整液水/冻结状态、没有证据支撑的额外 Source_Conditioner 端口和新的全局 command 总线。

**出口条件：**

- 活动物理端口全部闭合，合法边界端口有架构说明；
- warning ledger 中没有未分类的活动物理 warning；
- update/compile 通过；
- `cold_idle`、`cold_nominal_current`、`cold_cegr_zero` 至少完成与本阶段目标一致的最小验证；
- `NE_DAE_IC_Failure` 若仍存在，必须明确失败位置、最小复现输入和下一阶段是否被阻断；
- 每个保留、重构、暂缓和历史模块均有实际记录。

**失败处理：** 任何新 warning、初态失败或守恒异常都先暂停结构扩展，回到本阶段最近一次记录的模型版本和输入，不能用增加块或放宽 solver 继续推进。

## 7. Phase 2：`platform_default` 参数单一真源

**目标：** 让每个活动参数都能回答来源、单位、适用范围、写入点和是否属于默认平台。

**计划 API：**

```matlab
platform = routeA_platform_default_parameters();
platform = routeA_apply_scaling_rule(platform, scalingRule);
caseCfg = routeA_merge_external_case(platform, externalCase, ...);
```

**执行内容：**

1. 建立参数表：名称、单位、默认值/范围、来源标签、适用对象、写入脚本、使用 block 和验证 case；
2. 将 `official_base`、`platform_default`、`scaling_rule`、`study_command`、`external_case`、`calibration` 分层；
3. 保留必要官方兼容标量别名，但所有别名只由一个装配入口生成；
4. 将 10 kW 台架、DQ60、旧 CSV、历史 workbook 和旧标定留在 `external_case`，不进入默认链；
5. 旧变量删除前建立兼容适配器，并用 read-back 确认活动模型已经迁移；
6. 记录一组默认平台 case 和一组显式 external case 的差异，避免误把外部案例结果当平台结果。

**出口条件：** 参数审计能够定位每个活动值的 source、单位、范围和唯一写入点；默认链不读取外部案例；一组冷态 nominal case 使用该入口可重复装配。

## 8. Phase 3：控制和负载接口收缩

**目标：** 保留用户侧 I/P/V 研究语义，但使同一 plant 只有一个内部 `I_cmd` 和一套气热拓扑。

**执行内容：**

1. Current 直接映射 `I_cmd`；Power 通过 `P_ref / max(V_stack,V_floor)` 产生 `I_cmd`；Voltage 由明确的电压控制器产生 `I_cmd`；
2. 明确一个 study 只能选择一种用户侧边界类型；
3. 气路命令使用分层 case/config 传递，只开放实际执行器命令和必要的上层设定值；
4. `cegr_ratio_cmd` 如果保留，只作为 setpoint，由控制器转换为阀开度、泵速、背压或其他设备命令；不得直接写入 `mdot_cegr` 或气体组分；
5. 每个控制输出记录命令、限幅值、实际反馈、控制误差、anti-windup 和故障状态；
6. 删除或归档没有唯一物理用途的 22 列全局 command profile，不以新总线替代旧总线。

**出口条件：** Current、Power、Voltage 通过同一个 `SimulationInput` 入口进入同一个 plant；模型拓扑 checksum 不因用户侧边界改变；cEGR 的实际流量和组分来自物理网络反馈。

## 9. Phase 4：runner、结果和失败分类收口

**目标：** 脚本只负责配置、调度和审计，不承担物理计算，不让可选审计插件掩盖 plant 是否完成。

**活动 API 目标：**

| 入口 | 唯一职责 |
|---|---|
| `routeA_platform_default_parameters` | 返回平台参数和 source metadata |
| `routeA_validate_case` | 校验单位、范围、互斥边界和参数层 |
| `routeA_prepare_simulation_input` | 生成 `SimulationInput`、solver、初态和记录元数据 |
| `run_routeA_study` | 调度 `sim`/`parsim`，保存 case-level 摘要 |
| `routeA_assess_outputs` | 从同一 `SimulationOutput` 提取 y/z/KPI/失败分类 |
| `routeA_audit_model` | 结构、参数、来源、守恒和证据审计 |

现有 I/P/V runner、Stage 1 water ledger、气体闭合脚本和历史 matrix runner 暂时保留为兼容或证据入口；在 Phase 4 之前不继续扩展其 API。水账本、气体闭合和策略专项审计作为 assessment plugin 接入，不直接塞进物理模型。

**出口条件：** 一个最小 case 能由 runner 固定模型版本、参数来源、输入、solver、初态、输出目录和失败处理；结果摘要能区分“未运行、运行失败、运行完成但审计失败、运行完成且通过”。

## 10. Phase 5：分层验证、回归和推广

**目标：** 先完成可解释的最小 case，再扩大研究问题和工况矩阵。

**验证顺序：**

1. 子系统开环：供气、背压、cEGR 分流/混合、阳极回流/吹扫、热端和电负载边界；
2. 整机开环：冷态 nominal、cEGR=0、小幅 cEGR、额定附近和高负载代表性 case；
3. 闭环策略：低负荷高电位/O2 分压与自增湿权衡；
4. 专项扩展：高负荷排水、动态饥饿、主动泵寄生功耗、冷启动/怠速概念配置；
5. 回归和矩阵：只有代表性 case 通过后才允许执行正式大规模扫描。

**推广门：** 至少一个低负荷、一个额定附近和一个高负荷代表性 case 在当前 v2 模型、参数链和 solver 上由 agent 完成端到端验证；每个 case 都有模型版本、输入、结果摘要、失败栈和审计结论。不得用 v09 结果替代 v2 证据，也不得因脚本静态检查为 0 就提前交接矩阵。

## 11. 阶段执行记录契约

每个阶段必须在 [RouteA_v2_Execution_Record](../RouteA_v2_Execution_Record/README.md) 产生记录。记录文件命名为：

```text
R<phase>_<short-name>_<YYYYMMDD>_vNN.md
```

每份记录至少包含：

- 阶段、状态、日期、目标模型/脚本和执行人；
- 输入版本、前置记录、模型 hash/时间、参数层、solver 和 case；
- 允许修改范围、禁止修改范围、实际变更和未变更项；
- 操作步骤和关键命令；
- read-back、`model_check`、update/compile、最小仿真和磁盘保存证据；
- 结果、warning/error 分类、KPI、失败栈和证据路径；
- 出口条件逐项判定；
- 未决问题、暂停/回滚决定和下一阶段准入条件。

状态只允许使用：`PENDING`、`IN_PROGRESS`、`PASSED`、`PASSED_WITH_OPEN_RISKS`、`BLOCKED`、`DEFERRED`。`PASSED_WITH_OPEN_RISKS` 必须写明风险是否阻断下一阶段；不能用“基本完成”替代状态。

## 12. 明确禁止的推进方式

- 未通过 Phase 0/0.5 就进行大规模 `.slx` 重构；
- 为解决一个未闭合端口继续增加 Source_Conditioner、观测块或全局 command 字段；
- 用 Terminator、强制质量流源或脚本伪造实际流量/组分来掩盖物理缺口；
- 把氧稀释、自增湿、排水、低负荷高电位、动态饥饿、寄生功耗或冷启动影响项包装成新的 cEGR 独立物理源；
- 用 `model_check` warning 减少、编译通过、Code Analyzer 通过或 v09 结果证明 v2 运行正确；
- 为 Current/Power/Voltage、低中高负载或不同 cEGR 目标复制 `.slx` 和活动 runner；
- 在没有 source、单位、适用范围和验证目标的情况下添加默认数值；
- 清理 `slprj/`、`.slxc` 或运行缓存作为常规验证前置条件；
- 在阶段记录尚未写完、上一阶段尚未收口时直接进入下一阶段。
