# RouteA cEGR-PEMFC Platform Implementation Plan v01

文件类型：平台实施计划  
日期：2026-07-24（初稿）；2026-07-29（更新：cold-start-only 回归）
前置文档：[模型裁决与资产处置](RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md)、[收敛实施路线图](RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)、[系统规格](RouteA_cEGR_PEMFC_Platform_system_v01.md)、[架构规格](RouteA_cEGR_PEMFC_Platform_architecture_v01.md)

本文件是平台架构和低层实施参考；阶段顺序、模型版本裁决、面板信息架构和停止条件以[收敛实施路线图](RouteA_cEGR_PEMFC_收敛实施路线图_v01.md)、[面板-模型双向迭代规划](RouteA_cEGR_PEMFC_面板-模型双向迭代规划_v01.md)和当前阶段的具体实施计划为准。当前状态：S0/S1/S2/S3 已完成，S4 cold-start-only 与 Voltage purge 周期响应门已收口，S5 P0 3600 s 已完成，Hydrogen Source runtime warning 已关闭，77 条结构 warning 已逐条建账，P1 已形成面板直驱基础链，当前转入 P2 面板修复和操作性提升；研究矩阵后置。

P1 的核心实施入口为[RouteA cEGR-PEMFC P1 完整燃料电池系统面板基础版实施计划](RouteA_cEGR_PEMFC_P1_完整燃料电池系统面板基础版实施计划_v01.md)。本文件中的通用平台拆解不能替代该阶段计划，也不能把 P0 的准备能力描述为 P1 面板功能已完成。

## 1. 实施总原则

本轮目标是把当前 RouteA 已完成的官方派生、CEGR、BOP、控制、runner 和观测资产收敛成可长期维护的 L2 系统平台，不继续进行无规划的功能叠加，也不回退到官方案例重新起步。RouteA_v2 采用“官方案例 + CEGR 文献 + 当前 RouteA 现状”的证据保留式重构。每个阶段都必须经过“定位 -> 修改 -> read-back -> `model_check` -> 最小仿真 -> 记录”闭环；未闭环的模块只标记为候选，不进入默认平台。

当前 dirty worktree、v09 正式结果和 v10 局部结构全部保留。它们不被回滚或覆盖；在规格冻结前不进行新的 `.slx` 结构编辑。

## 2. Phase 0：冻结接口和处置现状 — ✅ 已完成

**出口条件：** 用户确认本规格包的边界、单一内部 `I_cmd`、cEGR 被动默认语义、参数层和验证顺序。

工作项：

1. 以当前 `.slx`、官方 Gas Mixture 母版和 CEGR 文献映射完成结构差异表；
2. 将当前资产按 `PRESERVE`、`REFACTOR`、`DEFER`、`HISTORICAL` 分类；`Cathode_Source_Conditioner`、`Anode_Source_Conditioner` 和 22 列 command profile 先标记为待处置实现，不得继续派生新结构；
3. 将 v09 三组 formal MAT 标记为冻结历史/回归证据，不作为新平台结构或 v10 初态证明；
4. 建立参数清单：每个参数记录名称、单位、源、适用范围、写入层和使用块；
5. 建立 warning ledger：区分工具 read-back 误报、合法接口端口、实际未连接端口和模型级错误；
6. 读取并确认 [CEGR 文献研究与模型映射](../03_审计与研究/RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md) 的 Phase 0.5 出口条件。

## 3. Phase 0.5：CEGR 文献证据与模型映射 — ✅ 已完成

此阶段是 RouteA_v2 的结构修改准入门，优先级高于任何 `.slx` 重构。具体证据矩阵、论文精读和接口口径见 [CEGR 文献研究与模型映射](../03_审计与研究/RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md)。

必须完成：

1. 先固定 cEGR 的物理气路边界：阴极出口分流、阀/泵/阻力设备、入口混合和排气支路；
2. 对核心论文记录对象规模、变量口径、机制、控制对象、适用范围和不可迁移参数；
3. 将当前模型的每个 cEGR/BOP/控制模块映射到“文献影响 - 模型变量 - 模块 - 验证工况”，不把影响项误写成新的 cEGR 控制结构；
4. 先选定一个 RouteA_v2 首个闭环验证用例，不同时开放低负荷、高负荷、动态饥饿和冷启动全部目标；
5. 明确阀开度、泵速、背压等实际执行器与上层回流比/O2 分压/电压目标之间的转换关系；
6. 把 `mdot_fresh`、`mdot_cegr`、`mdot_mix_in`、湿/干基回流比、`lambda_fresh`、`lambda_mix`、`pO2_in` 和 `RH_in` 的口径固定下来。

**出口条件：** 用户确认文献证据矩阵、首个用例、变量口径和当前资产处置表；在此之前不进行大规模结构修改。

## 4. Phase 1：RouteA_v2 证据保留式结构收敛 — ✅ 已完成

目标是在保留当前 RouteA 已完成的官方派生、CEGR 主气路、BOP、控制、runner 和观测资产的前提下，收敛未闭合的接口和执行器语义，使现有模型成为”当前 RouteA 气路 + 官方物理组件 + 文献约束的验证工况”的可解释状态。此阶段不是重建官方案例，也不是把当前模型整体替换成另一个模型。

1. 保留官方 MEA、阳极/阴极气体域、热端、加湿器、排气、背压和已验证的当前 RouteA 控制/观测资产；
2. 对当前 Source_Conditioner 逐端口读回并按物理职责处置，不用 Terminator 掩盖物理端口缺失，也不在尚未解释前直接整体删除；
3. 保留并核查当前 cEGR 主气路，确保它具有明确混合点、分流点、压降、执行器和排气支路；
4. 新鲜空气优先复用官方 Oxygen Source/Reservoir/Compressor 结构，避免多路独立物种质量源与真实混合气路径并存；
5. 阳极保留当前已经完成且与官方语义一致的部分，独立 Source_Conditioner 只有在证据和初态均闭合后才重新开放；
6. 同一 plant 通过 mode/configuration 表达不同研究用途，不复制 Current/Power/Voltage 或不同 cEGR 目的的 `.slx`。

**出口条件：** active physical ports 关闭；模型 update/compile 通过；一个与首个文献用例对应的冷态/热态短 smoke 不出现 DAE initial-condition failure；所有保留模块和停用模块均有记录。

## 4. Phase 2：建立参数单一真源

新增或重构一个平台参数入口，建议目标 API 为：

```matlab
platform = routeA_platform_default_parameters();
platform = routeA_apply_scaling_rule(platform, scalingRule);
caseCfg = routeA_merge_external_case(platform, externalCase, ...);
```

约束：

- `platform_default` 只包含官方基础参数和通用 L2 参数；
- `scaling_rule` 只做可追溯的几何/额定等级迁移；
- `study_command` 不写入物理参数；
- `external_case` 需要显式启用，并在结果 metadata 记录 source、版本和适用范围；
- 不再把 demo stop time、控制器 tuning、设备几何、历史标定和命令 profile 混在一个无层级脚本中；
- 不删除旧变量前先建立 compatibility adapter，确认活动模型已迁移后再归档。

**出口条件：** 参数审计能回答“这个值来自哪里、用于什么、是否可用于默认平台”，且同一参数没有多个活动写入点。

## 5. Phase 3：收缩控制接口

1. 以 `I_cmd` 为 plant 内部电负载接口；
2. 将 Power/Voltage 适配器整理为同一个 Electrical Load Controller，保留用户侧 I/P/V 语义但不产生三个模型变体；
3. 将气路命令改为分层结构体，只在 case 中提供需要变化的字段，未提供字段由 `platform_default` 继承；
4. 删除或归档 22 列 Demux/Goto 全局 profile，除非经验证某个字段确实需要成为模型级实时总线；
5. 每个控制器输出同时提供命令、限幅值、实际反馈和错误，避免脚本从多个 workspace 变量拼接语义。

**出口条件：** 一个 Current、一个 Power、一个 Voltage case 都能通过同一个 `SimulationInput` 装配入口进入同一个 plant 拓扑；不能出现三种结构 checksum。

## 6. Phase 4：最小 runner 和结果层

活动 runner 收口为以下职责：

| 入口 | 唯一职责 |
|---|---|
| `routeA_platform_default_parameters` | 返回平台参数对象和 source metadata |
| `routeA_validate_case` | 校验单位、范围、边界互斥和参数层 |
| `routeA_prepare_simulation_input` | 生成 `SimulationInput`、求解器和初态配置 |
| `run_routeA_study` | 调度 `sim`/`parsim`，保存 case-level 结果 |
| `routeA_assess_outputs` | 从同一 `SimulationOutput` 提取 y/z/KPI/失败分类 |
| `routeA_audit_model` | 结构、参数、来源和守恒审计 |

现有 I/P/V runner、stage1 water ledger 和历史 matrix runner 先保留为兼容/证据入口，不能再作为新平台 API 继续扩展。水账本、气体闭合和策略专项审计从核心调度中解耦为 assessment plugin，避免一个可选审计失败就模糊掉仿真是否完成。

## 7. Phase 5：分层验证和推广

按测试计划从子系统到整机推进。只有 L1/L2 平台门通过后，才开始扩大 cEGR、负载或参数矩阵。大规模运行不得先于 agent 用同一模型、参数链和 solver 完成代表性端到端 case。

## 8. 明确禁止的推进方式

- 不再增加新的 Source_Conditioner、观测块或全局 command 字段来绕过尚未解决的物理端口；
- 不用 `model_check` warning 被动增多来证明模型“更完整”；
- 不用编译通过替代冷态初始条件和短仿真证据；
- 不用 v09 formal 结果证明 v10 结构或新参数已经验证；
- 不把响应量改名为主动控制量；
- 不为 Current/Power/Voltage、低中高负载或 cEGR 案例复制 `.slx` 和 runner；
- 不在没有参数 source、单位和适用范围的情况下继续添加默认数值。
