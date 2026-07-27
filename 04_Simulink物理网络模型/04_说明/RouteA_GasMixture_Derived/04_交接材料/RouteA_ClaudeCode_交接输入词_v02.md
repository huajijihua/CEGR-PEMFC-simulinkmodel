# Claude Code 交接输入词 v02：Route A cEGR-PEMFC 收敛与验证

你现在接手的是 E:\agentwork_pemfc_cEGR_0519 内的 CEGR-PEMFC 长线程任务。请把本轮工作视为已有审计和模型裁决之后的连续实施，不要从零重建项目，也不要把历史模型重新混入当前主线。

## 必须先读的文件

1. 项目规则：E:\agentwork_pemfc_cEGR_0519\AGENTS.md
2. 说明目录索引：E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\README.md
3. 模型裁决：E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\01_当前指导\RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md
4. 收敛路线：E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\01_当前指导\RouteA_cEGR_PEMFC_收敛实施路线图_v01.md
5. 当前审计：E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\03_审计与研究\RouteA_cEGR_PEMFC_Platform_current-audit_20260724_v01.md
6. 系统、架构、实施和测试规格：
   - E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\01_当前指导\RouteA_cEGR_PEMFC_Platform_system_v01.md
   - E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\01_当前指导\RouteA_cEGR_PEMFC_Platform_architecture_v01.md
   - E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\01_当前指导\RouteA_cEGR_PEMFC_Platform_implementation-plan_v01.md
   - E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\01_当前指导\RouteA_cEGR_PEMFC_Platform_test-plan_v01.md
7. CEGR 文献映射：
   E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\03_审计与研究\RouteA_cEGR_PEMFC_literature-review-and-model-mapping_v01.md
8. 如需了解 v2 的历史实施状态，再读：
   E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\04_说明\RouteA_v2_Execution_Record\R00_baseline_and_interface_freeze_20260724_v02.md
   E:\agentwork_pemfc_cEGR_0519\RouteA_v2_PEMFC_cEGR_simulink\04_说明\RouteA_v2_Execution_Record\R01_phase1_physical_interface_convergence_20260724_v01.md

当前指导文件只从 01_当前指导/ 读取；实施证据只从 02_实施记录/ 读取；审计和文献只从 03_审计与研究/ 读取；交接词不属于模型规范。99_历史归档/2026-07-25_RouteA_说明整理/ 下的工程化建模规格 v01 仅供追溯，不得作为当前规划真源。

## 已冻结的模型裁决

- 唯一活动主模型：
  E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\01_模型\RouteA_GasMixture_Derived\PEMFuelCellSystem_GasMixture_cEGR_RouteA_v01.slx
- 官方 MathWorks Gas Mixture PEMFC 示例和 FuelCell_lib 是不可变参考内核。
- RouteA_v2 只允许作为隔离验证副本，不得发展成第二条主线、第二个参数真源或第二个正式 runner。
- RouteA_before、旧 Route B、旧台架模型、旧 runner 和 v09 MAT 只作为历史/外部案例证据。
- 默认参数必须保持 platform_default；external_case 必须显式启用并写入结果 metadata。
- Current、Power、Voltage 必须最终进入同一个内部 I_cmd，不得复制三套 plant 拓扑。

## 已知阻断项（更新于 2026-07-27）

以下阻断项已解决：
1. ~~当前阴极和阳极 Source_Conditioner 的混合 chamber 存在未闭合物理端口~~ — ✅ 已删除 Source_Conditioner
2. ~~冷态 DAE IC Failure~~ — ✅ 四个 cold smoke case 全部通过
3. ~~v09 结果不能证明 v10 结构~~ — ✅ S2/S3 已在当前 v10 结构上完成验证

当前剩余阻断项：
1. 初始状态文件 `RouteA_platform_default_initial_state.mat` 的 metadata 仍为 v09 schema，`routeA_attach_platform_default_initial_state.m` 拒绝加载。正式 runner 链需要通过该检查，当前验证均通过直接 SimulationInput 绕过。
2. Gate 4 动态验证尚未执行。

## 本次工作的目标 — 更新于 2026-07-27

以下阶段已完成：

S0 决策冻结：✅ 已完成 — 主模型裁决、资产处置、u/w/y/z 接口定义
S1 物理边界收敛：✅ 已完成 — Source_Conditioner 删除，恢复官方供气路径
S2 最小 plant：✅ 已完成 — 四个 cold smoke case 全部通过
S3 参数和控制收敛：✅ 已完成 — 恒电流/恒功率/恒电压 + cEGR 矩阵 + 入口组分控制全部完成

后续推进顺序：

S4 初态收敛：在当前主模型、当前参数链和当前拓扑 hash 下生成 v10 Current/Power/Voltage 初态，审计 schema、模型名、拓扑、参数层和冷热启动兼容性。
S5 分层验证：结构 -> 子系统开环 -> 整机开环 -> 闭环策略 -> 回归矩阵。Gate 0/0.5/1/2/3/4 未全部通过前，不跑正式大矩阵。
S6 CEGR 研究：按 cEGR=0/小回流、低负载、额定附近、负载动态、湿度/温度/背压/purge 扰动的顺序扩展；每个机制必须回到同一 plant 和同一 u/w/y/z 接口。

## 工具和修改纪律

- 进入 MATLAB/Simulink 时使用 Claude 专用 MATLAB MCP session，不抢占 Codex session；如果 MATLAB MCP 不可用，先报告阻断，不用 Python、临时脚本或 batch 冒充模型读回。
- 读取模型优先使用 model_overview、model_read、model_query_params、model_resolve_params、model_check。
- 修改 .slx 必须走 SATK/MATLAB/Simulink 官方 API；每次只做一个小变更，随后执行 read-back、model_check、update/compile、最小必要 smoke、显式保存和磁盘验证。
- 不直接修改 slx 二进制/XML；不新建第三个模型或按工况复制 runner。
- 不用 Terminator、人工质量源、放宽 solver 或删除 warning 来“制造通过”。
- 保留现有 dirty worktree、v09 结果、slprj、slxc 和运行缓存；不要未经说明清理或回滚用户资产。
- 不为了展示过程生成大量截图、CSV、模型副本或临时报告。

## 第一轮具体动作

1. 读完上述文件后，先对当前主模型做一次只读 model_overview/model_read/model_check，并确认当前文件 hash、solver、StopTime、模型 workspace 的 parameter layer 和 cEGR 状态。
2. 输出一份简洁的 S0 状态摘要，列出当前真实 warning、合法边界端口和未决 owner；将实际实施证据追加到 E:\agentwork_pemfc_cEGR_0519\04_Simulink物理网络模型\04_说明\RouteA_GasMixture_Derived\02_实施记录\01_当前分卷\，不要新建平行说明入口。
3. 建立或补充 warning ledger 和 Source_Conditioner 端口处置表，优先处理阴极和阳极 conditioner，不要先扩展控制字段；若新增表格或记录，放入当前实施分卷并在其 README/记录中注明。
4. 给出一个最小 S1 修改方案，明确目标路径、允许修改的 block、禁止修改的官方内核、预期 read-back 和 Gate 1/2 验收条件。
5. 在没有通过上述读回和方案核对前，不要直接进行大规模结构编辑或正式矩阵仿真。

每次回复都要报告：已读文件、实际证据、修改文件、模型 hash、model_check/compile/smoke 结果、未解决风险和下一步准入条件。若无法验证，明确写“未验证”，不要把脚本无报错或编译通过写成模型正确。
