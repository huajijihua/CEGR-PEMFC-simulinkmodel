# Claude-MATLAB MCP 会话分离说明

更新日期：2026-06-30

## 背景

Codex 和 Claude 都会使用 MATLAB MCP。MathWorks 的 `shareMATLABSession()` 会写入 `sessionDetails.json`，如果两个 agent 共用同一个 MCP session 根目录，后启动或后初始化的 MATLAB session 会覆盖前一个 session，导致 agent 可能 attach 到错误的 MATLAB。

因此，本机采用“普通 MATLAB 不注册 MCP；Codex/Claude 各自使用专用 MCP MATLAB GUI 和专用 session 根目录”的策略。

## 当前约定

1. 普通 MATLAB：只作为普通编程软件，不注册 MCP。
2. Codex 使用 MATLAB：通过桌面 `MATLAB_Agent_Launcher.hta` 的 `Codex MCP MATLAB` 按钮，或 `02_多物理场机理模型演示/02_脚本/start_codex_matlab_gui.ps1` 启动。
3. Claude 使用 MATLAB：通过桌面 `MATLAB_Agent_Launcher.hta` 的 `Claude MCP MATLAB` 按钮，或 `02_多物理场机理模型演示/02_脚本/start_claude_matlab_gui.ps1` 启动。
4. 两个 agent 同时使用 MATLAB 时，必须打开两个 MATLAB GUI。Claude 只 attach 命令窗口标记为 `CLAUDE` 的 session；Codex 只 attach 标记为 `CODEX` 的 session。
5. 如果出现 `Server is in use`、attach 失败、MATLAB MCP 工具未暴露，先检查启动器、角色标记、MCP 配置和 session 分离，不要换到另一个 agent 的 MATLAB GUI。

## session 根目录

- Codex session 根目录：`C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Codex`
- Claude session 根目录：`C:\Users\ADMIN\AppData\Roaming\MATLABMCP-Claude`

启动脚本会设置 `AGENT_MATLAB_MCP_APPDATA`。`startup.m` 正常运行 `satk_initialize`，然后调用 `C:\Users\ADMIN\Documents\MATLAB\register_agent_matlab_mcp_session.m`，把当前 MATLAB connector 信息写入角色专用 `sessionDetails.json`。这个机制不修改 MATLAB 进程的 `APPDATA`，所以 MATLAB 命令窗口里查询 `getenv("APPDATA")` 显示普通 Roaming 是正常状态。

## 已验证状态

2026-06-30 验证：Codex 客户端重启后正式暴露 `mcp__matlab` 工具，直接调用 `evaluate_matlab_code` 读回：

```text
pwd=E:\agentwork_pemfc_cEGR_0519
role=codex
mcp=1
appdata=C:\Users\ADMIN\AppData\Roaming
```

这说明正式 Codex MCP 工具已经 attach 到 Codex MATLAB session。此前用 Node 写的 MCP 探针只是诊断工具，不是后续工作流；后续应优先使用客户端正式暴露的 MATLAB MCP 工具。

## batch 的定位

`matlab.exe -batch` 不是禁用项，但不属于日常 agent-MCP 交互工作流。它适合可脱离 agent 交互的长时间任务，例如批量扫描、长时优化、夜间计算。

使用 batch 前应先通过 MCP GUI 完成小样本闭环，并明确输入、输出、日志和结果路径。batch 运行时 agent 不需要陪跑；运行结束后由 agent 读取结果、审计误差、定位失败点并决定下一轮优化。

## 已同步文件

- `C:\Users\ADMIN\.codex\config.toml`
- `C:\Users\ADMIN\.codex\AGENTS.md`
- `C:\Users\ADMIN\.claude\CLAUDE.md`
- `C:\Users\ADMIN\.claude\SHARED_CONTEXT.md`
- `C:\Users\ADMIN\Documents\MATLAB\startup.m`
- `C:\Users\ADMIN\Documents\MATLAB\register_agent_matlab_mcp_session.m`
- `E:\agentwork_pemfc_cEGR_0519\AGENTS.md`
- `E:\agentwork_pemfc_cEGR_0519\CLAUDE.md`
- `E:\agentwork_pemfc_cEGR_0519\01_自吸方案\项目Codex-MATLAB-Simulink工作流.md`
- `E:\agentwork_pemfc_cEGR_0519\02_多物理场机理模型演示\项目Codex-COMSOL工作流.md`
