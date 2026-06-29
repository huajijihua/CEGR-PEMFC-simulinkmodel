# 项目 Codex-MATLAB/Simulink 建模指导纲要

本文档不是单纯的工具配置说明，而是当前 PEMFC-cEGR 项目中 Codex 指导 MATLAB/Simulink 系统级建模，并与 COMSOL 高保真局部模型协同的工作纲要。工具链用于服务建模规格、物理一致性、验证闭环和 token 经济性。

## 当前工具链

- 主工具根目录：`C:\Users\ADMIN\.matlab\agentic-toolkits`
- MATLAB MCP Server：`C:\Users\ADMIN\.matlab\agentic-toolkits\bin\matlab-mcp-server.exe`
- MATLAB Agentic Toolkit：`C:\Users\ADMIN\.matlab\agentic-toolkits\matlab`
- Simulink Agentic Toolkit：`C:\Users\ADMIN\.matlab\agentic-toolkits\simulink`
- SATK 工具清单：`C:\Users\ADMIN\.matlab\agentic-toolkits\simulink\tools\tools.json`
- MATLAB MCP Server Toolbox：由 MATLAB Add-On Manager 管理，位于 `C:\Users\ADMIN\AppData\Roaming\MathWorks\MATLAB Add-Ons\Toolboxes\MATLAB MCP Server Toolbox`

当前验证版本：

- MATLAB：R2025b
- MATLAB MCP Server：v0.11.1
- MATLAB Agentic Toolkit：2026.06.18
- Simulink Agentic Toolkit：2026.06.24
- SATK 工具入口：7 个，包含 `model_check`

## 建模指导思想

1. 先定义研究问题、系统边界、模型层级、输入输出、状态变量、控制量、参数来源、验证方式和结论用途，再决定软件路线。
2. MATLAB/Simulink 是系统级主线，负责动态模型、控制策略、参数扫描、优化、拟合、数据处理和结果审计。
3. COMSOL 用于高保真局部机理、空间分布、多物理场耦合、边界条件和关键部件校核。
4. MATLAB/Simulink-COMSOL 协同用于把高保真局部响应转化为系统级参数、边界、代理模型、降阶模型或验证证据。
5. 经验拟合只能用于参数校准或局部插值，不能替代关键物理链路；低误差但破坏物理敏感性的结果应标记为不合格或限制用途。

## MATLAB/Simulink 自动建模主流程

1. 定义任务：目标模型、目标子系统、工况、输入输出、状态变量、控制量、验收指标、允许修改范围和禁止修改范围。
2. 建立模型规格：模块边界、信号单位、参数来源、核心方程、初始化逻辑、故障/边界工况和验证数据。
3. 只读定位优先使用 `model_overview`。
4. 需要局部结构和公式时，对目标子系统使用 `model_read(depth=0/1)`。
5. 参数和配置查询使用 `model_query_params`；变量引用解析使用 `model_resolve_params`。
6. 结构或参数修改使用 `model_edit`、MATLAB/Simulink API 或受控脚本。
7. 结构修改后先运行 `model_check`，再做 `model_read` 或 `model_query_params` 的读回确认。
8. 行为验证使用最小必要工况、已有脚本、`sim()`、`model_test` 或 MATLAB 单元测试。
9. MATLAB 本地完成数据处理和结果筛选，只把 KPI、摘要、失败栈和必要证据带回 Codex。

## MATLAB/Simulink-COMSOL 协同纲要

1. 协同前先固定 `interface_contract`：参数名、单位、输入工况、边界变量、COMSOL 探针/派生值、结果读取方式、模型版本和验收指标。
2. 优先用 Simulink 做系统级快速扫描和控制策略筛选，只把强耦合、强敏感、强约束或需要空间分布证据的局部问题交给 COMSOL。
3. COMSOL 结果回灌到系统模型时，必须保留单位、适用范围、误差指标、插值/拟合边界和物理解释。
4. 协同验证从小到大推进：接口读回、单工况 smoke test、关键 KPI 对照、小样本扫描、必要时再做批量工况。
5. 大批量扫描或长时间求解可由 MATLAB、COMSOL batch 或集群流程编排；GUI 主要用于模型检查、关键节点确认和最终保存。

## Token 控制规则

- 不默认全模型 `depth=inf` 深读。
- 不默认回传完整仿真日志、完整 timeseries、完整模型树、完整场数据或工作区 dump。
- 不默认导出图片、CSV、模型副本或报告。
- 需要中间产物时，放入任务专用目录，并在任务结束时说明保留原因。

## 常用验证命令

在 PowerShell 中检查 MCP Server：

```powershell
& "C:\Users\ADMIN\.matlab\agentic-toolkits\bin\matlab-mcp-server.exe" --version
```

在 MATLAB 中检查 SATK：

```matlab
addpath("C:\Users\ADMIN\AppData\Roaming\MathWorks\MATLAB Add-Ons\Toolboxes\MATLAB MCP Server Toolbox")
addpath("C:\Users\ADMIN\.matlab\agentic-toolkits\simulink")
cd("C:\Users\ADMIN\.matlab\agentic-toolkits\simulink")
validate_installation
which model_check
```

## 排错入口

- 如果 MATLAB 启动时报 `shareMATLABSession failed`，检查 `C:\Users\ADMIN\Documents\MATLAB\startup.m` 是否添加了 MATLAB MCP Server Toolbox 路径。
- 如果 Codex 看不到 SATK 新工具，检查 `C:\Users\ADMIN\.codex\config.toml` 的 `--extension-file` 是否指向新版 `simulink\tools\tools.json`。
- 如果技能说明仍指向旧路径，检查 `C:\Users\ADMIN\.agents\skills` 中的链接目标是否指向 `agentic-toolkits\matlab` 和 `agentic-toolkits\simulink`。
