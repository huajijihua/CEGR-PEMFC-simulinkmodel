# PEMFC-cEGR 项目规则

## 项目边界与规则层级

1. 本文件是 PEMFC-cEGR 的唯一项目级 agent 入口。Codex、Claude Code for VSCode、OpenCode 进入本目录后均先读取本文件。
2. 项目规则补充 CCswitch 全局基线；用户当次指令、当前项目指导文件和已启用 skill 中更具体且不冲突的规则优先。
3. 不在项目根目录创建 `CLAUDE.md`、`OPENCODE.md`、`SHARED_CONTEXT.md` 等重复规则文件。模型、服务商、账号、MCP、skills 与全局提示词均由 CCswitch 管理。

本项目研究阴极尾气循环 PEMFC 系统。先明确研究问题、模型边界、保真度、接口和验证方式，再选择最小足够的 MATLAB/Simulink、COMSOL、AMESim 或协同路线。

## Route A 当前主线

1. 系统级主线是 `04_Simulink物理网络模型/01_模型/RouteA_GasMixture_Derived/` 下的官方 Gas Mixture PEMFC 派生平台；COMSOL 仅用于局部机理、空间分布和关键部件校核，AMESim 资产仅以受控外部接口结果参与本项目。
2. 当前默认参数必须属于 `platform_default`；功率等级迁移使用 `scaling_rule`。10 kW 台架、DQ60、旧标定、公司临时资料和历史模型只可作为显式 `external_case` 或审计背景，不能进入默认参数链、默认模型架构或验收标准。
3. Route A 优先复用 MathWorks 官方模型、组件、求解器和工作区设置。自定义内容只覆盖 cEGR 特有支路、接口补丁和官方资产无法覆盖的最小范围。
4. 进入新的 `.slx` 结构、保真度或阶段性实施前，先读取：
   - `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_模型裁决与资产处置_v01.md`
   - `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_收敛实施路线图_v01.md`
5. 资产角色、外部案例恢复和历史参数边界见 `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_外部案例与归档资产索引_v01.md`；项目专属仿真工具链、COMSOL server 与协同接口约束见 `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/RouteA_cEGR_PEMFC_仿真工具链与协同接口约束_v01.md`。

## 执行与验证

1. 对明确的模型修改、参数研究或仿真任务，按一个逻辑切片连续完成读取、修改、读回和最小必要验证。保持会话连续，不为每个小改动创建快照、临时模型、诊断脚本或过程报告。
2. 每个活动模型或研究只维护一个可复用正式 runner；不复制 `.slx` 或 runner 来表达新工况。失败先处理首个真实阻塞原因，没有新证据不重复尝试或调整下游参数。
3. 对任何 MATLAB/Simulink 读取、参数解析、模型修改、结构检查、编译或仿真任务，第一步必须检查当前会话是否实际暴露 MATLAB MCP 与所需 SATK 能力；只有确认可用后才能继续任务。未暴露、连接失败或能力不足时，必须停止该 MATLAB/Simulink 任务并向用户报告阻塞原因；不得以 `matlab -batch`、MATLAB GUI、终端脚本或其他客户端会话作为替代执行面。
4. 结构化模型只使用已确认可用的 MATLAB MCP/SATK、COMSOL API/LiveLink 或 AMESim 官方 API。具体工具路由、客户端 session 和能力边界以当前客户端配置及对应 workflow skill 为准；不得假定其他客户端的 MCP、插件或 session 可用。
5. 长时间 MATLAB GUI 任务只有在流程、输入输出契约和验收判据固定，且 agent 已以同一模型、参数链和求解器完成代表性端到端 case 后，才可交接用户离线执行；正式研究通常还应预计约 30 分钟以上且覆盖 10 个以上工况或等量级矩阵。否则由 agent 继续完成或拆分为可验证切片。
6. 对所有修改区分已实现、结构读回、已执行、行为验证和适用范围内验证；无法闭环时明确未验证原因和剩余风险。

## 说明、保存与交付

1. `01_当前指导/` 是覆盖式更新的规划、裁决、接口和实施指导真源；`02_实施记录/01_当前分卷/` 只追加实际工作、读回证据、验证结果和未决风险。实施记录的触发与格式以 `02_实施记录/README.md` 为准。
2. 阶段完成、S 阶段收敛、阻塞性问题解决或新模型能力首次交付时，必须更新相应当前指导，并追加实施记录；运行前不得预写验证数值。
3. 阶段收口或 Git 提交前，先通过 MATLAB/Simulink 保存涉及的正式模型，确认 `Dirty=off`，核对正式文件已写盘及提交范围，再进行读回和必要验证。`.slx.autosave` 不替代正式模型。
4. `slprj/`、`.slxc` 与当前运行缓存默认保留且不纳入 Git。只保留模型、正式 runner、必要结果和最终报告；不默认导出完整日志、timeseries、模型树、工作区 dump、图片或冗余 CSV。

## 目录职责

| 位置 | 职责 |
|---|---|
| `00_支撑材料/` | 官方示例、文献和候选组件来源池，不定义当前模型要求。 |
| `04_Simulink物理网络模型/` | 当前 Route A 模型、runner、结果与说明工作树。 |
| `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/01_当前指导/` | 当前规划、裁决、接口、工具链与外部案例指导。 |
| `04_Simulink物理网络模型/04_说明/RouteA_GasMixture_Derived/02_实施记录/` | 实际实施证据与历史追溯。 |
| `99_历史归档/` | 唯一历史归档根目录；不在活动目录建立嵌套归档。 |
