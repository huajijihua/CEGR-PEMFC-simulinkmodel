# PEMFC-cEGR 项目规则

本文件是项目级规则，与全局 CLAUDE.md 互补。加载优先级：全局 CLAUDE.md → 本文件 → 当前任务上下文。

## 项目标识

- 项目目录：`E:\agentwork_pemfc_cEGR_0519`
- 研究问题：10 kW 级 PEMFC 阴极尾气循环（cEGR）系统建模与验证
- 与 Codex 对等共享此目录和输出路径。`AGENTS.md` 是 Codex 的补充规则，双方均读取，但 Claude Code 不照搬其手工作坊倾向——建模检查优先使用 SATK MCP 工具。

## 模型矩阵

| 分支 | 路径 | 状态 | 保真度 | 结构特征 |
|------|------|------|--------|----------|
| 车载系统 v3 | `01_自吸方案/01_车载系统_10kW_GZS60_v3/` | 已冻结 | L2 标定型 | 有 GZS60 膜加湿器，含中冷器/空压机 BOP |
| 台架测试 v1 | `01_自吸方案/02_台架测试_10kW/` | 可运行 | L2 标定型 | 无加湿器，DQ60 空压机等效（MAP 为图像数字化） |
| ★简化台架 v1 | `01_自吸方案/03_台架测试_10kW_简化版/` | **当前主线** | L2 标定型 | 无空压机/加湿器 BOP，直接以台架入堆条件为边界 |
| COMSOL 机理 | `02_多物理场机理模型演示/` | 活跃 | L3 高保真 | 2D PEMFC + cEGR，用于局部机理研究和参数校核 |

## 当前主线快速入口（简化台架 v1）

所有脚本从 `01_自吸方案/03_台架测试_10kW_简化版/02_脚本/` 运行：

| 用途 | 入口 | 说明 |
|------|------|------|
| 参数默认值 | `init_testbench_10kw_simplified_defaults.m` | 返回 P 结构体，含物性、标定参数、冷却曲线 |
| 工况装配 | `init_testbench_10kw_simplified_egr(caseIndex, dataMode)` | 从 `combined_noegr_cegr_fit_points.csv` 读取稳态点 |
| 电压标定 | `calibrate_testbench_10kw_simplified_egr.m` | 五参数活化 + 膜电导率修正 |
| 压力标定 | `calibrate_testbench_10kw_simplified_pressure.m` | 阴/阳极出口导纳和库存体积 |
| 温度标定 | `calibrate_testbench_10kw_simplified_temperature.m` | 冷却流量-换热曲线 |
| 批量审计 | `run_core_fix_v01_audit.m` | 回放全部 29 个统一工况点 |
| 自定义进气 | `run_testbench_10kw_simplified_custom_inlet_study.m` | 25°C/1atm/50%RH 新鲜空气 EGR 扫描 |
| 模型本体 | `../01_模型/CEGR_TestBench_10kW_SimplifiedEGR_v01.slx` | 7 个 MATLAB Function 模块 |

参数真源：`00_输入参数/标定参数/simplified_*.csv`。工况真源：`00_输入参数/实验数据/combined_noegr_cegr_fit_points.csv`（29点）。

## 工具链验证入口

进入项目后优先验证工具可达：

1. **MATLAB MCP**：SATK 7 个工具应可调用（`model_overview`、`model_read`、`model_edit`、`model_check`、`model_query_params`、`model_resolve_params`、`model_test`）；仿真通过 `evaluate_matlab_code` 调用 `sim()`
2. **COMSOL Server**：`localhost:2036`，优先 MATLAB LiveLink（`mphstart`），备份 Python/mph
3. **AMEsim**：`D:\amesimsoft\Simcenter_Amesim_2511\Amesim\AMEPython.bat`，主工作区 `E:\agentwork_AMEsim_0625`

## MCP 配置说明

- 配置源：`C:\Users\ADMIN\.claude.json` → `mcpServers.matlab`
- 附件模式：`--matlab-session-mode=existing`（唯一推荐模式，不搭配 `--matlab-root`）
- 扩展工具：`--extension-file` 指向 `simulink\tools\tools.json`
- `--matlab-root` 与 `existing` 模式互斥（v0.11.1 强制拒绝），仅在 launch 模式下使用

## 工作流纪律

### MATLAB/Simulink
- **model_overview 是强制第一步**——即使已读过模型，每个建模 session 先获取当前快照
- 首次探入用 `model_overview(detail=tree)`（最省 token），需端口信息时升级到 `interfaces`
- 结构修改链：`model_read(depth=0/1)` → `model_edit` → `model_check` → `model_read` 回读确认
- `model_check` 尽量指定 scope 到修改子系统而非整模型 root
- 参数修改：SATK `model_edit` 修改模型后，同步更新对应的 `init_*.m` 默认值
- 批量仿真/标定：沿用现有 MATLAB 脚本（`init → calibrate → run_study`），通过 `evaluate_matlab_code` 合并多步操作为一次调用
- `init_*_defaults.m` 中的 P 结构体是唯一参数真源（single source of truth）

### COMSOL
- 用户 GUI 打开 `.mph` 并连接同一 Server（`localhost:2036`）→ Claude Code 通过 LiveLink 操作
- 修改前后必有 read-back verification，追踪到具体 feature 节点 API 路径
- 脚本不得擅自保存 `.mph`；最终保存由 GUI 执行
- 求解前先局部粗网格 smoke test，不解即改全模型

### AMEsim
- 本项目 `03_AMEsim系统模型/` 不持有 `.ame` 模型，只放引用说明
- 协同时通过 `interface_contract` (JSON) 传递参数和结果
- 合同模板放在 `00_支撑材料/interface_contracts/`

### 建模修改前置检查
修改模型前必须明确定义：目标模型/子系统、工况、输入输出、控制量、验收指标、允许修改范围、禁止修改范围。修改后必须闭环验证，无法验证时标记为「未验证」。

## Token 节约规则（项目特有）

- 模型读取默认深度：`model_read(depth=0/1)`，禁止无理由的 `depth=inf` 全模型深读
- **model_overview 分级**：首次探入用 `detail=tree`（仅层级），需端口信息时 `interfaces`，只有连线分析时用 `full`
- **合并 `evaluate_matlab_code` 调用**：`addpath` + `init` + `sim` + KPI `fprintf` 合并为一次调用，避免多次往返
- **MCP 资源按需加载**：`guidelines://coding` 仅在写 MATLAB 代码时加载，不默认读取
- MATLAB 脚本输出：只向 Claude Code 返回关键 KPI、收敛结果和错误栈，禁止回传完整迭代 log
- 结果文件：只读前几行验证写入成功，不整表读入
- 禁止读取：`slprj/` 目录、`*.slxc` 缓存、`.slx` 原始 XML、`.mph` 二进制
- 任务结束只保留关键结论、文件路径和未决事项，不保留完整仿真日志和 timeseries
- `outputs/` 目录下历史 PPT 和相关 npm 包不应读入上下文

## 报告与评审纪律

- 区分假设、方法、关键结果、风险和后续建议
- 结论强度匹配模型成熟度和验证证据——不把预研趋势表述为工程标定结论
- 电压拟合排在边界/守恒/压力/湿度/热链路检查之后，不能用电压参数补偿其他模块残差
- EGR 机理未完成实验定量验证前，只能做趋势分析，不承诺定量性能
